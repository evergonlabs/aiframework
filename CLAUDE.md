# CLAUDE.md — aiframework

> <div align="center">. Stack: c/none.

## Commands

```bash
# Lint
cppcheck --enable=all .

# Type check
find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n

# Test
make test

# Build
make

# Format
clang-format -i

```

## Invariants

- **INV-1**: Auth guards on all protected endpoints
- **INV-2**: Input validation on all API endpoints

## Architecture

- **Archetype**: api-service (mature, complex)

## Key Locations

- **API Layer**: tools/review-specialists/api.md
- **Scripts**: `bin/`
- **Scripts**: `tools/`
- **CI**: `.github/`

**Most important files** (by dependency rank):
- `lib/indexers/graph.py`
- `lib/indexers/registry.py`
- `lib/indexers/__init__.py`
- `lib/indexers/parsers/python.py`
- `lib/scanners/identity.sh`
- `lib/indexers/lang_bash.py`
- `lib/indexers/lang_go.py`
- `lib/indexers/lang_rust.py`
- `lib/validators/consistency.sh`
- `lib/indexers/parsers/go.py`

## Environment Variables

*None discovered. Add variables here when .env.example is created.*

## Gotchas

- Lint functions follow lint_hrNNN_name() convention with pass/fail return
- Bash 3.2 compatibility requires avoiding associative arrays
- Lean vs full CLAUDE.md dispatch based on archetype complexity
- Data registries in lib/data/ are the source of truth for detection
- Python 3.10+ required, not 3.9+ — match/case syntax used in indexer

## Testing

- **Framework:** make | **Run:** `make test` | **Pattern:** test_*.py / *_test.py | **Files:** 2

## Makefile

```bash
make install
make uninstall
make lint
make test
make check
```

## Custom Skills

- `/aiframework-review` — Project-specific code review
- `/aiframework-ship` — Full shipping workflow
- `/aiframework-learn` — Capture learnings to persistent storage

## Vault

Knowledge persists in `vault/` across sessions. Check `vault/memory/status.md` at session start.

```bash
vault/.vault/scripts/vault-tools.sh doctor   # Full diagnostic
vault/.vault/scripts/vault-tools.sh lint     # Quality scan
```

## Doc Sync

After structural changes, update docs per `.claude/rules/pipeline.md` matrix.
See `docs/reference/architecture.md` for module map and structure tree.

## Session Start

At session start: read `vault/memory/status.md`, check `git log --oneline -10`, check `git status`.
Full protocol in `.claude/rules/session-protocol.md`.

## Self-Evolution

This file auto-evolves. Rules of thumb:
- **Same mistake twice** → add to Invariants above
- **Applies only to certain files** → create `.claude/rules/<domain>.md` with `paths:` frontmatter
- **Multi-step workflow** → create `.claude/skills/<name>/SKILL.md`
- **Run `/aif-evolve` periodically** to synthesize learnings into rules
- **This file should get shorter** — migrate content to rules and skills as patterns stabilize
- **Run `aiframework refresh`** when dependencies or structure change

---

*Generated: 2026-04-16 by aiframework v1.1.0. Run `aiframework refresh` to update. Lean mode (complex).*





---
