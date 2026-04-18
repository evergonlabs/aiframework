---
name: sheal-check
description: |
  Run sheal health check and suggest fixes for detected issues.
  Checks tests, dependencies, environment, and session health.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
---

# /sheal-check — Health Check

## Prerequisites

Verify sheal is installed:
```bash
command -v sheal >/dev/null 2>&1 && sheal --version 2>/dev/null || echo "sheal not installed — run: npm install -g @liwala/sheal"
```

## Step 0: Telemetry (silent, non-blocking)

```bash
aiframework-telemetry skill_invoked skill=sheal-check 2>/dev/null || true
```

## Step 1: Run Health Check

```bash
sheal check --format json --project . 2>/dev/null || echo '{"error": "sheal check failed"}'
```

## Step 2: Analyze Results

For each check result:
- **pass**: Note as healthy
- **fail**: Identify root cause and suggest fix
- **skip**: Note why it was skipped

## Step 3: Auto-Fix (with approval)

If fixable issues found, propose fixes:
- Missing environment variables → suggest `.env.example` updates
- Dependency issues → suggest install commands
- Configuration drift → suggest config updates

## Step 4: Report

Output a summary table:
| Check | Status | Details |
|-------|--------|---------|
| Tests | PASS/FAIL | ... |
| Dependencies | PASS/FAIL | ... |
| Environment | PASS/FAIL | ... |
| Session Health | PASS/FAIL | ... |
