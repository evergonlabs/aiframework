# Session Protocol & Execution Matrices

## Session Start Protocol

At the start of each session:
1. Read `vault/memory/status.md` — check for ongoing work and operational context
2. Read `vault/wiki/index.md` — scan domain concepts and knowledge pages
3. Read `tools/learnings/aiframework-learnings.jsonl` — surface relevant learnings
4. Check `git log --oneline -10` — understand recent work
5. Check `git status` — understand current state
6. If a STATUS.md file exists — read it for multi-phase task progress
7. Run `aiframework-update-check` — notify developer of updates or drift
8. Decision Priority: User > Invariants > Workflow Rules > Core Principles > Docs

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

---

## Session Learnings

Stored in `tools/learnings/aiframework-learnings.jsonl`. Use `/learn` to add new entries.

### Format (JSONL)
```json
{"date": "2026-04-15", "category": "bug|gotcha|pattern|decision", "summary": "One-line summary", "detail": "Full explanation", "files": ["path/to/relevant/file"]}
```

To query: `grep "keyword" tools/learnings/aiframework-learnings.jsonl`
To add: `/aiframework-learn "description"` or append a JSON line manually.

---

## gstack Browser Integration

Use `$B` commands for browser interactions (~20x faster than Playwright MCP):
- `$B goto <url>` — navigate | `$B snapshot` — page structure | `$B click @e1` — click
- `$B fill @e1 "text"` — fill input | `$B screenshot` — capture | `$B diff` — compare
- `$B console` — logs | `$B network` — requests | `$B chain "cmd1" "cmd2"` — chain
