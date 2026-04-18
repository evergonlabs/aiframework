#!/usr/bin/env bash
# Generator: Git Hooks
# Creates pre-commit and pre-push hooks based on manifest

generate_hooks() {
  local m="$MANIFEST"

  # Check if hooks already exist
  local hook_system
  hook_system=$(echo "$m" | jq -r '.quality.hooks.system // empty')

  if [[ "$hook_system" == "husky" ]]; then
    log_warn "Project uses Husky — skipping .githooks creation"
    return 0
  fi

  if [[ "$hook_system" == "pre-commit" ]]; then
    log_warn "Project uses pre-commit framework — skipping .githooks creation"
    return 0
  fi

  local lang
  lang=$(echo "$m" | jq -r '.stack.language')
  local name
  name=$(echo "$m" | jq -r '.identity.name')
  local lint_cmd
  lint_cmd=$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')
  local typecheck
  typecheck=$(echo "$m" | jq -r '.commands.typecheck // "NOT_CONFIGURED"')
  local test_cmd
  test_cmd=$(echo "$m" | jq -r '.commands.test // "NOT_CONFIGURED"')
  local build_cmd
  build_cmd=$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')

  # Sanitize commands before writing into git hooks (E1, E5 CRITICAL)
  if command -v _sanitize_manifest_val &>/dev/null; then
    lint_cmd=$(_sanitize_manifest_val "$lint_cmd")
    typecheck=$(_sanitize_manifest_val "$typecheck")
    test_cmd=$(_sanitize_manifest_val "$test_cmd")
    build_cmd=$(_sanitize_manifest_val "$build_cmd")
    name=$(_sanitize_manifest_val "$name")
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create .githooks/pre-commit and .githooks/pre-push"
    return 0
  fi

  mkdir -p "$TARGET_DIR/.githooks"

  # --- Pre-commit hook ---
  local precommit_check=""
  local precommit_label=""

  case "$lang" in
    typescript)
      if [[ "$typecheck" != "NOT_CONFIGURED" ]]; then
        precommit_check="$typecheck"
        precommit_label="Type checking"
      elif [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then
        precommit_check="$lint_cmd"
        precommit_label="Lint checking"
      fi
      ;;
    python)
      if [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then
        precommit_check="$lint_cmd"
        precommit_label="Lint checking"
      fi
      ;;
    rust)
      precommit_check="cargo check --workspace"
      precommit_label="Compile checking"
      ;;
    go)
      precommit_check="go vet ./..."
      precommit_label="Vet checking"
      ;;
    *)
      if [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then
        precommit_check="$lint_cmd"
        precommit_label="Lint checking"
      fi
      ;;
  esac

  if [[ -n "$precommit_check" ]]; then
    # Preserve existing hooks
    if ! preserve_hook "$TARGET_DIR/.githooks/pre-commit"; then
      precommit_check=""  # skip pre-commit generation
    fi
  fi

  if [[ -n "$precommit_check" ]]; then
    # Extract the core tool name for availability check
    local core_tool
    core_tool=$(echo "$precommit_check" | grep -oE 'shellcheck|eslint|ruff|clippy|tsc|mypy|pyright' | head -1)

    cat > "$TARGET_DIR/.githooks/pre-commit" << PRECOMMIT
#!/bin/bash
PRECOMMIT

    # Add tool availability check if core tool is known
    if [[ -n "$core_tool" ]]; then
      cat >> "$TARGET_DIR/.githooks/pre-commit" << TOOLCHECK
# Check if ${core_tool} is installed
if ! command -v ${core_tool} >/dev/null 2>&1; then
  echo "Pre-commit: ${core_tool} not installed — skipping lint check"
  echo "  Install: brew install ${core_tool} (macOS) or apt-get install ${core_tool} (Linux)"
  exit 0
fi
TOOLCHECK
    fi

    cat >> "$TARGET_DIR/.githooks/pre-commit" << PRECOMMIT
echo "Pre-commit: ${precommit_label}..."
${precommit_check} 2>&1
if [ \$? -ne 0 ]; then
  echo "${precommit_label} failed. Fix errors before committing."
  exit 1
fi
echo "${precommit_label} passed."
PRECOMMIT
    chmod +x "$TARGET_DIR/.githooks/pre-commit"
    log_ok "Created .githooks/pre-commit (${precommit_label})"
  else
    log_warn "No pre-commit hook created — no type checker or linter configured"
    # Document skip reason
    cat > "$TARGET_DIR/.githooks/pre-commit-SKIPPED.md" << 'SKIPDOC'
# Pre-commit Hook: SKIPPED

**Reason:** No type checker or linter is configured for this project.

**When to add:**
- Configure a linter (ESLint, Ruff, Clippy, etc.)
- Re-run aiframework to auto-generate the pre-commit hook
SKIPDOC
  fi

  # --- Pre-push hook ---
  # Build skip patterns from project structure
  local skip_patterns='^docs/|^scripts/|^tools/|^\.github/|^\.githooks/|^CLAUDE\.md$|^CONTRIBUTING\.md$|^SETUP-DEV\.md$|^STATUS\.md$|^CHANGELOG\.md$|^VERSION$|^AUTOMATION-PLAYBOOK.*$|^LICENSE$|^README\.md$|^\.env|^\.gitignore$'

  # Add manifest-detected dirs to skip patterns
  local extra_skip_dirs
  extra_skip_dirs=$(echo "$m" | jq -r '.structure.doc_dirs[]?' 2>/dev/null)
  if [[ -n "$extra_skip_dirs" ]]; then
    while IFS= read -r edir; do
      [[ -z "$edir" ]] && continue
      skip_patterns+="|^${edir}/"
    done <<< "$extra_skip_dirs"
  fi

  # Add test file patterns based on language
  case "$lang" in
    typescript|javascript) skip_patterns+="|\.test\.(ts|tsx|js|jsx)$|\.spec\.(ts|tsx|js|jsx)$" ;;
    python) skip_patterns+="|test_.*\.py$|.*_test\.py$" ;;
    go) skip_patterns+="|.*_test\.go$" ;;
    rust) skip_patterns+="|/tests/.*\.rs$" ;;
  esac

  # Preserve existing pre-push hook
  if ! preserve_hook "$TARGET_DIR/.githooks/pre-push"; then
    # Still activate hooks path even if we didn't generate hooks
    git -C "$TARGET_DIR" config core.hooksPath .githooks 2>/dev/null || true
    log_ok "Git hooks preserved (core.hooksPath set)"
    return 0
  fi

  # Count gates
  local gate_num=0
  local total_gates=0
  [[ "$lint_cmd" != "NOT_CONFIGURED" ]] && total_gates=$((total_gates + 1))
  [[ "$test_cmd" != "NOT_CONFIGURED" ]] && total_gates=$((total_gates + 1))
  [[ "$build_cmd" != "NOT_CONFIGURED" ]] && total_gates=$((total_gates + 1))

  cat > "$TARGET_DIR/.githooks/pre-push" << PREPUSH_HEAD
