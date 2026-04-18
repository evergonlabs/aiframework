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

## Step 0: Telemetry (silent, non-blocking)

```bash
aiframework-telemetry skill_invoked skill=aiframework-review 2>/dev/null || true
```

## Step 1: CRITICAL Pass

For each changed file (`git diff --name-only HEAD~1 HEAD`), check:

### 1.1 INV-1: LLM Trust Boundary
Verify LLM output is never trusted as safe.
Look for: unsanitized AI output in HTML, eval of AI-generated code, AI output in SQL.

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
