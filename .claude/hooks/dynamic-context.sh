#!/bin/bash
# Dynamic context injection — tells Claude what to focus on this session
# Runs as part of SessionStart to provide session-specific context.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CONTEXT=""

# ── Recent git activity → focus areas ──
if command -v git &>/dev/null && git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
  # What files changed recently?
  RECENT_FILES=$(git -C "$PROJECT_DIR" log --oneline --name-only -20 2>/dev/null | grep -v "^[a-f0-9]" | sort | uniq -c | sort -rn | head -5 | awk '{print $2}')

  if [[ -n "$RECENT_FILES" ]]; then
    CONTEXT="${CONTEXT}Recently active files (focus areas for this session):\n"
    while IFS= read -r file; do
      [[ -n "$file" ]] && CONTEXT="${CONTEXT}  - ${file}\n"
    done <<< "$RECENT_FILES"
    CONTEXT="${CONTEXT}\n"
  fi

  # Any uncommitted changes?
  DIRTY=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | head -5)
  if [[ -n "$DIRTY" ]]; then
    DIRTY_COUNT=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    CONTEXT="${CONTEXT}Uncommitted changes: ${DIRTY_COUNT} files modified.\n"
  fi

  # Current branch
  BRANCH=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null || echo "")
  if [[ -n "$BRANCH" && "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
    CONTEXT="${CONTEXT}Working on branch: ${BRANCH}\n"
  fi
fi

# ── Vault status (ongoing work) ──
STATUS_FILE="$PROJECT_DIR/vault/memory/status.md"
if [[ -f "$STATUS_FILE" ]]; then
  # Extract first non-empty, non-heading line as current status
  STATUS_LINE=$(grep -v "^#\|^$\|^---" "$STATUS_FILE" 2>/dev/null | head -1)
  if [[ -n "$STATUS_LINE" ]]; then
    CONTEXT="${CONTEXT}Last session status: ${STATUS_LINE}\n"
  fi
fi

# ── Recent learnings ──
LEARNINGS_DIR="$PROJECT_DIR/tools/learnings"
if [[ -d "$LEARNINGS_DIR" ]]; then
  LATEST=$(find "$LEARNINGS_DIR" -name "*.jsonl" -exec tail -1 {} \; 2>/dev/null | tail -1)
  if [[ -n "$LATEST" ]]; then
    SUMMARY=$(echo "$LATEST" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('summary',''))" 2>/dev/null || echo "")
    if [[ -n "$SUMMARY" ]]; then
      CONTEXT="${CONTEXT}Latest learning: ${SUMMARY}\n"
    fi
  fi
fi

# ── Output ──
if [[ -n "$CONTEXT" ]]; then
  printf '%s' "$CONTEXT" | jq -Rs '{continue: true, systemMessage: ("Session context:\n" + .)}'
fi
