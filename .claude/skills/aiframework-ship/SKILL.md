---
name: aiframework-ship
description: |
  aiframework shipping workflow. Runs lint + test + build, reviews code,
  checks invariants, updates docs + changelog, commits.
  NEVER pushes without explicit approval.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# /aiframework-ship — Shipping Workflow

## Step 1: Verify

```bash
find . -name .sh -not -path .git -not -path vault  xargs shellcheck
find . -name .sh -not -path .git -not -path vault  xargs bash -n
make test
```

## Step 2: Invariant Scan
Check changed files against all invariants in CLAUDE.md.

## Step 3: Doc Sync
Update any documentation affected by the changes.

## Step 4: CHANGELOG + VERSION bump
- Update CHANGELOG.md with user-facing description
- Bump VERSION (PATCH=fix, MINOR=feature, MAJOR=breaking)

## Step 5: Commit (NEVER push without asking the user)

## Step 5.5: Vault Update

If vault/ exists:
- Update `vault/memory/status.md` with shipping details
- If significant architectural decision was made → create ADR in `vault/memory/decisions/`
- Run `vault/.vault/scripts/vault-tools.sh lint`

## Step 6: Report

Output a summary table:
| Step | Status | Details |
|------|--------|---------|
| Lint | PASS/FAIL | ... |
| Type check | PASS/FAIL | ... |
| Tests | PASS/FAIL | X passed, Y failed |
| Build | PASS/FAIL | ... |
| Invariants | PASS/FAIL | ... |
| Docs | SYNCED/NEEDS UPDATE | ... |
| Changelog | UPDATED | ... |
| Committed | YES/NO | commit hash |
