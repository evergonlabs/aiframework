#!/usr/bin/env bash
# test_validators.sh — Unit tests for lib/validators/
# Runs against fixture repos in /tmp to test each validator module.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$ROOT_DIR/lib"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors (must match bin/aiframework for validators — used by sourced validator files)
# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
GREEN='\033[0;32m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
BLUE='\033[0;34m'
# shellcheck disable=SC2034
CYAN='\033[0;36m'
# shellcheck disable=SC2034
BOLD='\033[1m'
# shellcheck disable=SC2034
NC='\033[0m'

pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "  ${GREEN}PASS${NC} $1"
}

fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
  echo -e "  ${RED}FAIL${NC} $1: $2"
}

# --- Fixture setup ---
FIXTURE_DIR=""

setup_fixture() {
  FIXTURE_DIR=$(mktemp -d /tmp/aif-test-XXXXXX)
  cd "$FIXTURE_DIR"
  git init --quiet
  git config user.email "test@test.com"
  git config user.name "Test"

  # Create minimal manifest
  mkdir -p .aiframework
  cat > .aiframework/manifest.json <<'MANIFEST'
{
  "identity": {"name": "test-project", "short_name": "test", "description": "Test"},
  "stack": {"language": "bash", "framework": "none", "is_monorepo": false, "key_dependencies": []},
  "commands": {"lint": "echo lint", "test": "echo test", "build": "NOT_CONFIGURED", "install": "NOT_CONFIGURED", "typecheck": "NOT_CONFIGURED", "github_url": "NOT_FOUND", "local_path": "/tmp/test"},
  "ci": {"provider": "none", "deploy_target": "none"},
  "env": {"variables": []},
  "quality": {},
  "domain": {"detected_domains": []},
  "structure": {"file_counts": {}},
  "archetype": {"type": "minimal", "complexity": "simple", "maturity": "greenfield"},
  "_meta": {"generated_at": "2026-04-16T00:00:00Z", "aiframework_version": "1.1.0", "target_dir": "/tmp/test", "scanner": "aiframework/discover"}
}
MANIFEST

  # Create expected files
  echo "# CLAUDE.md" > CLAUDE.md
  echo "# Changelog" > CHANGELOG.md
  echo "1.0.0" > VERSION
  echo "# Status" > STATUS.md
  echo "# Setup" > SETUP-DEV.md
  echo "# Contributing" > CONTRIBUTING.md
  mkdir -p docs/{onboarding,guides,reference,explanation,decisions}
  echo "# Docs" > docs/README.md
  mkdir -p tools/learnings
  echo "" > tools/learnings/test-learnings.jsonl

  # Create hooks
  mkdir -p .githooks
  echo "#!/bin/bash" > .githooks/pre-commit
  cat > .githooks/pre-push <<'HOOK'
#!/bin/bash
echo lint
echo test
HOOK
  chmod +x .githooks/pre-commit .githooks/pre-push
  git config core.hooksPath .githooks

  # Create skills
  mkdir -p .claude/skills/test-review .claude/skills/test-ship
  echo "review skill" > .claude/skills/test-review/SKILL.md
  echo "ship skill" > .claude/skills/test-ship/SKILL.md

  # Create review specialists
  mkdir -p tools/review-specialists
  echo "# DB Review" > tools/review-specialists/database.md

  # Vault structure
  mkdir -p vault/{raw,wiki/{sources,concepts,entities,comparisons},memory/{decisions,notes},.vault/{scripts,rules,schemas}}
  echo "# Index" > vault/wiki/index.md
  echo "# Status" > vault/memory/status.md
  echo "# Rules" > vault/.vault/rules/hard-rules.md
  echo '{}' > vault/.vault/staleness-config.json
  echo "#!/bin/bash" > vault/.vault/scripts/vault-tools.sh
  chmod +x vault/.vault/scripts/vault-tools.sh

  # Stage and commit
  git add -A
  git commit -m "initial" --quiet

  export TARGET_DIR="$FIXTURE_DIR"
  export MANIFEST_PATH="$FIXTURE_DIR/.aiframework/manifest.json"
  export MANIFEST
  MANIFEST=$(cat "$MANIFEST_PATH")
}

