#!/bin/bash
# aiframework session-start hook for Claude Code
# Runs automatically when a Claude Code session begins.
# Returns a JSON systemMessage that Claude reads and acts on.
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MESSAGES=""

# ── 1. Check if aiframework is installed ──
if ! command -v aiframework &>/dev/null; then
  MESSAGES="${MESSAGES}aiframework is not installed. Install it: curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh\n"
fi

# ── 2. Check if repo is bootstrapped ──
if [[ ! -f "$PROJECT_DIR/CLAUDE.md" ]]; then
  MESSAGES="${MESSAGES}This repo has not been bootstrapped. Run: aiframework run --target .\n"
elif [[ ! -d "$PROJECT_DIR/.aiframework" ]]; then
  MESSAGES="${MESSAGES}CLAUDE.md exists but .aiframework/ is missing. Run: aiframework run --target .\n"
fi

# ── 3. Check CLAUDE.md freshness ──
if [[ -f "$PROJECT_DIR/CLAUDE.md" && -f "$PROJECT_DIR/.aiframework/manifest.json" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    CLAUDE_MTIME=$(stat -f %m "$PROJECT_DIR/CLAUDE.md" 2>/dev/null || echo 0)
  else
    CLAUDE_MTIME=$(stat -c %Y "$PROJECT_DIR/CLAUDE.md" 2>/dev/null || echo 0)
  fi
  NOW=$(date +%s)
  DAYS_OLD=$(( (NOW - CLAUDE_MTIME) / 86400 ))

  if [[ $DAYS_OLD -gt 14 ]]; then
    MESSAGES="${MESSAGES}CLAUDE.md is ${DAYS_OLD} days old. Run: aiframework refresh\n"
  fi

  # Check if source files changed since last scan
  if command -v git &>/dev/null && git -C "$PROJECT_DIR" rev-parse --git-dir &>/dev/null 2>&1; then
    RECENT_COMMITS=$(git -C "$PROJECT_DIR" log --since="${DAYS_OLD} days ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$RECENT_COMMITS" -gt 20 ]]; then
      MESSAGES="${MESSAGES}${RECENT_COMMITS} commits since last scan. Run: aiframework refresh\n"
    fi
  fi
fi

# ── 4. Check if code index exists ──
if [[ -f "$PROJECT_DIR/.aiframework/manifest.json" && ! -f "$PROJECT_DIR/.aiframework/code-index.json" ]]; then
  MESSAGES="${MESSAGES}Code index missing. Run: aiframework index --target . (enables symbol search and knowledge graph)\n"
fi

# ── 5. Check if /aif-ready has been run ──
AIF_READY_MARKER="$PROJECT_DIR/.aiframework/.aif-ready-done"
if [[ -f "$PROJECT_DIR/CLAUDE.md" && -d "$PROJECT_DIR/.aiframework" ]]; then
  if [[ ! -f "$AIF_READY_MARKER" ]]; then
    MESSAGES="${MESSAGES}First session detected. Running automatic enhancement — researching your stack, discovering skills, and optimizing your configuration. Type /aif-ready to start, or I'll suggest improvements as we work.\n"
  else
    # Check if marker is older than 30 days
    if [[ "$(uname)" == "Darwin" ]]; then
      MARKER_MTIME=$(stat -f %m "$AIF_READY_MARKER" 2>/dev/null || echo 0)
    else
      MARKER_MTIME=$(stat -c %Y "$AIF_READY_MARKER" 2>/dev/null || echo 0)
    fi
    MARKER_NOW=$(date +%s)
    MARKER_DAYS_OLD=$(( (MARKER_NOW - MARKER_MTIME) / 86400 ))
    if [[ $MARKER_DAYS_OLD -gt 30 ]]; then
      MESSAGES="${MESSAGES}/aif-ready was last run ${MARKER_DAYS_OLD} days ago. Consider re-running /aif-ready for updated stack research.\n"
    fi
  fi
fi

# ── 6. Check companion tools ──
if ! command -v sheal &>/dev/null; then
  MESSAGES="${MESSAGES}sheal (session intelligence) is not installed. Install: npm install -g @liwala/sheal\n"
fi

if [[ ! -d "$HOME/.claude/skills/gstack" ]]; then
  MESSAGES="${MESSAGES}gstack (37 workflow skills) is not installed. Install: git clone https://github.com/garrytan/gstack ~/.claude/skills/gstack\n"
fi

# ── 7. Check vault health ──
if [[ -d "$PROJECT_DIR/vault" && ! -f "$PROJECT_DIR/vault/wiki/index.md" ]]; then
  MESSAGES="${MESSAGES}Vault exists but wiki index is missing. Run: aiframework run --target . --tier full\n"
fi

# ── 8. Check for update ──
if command -v aiframework &>/dev/null; then
  CURRENT_VER=$(aiframework --version 2>/dev/null | awk '{print $NF}' || echo "unknown")
  REMOTE_VER=$(curl -fsSL --connect-timeout 2 --max-time 3 https://raw.githubusercontent.com/evergonlabs/aiframework/main/VERSION 2>/dev/null | tr -d '[:space:]' || echo "")
  if [[ -n "$REMOTE_VER" && "$REMOTE_VER" != "$CURRENT_VER" && "$REMOTE_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    MESSAGES="${MESSAGES}aiframework update available: ${CURRENT_VER} → ${REMOTE_VER}. Run: aiframework update\n"
  fi
fi

# ── 9. Auto-evolve suggestion ──
if [[ -d "$PROJECT_DIR/tools/learnings" ]]; then
  LEARNING_COUNT=$(find "$PROJECT_DIR/tools/learnings" -name "*.jsonl" -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
  LAST_EVOLVE="$PROJECT_DIR/.aiframework/.last-evolve"
  if [[ "$LEARNING_COUNT" -gt 5 ]] && [[ ! -f "$LAST_EVOLVE" || -n "$(find "$LAST_EVOLVE" -mtime +7 2>/dev/null)" ]]; then
    MESSAGES="${MESSAGES}${LEARNING_COUNT} learnings accumulated. Run /aif-evolve to promote the best into permanent rules.\n"
  fi
fi

# ── Output ──
if [[ -n "$MESSAGES" ]]; then
  # Build systemMessage for Claude to read
  SYSTEM_MSG="aiframework session check:\n${MESSAGES}"
  # Use printf to properly format, then pipe to jq
  printf '%s' "$SYSTEM_MSG" | jq -Rs '{continue: true, systemMessage: .}'
else
  # Everything is good — no message needed
  exit 0
fi
