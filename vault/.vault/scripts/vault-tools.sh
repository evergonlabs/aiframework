#!/usr/bin/env bash
# vault-tools.sh — Vault maintenance and operational tooling
# Usage: vault-tools.sh <command> [options]
#
# Commands:
#   lint [--report]       Full vault quality scan against all hard rules
#   validate <file>       Single-file frontmatter validation
#   orphans               Find pages with no inbound wikilinks
#   stale [days]          Find content exceeding staleness thresholds
#   tag-audit             Validate all tags against approved taxonomy
#   content-audit         Detect injection patterns in content
#   status                Vault operational status summary
#   stats                 Page counts, tag usage, link density
#   index-rebuild         Regenerate wiki/index.md from existing files
#   init-hooks            Install git pre-commit hooks
#   doctor                Full diagnostic (runs all checks)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib-utils.sh
source "$SCRIPT_DIR/lib-utils.sh"
# shellcheck source=lib-lint.sh
source "$SCRIPT_DIR/lib-lint.sh"

VAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WIKI_DIR="$VAULT_ROOT/wiki"
MEMORY_DIR="$VAULT_ROOT/memory"
INDEX_FILE="$WIKI_DIR/index.md"
LOG_FILE="$WIKI_DIR/log.md"
TAGS_FILE="$VAULT_ROOT/.vault/rules/tags.md"
STALENESS_CONFIG="$VAULT_ROOT/.vault/schemas/content-policy.json"

# ── Commands ──

cmd_lint() {
  local report_mode=false
  [[ "${1:-}" == "--report" ]] && report_mode=true

  echo "============================================"
  echo "  Vault Lint — Full Quality Scan"
  echo "============================================"
  echo ""

  local total_errors=0
  lint_all "$VAULT_ROOT" || total_errors=$?

  echo ""
  echo "--------------------------------------------"
  if [[ $total_errors -eq 0 ]]; then
    log_pass "Vault lint PASSED — all checks clean"
  else
    log_fail "Vault lint FAILED — $total_errors rule group(s) with violations"
  fi

  if $report_mode; then
    local report_file="$VAULT_ROOT/.vault/lint-report-$(date +%Y%m%d-%H%M%S).txt"
    {
      echo "Vault Lint Report — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo "Errors: $total_errors"
    } > "$report_file"
    log_info "Report saved to: $report_file"
  fi

  return $((total_errors > 0 ? 1 : 0))
}

cmd_validate() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    log_fail "Usage: vault-tools.sh validate <file>"
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    # Try relative to vault root
    file="$VAULT_ROOT/$file"
  fi

  if [[ ! -f "$file" ]]; then
    log_fail "File not found: $1"
    return 1
  fi

  echo "Validating: $(rel_path "$file" "$VAULT_ROOT")"
  echo ""

  local errors=0

  # Check frontmatter exists
  if ! has_frontmatter "$file"; then
    log_fail "No YAML frontmatter found"
    return 1
  fi
  log_pass "Has YAML frontmatter"

  # Check required fields
  local required_fields=("title" "type" "created" "updated" "status" "tags")
  for field in "${required_fields[@]}"; do
    local val
    val=$(get_frontmatter_field "$file" "$field")
    if [[ -n "$val" || "$field" == "tags" ]]; then
      log_pass "Field present: $field"
    else
      log_fail "Missing required field: $field"
      errors=$((errors + 1))
    fi
  done

  # Check tags
  local tag_count
  tag_count=$(get_frontmatter_tags "$file" | grep -c . || true)
  if [[ "$tag_count" -gt 0 ]]; then
    log_pass "Has $tag_count tag(s)"

    # Validate each tag
    local approved
    approved=$(load_approved_tags "$VAULT_ROOT")
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      if validate_tag "$tag" "$approved"; then
        log_pass "  Tag OK: $tag"
      else
        log_fail "  Unapproved tag: $tag"
        errors=$((errors + 1))
      fi
    done < <(get_frontmatter_tags "$file")
  else
    log_fail "No tags found"
    errors=$((errors + 1))
  fi

  # Check line count
  local lines
  lines=$(count_lines "$file")
  if [[ $lines -gt 400 ]]; then
    log_fail "Line count: $lines (BLOCK limit: 400)"
    errors=$((errors + 1))
  elif [[ $lines -gt 200 ]]; then
    log_warn "Line count: $lines (WARN limit: 200)"
  else
    log_pass "Line count: $lines"
  fi

  # Check wikilinks
  local wl_count
  wl_count=$(count_wikilinks "$file")
  if [[ "$wl_count" -ge 3 ]]; then
    log_pass "Wikilinks: $wl_count (meets SR-003 minimum)"
  else
    log_warn "Wikilinks: $wl_count (SR-003 recommends >= 3)"
  fi

  echo ""
  if [[ $errors -eq 0 ]]; then
    log_pass "Validation PASSED"
  else
    log_fail "Validation FAILED — $errors error(s)"
  fi
  return $((errors > 0 ? 1 : 0))
}