teardown_fixture() {
  if [[ -n "$FIXTURE_DIR" && -d "$FIXTURE_DIR" ]]; then
    rm -rf "$FIXTURE_DIR"
  fi
}

# --- Shared validator state (mimics verify command) ---
passed=0
failed=0
warnings=0
total_checks=0

reset_counters() {
  # shellcheck disable=SC2034
  passed=0; failed=0; warnings=0; total_checks=0
}

# Source report_row from files validator
source "$LIB_DIR/validators/files.sh"

# ============================================================
# TEST: validate_files — happy path
# ============================================================
test_files_happy() {
  echo -e "\n${BOLD}test_files_happy${NC}"
  setup_fixture
  reset_counters

  validate_files

  if [[ $failed -eq 0 ]]; then
    pass "All file checks pass with complete fixture"
  else
    fail "Expected 0 failures" "got $failed"
  fi
  teardown_fixture
}

# ============================================================
# TEST: validate_files — missing files
# ============================================================
test_files_missing() {
  echo -e "\n${BOLD}test_files_missing${NC}"
  setup_fixture
  rm -f "$FIXTURE_DIR/CHANGELOG.md" "$FIXTURE_DIR/STATUS.md"
  reset_counters

  validate_files

  if [[ $failed -gt 0 ]]; then
    pass "Detects missing core files (got $failed failures)"
  else
    fail "Expected failures for missing files" "got 0"
  fi
  teardown_fixture
}

# ============================================================
# TEST: validate_security — happy path (no secrets)
# ============================================================
test_security_happy() {
  echo -e "\n${BOLD}test_security_happy${NC}"
  setup_fixture
  reset_counters

  source "$LIB_DIR/validators/security.sh"
  validate_security

  if [[ $failed -eq 0 ]]; then
    pass "Security scan passes on clean fixture"
  else
    fail "Expected 0 failures" "got $failed"
  fi
  teardown_fixture
}

# ============================================================
# TEST: validate_security — detects secrets
# ============================================================
test_security_detects_secrets() {
  echo -e "\n${BOLD}test_security_detects_secrets${NC}"
  setup_fixture
  echo "ghp_aBcDeFgHiJkLmNoPqRsTuVwXyZaBcDeFgHiJk" >> "$FIXTURE_DIR/CLAUDE.md"
  reset_counters

  source "$LIB_DIR/validators/security.sh"
  validate_security

  if [[ $failed -gt 0 ]]; then
    pass "Detects GitHub token in CLAUDE.md (got $failed failures)"
  else
    fail "Expected to detect secret" "got 0 failures"
  fi
  teardown_fixture
}

# ============================================================
# TEST: validate_security — detects Stripe key
# ============================================================
test_security_detects_stripe() {
  echo -e "\n${BOLD}test_security_detects_stripe${NC}"
  setup_fixture
  echo "sk_live_aBcDeFgHiJkLmNoPqRsTuVwXy" >> "$FIXTURE_DIR/CLAUDE.md"
  reset_counters

  source "$LIB_DIR/validators/security.sh"
  validate_security

  if [[ $failed -gt 0 ]]; then
    pass "Detects Stripe secret key (got $failed failures)"
  else
    fail "Expected to detect Stripe key" "got 0 failures"
  fi
  teardown_fixture
}

# ============================================================
# TEST: validate_consistency — happy path
# ============================================================
test_consistency_happy() {
  echo -e "\n${BOLD}test_consistency_happy${NC}"
  setup_fixture
  reset_counters

  source "$LIB_DIR/validators/consistency.sh"
  validate_consistency

  # Should have no hard failures in a minimal fixture
  if [[ $failed -eq 0 ]]; then
    pass "Consistency check passes on clean fixture"
  else
    fail "Expected 0 failures" "got $failed"
  fi
  teardown_fixture
}