#!/bin/bash

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${name} Pre-Push Quality Gate"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CHANGED_FILES=\$(git diff --name-only HEAD~1 HEAD 2>/dev/null)

SKIP_PATTERNS="${skip_patterns}"

NEEDS_CHECK=false
for file in \$CHANGED_FILES; do
  if ! echo "\$file" | grep -qE "\$SKIP_PATTERNS"; then
    NEEDS_CHECK=true
    break
  fi
done

if [ "\$NEEDS_CHECK" = false ]; then
  echo "  Only non-app files changed — skipping quality checks"
  exit 0
fi
PREPUSH_HEAD

  # Add gates
  if [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then
    gate_num=$((gate_num + 1))
    # Extract core lint tool for availability check
    local lint_tool
    lint_tool=$(echo "$lint_cmd" | grep -oE 'shellcheck|eslint|ruff|clippy|golangci-lint|rubocop' | head -1)

    cat >> "$TARGET_DIR/.githooks/pre-push" << GATE
# Gate ${gate_num}: Lint
GATE

    # Add tool availability check if it's an external tool
    if [[ -n "$lint_tool" ]]; then
      cat >> "$TARGET_DIR/.githooks/pre-push" << LINTCHECK
if ! command -v ${lint_tool} >/dev/null 2>&1; then
  echo "  [${gate_num}/${total_gates}] ${lint_tool} not installed — skipping lint"
else
LINTCHECK
    fi

    cat >> "$TARGET_DIR/.githooks/pre-push" << GATE
echo "  [${gate_num}/${total_gates}] Linting..."
${lint_cmd} 2>&1
if [ \$? -ne 0 ]; then
  echo "  BLOCKED: Lint errors. Fix before pushing."
  exit 1
fi
echo "  [${gate_num}/${total_gates}] Lint passed"
GATE

    # Close the if block if we opened one
    if [[ -n "$lint_tool" ]]; then
      echo "fi" >> "$TARGET_DIR/.githooks/pre-push"
    fi
    echo "" >> "$TARGET_DIR/.githooks/pre-push"
  fi

  if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then
    gate_num=$((gate_num + 1))
    cat >> "$TARGET_DIR/.githooks/pre-push" << GATE
# Gate ${gate_num}: Test
echo "  [${gate_num}/${total_gates}] Testing..."
_test_output=\$(${test_cmd} 2>&1) || _test_exit=\$?
echo "\$_test_output" | tail -5
if [ "\${_test_exit:-0}" -ne 0 ]; then
  echo "  BLOCKED: Test failures. Fix before pushing."
  exit 1
fi
echo "  [${gate_num}/${total_gates}] Tests passed"

GATE
  fi

  if [[ "$build_cmd" != "NOT_CONFIGURED" ]]; then
    gate_num=$((gate_num + 1))
    cat >> "$TARGET_DIR/.githooks/pre-push" << GATE
# Gate ${gate_num}: Build
echo "  [${gate_num}/${total_gates}] Building..."
_build_output=\$(${build_cmd} 2>&1) || _build_exit=\$?
echo "\$_build_output" | tail -3
if [ "\${_build_exit:-0}" -ne 0 ]; then
  echo "  BLOCKED: Build failed. Fix before pushing."
  exit 1
fi
echo "  [${gate_num}/${total_gates}] Build passed"

GATE
  fi

  # --- Invariant checks based on detected domains ---
  local domains
  domains=$(echo "$m" | jq -r '.domain.detected_domains[]? | .name' 2>/dev/null)

  if [[ -n "$domains" ]]; then
    cat >> "$TARGET_DIR/.githooks/pre-push" << 'INVARIANT_HEAD'
# Invariant checks — domain-specific
CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null)
INVARIANT_FAIL=false
INVARIANT_HEAD

    for dom in $domains; do
      case "$dom" in
        auth)
          cat >> "$TARGET_DIR/.githooks/pre-push" << 'INV_AUTH'
