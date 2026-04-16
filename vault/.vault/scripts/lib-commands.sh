#!/usr/bin/env bash
# lib-commands.sh — Additional vault tool commands
# Source this file; do not execute directly.
# Extracted from vault-tools.sh to stay within HR-005 line limits.

# Requires: VAULT_ROOT, WIKI_DIR, INDEX_FILE set by vault-tools.sh
# Requires: lib-utils.sh sourced (get_frontmatter_field, get_frontmatter_tags, rel_path, log_pass, log_fail)

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
    primary_tag=$(get_frontmatter_tags "$file" 2>/dev/null | head -1 || true)
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