# ============================================================
# TEST: validate_consistency — detects placeholders
# ============================================================
test_consistency_placeholders() {
  echo -e "\n${BOLD}test_consistency_placeholders${NC}"
  setup_fixture
  echo "Install: {{INSTALL_CMD}}" >> "$FIXTURE_DIR/CLAUDE.md"
  reset_counters

  source "$LIB_DIR/validators/consistency.sh"
  validate_consistency

  if [[ $failed -gt 0 ]]; then
    pass "Detects {{}} placeholder in CLAUDE.md (got $failed failures)"
  else
    fail "Expected to detect placeholder" "got 0 failures"
  fi
  teardown_fixture
}

# ============================================================
# TEST: validate_quality_gate — happy path
# ============================================================
test_quality_gate_happy() {
  echo -e "\n${BOLD}test_quality_gate_happy${NC}"
  setup_fixture
  # Make CLAUDE.md substantial
  for i in $(seq 1 60); do echo "Line $i of CLAUDE.md content" >> "$FIXTURE_DIR/CLAUDE.md"; done
  reset_counters

  source "$LIB_DIR/validators/quality_gate.sh"
  validate_quality_gate

  if [[ $failed -eq 0 ]]; then
    pass "Quality gate passes with valid fixture"
  else
    fail "Expected 0 failures" "got $failed"
  fi
  teardown_fixture
}

# ============================================================
# TEST: validate_freshness — happy path
# ============================================================
test_freshness_happy() {
  echo -e "\n${BOLD}test_freshness_happy${NC}"
  setup_fixture
  reset_counters

  source "$LIB_DIR/validators/freshness.sh"
  validate_freshness

  if [[ $failed -eq 0 ]]; then
    pass "Freshness check passes on fresh fixture"
  else
    fail "Expected 0 failures" "got $failed"
  fi
  teardown_fixture
}

# --- Logging stubs for generator modules ---
log_info()  { :; }
log_ok()    { :; }
log_warn()  { :; }

# ============================================================
# TEST: preserve_tracking — skip when file exists
# ============================================================
test_preserve_tracking_skip() {
  echo -e "\n${BOLD}test_preserve_tracking_skip${NC}"
  setup_fixture

  source "$LIB_DIR/generators/preserve.sh"
  # CHANGELOG.md already exists in fixture
  if preserve_tracking "$FIXTURE_DIR/CHANGELOG.md"; then
    fail "Expected return 1 (skip)" "got 0"
  else
    pass "preserve_tracking returns 1 when file exists"
  fi
  teardown_fixture
}

# ============================================================
# TEST: preserve_tracking — create when file missing
# ============================================================
test_preserve_tracking_create() {
  echo -e "\n${BOLD}test_preserve_tracking_create${NC}"
  setup_fixture

  source "$LIB_DIR/generators/preserve.sh"
  rm -f "$FIXTURE_DIR/CHANGELOG.md"
  if preserve_tracking "$FIXTURE_DIR/CHANGELOG.md"; then
    pass "preserve_tracking returns 0 when file missing"
  else
    fail "Expected return 0 (proceed)" "got 1"
  fi
  teardown_fixture
}

# ============================================================
# TEST: preserve_doc — skip when file exists
# ============================================================
test_preserve_doc_skip() {
  echo -e "\n${BOLD}test_preserve_doc_skip${NC}"
  setup_fixture

  source "$LIB_DIR/generators/preserve.sh"
  # CONTRIBUTING.md already exists in fixture
  if preserve_doc "$FIXTURE_DIR/CONTRIBUTING.md"; then
    fail "Expected return 1 (skip)" "got 0"
  else
    pass "preserve_doc returns 1 when file exists"
  fi
  teardown_fixture
}

# ============================================================
# TEST: preserve_hook — skip when file exists
# ============================================================
test_preserve_hook_skip() {
  echo -e "\n${BOLD}test_preserve_hook_skip${NC}"
  setup_fixture

  source "$LIB_DIR/generators/preserve.sh"
  # .githooks/pre-push already exists in fixture
  if preserve_hook "$FIXTURE_DIR/.githooks/pre-push"; then
    fail "Expected return 1 (skip)" "got 0"
  else
    pass "preserve_hook returns 1 when hook exists"
  fi
  teardown_fixture
}