# INV-1: Auth invariant: new route files must reference auth middleware
for f in $(echo "$CHANGED" | grep -E '(route|controller|endpoint|handler)'); do
  if [ -f "$f" ] && ! grep -qE '(auth|guard|protect|middleware|requireAuth|isAuthenticated)' "$f"; then
    echo "  WARNING: $f looks like a route file but has no auth middleware reference"
    INVARIANT_FAIL=true
  fi
done
INV_AUTH
          ;;
        database)
          cat >> "$TARGET_DIR/.githooks/pre-push" << 'INV_DB'
# INV-2: Database invariant: no raw SQL strings in changed files
for f in $(echo "$CHANGED" | grep -vE '\.(md|txt|yml|yaml|json)$'); do
  if [ -f "$f" ] && grep -nE '(SELECT\s+.+\s+FROM|INSERT\s+INTO|UPDATE\s+.+\s+SET|DELETE\s+FROM|DROP\s+TABLE)' "$f" | grep -vE '(migration|seed|\.sql$)' > /dev/null 2>&1; then
    echo "  WARNING: $f may contain raw SQL — use ORM or query builder"
    INVARIANT_FAIL=true
  fi
done
INV_DB
          ;;
        ai)
          cat >> "$TARGET_DIR/.githooks/pre-push" << 'INV_AI'
