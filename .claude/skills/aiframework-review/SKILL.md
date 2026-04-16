---
name: aiframework-review
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

# /aiframework-review — Code Review

## Step 1: CRITICAL Pass

For each changed file (`git diff --name-only HEAD~1 HEAD`), check:

### 1.1 INV-1: Input Validation
Verify all API endpoints validate input before processing.
Look for: missing validation, untyped request bodies, direct user input in queries.

### 1.2 INV-2: No Secrets in Source Code
Verify no API keys, passwords, tokens, or credentials are committed.
Look for: hardcoded secrets, .env files committed, credentials in config, tokens in URLs.


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
