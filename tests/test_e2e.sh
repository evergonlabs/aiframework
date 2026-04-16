#!/usr/bin/env bash
# Integration tests for aiframework pipeline
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
FIXTURES="$SCRIPT_DIR/fixtures"
PASSED=0
FAILED=0

pass() { echo "  PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL: $1"; FAILED=$((FAILED + 1)); }

setup_fixture() {
  local name="$1"
  local dir="$FIXTURES/$name"
  rm -rf "$dir"
  mkdir -p "$dir"
  cd "$dir" && git init -q
  echo "$dir"
}

echo "=== aiframework integration tests ==="
echo ""

# Test 1: Next.js project
echo "Test 1: Next.js TypeScript project"
dir=$(setup_fixture "nextjs-app")
echo '{"name":"myapp","scripts":{"dev":"next dev","build":"next build","test":"jest","lint":"eslint ."}}' > "$dir/package.json"
echo '{"compilerOptions":{"strict":true}}' > "$dir/tsconfig.json"
mkdir -p "$dir/src/components"
echo 'export default function Home() { return "hello" }' > "$dir/src/components/Home.tsx"
echo 'export function api() { return "data" }' > "$dir/src/api.ts"

"$ROOT_DIR/bin/aiframework" discover --target "$dir" --non-interactive 2>/dev/null || true
[[ -f "$dir/.aiframework/manifest.json" ]] && pass "manifest created" || fail "manifest missing"
[[ -f "$dir/.aiframework/code-index.json" ]] && pass "code-index created" || fail "code-index missing"
lang=$(jq -r '.stack.language' "$dir/.aiframework/manifest.json" 2>/dev/null || echo "unknown")
[[ "$lang" == "typescript" || "$lang" == "javascript" ]] && pass "language=$lang" || fail "language=$lang (expected typescript/javascript)"
arch=$(jq -r '.archetype.type' "$dir/.aiframework/manifest.json" 2>/dev/null || echo "unknown")
[[ "$arch" != "unknown" ]] && pass "archetype=$arch" || fail "archetype=unknown"

"$ROOT_DIR/bin/aiframework" generate --target "$dir" 2>/dev/null || true
[[ -f "$dir/CLAUDE.md" ]] && pass "CLAUDE.md generated" || fail "CLAUDE.md missing"
[[ -f "$dir/AGENTS.md" ]] && pass "AGENTS.md generated" || fail "AGENTS.md missing"
[[ -d "$dir/vault" ]] && pass "vault created" || fail "vault missing"

# Lean CLAUDE.md: must be under 200 lines
line_count=$(wc -l < "$dir/CLAUDE.md" | tr -d '[:space:]')
[[ "$line_count" -lt 200 ]] && pass "CLAUDE.md is lean ($line_count lines)" || fail "CLAUDE.md too large ($line_count lines, expected <200)"

echo ""

# Test 2: Python FastAPI project
echo "Test 2: Python project"
dir=$(setup_fixture "python-api")
printf '[project]\nname = "myapi"\nversion = "1.0.0"\ndependencies = ["fastapi", "uvicorn"]\n' > "$dir/pyproject.toml"
mkdir -p "$dir/src/myapi"
printf 'from fastapi import FastAPI\napp = FastAPI()\n@app.get("/")\ndef root():\n    return {"ok": True}\n' > "$dir/src/myapi/main.py"
printf 'def add(a, b):\n    return a + b\n' > "$dir/src/myapi/utils.py"

"$ROOT_DIR/bin/aiframework" discover --target "$dir" --non-interactive 2>/dev/null || true
[[ -f "$dir/.aiframework/manifest.json" ]] && pass "manifest created" || fail "manifest missing"
lang=$(jq -r '.stack.language' "$dir/.aiframework/manifest.json" 2>/dev/null || echo "unknown")
[[ "$lang" == "python" ]] && pass "language=python" || fail "language=$lang"
syms=$(jq -r '._meta.total_symbols' "$dir/.aiframework/code-index.json" 2>/dev/null || echo "0")
[[ "$syms" -ge 2 ]] && pass "symbols=$syms (>=2)" || fail "symbols=$syms (<2)"

echo ""

# Test 3: Minimal repo (few files, no package manager)
echo "Test 3: Minimal repo"
dir=$(setup_fixture "minimal")
echo '#!/bin/bash' > "$dir/run.sh"
echo 'echo hello' >> "$dir/run.sh"
echo '# My Project' > "$dir/README.md"
echo 'stuff' > "$dir/config.txt"

