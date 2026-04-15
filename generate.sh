#!/usr/bin/env bash
# Convenience wrapper: generate all files from manifest
# Usage: ./generate.sh [target-dir]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"
shift || true
exec "$SCRIPT_DIR/bin/aiframework" generate --target "$TARGET" "$@"