cmd_orphans() {
  echo "============================================"
  echo "  Orphan Detection"
  echo "============================================"
  echo ""

  if [[ ! -f "$INDEX_FILE" ]]; then
    log_fail "wiki/index.md not found"
    return 1
  fi

  local index_content
  index_content=$(cat "$INDEX_FILE")
  local orphan_count=0

  # Find files not in index
  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    [[ "$rel" == "wiki/index.md" || "$rel" == "wiki/log.md" ]] && continue

    if ! echo "$index_content" | grep -qF "$rel"; then
      log_warn "Orphan (not in index): $rel"
      orphan_count=$((orphan_count + 1))
    fi
  done < <(find "$WIKI_DIR" -name "*.md" -type f -print0 2>/dev/null)

  # Find pages with no inbound wikilinks from other pages
  echo ""
  echo "--- Inbound Link Analysis ---"
  local all_links=""
  while IFS= read -r -d '' file; do
    all_links="${all_links}$(extract_wikilinks "$file")
"
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  while IFS= read -r -d '' file; do
    local slug
    slug=$(basename "$file" .md)
    [[ "$slug" == "index" || "$slug" == "log" ]] && continue

    if ! echo "$all_links" | grep -qxF "$slug"; then
      log_warn "No inbound links: $slug ($(rel_path "$file" "$VAULT_ROOT"))"
      orphan_count=$((orphan_count + 1))
    fi
  done < <(find "$WIKI_DIR" -name "*.md" -type f -print0 2>/dev/null)

  echo ""
  if [[ $orphan_count -eq 0 ]]; then
    log_pass "No orphans detected"
  else
    log_warn "Found $orphan_count orphan issue(s)"
  fi
}

cmd_stale() {
  local threshold_days="${1:-}"

  echo "============================================"
  echo "  Staleness Check"
  echo "============================================"
  echo ""

  local stale_count=0

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    local dir_type
    dir_type=$(echo "$rel" | cut -d'/' -f1-2)

    # Determine threshold based on content type
    local max_age=30
    case "$dir_type" in
      wiki/sources)     max_age=14 ;;
      wiki/concepts)    max_age=30 ;;
      wiki/entities)    max_age=60 ;;
      wiki/comparisons) max_age=90 ;;
      memory/decisions) max_age=180 ;;
      memory/notes)     max_age=7 ;;
    esac

    # Override with explicit threshold if provided
    [[ -n "$threshold_days" ]] && max_age="$threshold_days"

    local age
    age=$(file_age_days "$file")

    if [[ $age -gt $max_age ]]; then
      local updated
      updated=$(get_frontmatter_field "$file" "updated")
      log_warn "STALE: $rel — ${age}d old (max: ${max_age}d, updated: ${updated:-unknown})"
      stale_count=$((stale_count + 1))
    fi
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  echo ""
  if [[ $stale_count -eq 0 ]]; then
    log_pass "No stale content detected"
  else
    log_warn "Found $stale_count stale file(s)"
  fi
}

