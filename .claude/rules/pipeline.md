# Pipeline & Skill Routing

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
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs shellcheck              # Must pass with 0 errors
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n         # Must pass
make test              # Must pass
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
| "session retro", "sheal retro", "session review" | Run `/sheal-retro` |
| "what learnings", "show rules", "applied learnings" | Run `/sheal-drift` or `sheal learn list` (CLI) |
| "search sessions", "what happened with" | Run `/sheal-ask` |
| "health check", "runtime check" | Run `/sheal-check` |

---

## Quick Reference Matrix

| Trigger | Skills to run (in order) |
|---------|------------------------|
| Bug reported | `/investigate` → fix → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| New feature | `/plan-eng-review` → build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| Small fix | build → verify → `/review` → docs → `/ship` |
| Refactor | build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` |

---

## Doc-Sync Matrix

When any file in a domain's key files changes, update the corresponding docs.
**Skip when:** pure bug fixes with no API/UI surface change, test-only changes, dependency updates.
**Always check:** no doc references stale counts, removed features, or outdated file paths.

| Domain | Key Files | Doc Impact |
|--------|-----------|------------|
| AI/LLM Integration | bin/aiframework-update-check, bin/aiframework-mcp | CLAUDE.md, docs/ |

