---
name: sheal-ask
description: |
  Query session history using natural language.
  Search past sessions for patterns, decisions, and context.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# /sheal-ask — Query Session History

## Usage
`/sheal-ask "your question here"`

## Prerequisites

```bash
command -v sheal >/dev/null 2>&1 && sheal --version 2>/dev/null || echo "sheal not installed — run: npm install -g @liwala/sheal"
```

## Step 1: Query

```bash
sheal ask "$ARGUMENTS" --project . 2>/dev/null || echo "sheal ask failed — check installation"
```

## Step 2: Supplement with Local Sources

Also search:
- `tools/learnings/*-learnings.jsonl` for matching JSONL entries
- `vault/memory/decisions/` for related decisions
- `vault/memory/notes/` for related notes
- `git log --oneline -30 --grep="<keyword>"` for related commits

## Step 3: Synthesize

Combine sheal session history with local sources to provide a comprehensive answer.
Present the most relevant findings first.