# ============================================================
# TEST: _backup_file — creates backup copy
# ============================================================
test_backup_file_creates_backup() {
  echo -e "\n${BOLD}test_backup_file_creates_backup${NC}"
  setup_fixture

  source "$LIB_DIR/generators/preserve.sh"
  export TARGET_DIR="$FIXTURE_DIR"
  _PRESERVE_BACKUP_DIR="$FIXTURE_DIR/.aiframework/backups/test-run"

  echo "backup me" > "$FIXTURE_DIR/testfile.txt"
  _backup_file "$FIXTURE_DIR/testfile.txt"

  if find "$_PRESERVE_BACKUP_DIR" -name "testfile.txt" -type f 2>/dev/null | grep -q .; then
    pass "_backup_file creates backup of existing file"
  else
    fail "Expected backup file to exist" "not found in $_PRESERVE_BACKUP_DIR"
  fi
  teardown_fixture
}

# ============================================================
# TEST: _backup_file — skips symlinks
# ============================================================
test_backup_file_skips_symlink() {
  echo -e "\n${BOLD}test_backup_file_skips_symlink${NC}"
  setup_fixture

  source "$LIB_DIR/generators/preserve.sh"
  export TARGET_DIR="$FIXTURE_DIR"
  _PRESERVE_BACKUP_DIR="$FIXTURE_DIR/.aiframework/backups/test-symlink"

  echo "real" > "$FIXTURE_DIR/real.txt"
  ln -s "$FIXTURE_DIR/real.txt" "$FIXTURE_DIR/link.txt"
  _backup_file "$FIXTURE_DIR/link.txt"

  if [[ -d "$_PRESERVE_BACKUP_DIR" ]] && find "$_PRESERVE_BACKUP_DIR" -name "link.txt" -type f 2>/dev/null | grep -q .; then
    fail "Expected no backup for symlink" "backup was created"
  else
    pass "_backup_file skips symlinks"
  fi
  teardown_fixture
}

# ============================================================
# TEST: _sanitize_manifest_val — strips backticks
# ============================================================
test_sanitize_strips_backticks() {
  echo -e "\n${BOLD}test_sanitize_strips_backticks${NC}"
  setup_fixture

  source "$LIB_DIR/generators/skills.sh"
  local result
  result=$(_sanitize_manifest_val 'hello `world`')

  if [[ "$result" == "hello world" ]]; then
    pass "_sanitize_manifest_val strips backticks"
  else
    fail "Expected 'hello world'" "got '$result'"
  fi
  teardown_fixture
}

# ============================================================
# TEST: _sanitize_manifest_val — strips $()
# ============================================================
test_sanitize_strips_dollar_parens() {
  echo -e "\n${BOLD}test_sanitize_strips_dollar_parens${NC}"
  setup_fixture

  source "$LIB_DIR/generators/skills.sh"
  local result
  result=$(_sanitize_manifest_val 'hello $(rm -rf /)')

  # Allowlist approach: $, (, ) are stripped — no shell metacharacters remain
  if ! echo "$result" | grep -q '[$()]'; then
    pass "_sanitize_manifest_val strips \$() shell metacharacters"
  else
    fail "Expected no \$() in output" "got '$result'"
  fi
  teardown_fixture
}

# ============================================================
# TEST: _sanitize_manifest_val — strips ${}
# ============================================================
test_sanitize_strips_dollar_braces() {
  echo -e "\n${BOLD}test_sanitize_strips_dollar_braces${NC}"
  setup_fixture

  source "$LIB_DIR/generators/skills.sh"
  local result
  result=$(_sanitize_manifest_val 'hello ${HOME}')

  # Allowlist approach: $, {, } are stripped — no shell metacharacters remain
  if ! echo "$result" | grep -q '[${}]'; then
    pass "_sanitize_manifest_val strips \${} shell metacharacters"
  else
    fail "Expected no \${} in output" "got '$result'"
  fi
  teardown_fixture
}

