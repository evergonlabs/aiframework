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

# HR-007: Frontmatter 'updated' date accuracy (within 30 days of git last-modified)
lint_hr007_updated_accuracy() {
  local vault_root="$1"
  local errors=0

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")

    if ! has_frontmatter "$file"; then
      continue
    fi

    local updated
    updated=$(sed -n '/^---$/,/^---$/p' "$file" | grep -E '^updated:' | head -1 | sed 's/updated:[[:space:]]*//' | tr -d '"' | tr -d "'" | xargs)
    [[ -z "$updated" ]] && continue
    [[ "$updated" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { log_warn "HR-007: Unparseable date '$updated' in $rel"; continue; }

    # Get git last-modified date
    if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
      local git_date
      git_date=$(git -C "$vault_root" log -1 --format="%Y-%m-%d" -- "$file" 2>/dev/null || true)
      [[ -z "$git_date" ]] && continue

      # Compare dates — warn if frontmatter updated is >30 days before git date
      local updated_epoch git_epoch
      updated_epoch=$(date -j -f "%Y-%m-%d" "$updated" "+%s" 2>/dev/null || date -d "$updated" "+%s" 2>/dev/null || echo "0")
      git_epoch=$(date -j -f "%Y-%m-%d" "$git_date" "+%s" 2>/dev/null || date -d "$git_date" "+%s" 2>/dev/null || echo "0")

      if [[ "$updated_epoch" -gt 0 && "$git_epoch" -gt 0 ]]; then
        local diff_days=$(( (git_epoch - updated_epoch) / 86400 ))
        if [[ $diff_days -gt 30 ]]; then
          log_fail "HR-007: Stale 'updated' date in $rel (frontmatter: $updated, git: $git_date, ${diff_days}d behind)"
          ((errors++))
        fi
      fi
    fi
  done < <(find "$vault_root" -path "$vault_root/.vault" -prune -o -name '*.md' -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-007: Frontmatter 'updated' dates accurate"
  fi
  return $errors
}

# HR-009: Flat tags must use prefix/value format
lint_hr009_flat_tags() {
  local vault_root="$1"
  local errors=0

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")

    if ! has_frontmatter "$file"; then
      continue
    fi

    # Extract tags from frontmatter
    local in_tags=0
    while IFS= read -r line; do
      if [[ "$line" =~ ^tags: ]]; then
        # Inline tags: tags: [a, b, c]
        if [[ "$line" =~ \[ ]]; then
          local tag_list
          tag_list=$(echo "$line" | sed 's/.*\[//;s/\].*//' | tr ',' '\n')
          while IFS= read -r tag; do
            tag=$(echo "$tag" | xargs)
            tag=$(echo "$tag" | sed 's/^["'"'"']//;s/["'"'"']$//')
            [[ -z "$tag" ]] && continue
            if [[ ! "$tag" =~ / ]]; then
              log_fail "HR-009: Tag '$tag' missing prefix/value format in $rel (expected: prefix/value)"
              ((errors++))
            fi
          done <<< "$tag_list"
          continue
        fi
        in_tags=1
        continue
      fi
      if [[ $in_tags -eq 1 ]]; then
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
          local tag
          tag=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | xargs)
          [[ -z "$tag" ]] && continue
          if [[ ! "$tag" =~ / ]]; then
            log_fail "HR-009: Tag '$tag' missing prefix/value format in $rel (expected: prefix/value)"
            ((errors++))
          fi
        else
          in_tags=0
        fi
      fi
    done < <(awk 'NR==1 && /^---$/{f=1;next} f && /^---$/{exit} f' "$file")
  done < <(find "$vault_root" -path "$vault_root/.vault" -prune -o -name '*.md' -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-009: All tags use prefix/value format"
  fi
  return $errors
}

# HR-013: CI and template file protection (staged changes)
lint_hr013_ci_template_protection() {
  local vault_root="$1"
  local errors=0

  # Find repo root (vault may be a subdirectory)
  local repo_root
  repo_root=$(git -C "$vault_root" rev-parse --show-toplevel 2>/dev/null || echo "")
  [[ -z "$repo_root" ]] && { log_pass "HR-013: Not in a git repo (skip)"; return 0; }

  local ci_changes
  ci_changes=$(git -C "$repo_root" diff --cached --name-only -- ".github/workflows/" ".gitlab-ci.yml" "vault/.vault/templates/" 2>/dev/null || true)
  if [[ -n "$ci_changes" ]]; then
    log_warn "HR-013: Staged changes to CI/template files — verify intentional:"
    echo "$ci_changes" | sed 's/^/         /'
    # Warning only, not a hard error
  else
    log_pass "HR-013: No CI/template changes staged"
  fi

  return $errors
}

# HR-015: Append-only logs (log.md line count must not decrease)
lint_hr015_append_only_logs() {
  local vault_root="$1"
  local errors=0

  local log_file="$vault_root/wiki/log.md"
  [[ -f "$log_file" ]] || { log_pass "HR-015: No log.md found (skip)"; return 0; }

  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local current_lines prev_lines
    current_lines=$(wc -l < "$log_file" | tr -d '[:space:]')

    # Get previous committed version line count
    local rel_log
    rel_log=$(rel_path "$log_file" "$(git -C "$vault_root" rev-parse --show-toplevel 2>/dev/null)")
    prev_lines=$(git -C "$vault_root" show "HEAD:$rel_log" 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")

    if [[ "$prev_lines" -gt 0 && "$current_lines" -lt "$prev_lines" ]]; then
      log_fail "HR-015: log.md line count decreased ($prev_lines → $current_lines) — logs are append-only"
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-015: Log files are append-only"
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
  lint_hr007_updated_accuracy "$vault_root"  || ((total_errors++))
  lint_hr008_index_registration "$vault_root"|| ((total_errors++))
  lint_hr009_flat_tags "$vault_root"         || ((total_errors++))
  lint_hr010_binary_quarantine "$vault_root" || ((total_errors++))
  lint_hr011_vault_protection "$vault_root"  || ((total_errors++))
  lint_hr012_config_protection "$vault_root" || ((total_errors++))
  lint_hr013_ci_template_protection "$vault_root" || ((total_errors++))
  lint_hr014_no_deletion "$vault_root"       || ((total_errors++))
  lint_hr015_append_only_logs "$vault_root"  || ((total_errors++))

  return $total_errors
}
