#!/usr/bin/env bash
# Test suite: Sheal Integration
# Tests scanner, generator, bridge, and round-trip fidelity
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$ROOT_DIR/lib"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); TESTS_RUN=$((TESTS_RUN + 1)); echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { TESTS_FAILED=$((TESTS_FAILED + 1)); TESTS_RUN=$((TESTS_RUN + 1)); echo -e "  ${RED}FAIL${NC} $1: $2"; }

# Fixture helpers
FIXTURE_DIR=""
setup_fixture() {
  FIXTURE_DIR=$(mktemp -d /tmp/aif-sheal-test-XXXXXX)
  cd "$FIXTURE_DIR"
  git init -q 2>/dev/null
  mkdir -p .aiframework tools/learnings .claude/skills
}
teardown_fixture() {
  cd /tmp
  [[ -n "$FIXTURE_DIR" && -d "$FIXTURE_DIR" ]] && rm -rf "$FIXTURE_DIR"
}

# Provide stubs that the sourced libs expect
log_ok() { :; }
log_warn() { :; }
log_info() { :; }
log_step() { :; }
_aif_timeout() { local secs="$1"; shift; "$@"; }
export -f _aif_timeout log_ok log_warn log_info log_step

echo -e "${BOLD}=== Sheal Integration Test Suite ===${NC}"
echo ""

# ─────────────────────────────────────────────
# TEST 1: Scanner — sheal not installed
# ─────────────────────────────────────────────
echo -e "${BOLD}test_scanner_not_installed${NC}"
setup_fixture

MANIFEST="{}"
TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/scanners/sheal.sh"
scan_sheal 2>/dev/null || true

# Verify manifest has sheal block with installed=false
installed=$(echo "$MANIFEST" | jq -r '.sheal.installed')
[[ "$installed" == "false" ]] && pass "sheal.installed is false when not installed" || fail "sheal.installed" "expected false, got $installed"

version=$(echo "$MANIFEST" | jq -r '.sheal.version')
[[ "$version" == "unknown" ]] && pass "sheal.version defaults to unknown" || fail "sheal.version" "expected unknown, got $version"

initialized=$(echo "$MANIFEST" | jq -r '.sheal.initialized')
[[ "$initialized" == "false" ]] && pass "sheal.initialized is false" || fail "sheal.initialized" "expected false, got $initialized"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 2: Scanner — empty .sheal/ dir not treated as initialized
# ─────────────────────────────────────────────
echo -e "${BOLD}test_scanner_empty_sheal_dir${NC}"
setup_fixture
mkdir -p "$FIXTURE_DIR/.sheal"

MANIFEST="{}"
TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/scanners/sheal.sh"
scan_sheal 2>/dev/null || true

initialized=$(echo "$MANIFEST" | jq -r '.sheal.initialized')
[[ "$initialized" == "false" ]] && pass "Empty .sheal/ not treated as initialized" || fail "empty .sheal/ init" "expected false, got $initialized"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 3: Scanner — non-empty .sheal/ treated as initialized
# ─────────────────────────────────────────────
echo -e "${BOLD}test_scanner_nonempty_sheal_dir${NC}"
setup_fixture
mkdir -p "$FIXTURE_DIR/.sheal/learnings"
touch "$FIXTURE_DIR/.sheal/config.json"

MANIFEST="{}"
TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/scanners/sheal.sh"
scan_sheal 2>/dev/null || true

initialized=$(echo "$MANIFEST" | jq -r '.sheal.initialized')
[[ "$initialized" == "true" ]] && pass "Non-empty .sheal/ treated as initialized" || fail "nonempty .sheal/ init" "expected true, got $initialized"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 4: Scanner — MANIFEST preserved on jq failure
# ─────────────────────────────────────────────
echo -e "${BOLD}test_scanner_manifest_preserved${NC}"
setup_fixture

MANIFEST='{"identity":{"name":"test"}}'
TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/scanners/sheal.sh"
scan_sheal 2>/dev/null || true

# MANIFEST should still have identity AND sheal
has_identity=$(echo "$MANIFEST" | jq -r '.identity.name')
has_sheal=$(echo "$MANIFEST" | jq -r '.sheal.installed')
[[ "$has_identity" == "test" ]] && pass "MANIFEST identity preserved after scan_sheal" || fail "manifest preserve" "identity lost"
[[ "$has_sheal" == "false" ]] && pass "MANIFEST has sheal block added" || fail "manifest sheal" "sheal block missing"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 5: Generator — skip when not installed
# ─────────────────────────────────────────────
echo -e "${BOLD}test_generator_skip_not_installed${NC}"
setup_fixture

