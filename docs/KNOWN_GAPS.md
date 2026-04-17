# Known Gaps & Testing Checklist

> Last updated: 2026-04-17. Extensively self-tested; needs real-world validation.

This document lists everything we know is not yet verified in production. If you're an early adopter, testing any of these items and reporting back helps enormously.

## Status: Ready for Production Use

The core framework (`aiframework run/discover/generate/verify`) has been extensively audited and tested. The items below are edge cases and integration boundaries that need real-world validation.

---

## Checklist for Community Testers

### sheal CLI Compatibility
- [ ] Install `@liwala/sheal` via npm — does it install cleanly?
- [ ] Run `sheal --version` — does the output contain digits and dots?
- [ ] Run `sheal check --format json --skip tests --project .` — valid JSON output?
- [ ] Run `sheal init --project .` — creates `.sheal/` directory?
- [ ] Run `sheal rules --project .` — injects rules into AGENTS.md/CLAUDE.md?
- [ ] Run `sheal retro --project .` — produces session retro?
- [ ] Run `sheal drift --last 5 --format json --project .` — valid JSON?
- [ ] Run `sheal learn list --project .` — lists learnings?

### Real Repo Testing
- [ ] Run `aiframework run` on a **TypeScript/Next.js** project — correct CLAUDE.md?
- [ ] Run `aiframework run` on a **Python/FastAPI** project — correct commands detected?
- [ ] Run `aiframework run` on a **Go** project — correct archetype?
- [ ] Run `aiframework run` on a **Rust** project — correct framework detection?
- [ ] Run `aiframework run` on a **Ruby/Rails** project — correct domain detection?
- [ ] Run `aiframework run` on a **monorepo** — correct multi-app hooks?
- [ ] Open the generated CLAUDE.md in Claude Code — does Claude understand the project?
- [ ] Use `/aif-ready` after generation — does it enhance correctly?
- [ ] Use the generated `/review` and `/ship` skills — do they work?

### Platform Testing
- [ ] **macOS (stock bash 3.2)** — `aiframework run` completes without errors?
- [ ] **macOS (Homebrew bash 5)** — same?
- [ ] **Ubuntu/Debian Linux** — `make install` + `aiframework run` works?
- [ ] **Fedora/RHEL Linux** — same?
- [ ] **WSL (Windows)** — `make install` + `aiframework run` works?
- [ ] **Git Bash (Windows)** — `aiframework run` works? (may need `winpty`)

### Automation Hooks
- [ ] Open Claude Code on a generated project — does `SessionStart` hook fire?
- [ ] Close Claude Code session — does `Stop` hook fire?
- [ ] Edit a `.ts` file — does `PostToolUse` type-check fire?
- [ ] Commit code — does pre-commit lint run?
- [ ] Push code — does pre-push quality gate run?
- [ ] Change `package.json` then push — does auto-refresh detect drift?

### Edge Cases
- [ ] Run on a repo with no `package.json` (bare scripts) — graceful handling?
- [ ] Run on a repo with spaces in the path — no word-splitting errors?
- [ ] Run on a read-only filesystem — `.self-heal.json` atomic write fallback works?
- [ ] Run with `--dry-run` — no files written, correct preview output?
- [ ] Run with `--non-interactive` — no prompts, clean output?

---

## Known Design Decisions (Not Bugs)

| Decision | Rationale |
|:---------|:----------|
| `/aif-evolve` requires manual approval | Safety: rule changes to CLAUDE.md should be human-reviewed |
| `/aif-pulse` is manual | Discovery: user decides when to check for new features |
| sheal is optional | Not all projects use Node.js; the framework must be stack-agnostic |
| settings.json is merged, not overwritten | Preserves user customizations |
| `@latest` npm tag (not pinned hash) | CLI tools conventionally use `@latest`; graceful fallback on failure |

---

## How to Report Issues

1. Open an issue at [github.com/evergonlabs/aiframework/issues](https://github.com/evergonlabs/aiframework/issues)
2. Include: OS, bash version (`bash --version`), Node.js version (`node -v`), and the full command output
3. For sheal issues: include `sheal --version` output and whether `.sheal/` directory exists
