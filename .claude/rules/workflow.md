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

## New Feature Checklist
- [ ] Feature works as specified
- [ ] Edge cases handled
- [ ] Error states covered
- [ ] Tests added for new functionality
- [ ] Documentation updated if needed
- [ ] No regressions in existing functionality

### C QA Rules
- All heap allocations must have corresponding frees — verify with Valgrind or AddressSanitizer
- All user-facing buffers must use bounds-checked functions (snprintf, strncpy) — no strcpy/sprintf
- All public headers must use include guards or #pragma once

