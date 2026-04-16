#!/usr/bin/env bash
# pre-commit.sh — Git pre-commit hook for vault hard rule enforcement
# Checks: HR-001, HR-002, HR-003, HR-008, HR-011, HR-012, HR-014
#
# Install: vault-tools.sh init-hooks
# Or manually: cp .vault/hooks/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

set -euo pipefail

# Locate vault root (this hook may be in .git/hooks/ or .vault/hooks/)
find_vault_root() {
  local dir
  if [[ -n "${GIT_DIR:-}" ]]; then
    dir=$(cd "$GIT_DIR/.." && pwd)
  else
    dir=$(git rev-parse --show-toplevel 2>/dev/null)
  fi
  # Look for vault/ subdirectory
  if [[ -d "$dir/vault" ]]; then
    echo "$dir/vault"
  else
    echo "$dir"
  fi
}

VAULT_ROOT="$(find_vault_root)"
SCRIPTS_DIR="$VAULT_ROOT/.vault/scripts"

# Source utilities if available
if [[ -f "$SCRIPTS_DIR/lib-utils.sh" ]]; then
  source "$SCRIPTS_DIR/lib-utils.sh"
else
  # Minimal fallback
  log_fail() { echo "[FAIL] $*"; }
  log_pass() { echo "[PASS] $*"; }
  log_warn() { echo "[WARN] $*"; }
fi

if [[ -f "$SCRIPTS_DIR/lib-lint.sh" ]]; then
  source "$SCRIPTS_DIR/lib-lint.sh"
fi

echo "=== Vault Pre-Commit Checks ==="
echo ""

errors=0

# HR-001: No modifications to raw/
raw_changes=$(git diff --cached --name-only -- "vault/raw/" 2>/dev/null || true)
if [[ -n "$raw_changes" ]]; then
  log_fail "HR-001: Cannot modify files in raw/ (immutable)"
  echo "$raw_changes" | sed 's/^/  /'
  ((errors++))
else
  log_pass "HR-001: raw/ immutability"
fi

# HR-002: Check frontmatter on staged .md files in wiki/ and memory/
staged_md=$(git diff --cached --name-only --diff-filter=ACM -- "vault/wiki/*.md" "vault/wiki/**/*.md" "vault/memory/*.md" "vault/memory/**/*.md" 2>/dev/null || true)
if [[ -n "$staged_md" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ -f "$file" ]]; then
      first_line=$(head -1 "$file")
      if [[ "$first_line" != "---" ]]; then
        log_fail "HR-002: Missing YAML frontmatter in: $file"
        ((errors++))
      fi
    fi
  done <<< "$staged_md"
  if [[ $errors -eq 0 ]]; then
    log_pass "HR-002: Frontmatter present on staged files"
  fi
fi

# HR-003: Validate tags on staged files (if lib-lint available)
if type -t lint_hr003_approved_tags &>/dev/null && [[ -n "$staged_md" ]]; then
  approved=$(load_approved_tags "$VAULT_ROOT" 2>/dev/null || true)
  if [[ -n "$approved" ]]; then
    tag_errors=0
    while IFS= read -r file; do
      [[ -z "$file" || ! -f "$file" ]] && continue
      while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue
        if ! validate_tag "$tag" "$approved"; then
          log_fail "HR-003: Unapproved tag '$tag' in: $file"
          ((tag_errors++))
        fi
      done < <(get_frontmatter_tags "$file")
    done <<< "$staged_md"
    if [[ $tag_errors -eq 0 ]]; then
      log_pass "HR-003: All tags approved"
    fi
    errors=$((errors + tag_errors))
  fi
fi

# HR-008: Check new wiki files are indexed
new_wiki=$(git diff --cached --name-only --diff-filter=A -- "vault/wiki/**/*.md" 2>/dev/null || true)
if [[ -n "$new_wiki" ]]; then
  hr008_errors=0
  index_file="$VAULT_ROOT/wiki/index.md"
  if [[ -f "$index_file" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      rel="${file#vault/}"
      [[ "$rel" == "wiki/index.md" || "$rel" == "wiki/log.md" ]] && continue
      if ! grep -qF "$rel" "$index_file" 2>/dev/null; then
        # Also check staged version of index
        if ! git diff --cached -- "$index_file" 2>/dev/null | grep -qF "$rel"; then
          log_fail "HR-008: New file not in index: $rel"
          ((hr008_errors++))
        fi
      fi
    done <<< "$new_wiki"
  fi
  if [[ $hr008_errors -eq 0 ]]; then
    log_pass "HR-008: New files registered in index"
  fi
  errors=$((errors + hr008_errors))
fi

# HR-011: .vault/ protection
vault_changes=$(git diff --cached --name-only -- "vault/.vault/rules/" "vault/.vault/hooks/" "vault/.vault/scripts/" "vault/.vault/schemas/" 2>/dev/null || true)
if [[ -n "$vault_changes" ]]; then
  log_fail "HR-011: Changes to protected .vault/ paths require human review:"
  echo "$vault_changes" | sed 's/^/  /'
  ((errors++))
else
  log_pass "HR-011: .vault/ protection intact"
fi

# HR-012: Agent config protection
config_changes=$(git diff --cached --name-only -- "CLAUDE.md" "AGENTS.md" ".claude/" 2>/dev/null || true)
if [[ -n "$config_changes" ]]; then
  log_fail "HR-012: Changes to agent config files require human review:"
  echo "$config_changes" | sed 's/^/  /'
  ((errors++))
else
  log_pass "HR-012: Agent config protection intact"
fi

# HR-013: CI/Template protection
ci_changes=$(git diff --cached --name-only -- ".github/workflows/" ".gitlab-ci.yml" 2>/dev/null || true)
if [[ -n "$ci_changes" ]]; then
  echo "[WARN] HR-013: CI pipeline files modified — verify changes are intentional"
  echo "$ci_changes" | sed 's/^/  /'
fi

# HR-014: No file deletions in vault
vault_deletions=$(git diff --cached --diff-filter=D --name-only -- "vault/" 2>/dev/null || true)
if [[ -n "$vault_deletions" ]]; then
  log_fail "HR-014: File deletions not allowed (use status: archived instead):"
  echo "$vault_deletions" | sed 's/^/  /'
  ((errors++))
else
  log_pass "HR-014: No file deletions"
fi

echo ""
if [[ $errors -gt 0 ]]; then
  echo "=== PRE-COMMIT BLOCKED: $errors violation(s) ==="
  echo "Fix the issues above before committing."
  exit 1
else
  echo "=== Pre-commit checks PASSED ==="
  exit 0
fi