MANIFEST='{"sheal":{"installed":false}}'
TARGET_DIR="$FIXTURE_DIR"
DRY_RUN=false
source "$LIB_DIR/generators/sheal.sh"
generate_sheal

[[ ! -f "$FIXTURE_DIR/.self-heal.json" ]] && pass "No .self-heal.json when sheal not installed" || fail "generator skip" ".self-heal.json was created"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 6: Bridge — JSONL to sheal markdown
# ─────────────────────────────────────────────
echo -e "${BOLD}test_bridge_jsonl_to_sheal${NC}"
setup_fixture

mkdir -p "$FIXTURE_DIR/tools/learnings" "$FIXTURE_DIR/.sheal/learnings"
echo '{"date":"2026-04-17","category":"bug","summary":"test learning","detail":"detailed info","files":[]}' > "$FIXTURE_DIR/tools/learnings/test-learnings.jsonl"

TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/bridge/sheal_learnings.sh"
bridge_jsonl_to_sheal "$FIXTURE_DIR" 2>/dev/null

# Check file was created
learn_count=$(find "$FIXTURE_DIR/.sheal/learnings" -name 'LEARN-*.md' | wc -l | tr -d '[:space:]')
[[ "$learn_count" -eq 1 ]] && pass "Created 1 LEARN file from JSONL" || fail "jsonl_to_sheal count" "expected 1, got $learn_count"

# Check title is YAML quoted
if [[ "$learn_count" -ge 1 ]]; then
  learn_file=$(find "$FIXTURE_DIR/.sheal/learnings" -name 'LEARN-*.md' | head -1)
  grep -qF 'title: "test learning"' "$learn_file" && pass "Title is YAML double-quoted" || fail "yaml title" "not quoted"
  grep -qF 'category: failure-loop' "$learn_file" && pass "Category mapped bug→failure-loop" || fail "category map" "wrong category"
  grep -qF 'source: aiframework' "$learn_file" && pass "Source tagged as aiframework" || fail "source tag" "missing"
fi

teardown_fixture

# ─────────────────────────────────────────────
# TEST 7: Bridge — dedup prevents re-sync
# ─────────────────────────────────────────────
echo -e "${BOLD}test_bridge_dedup${NC}"
setup_fixture

mkdir -p "$FIXTURE_DIR/tools/learnings" "$FIXTURE_DIR/.sheal/learnings"
echo '{"date":"2026-04-17","category":"bug","summary":"dedup test","detail":"info","files":[]}' > "$FIXTURE_DIR/tools/learnings/test-learnings.jsonl"

TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/bridge/sheal_learnings.sh"
bridge_jsonl_to_sheal "$FIXTURE_DIR" 2>/dev/null

# Run again — should not create a second file
bridge_jsonl_to_sheal "$FIXTURE_DIR" 2>/dev/null || true

