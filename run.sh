#!/usr/bin/env bash
# Convenience wrapper: full pipeline (discover → generate → verify)
# Usage: ./run.sh [target-dir]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"
shift || true
exec "$SCRIPT_DIR/bin/aiframework" run --target "$TARGET" "$@"
