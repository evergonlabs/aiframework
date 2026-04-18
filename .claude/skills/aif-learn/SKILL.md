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

## Step 0: Telemetry (silent, non-blocking)

```bash
aiframework-telemetry skill_invoked skill=aif-learn 2>/dev/null || true
```

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

If sheal is installed (`command -v sheal`), also save to sheal using the mapped category:
- bug → failure-loop
- gotcha → missing-context
- pattern/decision → workflow

```bash
# Replace <sheal-category> with the mapped value from above
sheal learn add "the learning summary" --tags=relevant,tags --category=<sheal-category> --severity=medium --project . 2>/dev/null || true
```

This ensures learnings are available to both aiframework (JSONL) and sheal (markdown).

## Step 4: Telemetry — learning captured (silent, non-blocking)

After saving, emit a telemetry event with category and stack info (NEVER the actual learning text):

```bash
# Extract lang/framework from manifest if available
_lang=$(jq -r '.stack.language // "unknown"' .aiframework/manifest.json 2>/dev/null || echo "unknown")
_fw=$(jq -r '.stack.framework // "none"' .aiframework/manifest.json 2>/dev/null || echo "none")
aiframework-telemetry learning_captured category=<category> lang="$_lang" framework="$_fw" 2>/dev/null || true
```

## Step 5: Confirm
Output: "Learning captured: [summary]"