# INV: AI/LLM trust boundary: check for unsanitized LLM output usage
for f in $(echo "$CHANGED" | grep -vE '\.(md|txt|yml|yaml|json)$'); do
  if [ -f "$f" ] && grep -nE '(innerHTML|dangerouslySetInnerHTML|eval\(|exec\()' "$f" > /dev/null 2>&1; then
    echo "  WARNING: $f may use unsanitized output — check LLM trust boundary"
    INVARIANT_FAIL=true
  fi
done
INV_AI
          ;;
      esac
    done

    # General invariant: no secrets in source code
    cat >> "$TARGET_DIR/.githooks/pre-push" << 'INV_SECRETS'
# INV: No secrets in source code
for f in $(echo "$CHANGED" | grep -vE '\.(md|txt|yml|yaml|json|lock)$'); do
  if [ -f "$f" ] && grep -nE '(ghp_[a-zA-Z0-9]{36}|sk-ant-|sk-proj-|AKIA[A-Z0-9]{16}|password\s*=\s*["\x27][^"\x27]+["\x27])' "$f" > /dev/null 2>&1; then
    echo "  WARNING: $f may contain hardcoded secrets"
    INVARIANT_FAIL=true
  fi
done
INV_SECRETS

    cat >> "$TARGET_DIR/.githooks/pre-push" << 'INV_TAIL'
if [ "$INVARIANT_FAIL" = true ]; then
  echo ""
  echo "  BLOCKED: Invariant violations detected."
  echo "  Fix the issues above before pushing."
  echo "  To bypass (not recommended): git push --no-verify"
  exit 1
fi
INV_TAIL
  fi

  cat >> "$TARGET_DIR/.githooks/pre-push" << 'REFRESH_GATE'

# Auto-refresh: regenerate aiframework output if key files drifted
# Uses aiframework refresh CLI directly (not library functions — they aren't sourced here)
if command -v aiframework >/dev/null 2>&1; then
  _refresh_output=$(aiframework refresh --target . --non-interactive 2>&1) || true
  if echo "$_refresh_output" | grep -q "Drift detected\|Re-running"; then
    echo "  [refresh] Key files changed — aiframework auto-refreshed configs"
    # Auto-commit refreshed files if any changed
    if [[ -n "$(git diff --name-only 2>/dev/null)" ]]; then
      git add CLAUDE.md .claude/ vault/ .aiframework/ 2>/dev/null || true
      git commit -m "chore(aiframework): auto-refresh on push [skip ci]" --no-verify 2>/dev/null || true
      echo "  [refresh] Auto-committed refreshed files"
    fi
  fi
fi
REFRESH_GATE

cat >> "$TARGET_DIR/.githooks/pre-push" << 'UPDATE_CHECK'

# Check for aiframework updates
if command -v aiframework-update-check >/dev/null 2>&1; then
  _upd=$(aiframework-update-check 2>/dev/null || true)
  if [[ "$_upd" == UPGRADE_AVAILABLE* ]]; then
    echo "  [aiframework] New version available: ${_upd#UPGRADE_AVAILABLE }"
    echo "  Run: aiframework update"
  fi
fi
UPDATE_CHECK

cat >> "$TARGET_DIR/.githooks/pre-push" << 'PREPUSH_TAIL'
echo ""
echo "  All gates passed — push allowed"
echo "  TIP: Run /review and /cso before creating a PR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
PREPUSH_TAIL

  chmod +x "$TARGET_DIR/.githooks/pre-push"
  log_ok "Created .githooks/pre-push (${total_gates} gates)"

  # Activate hooks
  (cd "$TARGET_DIR" && git config core.hooksPath .githooks 2>/dev/null) || true
  log_ok "Hooks activated: git config core.hooksPath .githooks"
}
