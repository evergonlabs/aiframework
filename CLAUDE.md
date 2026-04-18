# CLAUDE.md — aiframework

> Your repo already knows everything. Claude Code just can't read it yet. Stack: bash+python/none.

| You need to... | Read |
|----------------|------|
| Understand this repo | This file |
| Debug a recurring issue | `docs/LESSONS_LEARNED.md` |
| See architecture/modules | `docs/reference/architecture.md` |
| Check workflow rules | `.claude/rules/workflow.md` |

## Commands

```bash
# Lint
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs shellcheck

# Type check
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n

# Test
make test

```

## Invariants

- **INV-1**: LLM trust boundary — validate all AI output

## Architecture

- **Archetype**: cli-tool (active, complex)

## Key Locations

- **AI/LLM Integration**: bin/aiframework-update-check
- **AI/LLM Integration**: bin/aiframework-mcp
- **AI/LLM Integration**: bin/aiframework-telemetry
- **Scripts**: `bin/`
- **Scripts**: `tools/`
- **CI**: `.github/`
- **Data**: `lib/data/` — detection registries and config

**Most important files** (by dependency rank):
- `lib/generators/sheal.sh`
- `lib/scanners/sheal.sh`
- `lib/indexers/graph.py`
- `lib/bridge/sheal_learnings.sh`
- `lib/indexers/registry.py`
- `lib/validators/consistency.sh`
- `lib/generators/skills.sh`
- `lib/validators/files.sh`
- `lib/validators/freshness.sh`
- `lib/validators/quality_gate.sh`

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| SHA256 | No | - |
| TARBALL_URL | No | - |
| VERSION | No | - |

## Gotchas

> Criteria: (a) broadly reusable, (b) easy to violate, (c) costly when forgotten. Use `/aiframework-learn` to add.

- Lint functions follow lint_hrNNN_name() convention with pass/fail return
- Bash 3.2 compatibility requires avoiding associative arrays
- Lean vs full CLAUDE.md dispatch based on archetype complexity
- Data registries in lib/data/ are the source of truth for detection
- Python 3.10+ required, not 3.9+ — match/case syntax used in indexer

## Common Mistakes

- Not running the full test suite before marking done
- Editing the wrong config file (staging vs production)
- Forgetting to update documentation after changes

## Key State

- Source files: 80
- Tests: [run `make test` to count]

## Makefile

```bash
make install
make uninstall
make lint
make test
make check
make dist
```

## Automated Enforcement

| Trigger | What runs |
|---------|-----------|
| `git commit` | lint check |
| `git push` | lint + test + invariant scan |
| PR to main | CI: full build + test + lint |

## Skills

- `/aif-ready` — **Run first.** Researches your stack, enhances this file, makes repo Claude Code-ready
- `/aiframework-review` — Pre-commit code review checking invariants
- `/aiframework-ship` — Lint + review + changelog + commit (never pushes without approval)
- `/aiframework-learn` — Capture gotchas to persistent storage
- `/aif-evolve` — Weekly: synthesize learnings into better rules
- `/aif-pulse` — Monthly: discover new Claude Code features

## Vault

Knowledge persists in `vault/` across sessions. Check `vault/memory/status.md` at session start.

```bash
vault/.vault/scripts/vault-tools.sh doctor   # Full diagnostic
vault/.vault/scripts/vault-tools.sh lint     # Quality scan
```

## Doc Sync

After structural changes, update docs per `.claude/rules/pipeline.md` matrix.
See `docs/reference/architecture.md` for module map and structure tree.

## Getting Started

First time? Run `/aif-ready` — it researches your stack, enhances this file, and makes your repo fully Claude Code-ready.
Returning? Read `vault/memory/status.md`, check `git log --oneline -10`.

## Self-Evolution

This file auto-evolves. Rules of thumb:
- **Same mistake twice** → add to Invariants above with a "Reason:" annotation explaining why it matters
- **Applies only to certain files** → create `.claude/rules/<domain>.md` with `paths:` frontmatter
- **Multi-step workflow** → create `.claude/skills/<name>/SKILL.md`
- **Run `/aif-evolve` periodically** to synthesize learnings into rules
- **This file should get shorter** — migrate content to rules and skills as patterns stabilize
- **Heavy domain context** → create `DOMAIN.md` for domain-specific knowledge (loaded by Claude Code)
- **Run `aiframework refresh`** when dependencies or structure change

---

*Generated: 2026-04-18 by aiframework v1.3.0. Run `aiframework refresh` to update. Lean mode (complex).*