learn_count=$(find "$FIXTURE_DIR/.sheal/learnings" -name 'LEARN-*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
[[ "$learn_count" -eq 1 ]] && pass "Dedup prevents duplicate LEARN files" || fail "dedup" "expected 1, got $learn_count"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 8: Bridge — 500-file cap
# ─────────────────────────────────────────────
echo -e "${BOLD}test_bridge_500_cap${NC}"
setup_fixture

mkdir -p "$FIXTURE_DIR/tools/learnings" "$FIXTURE_DIR/.sheal/learnings"
# Create 500 existing files quickly using a subshell
(cd "$FIXTURE_DIR/.sheal/learnings" && seq -w 1 500 | while read -r i; do : > "LEARN-${i}-existing.md"; done)

echo '{"date":"2026-04-17","category":"bug","summary":"should be blocked","detail":"info","files":[]}' > "$FIXTURE_DIR/tools/learnings/test-learnings.jsonl"

TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/bridge/sheal_learnings.sh"
bridge_jsonl_to_sheal "$FIXTURE_DIR" 2>/dev/null || true

learn_count=$(find "$FIXTURE_DIR/.sheal/learnings" -name 'LEARN-*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
[[ "$learn_count" -eq 500 ]] && pass "500-file cap enforced (still 500)" || fail "500 cap" "expected 500, got $learn_count"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 9: Bridge — sheal to JSONL (reverse)
# ─────────────────────────────────────────────
echo -e "${BOLD}test_bridge_sheal_to_jsonl${NC}"
setup_fixture

mkdir -p "$FIXTURE_DIR/.sheal/learnings" "$FIXTURE_DIR/tools/learnings" "$FIXTURE_DIR/.aiframework"
echo '{"identity":{"short_name":"test"}}' > "$FIXTURE_DIR/.aiframework/manifest.json"

# Create a sheal-native learning (no source: aiframework)
cat > "$FIXTURE_DIR/.sheal/learnings/LEARN-001-native.md" << 'LEARNMD'
---
title: "native sheal learning"
category: workflow
severity: medium
status: active
date: 2026-04-17
---

This was discovered by sheal during a session.
LEARNMD

TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/bridge/sheal_learnings.sh"
bridge_sheal_to_jsonl "$FIXTURE_DIR" 2>/dev/null

jsonl_file="$FIXTURE_DIR/tools/learnings/test-learnings.jsonl"
[[ -f "$jsonl_file" ]] && pass "JSONL file created" || fail "sheal_to_jsonl" "no JSONL file"

if [[ -f "$jsonl_file" ]]; then
  line_count=$(wc -l < "$jsonl_file" | tr -d '[:space:]')
  [[ "$line_count" -eq 1 ]] && pass "One JSONL entry created" || fail "jsonl count" "expected 1, got $line_count"

  # Verify jq can parse it
  jq empty "$jsonl_file" 2>/dev/null && pass "JSONL is valid JSON" || fail "jsonl valid" "invalid JSON"

  # Check category mapping
  cat_val=$(jq -r '.category' "$jsonl_file")
  [[ "$cat_val" == "pattern" ]] && pass "Category mapped workflow→pattern" || fail "reverse cat" "expected pattern, got $cat_val"

  # Check source tag
  src_val=$(jq -r '.source' "$jsonl_file")
  [[ "$src_val" == "sheal" ]] && pass "Source tagged as sheal" || fail "source" "expected sheal, got $src_val"
fi

teardown_fixture

# ─────────────────────────────────────────────
# TEST 10: Bridge — source:aiframework skip prevents round-trip
# ─────────────────────────────────────────────
echo -e "${BOLD}test_bridge_source_skip${NC}"
setup_fixture

mkdir -p "$FIXTURE_DIR/.sheal/learnings" "$FIXTURE_DIR/tools/learnings" "$FIXTURE_DIR/.aiframework"
echo '{"identity":{"short_name":"test"}}' > "$FIXTURE_DIR/.aiframework/manifest.json"

# Create a file WITH source: aiframework (should be skipped on reverse)
cat > "$FIXTURE_DIR/.sheal/learnings/LEARN-001-from-aif.md" << 'LEARNMD'
---
title: "from aiframework"
category: workflow
severity: medium
status: active
date: 2026-04-17
source: aiframework
---

This came from aiframework and should NOT be synced back.
LEARNMD

TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/bridge/sheal_learnings.sh"
bridge_sheal_to_jsonl "$FIXTURE_DIR" 2>/dev/null || true

jsonl_file="$FIXTURE_DIR/tools/learnings/test-learnings.jsonl"
if [[ -f "$jsonl_file" ]]; then
  line_count=$(wc -l < "$jsonl_file" | tr -d '[:space:]')
else
  line_count=0
fi
[[ "$line_count" -eq 0 ]] && pass "source:aiframework files skipped (no JSONL entry)" || fail "source skip" "expected 0 lines, got $line_count"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 11: Bridge — category round-trip (all 4)
# ─────────────────────────────────────────────
echo -e "${BOLD}test_category_roundtrip${NC}"
setup_fixture

mkdir -p "$FIXTURE_DIR/tools/learnings" "$FIXTURE_DIR/.sheal/learnings" "$FIXTURE_DIR/.aiframework"
echo '{"identity":{"short_name":"test"}}' > "$FIXTURE_DIR/.aiframework/manifest.json"

# Write 4 entries with all categories
for cat in bug gotcha pattern decision; do
  echo "{\"date\":\"2026-04-17\",\"category\":\"$cat\",\"summary\":\"${cat} test entry\",\"detail\":\"detail for $cat\",\"files\":[]}" >> "$FIXTURE_DIR/tools/learnings/test-learnings.jsonl"
done

TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/bridge/sheal_learnings.sh"

# Forward: JSONL → sheal
bridge_jsonl_to_sheal "$FIXTURE_DIR" 2>/dev/null

sheal_count=$(find "$FIXTURE_DIR/.sheal/learnings" -name 'LEARN-*.md' | wc -l | tr -d '[:space:]')
[[ "$sheal_count" -eq 4 ]] && pass "Forward: 4 LEARN files created" || fail "forward count" "expected 4, got $sheal_count"

# Check sheal categories
grep -rq 'category: failure-loop' "$FIXTURE_DIR/.sheal/learnings/" && pass "bug→failure-loop mapped" || fail "bug map" "missing"
grep -rq 'category: missing-context' "$FIXTURE_DIR/.sheal/learnings/" && pass "gotcha→missing-context mapped" || fail "gotcha map" "missing"
grep -rq 'category: workflow' "$FIXTURE_DIR/.sheal/learnings/" && pass "pattern→workflow mapped" || fail "pattern map" "missing"
grep -rq 'category: decision' "$FIXTURE_DIR/.sheal/learnings/" && pass "decision→decision mapped" || fail "decision map" "missing"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 12: Bridge — short_name sanitization (path traversal)
# ─────────────────────────────────────────────
echo -e "${BOLD}test_bridge_path_traversal${NC}"
setup_fixture

mkdir -p "$FIXTURE_DIR/.sheal/learnings" "$FIXTURE_DIR/tools/learnings" "$FIXTURE_DIR/.aiframework"
echo '{"identity":{"short_name":"../../etc/evil"}}' > "$FIXTURE_DIR/.aiframework/manifest.json"

cat > "$FIXTURE_DIR/.sheal/learnings/LEARN-001-test.md" << 'LEARNMD'
---
title: "path traversal test"
category: workflow
severity: medium
status: active
date: 2026-04-17
---

Test body.
LEARNMD

TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/bridge/sheal_learnings.sh"
bridge_sheal_to_jsonl "$FIXTURE_DIR" 2>/dev/null

# The sanitized short_name should NOT create files outside tools/learnings/
[[ ! -f "$FIXTURE_DIR/../../etc/evil-learnings.jsonl" ]] && pass "Path traversal blocked" || fail "path traversal" "file created outside boundary"
# Should create inside tools/learnings/ with sanitized name
ls "$FIXTURE_DIR/tools/learnings/"*-learnings.jsonl >/dev/null 2>&1 && pass "JSONL created in safe directory" || fail "safe dir" "no JSONL file found"

teardown_fixture

# ─────────────────────────────────────────────
# TEST 13: Bridge — body 10K cap
# ─────────────────────────────────────────────
echo -e "${BOLD}test_bridge_body_cap${NC}"
setup_fixture

mkdir -p "$FIXTURE_DIR/.sheal/learnings" "$FIXTURE_DIR/tools/learnings" "$FIXTURE_DIR/.aiframework"
echo '{"identity":{"short_name":"test"}}' > "$FIXTURE_DIR/.aiframework/manifest.json"

# Create a learning with a very long body (20K chars)
{
  echo '---'
  echo 'title: "long body test"'
  echo 'category: workflow'
  echo 'date: 2026-04-17'
  echo '---'
  echo ''
  python3 -c "print('x' * 20000)"
} > "$FIXTURE_DIR/.sheal/learnings/LEARN-001-long.md"

TARGET_DIR="$FIXTURE_DIR"
source "$LIB_DIR/bridge/sheal_learnings.sh"
bridge_sheal_to_jsonl "$FIXTURE_DIR" 2>/dev/null

jsonl_file="$FIXTURE_DIR/tools/learnings/test-learnings.jsonl"
if [[ -f "$jsonl_file" ]]; then
  detail_len=$(jq -r '.detail | length' "$jsonl_file")
  # 10000 chars from cut + possible trailing newline from printf = 10001 max
  [[ "$detail_len" -le 10100 ]] && pass "Body capped near 10K chars (got $detail_len)" || fail "body cap" "expected <=10100, got $detail_len"
else
  fail "body cap" "no JSONL file created"
fi

teardown_fixture

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}=== Results ===${NC}"
echo -e "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}ALL SHEAL TESTS PASSED${NC}"
  exit 0
else
  echo -e "${RED}SOME TESTS FAILED${NC}"
  exit 1
fi