cmd_tag_audit() {
  echo "============================================"
  echo "  Tag Audit"
  echo "============================================"
  echo ""

  local approved
  approved=$(load_approved_tags "$VAULT_ROOT")
  if [[ -z "$approved" ]]; then
    log_fail "Cannot load approved tags from tags.md"
    return 1
  fi

  local approved_count
  approved_count=$(echo "$approved" | wc -l | tr -d ' ')
  log_info "Approved tags in taxonomy: $approved_count"
  echo ""

  local invalid_count=0
  local used_tags=""

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      used_tags="${used_tags}${tag}
"
      if ! validate_tag "$tag" "$approved"; then
        log_fail "Unapproved: '$tag' in $rel"
        invalid_count=$((invalid_count + 1))
      fi
      if ! validate_tag_format "$tag"; then
        log_fail "Bad format: '$tag' in $rel"
        invalid_count=$((invalid_count + 1))
      fi
    done < <(get_frontmatter_tags "$file")
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  # Show tag usage stats
  echo ""
  echo "--- Tag Usage ---"
  if [[ -n "$used_tags" ]]; then
    echo "$used_tags" | sort | uniq -c | sort -rn | head -20
  fi

  # Show unused approved tags
  echo ""
  echo "--- Unused Tags (from taxonomy) ---"
  local unused_count=0
  while IFS= read -r tag; do
    if ! echo "$used_tags" | grep -qxF "$tag"; then
      unused_count=$((unused_count + 1))
    fi
  done <<< "$approved"
  log_info "$unused_count approved tags are not yet in use"

  echo ""
  if [[ $invalid_count -eq 0 ]]; then
    log_pass "Tag audit PASSED"
  else
    log_fail "Tag audit FAILED — $invalid_count violation(s)"
  fi
  return $((invalid_count > 0 ? 1 : 0))
}

cmd_content_audit() {
  echo "============================================"
  echo "  Content Audit — Injection Detection"
  echo "============================================"
  echo ""

  local policy_file="$VAULT_ROOT/.vault/schemas/content-policy.json"
  local issues=0

  if [[ ! -f "$policy_file" ]]; then
    log_warn "content-policy.json not found; using built-in patterns"
  fi

  # Built-in injection patterns
  local -a patterns=(
    "(?i)(ignore|disregard|forget)\s+(all\s+)?(previous|above|prior)\s+(instructions?|rules?|constraints?)"
    "(?i)you\s+are\s+now\s+(a|an|the)\s+"
    "(?i)<!--.*(?:ignore|override|bypass).*-->"
    "(?i)\[\s*(?:INST|SYSTEM|PROMPT)\s*\]"
    "(?i)do\s+not\s+follow\s+(the\s+)?rules"
    "(?i)execute\s+(this\s+)?(bash|shell|command|script)"
  )

  local -a pattern_names=(
    "INJ-001: Instruction override attempt"
    "INJ-002: Role reassignment attempt"
    "INJ-004: Hidden HTML override"
    "INJ-005: Fake instruction block"
    "INJ-006: Rule bypass instruction"
    "INJ-007: Embedded command execution"
  )

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    local content
    content=$(cat "$file")

    for i in "${!patterns[@]}"; do
      if echo "$content" | grep -qP "${patterns[$i]}" 2>/dev/null; then
        log_fail "${pattern_names[$i]} in: $rel"
        issues=$((issues + 1))
      fi
    done
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" "$VAULT_ROOT/raw" -name "*.md" -type f -print0 2>/dev/null)

  echo ""
  if [[ $issues -eq 0 ]]; then
    log_pass "Content audit PASSED — no injection patterns detected"
  else
    log_fail "Content audit FAILED — $issues potential injection(s) found"
  fi
  return $((issues > 0 ? 1 : 0))
}

