---
description: "Workflow rules for development process — auto-loaded by Claude"
globs: "**/*"
---

# Workflow Rules

## Plan vs Execute
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan — don't keep pushing
- When given a task with clear scope: start executing immediately
- When hitting a wall (3+ failed attempts), stop and re-plan approach

## Autonomous Iteration
- Execute fix → verify with tests → if broken, fix again → loop until clean
- Iterate autonomously: don't ask for hand-holding on fixable issues
- Commit after each logical group of verified fixes

## Git Safety
- After fixes: `git add` + `git commit` — do NOT push until user says so
- NEVER push to main without explicit user confirmation
- NEVER commit after every small change — batch related changes into logical commits
- Prefer fewer, larger commits over many small ones

## Verification Before Done
- Never mark a task complete without proving it works
- Run verification commands — never assume it compiles
- Never claim "done" without running the actual verification command

## Subagent Strategy
- Use subagents for research, exploration, and parallel analysis
- Limit to 6-8 agents per wave maximum
- After each wave: summarize results, commit, then start next wave
- For large outputs: agents write results to files, not stdout

## QA Auto-Fix
When QA discovers issues, ALL must be automatically fixed:
1. Run tests — collect all failures
2. Fix each failure: identify root cause → fix implementation (never skip a test)
3. Run type check → must pass
4. Run tests again — all must pass
5. Commit

## Documentation Auto-Sync
After ANY feature implementation, refactor, or significant change:
1. CLAUDE.md — if change adds invariants, new key locations, new commands
2. docs/ — update relevant doc files

## Changelog Update
After marking any feature complete and before pushing:
1. Update CHANGELOG.md with user-facing description of changes
2. Bump VERSION file (PATCH for fixes, MINOR for features, MAJOR for breaking)

## Safety Guardrails
- NEVER add data expiry, TTL logic, or cleanup routines unless explicitly asked
- NEVER clone or run external GitHub repos — read READMEs via WebFetch only
- NEVER push to main without confirmation — pushes may trigger deploys that cost money
- Before changing 3+ files: list every file and what changes, wait for approval
- Verify correct file before editing — wrong Dockerfile, wrong config, wrong component
- When in doubt: run more checks, not fewer. Ask yourself: would a staff engineer approve this?
- Complete all phases in a single session when requested — do not suggest splitting work across sessions

## New Feature Checklist
- [ ] Feature works as specified
- [ ] Edge cases handled
- [ ] Error states covered
- [ ] Tests added for new functionality
- [ ] Documentation updated if needed
- [ ] No regressions in existing functionality

### Bash QA Rules
- All scripts must pass shellcheck with zero warnings
- All scripts must start with set -euo pipefail for strict error handling
- All user-supplied variables must be quoted — no unquoted $VAR expansions
- NEVER use `|| true` to silence errors without understanding the failure
- NEVER use `set +e` to disable error handling without re-enabling it

