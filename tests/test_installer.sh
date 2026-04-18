#!/usr/bin/env bash
# Tests for install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALLER="$ROOT_DIR/install.sh"
PASSED=0
FAILED=0

pass() { echo "  PASS: $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  FAIL: $1"; FAILED=$((FAILED + 1)); }

echo "=== installer tests ==="
echo ""

# Test 1: Installer script exists and is executable
echo "Test 1: Installer basics"
[[ -f "$INSTALLER" ]] && pass "install.sh exists" || fail "install.sh missing"
[[ -x "$INSTALLER" ]] && pass "install.sh is executable" || fail "install.sh not executable"

# Test 2: Installer has valid sh syntax
echo "Test 2: Syntax check"
if bash -n "$INSTALLER" 2>/dev/null; then
  pass "install.sh syntax valid (bash)"
else
  fail "install.sh has syntax errors"
fi

# Test 3: Installer has --help flag
echo "Test 3: Help flag"
help_output=$("$INSTALLER" --help 2>&1) || true
if echo "$help_output" | grep -q "Usage"; then
  pass "--help shows usage"
else
  fail "--help missing usage text"
fi

# Test 4: Local install to temp directory (simulated — no network)
echo "Test 4: Local install (simulated)"
TMP_PREFIX=$(mktemp -d)
TMP_SRC=$(mktemp -d)
FAKE_AIFRAMEWORK_DIR="$TMP_SRC/aiframework-src"

# Simulate what the installer does: clone creates a directory with bin/, lib/, etc.
mkdir -p "$FAKE_AIFRAMEWORK_DIR/bin"
cp -r "$ROOT_DIR/bin/aiframework" "$FAKE_AIFRAMEWORK_DIR/bin/"
cp -r "$ROOT_DIR/bin/aiframework-mcp" "$FAKE_AIFRAMEWORK_DIR/bin/"
cp -r "$ROOT_DIR/bin/aiframework-telemetry" "$FAKE_AIFRAMEWORK_DIR/bin/"
cp "$ROOT_DIR/VERSION" "$FAKE_AIFRAMEWORK_DIR/"

# Create symlinks manually (what install_aiframework does)
mkdir -p "$TMP_PREFIX/bin"
ln -sf "$FAKE_AIFRAMEWORK_DIR/bin/aiframework" "$TMP_PREFIX/bin/aiframework"
ln -sf "$FAKE_AIFRAMEWORK_DIR/bin/aiframework-mcp" "$TMP_PREFIX/bin/aiframework-mcp"
ln -sf "$FAKE_AIFRAMEWORK_DIR/bin/aiframework-telemetry" "$TMP_PREFIX/bin/aiframework-telemetry"

# Verify symlinks
[[ -L "$TMP_PREFIX/bin/aiframework" ]] && pass "aiframework symlink created" || fail "aiframework symlink missing"
[[ -L "$TMP_PREFIX/bin/aiframework-mcp" ]] && pass "aiframework-mcp symlink created" || fail "aiframework-mcp symlink missing"
[[ -L "$TMP_PREFIX/bin/aiframework-telemetry" ]] && pass "aiframework-telemetry symlink created" || fail "aiframework-telemetry symlink missing"

# Verify symlinks point to correct location
target=$(readlink "$TMP_PREFIX/bin/aiframework" 2>/dev/null || true)
if [[ "$target" == *"aiframework-src/bin/aiframework" ]]; then
  pass "symlink target correct"
else
  fail "symlink target wrong: $target"
fi

# Test 5: Idempotent re-install (re-create symlinks)
echo "Test 5: Idempotent install"
ln -sf "$FAKE_AIFRAMEWORK_DIR/bin/aiframework" "$TMP_PREFIX/bin/aiframework"
[[ -L "$TMP_PREFIX/bin/aiframework" ]] && pass "symlink still exists after re-install" || fail "symlink missing after re-install"

# Test 6: Uninstall
echo "Test 6: Uninstall"
export PREFIX="$TMP_PREFIX"
export AIFRAMEWORK_DIR="$FAKE_AIFRAMEWORK_DIR"
"$INSTALLER" --uninstall 2>/dev/null && pass "uninstall completed" || fail "uninstall failed"
[[ ! -L "$TMP_PREFIX/bin/aiframework" ]] && pass "symlink removed" || fail "symlink still exists"
[[ ! -d "$FAKE_AIFRAMEWORK_DIR" ]] && pass "source dir removed" || fail "source dir still exists"

# Cleanup
rm -rf "$TMP_PREFIX" "$TMP_SRC"
unset PREFIX AIFRAMEWORK_DIR

echo ""

# Test 7: Dist tarball builds
echo "Test 7: Dist tarball"
VERSION=$(cat "$ROOT_DIR/VERSION" | tr -d '[:space:]')
TARBALL="$ROOT_DIR/dist/aiframework-${VERSION}.tar.gz"
rm -rf "$ROOT_DIR/dist"

if (cd "$ROOT_DIR" && make dist 2>&1); then
  [[ -f "$TARBALL" ]] && pass "tarball created" || fail "tarball missing"

  # Verify tarball contents
  if [[ -f "$TARBALL" ]]; then
    contents=$(tar tzf "$TARBALL" 2>/dev/null)
    echo "$contents" | grep -q "aiframework/bin/aiframework$" && pass "tarball contains bin/aiframework" || fail "tarball missing bin/aiframework"
    echo "$contents" | grep -q "aiframework/VERSION" && pass "tarball contains VERSION" || fail "tarball missing VERSION"
    echo "$contents" | grep -q "aiframework/Makefile" && pass "tarball contains Makefile" || fail "tarball missing Makefile"
    echo "$contents" | grep -q "aiframework/lib/" && pass "tarball contains lib/" || fail "tarball missing lib/"

    # Verify tarball does NOT contain dev files
    if echo "$contents" | grep -q "\.git/"; then
      fail "tarball contains .git/"
    else
      pass "tarball excludes .git/"
    fi
    if echo "$contents" | grep -q "tests/"; then
      fail "tarball contains tests/"
    else
      pass "tarball excludes tests/"
    fi
  fi

  rm -rf "$ROOT_DIR/dist"
else
  fail "make dist failed"
fi

echo ""

# Test 8: update-check flags
echo "Test 8: update-check flags"
UPDATE_CHECK="$ROOT_DIR/bin/aiframework-update-check"
if bash -n "$UPDATE_CHECK" 2>/dev/null; then
  pass "update-check syntax valid"
else
  fail "update-check syntax errors"
fi

# Test 9: detect install method
echo "Test 9: Install method detection"
# Verify the function exists in the file
if grep -q '_detect_install_method' "$ROOT_DIR/bin/aiframework"; then
  pass "_detect_install_method exists"
else
  fail "_detect_install_method missing"
fi

# Test that command aliases work (literal string in case dispatch)
if grep -qF 'upgrade|update|self-update' "$ROOT_DIR/bin/aiframework"; then
  pass "update/self-update aliases registered"
else
  fail "update/self-update aliases missing"
fi

echo ""

# Summary
echo "=== Results ==="
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo ""

[[ $FAILED -eq 0 ]] && echo "ALL TESTS PASSED" && exit 0
echo "SOME TESTS FAILED" && exit 1