cmd_status() {
  echo "============================================"
  echo "  Vault Status"
  echo "============================================"
  echo ""

  # Directory existence
  local dirs=("raw" "wiki/sources" "wiki/concepts" "wiki/entities" "wiki/comparisons" "memory/decisions" "memory/notes" ".vault/scripts" ".vault/rules" ".vault/schemas" ".vault/hooks" "docs" "templates")
  local missing=0
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$VAULT_ROOT/$dir" ]]; then
      log_fail "Missing: $dir/"
      missing=$((missing + 1))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    log_pass "All ${#dirs[@]} directories present"
  fi

  # Key files
  echo ""
  local key_files=("wiki/index.md" "wiki/log.md" "memory/status.md" ".vault/rules/hard-rules.md" ".vault/rules/soft-rules.md" ".vault/rules/tags.md" ".vault/schemas/wiki-entry.json" ".vault/.initialized")
  for kf in "${key_files[@]}"; do
    if [[ -f "$VAULT_ROOT/$kf" ]]; then
      log_pass "Found: $kf"
    else
      log_fail "Missing: $kf"
    fi
  done

  # Git status
  echo ""
  if git -C "$VAULT_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
    local branch
    branch=$(git -C "$VAULT_ROOT" branch --show-current 2>/dev/null || echo "detached")
    log_info "Git branch: $branch"
    local staged
    staged=$(git -C "$VAULT_ROOT" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    local modified
    modified=$(git -C "$VAULT_ROOT" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    log_info "Staged: $staged  Modified: $modified"
  else
    log_info "Not inside a git repository"
  fi
}

cmd_stats() {
  echo "============================================"
  echo "  Vault Statistics"
  echo "============================================"
  echo ""

  # Page counts by type
  echo "--- Page Counts ---"
  local total=0
  for subdir in sources concepts entities comparisons; do
    local count
    count=$(find "$WIKI_DIR/$subdir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  wiki/$subdir: $count"
    total=$((total + count))
  done
  for subdir in decisions notes; do
    local count
    count=$(find "$MEMORY_DIR/$subdir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  memory/$subdir: $count"
    total=$((total + count))
  done
  local special=0
  for f in index.md log.md; do
    [[ -f "$WIKI_DIR/$f" ]] && special=$((special + 1))
  done
  [[ -f "$MEMORY_DIR/status.md" ]] && special=$((special + 1))
  echo "  Special files: $special"
  echo "  Total: $((total + special))"

  # Raw file count
  echo ""
  local raw_count
  raw_count=$(find "$VAULT_ROOT/raw" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "--- Raw Sources ---"
  echo "  Files: $raw_count"

  # Tag usage
  echo ""
  echo "--- Tag Usage (top 15) ---"
  local all_tags=""
  while IFS= read -r -d '' file; do
    all_tags="${all_tags}$(get_frontmatter_tags "$file")
"
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  if [[ -n "$all_tags" ]]; then
    echo "$all_tags" | grep -v '^$' | sort | uniq -c | sort -rn | head -15 | sed 's/^/  /'
  else
    echo "  (no tags found)"
  fi

  # Link density
  echo ""
  echo "--- Link Density ---"
  local total_links=0
  local total_pages=0
  while IFS= read -r -d '' file; do
    local wl
    wl=$(count_wikilinks "$file")
    total_links=$((total_links + wl))
    total_pages=$((total_pages + 1))
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $total_pages -gt 0 ]]; then
    local avg
    avg=$(echo "scale=1; $total_links / $total_pages" | bc 2>/dev/null || echo "n/a")
    echo "  Total wikilinks: $total_links"
    echo "  Total pages: $total_pages"
    echo "  Average links/page: $avg"
  fi
}

cmd_index_rebuild() {
  echo "============================================"
  echo "  Index Rebuild"
  echo "============================================"
  echo ""

  local today
  today=$(date +%Y-%m-%d)

  # Collect entries
  local entries=""
  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    [[ "$rel" == "wiki/index.md" || "$rel" == "wiki/log.md" ]] && continue

    local slug
    slug=$(basename "$file" .md)
    local page_type
    page_type=$(get_frontmatter_field "$file" "type")
    [[ -z "$page_type" ]] && page_type=$(basename "$(dirname "$file")")
    local created
    created=$(get_frontmatter_field "$file" "created")
    [[ -z "$created" ]] && created="$today"
    local status
    status=$(get_frontmatter_field "$file" "status")
    [[ -z "$status" ]] && status="current"
    local primary_tag
    primary_tag=$(get_frontmatter_tags "$file" | head -1)
    [[ -z "$primary_tag" ]] && primary_tag="-"

    entries="${entries}| ${slug} | ${rel} | ${page_type} | ${created} | ${status} | ${primary_tag} |
"
  done < <(find "$WIKI_DIR" -name "*.md" -type f -print0 2>/dev/null | sort -z)

  cat > "$INDEX_FILE" << REBUILDEOF
---
title: "Wiki Index"
type: index
created: "${today}"
updated: "${today}"
status: current
tags:
  - type/index
  - lifecycle/active
owner: system
confidence: high
---

# Wiki Index

> Auto-rebuilt on ${today} by vault-tools.sh. Review and verify freshness values.

## Entries

| Slug | Path | Type | Created | Status | Primary Tag |
|------|------|------|---------|--------|-------------|
${entries}
## Conventions

- **Type**: one of \`source\`, \`concept\`, \`entity\`, \`comparison\`, \`decision\`
- **Status**: \`draft\`, \`current\`, \`stale\`, \`archived\`
- Every entry must be reachable from this index (HR-008)
REBUILDEOF

  log_pass "Index rebuilt at wiki/index.md"
}

cmd_init_hooks() {
  echo "============================================"
  echo "  Hook Installation"
  echo "============================================"
  echo ""

  local repo_root
  if ! repo_root=$(git -C "$VAULT_ROOT" rev-parse --show-toplevel 2>/dev/null); then
    log_fail "Not inside a git repository — cannot install hooks"
    return 1
  fi

  local hooks_dir="$repo_root/.git/hooks"
  local pre_commit_src="$VAULT_ROOT/.vault/hooks/pre-commit.sh"

  if [[ ! -f "$pre_commit_src" ]]; then
    log_fail "pre-commit.sh not found at .vault/hooks/"
    return 1
  fi

  cp "$pre_commit_src" "$hooks_dir/pre-commit"
  chmod +x "$hooks_dir/pre-commit"

  log_pass "Pre-commit hook installed to $hooks_dir/pre-commit"
}

cmd_doctor() {
  echo "============================================"
  echo "  Vault Doctor — Full Diagnostic"
  echo "============================================"
  echo ""
  local issues=0

  echo ">>> Status Check"
  cmd_status
  echo ""

  echo ">>> Lint (all hard rules)"
  cmd_lint || issues=$((issues + 1))
  echo ""

  echo ">>> Tag Audit"
  cmd_tag_audit || issues=$((issues + 1))
  echo ""

  echo ">>> Content Audit"
  cmd_content_audit || issues=$((issues + 1))
  echo ""

  echo ">>> Orphan Check"
  cmd_orphans
  echo ""

  echo ">>> Staleness Check"
  cmd_stale
  echo ""

  echo ">>> Statistics"
  cmd_stats
  echo ""

  echo "============================================"
  if [[ $issues -eq 0 ]]; then
    log_pass "Doctor: Vault is healthy"
  else
    log_fail "Doctor: $issues check group(s) reported issues"
  fi
  return $((issues > 0 ? 1 : 0))
}

# ── Main Dispatch ──
case "${1:-help}" in
  lint)          shift; cmd_lint "$@" ;;
  validate)      shift; cmd_validate "$@" ;;
  orphans)       cmd_orphans ;;
  stale)         shift; cmd_stale "$@" ;;
  tag-audit)     cmd_tag_audit ;;
  content-audit) cmd_content_audit ;;
  status)        cmd_status ;;
  stats)         cmd_stats ;;
  index-rebuild) cmd_index_rebuild ;;
  init-hooks)    cmd_init_hooks ;;
  doctor)        cmd_doctor ;;
  help|--help|-h|*)
    echo "vault-tools.sh — Vault maintenance and operational tooling"
    echo ""
    echo "Usage: vault-tools.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  lint [--report]       Full vault quality scan against all hard rules"
    echo "  validate <file>       Single-file frontmatter validation"
    echo "  orphans               Find pages with no inbound wikilinks"
    echo "  stale [days]          Find content exceeding staleness thresholds"
    echo "  tag-audit             Validate all tags against approved taxonomy"
    echo "  content-audit         Detect injection patterns in content"
    echo "  status                Vault operational status summary"
    echo "  stats                 Page counts, tag usage, link density"
    echo "  index-rebuild         Regenerate wiki/index.md from existing files"
    echo "  init-hooks            Install git pre-commit hooks"
    echo "  doctor                Full diagnostic (runs all checks)"
    ;;
esac
