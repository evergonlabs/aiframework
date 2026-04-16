---
name: aif-review
description: |
  aiframework pre-landing code review with project-specific checks.
  Checks all invariants, runs specialist reviews based on changed files.
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

# /aif-review — Code Review

## Step 1: CRITICAL Pass

For each changed file (`git diff --name-only HEAD~1 HEAD`), check:

### 1.1 INV-1: Database Safety
Verify no raw SQL, all queries through ORM, migrations are reversible.
Look for: raw SQL strings, missing migrations, schema changes without migration.

### 1.2 INV-2: LLM Trust Boundary
Verify LLM output is never trusted as safe.
Look for: unsanitized AI output in HTML, eval of AI-generated code, AI output in SQL.


## Step 2: Specialist Army (if applicable)

Launch parallel specialists based on what files changed.
Check `tools/review-specialists/` for domain-specific review checklists.

## Step 3: Report

Output a table:
| Check | Status | Details |
|-------|--------|---------|
| ... | PASS/FAIL/WARN | ... |

## Step 4: Vault Check

If vault/ exists, check for related decisions:
- Read `vault/memory/decisions/` for ADRs related to changed files
- Run `vault/.vault/scripts/vault-tools.sh lint` to verify vault integrity