"$ROOT_DIR/bin/aiframework" discover --target "$dir" --non-interactive --no-index 2>/dev/null || true
[[ -f "$dir/.aiframework/manifest.json" ]] && pass "manifest created" || fail "manifest missing"
arch=$(jq -r '.archetype.type' "$dir/.aiframework/manifest.json" 2>/dev/null || echo "unknown")
[[ "$arch" == "minimal" ]] && pass "archetype=minimal" || fail "archetype=$arch (expected minimal)"

# Generate and check: minimal repos should NOT get extended rules
"$ROOT_DIR/bin/aiframework" generate --target "$dir" 2>/dev/null || true
if [[ -f "$dir/CLAUDE.md" ]]; then
  min_lines=$(wc -l < "$dir/CLAUDE.md" | tr -d '[:space:]')
  [[ "$min_lines" -lt 200 ]] && pass "CLAUDE.md is lean ($min_lines lines)" || fail "CLAUDE.md too large ($min_lines lines)"
fi
[[ ! -f "$dir/.claude/rules/pipeline.md" ]] && pass "no pipeline.md (simple project)" || fail "pipeline.md exists (should not for minimal)"

echo ""

# Test 4: Monorepo detection
echo "Test 4: Monorepo (npm workspaces)"
dir=$(setup_fixture "monorepo")
echo '{"name":"mono","private":true,"workspaces":["packages/*"]}' > "$dir/package.json"
mkdir -p "$dir/packages/api" "$dir/packages/web"
echo '{"name":"@mono/api"}' > "$dir/packages/api/package.json"
echo '{"name":"@mono/web"}' > "$dir/packages/web/package.json"

"$ROOT_DIR/bin/aiframework" discover --target "$dir" --non-interactive --no-index 2>/dev/null || true
[[ -f "$dir/.aiframework/manifest.json" ]] && pass "manifest created" || fail "manifest missing"
mono=$(jq -r '.stack.is_monorepo' "$dir/.aiframework/manifest.json" 2>/dev/null || echo "false")
[[ "$mono" == "true" ]] && pass "monorepo=true" || fail "monorepo=$mono"
arch=$(jq -r '.archetype.type' "$dir/.aiframework/manifest.json" 2>/dev/null || echo "unknown")
[[ "$arch" == "monorepo" ]] && pass "archetype=monorepo" || fail "archetype=$arch"

echo ""

# Test 5: Complex project — extended rules generation
echo "Test 5: Complex project (extended rules)"
dir=$(setup_fixture "complex-api")
echo '{"name":"bigapp","scripts":{"dev":"next dev","build":"next build","test":"jest","lint":"eslint ."}}' > "$dir/package.json"
echo '{"compilerOptions":{"strict":true}}' > "$dir/tsconfig.json"
mkdir -p "$dir/src/api" "$dir/src/auth"
echo 'export function handler() {}' > "$dir/src/api/route.ts"
echo 'export function login() {}' > "$dir/src/auth/session.ts"

"$ROOT_DIR/bin/aiframework" discover --target "$dir" --non-interactive --no-index 2>/dev/null || true
# Override complexity to complex for testing extended rules
jq '.archetype.complexity = "complex"' "$dir/.aiframework/manifest.json" > "$dir/.aiframework/manifest.json.tmp" && mv "$dir/.aiframework/manifest.json.tmp" "$dir/.aiframework/manifest.json"

"$ROOT_DIR/bin/aiframework" generate --target "$dir" 2>/dev/null || true
[[ -f "$dir/CLAUDE.md" ]] && pass "CLAUDE.md generated" || fail "CLAUDE.md missing"
[[ -f "$dir/AGENTS.md" ]] && pass "AGENTS.md generated" || fail "AGENTS.md missing"
[[ -f "$dir/.cursorrules" ]] && pass ".cursorrules generated" || fail ".cursorrules missing"
complex_lines=$(wc -l < "$dir/CLAUDE.md" | tr -d '[:space:]')
[[ "$complex_lines" -lt 200 ]] && pass "CLAUDE.md is lean ($complex_lines lines)" || fail "CLAUDE.md too large ($complex_lines lines)"
[[ -f "$dir/.claude/rules/pipeline.md" ]] && pass "pipeline.md generated" || fail "pipeline.md missing"
[[ -f "$dir/.claude/rules/session-protocol.md" ]] && pass "session-protocol.md generated" || fail "session-protocol.md missing"
[[ -f "$dir/.claude/rules/invariants.md" ]] && pass "invariants.md generated" || fail "invariants.md missing"
[[ -f "$dir/docs/reference/architecture.md" ]] && pass "architecture.md generated" || fail "architecture.md missing"
# Verify pipeline.md has key content
grep -q 'Autonomous Pipeline' "$dir/.claude/rules/pipeline.md" && pass "pipeline has 12-stage content" || fail "pipeline missing pipeline content"
grep -q 'Skill Routing' "$dir/.claude/rules/pipeline.md" && pass "pipeline has skill routing" || fail "pipeline missing skill routing"
# Verify session-protocol has execution matrices
grep -q 'Bug Fix Flow' "$dir/.claude/rules/session-protocol.md" && pass "session-protocol has matrices" || fail "session-protocol missing matrices"

