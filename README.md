<div align="center">

# aiframework

Make [Claude Code](https://docs.anthropic.com/en/docs/claude-code) understand your project instantly.

[![version](https://img.shields.io/badge/v1.4.0-blue?style=flat-square&label=version)](https://github.com/evergonlabs/aiframework/releases)
[![license](https://img.shields.io/badge/MIT-green?style=flat-square&label=license)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/evergonlabs/aiframework/ci.yml?style=flat-square&label=CI)](https://github.com/evergonlabs/aiframework/actions)
[![Claude Code](https://img.shields.io/badge/compatible-cc785c?style=flat-square&logo=anthropic&logoColor=white&label=claude%20code)](https://docs.anthropic.com/en/docs/claude-code)

</div>

---

## What it does

aiframework scans your repo — language, framework, dependencies, file structure, domains — and generates a `CLAUDE.md` plus supporting configs that Claude Code reads automatically.

**Before:** Claude asks "what framework is this?" and guesses wrong commands.
**After:** Claude knows your lint/test/build commands, your architecture, your security rules, and can navigate your codebase through a knowledge graph of every file.

```
$ aiframework run --target .

DISCOVER  ████████████████████ 13 scanners
  python / fastapi / api-service
  47 endpoints, 209 symbols, 4 domains detected

GENERATE  ████████████████████ 23 files written
  CLAUDE.md, .claude/rules/, .claude/skills/, vault/

VERIFY    ████████████████████ all checks passed
```

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
```

The installer checks dependencies, detects your OS and package manager, and tells you exactly what's missing.

```bash
# Preview what will be installed (no changes made)
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh -s -- --dry-run

# Auto-install missing deps (jq, Python, git) on Linux/macOS
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh -s -- --auto-deps
```

<details>
<summary>Other install methods</summary>

| Method | Command |
|:-------|:--------|
| **Homebrew** | `brew tap evergonlabs/tap && brew install aiframework` |
| **Manual** | `git clone https://github.com/evergonlabs/aiframework && cd aiframework && make install` |
| **Tarball** | Download from [Releases](https://github.com/evergonlabs/aiframework/releases), extract, `make install` |

</details>

<details>
<summary>Installer flags</summary>

| Flag | What it does |
|:-----|:-------------|
| `--dry-run` | Show what will be installed without making changes |
| `--auto-deps` | Auto-install missing dependencies (requires sudo on Linux) |
| `--no-modify-rc` | Don't add aiframework to your shell PATH |
| `--uninstall` | Remove aiframework and clean up |
| `--help` | Show all options |

</details>

### Requirements

| Tool | Version | Why |
|:-----|:--------|:----|
| `bash` | 3.2+ | Runs the CLI |
| `git` | any | Clones repos, tracks changes |
| `python3` | **3.10+** | Code indexer (uses match/case syntax) |
| `jq` | any | Reads JSON manifests |

Optional: `node`/`npm` (for [sheal](https://www.npmjs.com/package/@liwala/sheal) session intelligence), `shellcheck` (script linting).

### Platforms

| Platform | Status |
|:---------|:-------|
| macOS (Intel + ARM) | CI-tested |
| Linux (Ubuntu, Fedora, Arch) | CI-tested |
| Alpine Linux (musl) | CI-tested |
| WSL | Supported |
| Windows (Git Bash / MSYS2) | Supported (not in CI) |

---

## Quick start

**1. Bootstrap your project:**

```bash
aiframework run --target ~/your-project
```

This scans the repo and generates all config files. Takes about 60 seconds.

**2. Open Claude Code and run the setup skill:**

```bash
cd ~/your-project && claude
```

Then type:

```
/aif-ready
```

This researches your specific stack, enhances the generated configs, and optimizes settings. **Run once per project.** After that, just code.

---

## What gets generated

| File | Purpose |
|:-----|:--------|
| `CLAUDE.md` | Main config — stack, commands, rules, architecture |
| `.claude/rules/` | Auto-loaded instructions by path pattern (workflow, testing, security) |
| `.claude/skills/` | Slash commands (`/aif-review`, `/aif-ship`, etc.) |
| `.claude/settings.json` | Permissions and automation config |
| `.cursorrules` | Cursor IDE rules (same data, Cursor format) |
| `.githooks/` | Pre-commit lint + pre-push quality gate |
| `.github/workflows/ci.yml` | CI pipeline matched to your language |
| `vault/wiki/` | Knowledge graph — one page per source file, linked by imports |
| `docs/` | Architecture doc + Diataxis scaffold |
| `AGENTS.md` | Compatible with Cursor, Copilot, Codex, Gemini |
| `tools/learnings/` | Persistent learning storage (JSONL) |

Same repo, same output, every time. Deterministic.

---

## How it works

```
aiframework run --target /path/to/repo
│
│  DISCOVER ──── scan everything, assume nothing
│  ├── identity       name, version, short name
│  ├── stack          language, framework, monorepo?
│  ├── commands       package manager, lint, test, build
│  ├── structure      files, dirs, source roots
│  ├── ci + deploy    GitHub Actions, Docker, Fly.io, Vercel...
│  ├── env            variables from .env, config files
│  ├── domain         18 types (auth, db, ai, graphql...)
│  ├── code_index     symbols + imports + edges (20 languages)
│  └── archetype      library, cli-tool, web-app, api-service...
│  ╰──→ manifest.json + code-index.json
│
│  GENERATE ──── deterministic, reproducible
│  ╰──→ CLAUDE.md, rules, skills, hooks, CI, vault, docs
│
│  VERIFY ────── trust, but verify
│  ├── files          do expected files exist?
│  ├── consistency    commands match across CLAUDE.md, hooks, CI?
│  ├── security       secrets in source? .gitignore coverage?
│  ├── quality_gate   lint/test commands working?
│  └── freshness      manifest stale? files drifted?
│  ╰──→ PASS / FAIL / WARN
```

### Language support

20 languages with framework detection:

| Language | Frameworks |
|:---------|:-----------|
| TypeScript / JavaScript | Next.js, NestJS, React, Vue, Express, Hono, Svelte |
| Python | FastAPI, Django, Flask, Starlette |
| Go | Gin, Echo, Chi, Fiber |
| Rust | Actix, Axum, Rocket, Warp |
| Ruby | Rails, Sinatra |
| Java | Spring Boot, Quarkus |
| C# | ASP.NET, Blazor |
| PHP | Laravel, Symfony |
| Kotlin, Swift, Elixir, Bash | Major frameworks |
| C, C++, Scala, Dart, Zig, Lua, R | Extensible via `lib/data/languages.json` |

The code indexer reads your actual source to extract functions, classes, types, and import edges — so Claude Code can navigate your codebase intelligently.

---

## Slash commands

Available inside Claude Code after running `/aif-ready`:

| Command | What it does |
|:--------|:-------------|
| `/aif-ready` | One-time setup — researches stack, enhances configs |
| `/aif-review` | Pre-commit code review against your project's rules |
| `/aif-ship` | Lint + review + changelog + commit (never pushes without approval) |
| `/aif-learn` | Save a gotcha so Claude remembers next time |
| `/aif-analyze` | Find missing tests, circular deps, dead code |
| `/aif-evolve` | Promote accumulated learnings into permanent rules |
| `/aif-pulse` | Discover new Claude Code features to adopt |

Configs auto-refresh on every `git push` — no manual sync needed.

---

## CLI reference

```
aiframework <command> [options]

Commands:
  run            discover + generate + verify (full pipeline)
  discover       scan repo → manifest.json + code-index.json
  generate       manifest → all config files
  verify         validate generated files (5 validators)
  refresh        re-discover + generate only if drift detected
  report         human-readable summary of discovered data
  index          build code-index.json (standalone)
  stats          cross-repo knowledge store statistics
  update         self-update + refresh all bootstrapped repos

Options:
  --target <path>       target repo (default: cwd)
  --non-interactive     skip user context questions
  --no-index            skip code indexing
  --dry-run             preview without writing
  --verbose             detailed output
```

Aliases: `update` = `upgrade` = `self-update`.

---

## Upgrading

```bash
aiframework update
```

Auto-detects install method (git / Homebrew / tarball), pulls latest, verifies checksum, and refreshes all bootstrapped repos.

---

## Knowledge graph

Every source file gets a wiki page in `vault/wiki/`. Every import becomes a bidirectional link. Claude Code traverses the graph to understand any part of the codebase without reading every file.

```
vault/wiki/
├── index.md                          master registry
├── concepts/
│   └── architecture.md               module graph + top files by PageRank
└── entities/
    ├── src-api-auth-controller-ts.md  symbols, imports, imported-by
    ├── src-api-auth-service-ts.md     [[linked]] to controller
    └── ...                            one page per source file
```

Auto-updates on every `git push`.

---

## Extending

All detection is data-driven. Add a language, domain, or archetype by editing one JSON file:

| Registry | Entries | File |
|:---------|:--------|:-----|
| Languages | 20 | `lib/data/languages.json` |
| Domains | 18 | `lib/data/domains.json` |
| Deploy targets | 24 | `lib/data/deploy_targets.json` |
| Archetypes | 11 | `lib/data/archetypes.json` |

---

## Ecosystem

aiframework handles **setup-time** intelligence. Two optional tools extend it at runtime:

| Tool | What | Install |
|:-----|:-----|:--------|
| [gstack](https://github.com/garrytan/gstack) | 37 runtime skills: `/ship`, `/qa`, `/review`, `/investigate`, `/cso`, browser automation | See gstack README |
| [sheal](https://www.npmjs.com/package/@liwala/sheal) | Session intelligence: watches sessions, extracts learnings, detects drift | Auto-installed (needs Node.js) |

Both are optional. aiframework works fully standalone.

---

## Roadmap

aiframework v2 is being rewritten in Rust for zero-dependency distribution:

| Feature | Status |
|:--------|:-------|
| Code indexer (12 parsers, tree-sitter) | Done |
| Dependency graph + PageRank | Done |
| Complexity metrics | Done |
| Language/framework detection | Done |
| Scanner modules (identity, stack, commands, structure) | Done |
| Generator modules (CLAUDE.md, rules, skills) | In progress |
| MCP server | Planned |
| Cross-platform binary releases (6 targets) | Planned |

The Rust binary is 2 MB, has zero runtime dependencies, and indexes code 3-5x faster than the Python version. Track progress in `rust/`.

---

## Telemetry

Anonymous, aggregate usage data to prioritize languages, fix common failures, and improve generated output.

**Collected:** event type (`run`, `refresh`), version, OS, detected language/framework, error counts, duration.
**Never collected:** source code, file contents, file paths, project names, git history, personal information.

Opt out:

```bash
mkdir -p ~/.aiframework && echo "telemetry: false" >> ~/.aiframework/config
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

<div align="center">

**[Evergon Labs](https://github.com/evergonlabs)** · [MIT License](LICENSE) · [Report an issue](https://github.com/evergonlabs/aiframework/issues)

[![GitHub stars](https://img.shields.io/github/stars/evergonlabs/aiframework?style=social)](https://github.com/evergonlabs/aiframework)

</div>
