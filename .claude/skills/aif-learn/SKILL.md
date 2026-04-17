---
name: aif-learn
description: |
  Capture a project learning to persistent storage.
  Saves to tools/learnings/ (JSONL) and optionally vault/memory/notes/.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
---

# /aif-learn — Capture Learning

## Usage
`/aif-learn "description of what was learned"`

## Step 1: Classify
Determine category: bug, gotcha, pattern, or decision

## Step 2: Save to learnings file
Append a JSON line to `tools/learnings/aif-learnings.jsonl`:
```json
{"date": "YYYY-MM-DD", "category": "category", "summary": "one-line", "detail": "full explanation", "files": ["relevant/files"]}
```

## Step 3: Save to vault (if significant)
If the learning is significant (would affect future architecture decisions):
- Create a note in `vault/memory/notes/` with YAML frontmatter
- Or create a decision record in `vault/memory/decisions/` using ADR format from `vault/templates/decision-record.md`

## Step 3b: Dual-write to sheal (if installed)

If sheal is installed (`command -v sheal`), also save to sheal:
```bash
sheal learn add "the learning summary" --tags=relevant,tags --category="$CATEGORY" --severity=medium --project . 2>/dev/null || true
```

This ensures learnings are available to both aiframework (JSONL) and sheal (markdown).

## Step 4: Confirm
Output: "Learning captured: [summary]"
