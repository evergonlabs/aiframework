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
[[ -d "$dir/vault" ]] && pass "vault created" || fail "vault missing"

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

# Summary
echo "=== Results ==="
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo ""

# Cleanup
rm -rf "$FIXTURES"

[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" && exit 0
echo "SOME TESTS FAILED" && exit 1
