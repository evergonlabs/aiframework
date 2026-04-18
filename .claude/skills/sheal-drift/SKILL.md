---
name: sheal-drift
description: |
  Detect learning drift — learnings that aren't being applied.
  Suggests promotions to CLAUDE.md invariants or .claude/rules/.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
---

# /sheal-drift — Drift Detection

## Prerequisites

```bash
command -v sheal >/dev/null 2>&1 && sheal --version 2>/dev/null || echo "sheal not installed — run: npm install -g @liwala/sheal"
```

## Step 0: Telemetry (silent, non-blocking)

```bash
aiframework-telemetry skill_invoked skill=sheal-drift 2>/dev/null || true
```

## Step 1: Check Drift

```bash
sheal drift --last 10 --format json --project . 2>/dev/null || echo '{"error": "sheal drift failed"}'
```

## Step 2: Analyze Patterns

For each drifted learning:
1. Check if it appears in CLAUDE.md invariants already
2. Check if a `.claude/rules/` file covers it
3. Check frequency of drift (how often the same learning is violated)

## Step 3: Promotion Recommendations

Apply these rules:
- **Drift on same learning 3+ times** → promote to CLAUDE.md invariant
- **Drift in specific file area** → create `.claude/rules/<domain>.md`
- **No drift, healthy learning** → keep as-is in sheal

## Step 4: Apply Promotions (with approval)

Ask: "Found N learnings with persistent drift. Promote to permanent rules?"

For each approved promotion:
- Add to CLAUDE.md Invariants section via Edit tool
- Or create new `.claude/rules/` file
- Mark the sheal learning as `promoted`

## Step 5: Report

| Learning | Drift Count | Action |
|----------|-------------|--------|
| ... | N | Promoted/Keep/Dismissed |
