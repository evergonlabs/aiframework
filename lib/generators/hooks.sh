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

  local lang=$(echo "$m" | jq -r '.stack.language')
  local name=$(echo "$m" | jq -r '.identity.name')
  local lint_cmd=$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')
  local typecheck=$(echo "$m" | jq -r '.commands.typecheck // "NOT_CONFIGURED"')
  local test_cmd=$(echo "$m" | jq -r '.commands.test // "NOT_CONFIGURED"')
  local build_cmd=$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')

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
    cat > "$TARGET_DIR/.githooks/pre-commit" << PRECOMMIT
#!/bin/bash
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
  fi

  # --- Pre-push hook ---
  # Build skip patterns from project structure
  local skip_patterns='^docs/|^scripts/|^tools/|^\.github/|^\.githooks/|^CLAUDE\.md$|^CONTRIBUTING\.md$|^SETUP-DEV\.md$|^STATUS\.md$|^CHANGELOG\.md$|^VERSION$|^AUTOMATION-PLAYBOOK.*$|^LICENSE$|^README\.md$|^\.env|^\.gitignore$'

  # Add test file patterns based on language
  case "$lang" in
    typescript|javascript) skip_patterns+="|\.test\.(ts|tsx|js|jsx)$|\.spec\.(ts|tsx|js|jsx)$" ;;
    python) skip_patterns+="|test_.*\.py$|.*_test\.py$" ;;
    go) skip_patterns+="|.*_test\.go$" ;;
    rust) skip_patterns+="|/tests/.*\.rs$" ;;
  esac

  # Count gates
  local gate_num=0
  local total_gates=0
  [[ "$lint_cmd" != "NOT_CONFIGURED" ]] && ((total_gates++))
  [[ "$test_cmd" != "NOT_CONFIGURED" ]] && ((total_gates++))
  [[ "$build_cmd" != "NOT_CONFIGURED" ]] && ((total_gates++))

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
    ((gate_num++))
    cat >> "$TARGET_DIR/.githooks/pre-push" << GATE
# Gate ${gate_num}: Lint
echo "  [${gate_num}/${total_gates}] Linting..."
${lint_cmd} 2>&1
if [ \$? -ne 0 ]; then
  echo "  BLOCKED: Lint errors. Fix before pushing."
  exit 1
fi
echo "  [${gate_num}/${total_gates}] Lint passed"

GATE
  fi

  if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then
    ((gate_num++))
    cat >> "$TARGET_DIR/.githooks/pre-push" << GATE
# Gate ${gate_num}: Test
echo "  [${gate_num}/${total_gates}] Testing..."
${test_cmd} 2>&1 | tail -5
if [ \$? -ne 0 ]; then
  echo "  BLOCKED: Test failures. Fix before pushing."
  exit 1
fi
echo "  [${gate_num}/${total_gates}] Tests passed"

GATE
  fi

  if [[ "$build_cmd" != "NOT_CONFIGURED" ]]; then
    ((gate_num++))
    cat >> "$TARGET_DIR/.githooks/pre-push" << GATE
# Gate ${gate_num}: Build
echo "  [${gate_num}/${total_gates}] Building..."
${build_cmd} 2>&1 | tail -3
if [ \$? -ne 0 ]; then
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
      esac
    done

    cat >> "$TARGET_DIR/.githooks/pre-push" << 'INV_TAIL'
if [ "$INVARIANT_FAIL" = true ]; then
  echo ""
  echo "  Invariant warnings detected. Review before pushing."
  echo "  To bypass: git push --no-verify"
fi
INV_TAIL
  fi

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
