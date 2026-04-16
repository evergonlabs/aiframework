#!/usr/bin/env bash
# lib-lint.sh — Individual lint check functions for each hard rule.
# Source this file after lib-utils.sh; do not execute directly.

# Each function returns 0 on pass, 1 on failure.
# Each function prints its own diagnostics.

# HR-001: raw/ immutability (check via git — files in raw/ should not appear in staged changes)
lint_hr001_raw_immutability() {
  local vault_root="$1"
  local raw_dir="$vault_root/raw"
  local errors=0

  if [[ ! -d "$raw_dir" ]]; then
    log_warn "HR-001: raw/ directory does not exist"
    return 0
  fi

  # If inside a git repo, check for staged modifications to raw/
  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local modified
    modified=$(git -C "$vault_root" diff --cached --name-only -- "raw/" 2>/dev/null)
    if [[ -n "$modified" ]]; then
      log_fail "HR-001: Staged modifications detected in raw/ (immutable):"
      echo "$modified" | sed 's/^/         /'
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-001: raw/ immutability"
  fi
  return $errors
}

# HR-002: Mandatory YAML frontmatter
lint_hr002_frontmatter() {
  local vault_root="$1"
  local errors=0
  local required_fields=("title" "type" "created" "updated" "status" "tags")

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")

    if ! has_frontmatter "$file"; then
      log_fail "HR-002: Missing frontmatter: $rel"
      ((errors++))
      continue
    fi

    for field in "${required_fields[@]}"; do
      local val
      val=$(get_frontmatter_field "$file" "$field")
      if [[ -z "$val" && "$field" != "tags" ]]; then
        log_fail "HR-002: Missing field '$field' in: $rel"
        ((errors++))
      fi
    done

    # Check tags separately (it's a list)
    local tag_count
    tag_count=$(get_frontmatter_tags "$file" | grep -c . || true)
    if [[ "$tag_count" -eq 0 ]]; then
      log_fail "HR-002: No tags found in: $rel"
      ((errors++))
    fi
  done < <(find "$vault_root/wiki" "$vault_root/memory" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-002: All files have valid frontmatter"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-003: Tags from approved taxonomy only
lint_hr003_approved_tags() {
  local vault_root="$1"
  local errors=0
  local approved
  approved=$(load_approved_tags "$vault_root")

  if [[ -z "$approved" ]]; then
    log_warn "HR-003: Could not load approved tags from tags.md"
    return 0
  fi

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      if ! validate_tag "$tag" "$approved"; then
        log_fail "HR-003: Unapproved tag '$tag' in: $rel"
        ((errors++))
      fi
      if ! validate_tag_format "$tag"; then
        log_fail "HR-003: Invalid tag format '$tag' in: $rel (must be prefix/value)"
        ((errors++))
      fi
    done < <(get_frontmatter_tags "$file")
  done < <(find "$vault_root/wiki" "$vault_root/memory" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-003: All tags are from approved taxonomy"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-004: Wiki page length limit (200 warn / 400 block)
lint_hr004_wiki_length() {
  local vault_root="$1"
  local errors=0
  local warnings=0

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    local lines
    lines=$(count_lines "$file")

    if [[ $lines -gt 400 ]]; then
      log_fail "HR-004: BLOCK — $rel has $lines lines (max 400)"
      ((errors++))
    elif [[ $lines -gt 200 ]]; then
      log_warn "HR-004: WARN — $rel has $lines lines (target < 200)"
      ((warnings++))
    fi
  done < <(find "$vault_root/wiki" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
    log_pass "HR-004: All wiki pages within length limits"
  elif [[ $errors -eq 0 ]]; then
    log_warn "HR-004: $warnings page(s) approaching limit"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-005: Code file length limit (400 warn / 600 block)
lint_hr005_code_length() {
  local vault_root="$1"
  local errors=0

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    local lines
    lines=$(count_lines "$file")

    if [[ $lines -gt 600 ]]; then
      log_fail "HR-005: BLOCK — $rel has $lines lines (max 600)"
      ((errors++))
    elif [[ $lines -gt 400 ]]; then
      log_warn "HR-005: WARN — $rel has $lines lines (target < 400)"
    fi
  done < <(find "$vault_root/.vault/scripts" -name "*.sh" -type f -print0 2>/dev/null; find "$vault_root/.vault/schemas" -name "*.json" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-005: All code files within length limits"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-006: Unique page titles
lint_hr006_unique_titles() {
  local vault_root="$1"
  local errors=0
  local seen_titles=""
  local seen_files=""

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    local title
    title=$(get_frontmatter_field "$file" "title")
    [[ -z "$title" ]] && continue

    if echo "$seen_titles" | grep -qF "|$title|"; then
      log_fail "HR-006: Duplicate title '$title' in: $rel"
      ((errors++))
    else
      seen_titles="${seen_titles}|${title}|"
    fi
  done < <(find "$vault_root/wiki" "$vault_root/memory" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-006: All page titles are unique"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-008: Index registration required
lint_hr008_index_registration() {
  local vault_root="$1"
  local index_file="$vault_root/wiki/index.md"
  local errors=0

  if [[ ! -f "$index_file" ]]; then
    log_fail "HR-008: wiki/index.md not found"
    return 1
  fi

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    # Skip index.md and log.md themselves
    [[ "$rel" == "wiki/index.md" || "$rel" == "wiki/log.md" ]] && continue

    if ! is_indexed "$rel" "$index_file"; then
      log_fail "HR-008: Unregistered page: $rel"
      ((errors++))
    fi
  done < <(find "$vault_root/wiki" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-008: All wiki pages are registered in index"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-010: Binary file quarantine
lint_hr010_binary_quarantine() {
  local vault_root="$1"
  local errors=0

  while IFS= read -r -d '' file; do
    local ext="${file##*.}"
    if [[ "$ext" != "md" && "$ext" != "json" ]]; then
      local rel
      rel=$(rel_path "$file" "$vault_root")
      log_fail "HR-010: Non-md/json file in wiki/memory: $rel"
      ((errors++))
    fi
  done < <(find "$vault_root/wiki" "$vault_root/memory" -type f -print0 2>/dev/null)

  # Check for symlinks
  while IFS= read -r -d '' link; do
    local rel
    rel=$(rel_path "$link" "$vault_root")
    log_fail "HR-010: Symlink detected in wiki/memory: $rel"
    ((errors++))
  done < <(find "$vault_root/wiki" "$vault_root/memory" -type l -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-010: No binary files or symlinks in wiki/memory"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-011: .vault/ protection (check staged changes)
lint_hr011_vault_protection() {
  local vault_root="$1"
  local errors=0

  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local protected_changes
    protected_changes=$(git -C "$vault_root" diff --cached --name-only -- ".vault/rules/" ".vault/hooks/" ".vault/scripts/" ".vault/schemas/" 2>/dev/null)
    if [[ -n "$protected_changes" ]]; then
      log_fail "HR-011: Staged changes to protected .vault/ paths:"
      echo "$protected_changes" | sed 's/^/         /'
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-011: .vault/ protection intact"
  fi
  return $errors
}

# HR-012: Agent config protection (check staged changes)
lint_hr012_config_protection() {
  local vault_root="$1"
  local errors=0

  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local repo_root
    repo_root=$(git -C "$vault_root" rev-parse --show-toplevel 2>/dev/null)
    local config_changes
    config_changes=$(git -C "$repo_root" diff --cached --name-only -- "CLAUDE.md" "AGENTS.md" ".claude/" 2>/dev/null)
    if [[ -n "$config_changes" ]]; then
      log_fail "HR-012: Staged changes to agent config files:"
      echo "$config_changes" | sed 's/^/         /'
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-012: Agent config protection intact"
  fi
  return $errors
}

# HR-014: No file deletion (check staged deletions)
lint_hr014_no_deletion() {
  local vault_root="$1"
  local errors=0

  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local deletions
    deletions=$(git -C "$vault_root" diff --cached --diff-filter=D --name-only 2>/dev/null)
    if [[ -n "$deletions" ]]; then
      log_fail "HR-014: File deletions detected (use status: archived instead):"
      echo "$deletions" | sed 's/^/         /'
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-014: No file deletions detected"
  fi
  return $errors
}

# Composite: Run all lint checks
lint_all() {
  local vault_root="$1"
  local total_errors=0

  lint_hr001_raw_immutability "$vault_root" || ((total_errors++))
  lint_hr002_frontmatter "$vault_root"      || ((total_errors++))
  lint_hr003_approved_tags "$vault_root"     || ((total_errors++))
  lint_hr004_wiki_length "$vault_root"       || ((total_errors++))
  lint_hr005_code_length "$vault_root"       || ((total_errors++))
  lint_hr006_unique_titles "$vault_root"     || ((total_errors++))
  lint_hr008_index_registration "$vault_root"|| ((total_errors++))
  lint_hr010_binary_quarantine "$vault_root" || ((total_errors++))
  lint_hr011_vault_protection "$vault_root"  || ((total_errors++))
  lint_hr012_config_protection "$vault_root" || ((total_errors++))
  lint_hr014_no_deletion "$vault_root"       || ((total_errors++))

  return $total_errors
}