# Verify AGENTS.md content
grep -q '## Build' "$dir/AGENTS.md" && pass "AGENTS.md has Build section" || fail "AGENTS.md missing Build"
agents_lines=$(wc -l < "$dir/AGENTS.md" | tr -d '[:space:]')
[[ "$agents_lines" -lt 150 ]] && pass "AGENTS.md under 150 lines ($agents_lines)" || fail "AGENTS.md too large ($agents_lines)"

echo ""

# Test 6: Config-gated output (only AGENTS.md)
echo "Test 6: Config-gated output"
dir=$(setup_fixture "config-test")
echo '{"name":"cfgapp","scripts":{"build":"make"}}' > "$dir/package.json"
"$ROOT_DIR/bin/aiframework" discover --target "$dir" --non-interactive --no-index 2>/dev/null || true
mkdir -p "$dir/.aiframework"
echo '{"formats":["agents"],"tier":"minimal"}' > "$dir/.aiframework/config.json"
"$ROOT_DIR/bin/aiframework" generate --target "$dir" 2>/dev/null || true
[[ -f "$dir/AGENTS.md" ]] && pass "AGENTS.md generated (config)" || fail "AGENTS.md missing (config)"
[[ ! -f "$dir/CLAUDE.md" ]] && pass "CLAUDE.md not generated (config)" || fail "CLAUDE.md exists (should be gated)"
[[ ! -d "$dir/vault" ]] && pass "vault not generated (minimal tier)" || fail "vault exists (should be gated)"

# Test 7: Standard tier — hooks + skills but no vault
echo "Test 7: Standard tier config"
dir=$(setup_fixture "standard-tier")
echo '{"name":"stdapp","scripts":{"build":"make","test":"make test"}}' > "$dir/package.json"
"$ROOT_DIR/bin/aiframework" discover --target "$dir" --non-interactive --no-index 2>/dev/null || true
mkdir -p "$dir/.aiframework"
echo '{"tier":"standard"}' > "$dir/.aiframework/config.json"
"$ROOT_DIR/bin/aiframework" generate --target "$dir" 2>/dev/null || true
[[ -f "$dir/CLAUDE.md" ]] && pass "CLAUDE.md generated (standard)" || fail "CLAUDE.md missing"
[[ -f "$dir/AGENTS.md" ]] && pass "AGENTS.md generated (standard)" || fail "AGENTS.md missing"
[[ -f "$dir/.cursorrules" ]] && pass ".cursorrules generated (standard)" || fail ".cursorrules missing"

echo ""

# Test 8: AGENTS.md should not show NOT_CONFIGURED
echo "Test 8: AGENTS.md quality"
dir=$(setup_fixture "agents-quality")
echo '{"name":"aqapp","scripts":{"test":"jest"}}' > "$dir/package.json"
"$ROOT_DIR/bin/aiframework" discover --target "$dir" --non-interactive --no-index 2>/dev/null || true
"$ROOT_DIR/bin/aiframework" generate --target "$dir" 2>/dev/null || true
if [[ -f "$dir/AGENTS.md" ]]; then
  if grep -q 'NOT_CONFIGURED' "$dir/AGENTS.md"; then
    fail "AGENTS.md contains NOT_CONFIGURED"
  else
    pass "AGENTS.md clean (no NOT_CONFIGURED)"
  fi
fi

echo ""

# Summary
echo "=== Results ==="
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo ""

# Cleanup
rm -rf "$FIXTURES"

[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" && exit 0
echo "SOME TESTS FAILED" && exit 1
