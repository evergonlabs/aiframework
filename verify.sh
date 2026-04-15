#!/usr/bin/env bash
# Convenience wrapper: verify generated files against manifest
# Usage: ./verify.sh [target-dir]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"
shift || true
exec "$SCRIPT_DIR/bin/aiframework" verify --target "$TARGET" "$@"
