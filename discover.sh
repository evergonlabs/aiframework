#!/usr/bin/env bash
# Convenience wrapper: discover a repo and output manifest.json
# Usage: ./discover.sh [target-dir]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"
exec "$SCRIPT_DIR/bin/aiframework" discover --target "$TARGET"