# ============================================================
# TEST: _sanitize_manifest_val — preserves normal text
# ============================================================
test_sanitize_preserves_normal() {
  echo -e "\n${BOLD}test_sanitize_preserves_normal${NC}"
  setup_fixture

  source "$LIB_DIR/generators/skills.sh"
  local result
  result=$(_sanitize_manifest_val 'my-app v1.0')

  if [[ "$result" == "my-app v1.0" ]]; then
    pass "_sanitize_manifest_val preserves normal text"
  else
    fail "Expected 'my-app v1.0'" "got '$result'"
  fi
  teardown_fixture
}

# ============================================================
# TEST: scan_skill_suggestions — detects deploy script
# ============================================================
test_skill_suggest_deploy() {
  echo -e "\n${BOLD}test_skill_suggest_deploy${NC}"
  setup_fixture

  source "$LIB_DIR/scanners/skill_suggest.sh"
  echo "#!/bin/bash" > "$FIXTURE_DIR/deploy.sh"

  scan_skill_suggestions

  if echo "$MANIFEST" | jq -e '.skill_suggestions[] | select(.name == "deploy")' >/dev/null 2>&1; then
    pass "scan_skill_suggestions detects deploy.sh"
  else
    fail "Expected deploy suggestion in MANIFEST" "not found"
  fi
  teardown_fixture
}

# ============================================================
# TEST: scan_skill_suggestions — empty fixture yields no suggestions
# ============================================================
test_skill_suggest_empty() {
  echo -e "\n${BOLD}test_skill_suggest_empty${NC}"
  setup_fixture

  source "$LIB_DIR/scanners/skill_suggest.sh"
  # Fixture has no deploy.sh, docker-compose.yml, etc.

  scan_skill_suggestions

  local count
  count=$(echo "$MANIFEST" | jq '.skill_suggestions | length' 2>/dev/null || echo "-1")

  if [[ "$count" -eq 0 ]]; then
    pass "scan_skill_suggestions returns 0 suggestions on empty fixture"
  else
    fail "Expected 0 suggestions" "got $count"
  fi
  teardown_fixture
}

# ============================================================
# TEST: scan_skill_suggestions — detects docker-compose
# ============================================================
test_skill_suggest_docker() {
  echo -e "\n${BOLD}test_skill_suggest_docker${NC}"
  setup_fixture

  source "$LIB_DIR/scanners/skill_suggest.sh"
  echo "version: '3'" > "$FIXTURE_DIR/docker-compose.yml"

  scan_skill_suggestions

  if echo "$MANIFEST" | jq -e '.skill_suggestions[] | select(.name == "infra")' >/dev/null 2>&1; then
    pass "scan_skill_suggestions detects docker-compose.yml"
  else
    fail "Expected infra suggestion in MANIFEST" "not found"
  fi
  teardown_fixture
}

# ============================================================
# Run all tests
# ============================================================
echo -e "${BOLD}=== Validator Test Suite ===${NC}"

test_files_happy
test_files_missing
test_security_happy
test_security_detects_secrets
test_security_detects_stripe
test_consistency_happy
test_consistency_placeholders
test_quality_gate_happy
test_freshness_happy
test_preserve_tracking_skip
test_preserve_tracking_create
test_preserve_doc_skip
test_preserve_hook_skip
test_backup_file_creates_backup
test_backup_file_skips_symlink
test_sanitize_strips_backticks
test_sanitize_strips_dollar_parens
test_sanitize_strips_dollar_braces
test_sanitize_preserves_normal
test_skill_suggest_deploy
test_skill_suggest_empty
test_skill_suggest_docker

echo ""
echo -e "${BOLD}=== Results ===${NC}"
echo -e "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_FAILED -gt 0 ]]; then
  echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
  exit 1
else
  echo -e "  Failed: 0"
  echo -e "  ${GREEN}All tests passed.${NC}"
fi
