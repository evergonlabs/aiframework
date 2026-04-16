# CLAUDE.md — aiframework

**Source of truth for Claude Code in this repository.**
**Update this file after significant decisions, bug fixes, or architectural changes.**

**Last updated: 2026-04-16**

---

## When to Read Which Doc

| You need to... | Read |
|----------------|------|
| Understand how to work in this repo | This file (CLAUDE.md) |
| Debug a recurring issue | `docs/LESSONS_LEARNED.md` (if exists) |
| Find documentation | `docs/` |
| See available make targets | `Makefile` |

---

## Decision Priority

When instructions conflict, follow this order:
1. **User's explicit instruction** in the current conversation
2. **Invariants** (below) — these are never overridden
3. **Workflow Rules** (below) — process guardrails
4. **Core Principles** (below) — design philosophy
5. **Reference docs** (\`docs/\`) — context, but code is always the source of truth

When determining system behavior (API shapes, data flow, field names):
1. **Read the code** — schemas, route handlers, models are the source of truth
2. **Verified external docs** — official API docs, confirmed library behavior
3. **Assume nothing** — if you can't verify it, say so

---

## Workflow Rules

### 1. Plan vs Execute
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan — don't keep pushing
- When given a task with clear scope: start executing immediately
- When hitting a wall (3+ failed attempts), stop and re-plan approach

### 2. Autonomous Iteration
- Execute fix → verify with tests → if broken, fix again → loop until clean
- Iterate autonomously: don't ask for hand-holding on fixable issues
- Commit after each logical group of verified fixes

### 3. Verification Before Done
- Never mark a task complete without proving it works
- Run verification commands (Stage 4) — never assume it compiles
- Never claim "done" without running the actual verification command

### 4. Git Safety
- After fixes: \`git add\` + \`git commit\` — but do NOT push until user says so
- NEVER push to main without explicit user confirmation
- NEVER commit after every small change — batch related changes into logical commits
- Prefer fewer, larger commits over many small ones

### 5. Subagent Strategy
- Use subagents for research, exploration, and parallel analysis
- Limit to 6-8 agents per wave maximum
- After each wave: summarize results, commit, then start next wave
- Use \`/compact\` after each major milestone to maintain headroom

### 6. QA Auto-Fix
When QA discovers issues, ALL must be automatically fixed:
1. Run tests — collect all failures
2. Fix each failure: identify root cause → fix implementation (never skip a test)
3. Run type check → must pass
4. Run tests again — all must pass
5. Commit

**C QA Rules:**
- All heap allocations must have corresponding frees — verify with Valgrind or AddressSanitizer
- All user-facing buffers must use bounds-checked functions (snprintf, strncpy) — no strcpy/sprintf
- All public headers must use include guards or #pragma once

### 7. Documentation Auto-Sync
After ANY feature implementation, refactor, or significant change — before marking complete:
1. CLAUDE.md — if change adds invariants, new key locations, new commands
2. docs/ — update relevant doc files

### 8. Changelog Update
After marking any feature complete and before pushing:
1. Update CHANGELOG.md with user-facing description of changes
2. Bump VERSION file (PATCH for fixes, MINOR for features, MAJOR for breaking changes)

### 9. CLAUDE.md Auto-Evolution
This file is a living document that grows with the project. After ANY session with code changes:
- **New service/module added** → add to Key Locations
- **New env var added** → add to Environment Variables table
- **Non-obvious bug fixed** → add to Session Learnings via \`/learn\`
- **New invariant discovered** → add to Invariants section
- **Structural change** → update Project Structure
- NEVER delete content — only add, refine, or mark as deprecated

### 10. New Feature Checklist
Before marking any new feature complete, verify ALL applicable items:
- [ ] Feature works as specified
- [ ] Edge cases handled
- [ ] Error states covered
- [ ] Tests added for new functionality
- [ ] Documentation updated if needed
- [ ] No regressions in existing functionality

---

## Core Principles

*Core principles will emerge as the project matures. Add principles here when patterns are established.*

1. Code must pass all configured quality gates before merge
2. Follow c community conventions and idioms
3. Never commit secrets, credentials, or API keys — use environment variables

---

## Project Identity

**aiframework** — One command. Any repo. Fully configured for AI-assisted development with Claude Code.

**Stack:** c / none

---

## Repository

**GitHub:** `https://github.com/evergonlabs/aiframework`
**Local path:** `/Users/rachidajaja/aiframework`

---

## Project Structure

```
├── bin/
├── docs/
│   ├── decisions/
│   ├── explanation/
│   ├── guides/
│   ├── onboarding/
│   ├── reference/
├── lib/
│   ├── data/
│   ├── freshness/
│   ├── generators/
│   ├── indexers/
│   ├── knowledge/
│   ├── scanners/
│   ├── validators/
├── templates/
├── tests/
│   ├── __pycache__/
├── tools/
│   ├── learnings/
│   ├── review-specialists/
├── vault/
│   ├── .vault/
│   ├── docs/
│   ├── memory/
│   ├── raw/
│   ├── templates/
│   ├── wiki/
├── Makefile
├── .gitignore
```

---

## Key Commands

```bash
# Build
make

# Lint
cppcheck --enable=all .

# Type check
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n

# Test
make test


# Format
clang-format -i
```

---

## CI Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|

---

## Key Locations

- **API Layer**: tools/review-specialists/api.md
- **Config**: `Makefile` — Build targets and automation
- **Config**: `.gitignore` — Project configuration
- **Scripts**: `bin/` — CLI entry points and tools
- **Scripts**: `tools/` — Project scripts
- **CI**: `.github/` — CI/CD pipeline definitions
- **Tests**: `tests/` — Test suite
- **Source**: `docs/README.md` — Module documentation
- **Source**: `lib/indexers/__init__.py` — Source module
- **Source**: `lib/indexers/graph.py` — Source module
- **Source**: `lib/indexers/lang_bash.py` — Source module
- **Source**: `lib/indexers/lang_go.py` — Source module
- **Source**: `lib/indexers/lang_python.py` — Source module
- **Source**: `lib/indexers/lang_ruby.py` — Source module
- **Source**: `lib/indexers/lang_rust.py` — Source module
- **Source**: `lib/indexers/lang_typescript.py` — Source module
- **Source**: `lib/indexers/parse.py` — Source module
- **Source**: `lib/knowledge/store.sh` — Source module
- **Source**: `lib/scanners/archetype.sh` — Repo analysis scanner
- **Source**: `lib/scanners/commands.sh` — Repo analysis scanner
- **Source**: `lib/scanners/quality.sh` — Repo analysis scanner
- **Source**: `lib/scanners/stack.sh` — Repo analysis scanner
- **Source**: `lib/scanners/structure.sh` — Repo analysis scanner
- **Source**: `lib/validators/consistency.sh` — Consistency validator
- **Source**: `lib/validators/security.sh` — Security validator
- **Source**: `lib/validators/freshness.sh` — Freshness validator
- **Source**: `lib/freshness/track.sh` — Freshness tracking module
- **Source**: `vault/.vault/scripts/lib-utils.sh` — Utility functions
- **Source**: `vault/raw/README.md` — Module documentation
- **Source**: `vault/wiki/sources/README.md` — Module documentation

---

## Module Map

| Module | Role | Files | Key Symbols | Depends On |
|--------|------|-------|-------------|------------|
| . | general | 4 | - | - |
| lib/freshness | general | 1 | freshness_save_hashes, freshness_check_drift | - |
| lib/generators | generation | 10 | generate_tracking, _sanitize_manifest_val, generate_skills | - |
| lib/indexers | general | 9 | _extract_rdoc_comment, parse_ruby, _extract_doc_comment | lib/indexers |
| lib/knowledge | general | 1 | knowledge_init, knowledge_record_profile, knowledge_record_miss | - |
| lib/scanners | discovery | 12 | _arr_to_json, scan_structure, scan_stack | - |
| lib/validators | verification | 5 | report_row, validate_files, validate_quality_gate | - |
| tests | testing | 3 | pass, fail, setup_fixture | - |
| vault/.vault/hooks | general | 1 | find_vault_root | - |
| vault/.vault/scripts | tooling | 3 | cmd_lint, cmd_validate, cmd_orphans | - |

### Architecture Hot Spots

- **Most complex**: `tests` (60 symbols across 3 files)

---

## Repo Map (Most Important Files)

> Files ranked by architectural importance (how many other files depend on them).

- `lib/indexers/__init__.py` (score: 0.004362244897959184)
- `lib/indexers/graph.py` (score: 0.004362244897959184)
- `vault/.vault/scripts/vault-tools.sh` (score: 0.0030612244897959186)
- `lib/validators/files.sh` (score: 0.0030612244897959186)
- `tests/test_validators.sh` (score: 0.0030612244897959186)
- `lib/indexers/lang_bash.py` (score: 0.0030612244897959186)
- `lib/generators/vault.sh` (score: 0.0030612244897959186)
- `lib/indexers/lang_rust.py` (score: 0.0030612244897959186)
- `lib/indexers/lang_go.py` (score: 0.0030612244897959186)
- `lib/generators/skills.sh` (score: 0.0030612244897959186)
- `lib/indexers/lang_ruby.py` (score: 0.0030612244897959186)
- `lib/generators/tracking.sh` (score: 0.0030612244897959186)
- `lib/generators/vault_ingest.sh` (score: 0.0030612244897959186)
- `lib/scanners/structure.sh` (score: 0.0030612244897959186)
- `vault/.vault/hooks/pre-commit.sh` (score: 0.0030612244897959186)

---

## API Contract Rules

- **Validation:** unknown
- All API endpoints MUST validate input before processing
- Response shapes must be consistent — use typed response wrappers
- Never expose internal errors to clients — use error codes
- Breaking API changes require version bump and migration plan

---

## Makefile System

Available `make` targets:

```bash
make install
make uninstall
make lint
make test
make check
```

---

## Autonomous Pipeline (12 Stages)

### Stage 1: INVESTIGATE (before writing any code)
When: User reports a bug or asks to fix something.
```
/investigate "description of the issue"
```

### Stage 2: PLAN (before major features)
When: User asks for a significant feature or architectural change.
```
/plan-eng-review "description of the feature"
```

### Stage 3: BUILD (write the code)
Rules: No secrets in code — use environment variables.

### Stage 4: VERIFY (after every code change — ALWAYS)
```bash
cppcheck --enable=all .              # Must pass with 0 errors
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n         # Must pass
make test              # Must pass
make             # Must compile/build
```

> Run `vault/.vault/scripts/vault-tools.sh lint` to verify vault integrity.

### Stage 5: REVIEW
```
/review
```

### Stage 6: SECURITY (when touching auth/security/API)
```
/cso
```

### Stage 6.5: CHANGELOG UPDATE
After completing any feature, fix, or significant change:
1. Update `CHANGELOG.md` with user-facing description
2. Bump `VERSION` file (PATCH for fixes, MINOR for features, MAJOR for breaking)
3. Commit changelog + version bump with the feature commit

### Stage 7: DOCS (after structural changes)
Run doc-sync check against this matrix:

| Change Type | Files to Update |
|-------------|----------------|
| New endpoint/route | CLAUDE.md (Key Locations), API docs |
| New env variable | CLAUDE.md (Env Variables), .env.example |
| New invariant | CLAUDE.md (Invariants) |
| Schema change | CLAUDE.md (Key Locations), migration docs |
| New dependency | CLAUDE.md (Project Identity), package manifest |
| New service/module | CLAUDE.md (Key Locations, Project Structure) |
| Architectural change | `docs/` architecture docs |

### Stage 8: QA (before every deploy)
```
/qa
```

### Stage 9: SHIP
```
/ship
```

### Stage 10: POST-DEPLOY
```
/canary
```

### Stage 11: LEARN
```
/learn "description of what was learned"
```

### Stage 12: RETRO (weekly)
```
/retro
```

---

## Skill Routing Table

| User says something like... | Claude's action |
|-----------------------------|----------------|
| "there's a bug", "it's broken", "fix this" | Start with `/investigate` before coding |
| "add feature", "build X" (big scope) | `/plan-eng-review` then build |
| "add feature", "change X" (small, clear) | Build directly, then verify + `/review` |
| "check security", "audit" | Run `/cso` immediately |
| "review the code", "check quality" | Run `/review` immediately |
| "test the app", "QA", "does it work" | Run `/qa` on the app URL |
| "deploy", "push", "ship it", "create PR" | Full pipeline: verify → `/review` → `/cso` → `/qa` → `/ship` |
| "what do we know about X", "previous decisions" | Check vault: `vault/wiki/index.md` and `vault/memory/decisions/` |
| "vault health", "check vault" | Run `vault/.vault/scripts/vault-tools.sh doctor` |
| "refactor", "clean up", "simplify" | Build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` |
| "update docs", "fix docs" | Update docs directly, then verify + `/review` |
| "performance", "optimize", "too slow" | `/investigate` → profile → fix → verify → `/review` |
| "CI", "tests failing", "pipeline broken" | `/investigate` the CI/test failure, fix, verify locally |
| "what changed recently", "catch me up" | Check `git log --oneline -20` + `vault/memory/status.md` |
| "give feedback", "rate the output" | Run `/aif-feedback` to collect structured feedback |

---

## End-of-Session Checklist

Before ending ANY session where code was changed, Claude MUST complete:

- [ ] **Verify**: Did I run lint + test + build? All pass?
- [ ] **Review**: Did I run `/review` on the changes?
- [ ] **Security**: If I touched auth/API/permissions → did I run `/cso`?
- [ ] **Docs**: Did any structural change happen? → Update docs
- [ ] **Learn**: Did I discover something non-obvious? → `/learn`
- [ ] **CHANGELOG**: Did I update CHANGELOG.md + VERSION?
- [ ] **Commit**: Are all changes committed with a descriptive message?
- [ ] **STATUS.md**: Did I update STATUS.md with current progress for multi-phase tasks?
- [ ] **Push**: Ready to push? Confirm with user before pushing.
- [ ] **Vault**: Did I update vault/memory/status.md with session progress?
- [ ] **Decisions**: Any significant decisions? → Log in vault/memory/decisions/

---

## Quick Reference Matrix

| Trigger | Skills to run (in order) |
|---------|------------------------|
| Bug reported | `/investigate` → fix → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| New feature | `/plan-eng-review` → build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| Small fix | build → verify → `/review` → docs → `/ship` |
| Refactor | build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` |

---

## Invariants

### INV-1: Input validation on all API endpoints
Every endpoint accepting user input must validate and sanitize before processing.


### INV-2: No secrets in source code
Never commit API keys, passwords, tokens, or credentials. All secrets must be stored in environment variables or a secrets manager.


---

## Project Profile

- **Archetype**: api-service
- **Maturity**: mature
- **Complexity**: complex

### Archetype Invariants

- {
-   "id": "SVC-1",
-   "rule": "All endpoints must be documented in OpenAPI/GraphQL schema",
-   "severity": "medium"
- }
- {
-   "id": "SVC-2",
-   "rule": "All endpoints must have request/response validation",
-   "severity": "high"
- }
- {
-   "id": "SVC-3",
-   "rule": "Health check endpoint must exist at /health or /healthz",
-   "severity": "medium"
- }

---

## Environment Variables

*No environment variables discovered. Add variables here when .env.example is created.*

---

## Deploy

*No deployment pipeline discovered. Add deploy configuration when ready.*

---

## GitHub Secrets

*No CI secrets discovered. Add secrets here when CI workflows are configured.*

---

## Testing

- **Framework:** make
- **Config:** data-driven
- **Run:** `make test`
- **Pattern:** test_*.py / *_test.py
- **Test files:** 1

---

## Custom Skills

### `/aif-review`
Project-specific code review checking all invariants.

### `/aif-ship`
Full shipping workflow: verify → review → docs → changelog → commit.

### `/aif-learn`
Capture project learnings to persistent storage (JSONL + vault).

### `/aif-feedback`
Collect structured feedback on generated output quality.

### `/aif-evolve`
Analyze accumulated learnings and patterns. Synthesizes JSONL learnings into CLAUDE.md updates, new rules, and vault entries. Run periodically.

### `/aif-enhance`
Research gaps in manifest using Claude Code's native tools. Enriches vault with concept pages and framework conventions.

### `/aif-research`
Deep-dive research on a topic using web search and code analysis. Produces structured findings.

### `/aif-analyze`
Analyze codebase patterns, architecture, and quality metrics. Identifies improvement opportunities.

### `/aif-ingest`
Ingest external documents into the vault. Processes raw files into wiki pages.

### `/aif-pulse`
Check for latest Claude Code features, best practices, and ecosystem updates. Discovers new capabilities and suggests project improvements. Run weekly.

---

## Review Specialists

### API Layer
Trigger paths: tools/review-specialists/api.md

- [ ] All inputs validated before processing
- [ ] Error responses use consistent format
- [ ] Rate limiting configured for public endpoints
- [ ] CORS policy is restrictive (not wildcard)
- [ ] Response types are explicitly defined
- [ ] No sensitive data in URL parameters
- [ ] Pagination on list endpoints
- [ ] API versioning strategy documented


---

## Doc-Sync Matrix

| Domain | Key Files | Doc Impact |
|--------|-----------|------------|
| API Layer | tools/review-specialists/api.md | CLAUDE.md, docs/ |

When any file in a domain's key files changes, update the corresponding docs.

---

## Persistent Memory Vault

Your knowledge persists across sessions in `vault/`. Three-layer architecture:

| Layer | Path | Purpose | Lifetime |
|-------|------|---------|----------|
| **Raw** | `vault/raw/` | Immutable source documents (human-owned) | Permanent |
| **Wiki** | `vault/wiki/` | Processed knowledge (concepts, entities, comparisons) | Long-lived |
| **Memory** | `vault/memory/` | Operational state (decisions, notes, status) | Variable |

**Data flow:** `raw/` → `wiki/` → `memory/` (strictly unidirectional)

### Quick Commands

```bash
vault/.vault/scripts/vault-tools.sh status       # Vault health
vault/.vault/scripts/vault-tools.sh doctor        # Full diagnostic
vault/.vault/scripts/vault-tools.sh lint          # Quality scan
vault/.vault/scripts/vault-tools.sh stale         # Find outdated content
vault/.vault/scripts/vault-tools.sh orphans       # Find unlinked pages
vault/.vault/scripts/vault-tools.sh stats         # Usage metrics
```

### How to Use

- **Session START**: Read `vault/memory/status.md` for ongoing work context
- **During work**: Save insights to `vault/memory/notes/` (auto-archive after 7 days)
- **Significant decisions**: Log to `vault/memory/decisions/` using ADR format
- **Session END**: Update `vault/memory/status.md` with progress
- **New knowledge**: Create wiki pages in `vault/wiki/concepts/` or `vault/wiki/entities/`

### Architecture

See `vault/docs/architecture.md` for the full three-layer model.
See `vault/.vault/rules/hard-rules.md` for 15 integrity rules enforced by pre-commit hooks.

---

## Session Learnings

Stored in `tools/learnings/aiframework-learnings.jsonl`. Use `/learn` to add new entries.

*Learnings accumulate over time. After fixing a non-obvious bug or discovering a gotcha, run `/aiframework-learn` to capture it.*

### Learnings Format (JSONL)

Each line in the learnings file is a JSON object:
```json
{"date": "2026-04-15", "category": "bug|gotcha|pattern|decision", "summary": "One-line summary", "detail": "Full explanation", "files": ["path/to/relevant/file"]}
```

To query: `grep "keyword" tools/learnings/aiframework-learnings.jsonl`
To add: `/aiframework-learn "description"` or append a JSON line manually.

---

## gstack Browser Integration

If gstack is installed (`~/.claude/skills/gstack/`), use `$B` commands for browser interactions:
- `$B` is ~20x faster than Playwright MCP (~100ms vs ~2-5s)
- Uses ref-based element selection (`@e1`, `@e2`) instead of CSS selectors
- Persistent Chromium daemon — cookies/tabs/login persist between commands

### Command Reference

| Command | Usage | Description |
|---------|-------|-------------|
| `goto` | `$B goto <url>` | Navigate to a URL |
| `snapshot` | `$B snapshot` | Get page structure with element refs |
| `click` | `$B click @e1` | Click an element by ref |
| `fill` | `$B fill @e1 "text"` | Fill an input field |
| `screenshot` | `$B screenshot` | Capture a screenshot |
| `console` | `$B console` | Read browser console logs |
| `network` | `$B network` | Read network requests/responses |
| `text` | `$B text @e1` | Get text content of an element |
| `html` | `$B html @e1` | Get HTML content of an element |
| `responsive` | `$B responsive <width>` | Set viewport width for responsive testing |
| `diff` | `$B diff` | Compare current page with previous snapshot |
| `chain` | `$B chain "click @e1" "fill @e2 text" "screenshot"` | Chain multiple commands |

---

## Session Start Protocol

At the start of each session:
1. Read `vault/memory/status.md` — check for ongoing work and operational context
2. Read `vault/wiki/index.md` — scan domain concepts and knowledge pages
3. Read `tools/learnings/aiframework-learnings.jsonl` — surface relevant learnings
4. Check `git log --oneline -10` — understand recent work
5. Check `git status` — understand current state
6. If a STATUS.md file exists — read it for multi-phase task progress
7. Decision Priority: User > Invariants > Workflow Rules > Core Principles > Docs

---

*Generated: 2026-04-16 by aiframework v1.1.0. Run `aiframework refresh` to update.*

<!-- CLAUDE.md Guidance:
- Update this file after significant decisions, bug fixes, or architectural changes
- NEVER delete content — only add, refine, or mark as deprecated
- Use /learn to capture non-obvious discoveries
- Session summary format: "Session YYYY-MM-DD: <what was done>, <key decisions>, <blockers>"
-->

<!-- Previous Session Summary:
Session 2026-04-16: Initial CLAUDE.md generation via aiframework.
Key decisions: Automated project analysis and documentation generation.
Blockers: None.
-->

---

## Execution Matrices

### Bug Fix Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | `/investigate` — reproduce & understand | Can reproduce? |
| 2 | Plan fix approach | Root cause identified? |
| 3 | Implement fix | Code change minimal & correct? |
| 4 | Verify: lint + typecheck + test + build | All pass? |
| 5 | `/review` | No issues? |
| 6 | `/cso` (if security-related) | No vulnerabilities? |
| 7 | Update docs + CHANGELOG | Docs accurate? |
| 8 | `/qa` | App works? |
| 9 | `/ship` | PR/deploy clean? |
| 10 | `/learn` | Lesson captured? |

### Feature Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | `/plan-eng-review` | Plan approved? |
| 2 | Build — implement feature | Code complete? |
| 3 | Write tests | Coverage adequate? |
| 4 | Verify: lint + typecheck + test + build | All pass? |
| 5 | `/review` | No issues? |
| 6 | `/cso` | No security gaps? |
| 7 | Update docs + CHANGELOG + VERSION | Docs accurate? |
| 8 | `/qa` | Feature works end-to-end? |
| 9 | `/ship` | PR/deploy clean? |
| 10 | `/canary` | No regressions? |
| 11 | `/learn` | Lessons captured? |

### Deploy Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | Verify: lint + typecheck + test + build | All pass? |
| 2 | `/review` | No issues? |
| 3 | `/cso` | Secure? |
| 4 | `/qa` | QA pass? |
| 5 | Update CHANGELOG + VERSION | Done? |
| 6 | `/ship` | Deploy triggered? |
| 7 | `/canary` — monitor post-deploy | Healthy? |

### Weekly Cadence

| Day | Task |
|-----|------|
| Monday | Review open PRs, triage issues |
| Wednesday | `/retro` — mid-week check |
| Friday | `/retro` — weekly retrospective, update CLAUDE.md, run `vault-tools.sh doctor` |

### Failure Recovery Table

| Failure | Recovery Action |
|---------|----------------|
| Test fails after code change | Revert change, re-investigate, fix root cause |
| Build fails | Check compiler errors, fix type/syntax issues |
| Lint fails | Auto-fix with formatter, then manual review |
| Deploy fails | Rollback, check logs, fix and re-deploy |
| `/cso` finds vulnerability | Block deploy, fix immediately, re-run `/cso` |
| QA regression | Investigate with `/investigate`, add regression test |

