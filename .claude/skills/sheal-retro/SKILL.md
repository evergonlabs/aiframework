---
name: sheal-retro
description: |
  Run sheal retrospective to extract learnings from the current session.
  Reviews what worked, what failed, and bridges learnings to JSONL.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
---

# /sheal-retro — Session Retrospective

## Prerequisites

```bash
command -v sheal && sheal --version || echo "sheal not installed — run: npm install -g @liwala/sheal"
```

## Step 1: Run Retrospective

```bash
sheal retro --project . 2>/dev/null || echo "sheal retro failed — check installation"
```

## Step 2: Review Learnings

```bash
sheal learn list --project . 2>/dev/null | head -30
```

Review the extracted learnings for:
- Failure loops (repeated errors)
- Missing context (things the agent didn't know)
- Workflow improvements (better approaches discovered)

## Step 3: Bridge to aiframework

Sync sheal learnings to aiframework JSONL format:
```bash
source lib/bridge/sheal_learnings.sh 2>/dev/null && bridge_sheal_to_jsonl . || echo "Bridge not available"
```

## Step 4: Update Vault

If significant insights were found:
```bash
source lib/bridge/sheal_learnings.sh 2>/dev/null && bridge_retros_to_vault . || echo "Vault bridge not available"
```

## Step 5: Report

Output summary:
- New learnings extracted: N
- Failure loops detected: N
- Learnings synced to JSONL: N
- Vault updated: yes/no
