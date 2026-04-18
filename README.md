<div align="center">

<br>

```

   ░█████╗░██╗███████╗██████╗░░█████╗░███╗░░░███╗███████╗░██╗░░░░░░░██╗░█████╗░██████╗░██╗░░██╗
   ██╔══██╗██║██╔════╝██╔══██╗██╔══██╗████╗░████║██╔════╝░██║░░██╗░░██║██╔══██╗██╔══██╗██║░██╔╝
   ███████║██║█████╗░░██████╔╝███████║██╔████╔██║█████╗░░░╚██╗████╗██╔╝██║░░██║██████╔╝█████═╝░
   ██╔══██║██║██╔══╝░░██╔══██╗██╔══██║██║╚██╔╝██║██╔══╝░░░░████╔═████║░██║░░██║██╔══██╗██╔═██╗░
   ██║░░██║██║██║░░░░░██║░░██║██║░░██║██║░╚═╝░██║███████╗░░╚██╔╝░╚██╔╝░╚█████╔╝██║░░██║██║░╚██╗
   ╚═╝░░╚═╝╚═╝╚═╝░░░░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░░░░╚═╝╚══════╝░░╚═╝░░░╚═╝░░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝

```

Make [Claude Code](https://docs.anthropic.com/en/docs/claude-code) understand your project instantly.

[![version](https://img.shields.io/badge/v1.3.0-blue?style=flat-square&label=version)](https://github.com/evergonlabs/aiframework/releases)
[![license](https://img.shields.io/badge/MIT-green?style=flat-square&label=license)](LICENSE)
[![Claude Code](https://img.shields.io/badge/compatible-cc785c?style=flat-square&logo=anthropic&logoColor=white&label=claude%20code)](https://docs.anthropic.com/en/docs/claude-code)

</div>

---

## The Problem

When you open [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in a project, it doesn't know your stack, your test commands, your coding conventions, or how your files connect. You end up repeating context every session.

**aiframework fixes this.** It scans your repo &mdash; language, framework, dependencies, file structure, domains &mdash; and generates a `CLAUDE.md` file plus supporting configs. Claude Code reads these automatically, so it knows your project from the first message.

**Before:** Claude asks "what framework is this?" and guesses wrong commands.<br>
**After:** Claude knows your lint/test/build commands, your architecture, your security rules, and can navigate your codebase through a knowledge graph of every file.

---

## Quick Start

Three commands. Takes about 60 seconds.

**1. Install aiframework** (paste this into your terminal):

```bash
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
```

This downloads and installs aiframework. It will check that you have the [required tools](#requirements) and tell you if anything is missing.

**2. Point it at your project:**

```bash
aiframework run --target ~/your-project
```

Replace `~/your-project` with the path to any git repo. aiframework scans it and generates config files that Claude Code will read.

**3. Open Claude Code and run the setup skill:**

```bash
cd ~/your-project
claude
```

Once Claude Code opens, type this command (it's a "slash command" &mdash; Claude Code's way of running built-in actions):

```
/aif-ready
```

This researches your specific stack online, enhances the generated configs, and optimizes your settings. **You only need to do this once per project.**

After that, just code. Claude knows your stack, commands, architecture, and conventions.

<details>
<summary>Other install methods</summary>

| Method | Command |
|:-------|:--------|
| **Homebrew** | `brew tap evergonlabs/tap && brew install aiframework` |
| **Manual** | `git clone https://github.com/evergonlabs/aiframework && cd aiframework && make install` |
| **Tarball** | Download from [Releases](https://github.com/evergonlabs/aiframework/releases), extract, `make install` |

</details>

<details>
<summary>Requirements</summary>

You need these installed before running the installer. Most developers already have them. If something's missing, the installer will tell you exactly what to install and how.

| Tool | Why | Check with |
|:-----|:----|:-----------|
| `bash` | Runs the scripts | `bash --version` (need 3.2+) |
| `git` | Clones and tracks your repo | `git --version` |
| `jq` | Reads JSON config files | `jq --version` (install: `brew install jq` or `apt install jq`) |
| `python3` | Powers the code indexer | `python3 --version` (need 3.10+) |

Optional: `node`/`npm` (for runtime session intelligence), `shellcheck` (lints scripts).

</details>

---

## What It Does

aiframework scans your repo to understand what it is &mdash; what language, what framework, what commands to run, how the files connect &mdash; then writes config files that Claude Code reads automatically:

```
$ aiframework run --target .

DISCOVER  ████████████████████ 13 scanners
  python / fastapi / api-service
  47 endpoints, 209 symbols, 4 domains detected

GENERATE  ████████████████████ 23 files written
  CLAUDE.md, .claude/rules/, .claude/skills/, vault/
  .githooks/, .github/workflows/, docs/, AGENTS.md

VERIFY    ████████████████████ all checks passed
```

### What gets created

| File | What it's for |
|:-----|:--------------|
| `CLAUDE.md` | The main file Claude Code reads &mdash; your stack, commands, rules, architecture |
| `.claude/rules/` | Extra instructions Claude follows automatically (workflow, testing, security) |
| `.claude/skills/` | Slash commands you can type in Claude Code (`/aif-review`, `/aif-ship`, etc.) |
| `.claude/settings.json` | Permissions and automation (e.g., auto-lint on file save) |
| `.githooks/` | Git hooks that lint on commit and run quality checks on push |
| `.github/workflows/ci.yml` | CI pipeline matched to your language |
| `vault/wiki/` | A knowledge graph of your codebase &mdash; one page per file, linked by imports ([details](#knowledge-graph)) |
| `docs/` | Documentation scaffold |
| `AGENTS.md` | Config that also works with Cursor, Copilot, Codex, and Gemini |

Same repo, same output, every time. Then `/aif-ready` enhances it with knowledge specific to your framework.

---

## How It Works

```
aiframework run --target /path/to/repo
│
│  DISCOVER ──────────────── scan everything, assume nothing
│  │
│  ├── identity       name, version, short name
│  ├── stack          language, framework, monorepo?
│  ├── commands       package manager, lint, test, build
│  ├── structure      files, dirs, source roots, test files
│  ├── ci + deploy    GitHub Actions, Docker, Fly.io, Vercel...
│  ├── env            variables from .env, config files
│  ├── domain         18 types (auth, db, ai, graphql...)
│  ├── code_index     symbols + imports + edges (20 languages)
│  └── archetype      library, cli-tool, web-app, api-service...
│  │
│  ╰──→ manifest.json + code-index.json
│
│  GENERATE ──────────────── deterministic, reproducible
│  │
│  ├── CLAUDE.md          80-150 lines, lean, high-signal
│  ├── .claude/rules/     auto-loaded by path pattern
│  ├── .claude/skills/    project skills + framework skills
│  ├── .githooks/         pre-commit + pre-push with auto-refresh
│  ├── .github/workflows/ CI pipeline for your language
│  ├── vault/             31-file knowledge base
│  └── docs/              Diataxis scaffold
│
│  VERIFY ────────────────── trust, but verify
│  │
│  ├── files          do all expected files exist?
│  ├── consistency    do commands match across CLAUDE.md, hooks, CI?
│  ├── security       any secrets in source? .gitignore coverage?
│  ├── quality_gate   are lint/test commands actually working?
│  └── freshness      is the manifest stale? did files drift?
│
╰──→ PASS / FAIL / WARN
```

### Language support

| Language | Frameworks |
|:---------|:-----------|
| TypeScript / JavaScript | Next.js, NestJS, React, Vue, Express, Hono, Svelte |
| Python | FastAPI, Django, Flask, Starlette |
| Go | Gin, Echo, Chi, Fiber |
| Rust | Actix, Axum, Rocket, Warp |
| Ruby | Rails, Sinatra |
| Java | Spring Boot, Quarkus |
| C# | ASP.NET, Blazor |
| PHP, Kotlin, Swift, Elixir, Bash | Major frameworks |
| + 12 more | Extensible via `lib/data/languages.json` |

The code indexer reads your actual source code to find functions, classes, types, and how files import each other &mdash; so Claude Code can navigate your codebase intelligently.

---

## Daily Workflow

Once you've run `/aif-ready`, these slash commands are available inside Claude Code:

| Command | When to use it | What it does |
|:--------|:---------------|:-------------|
| `/aif-ready` | Once per project | Researches your stack, enhances configs |
| `/aif-review` | Before committing | Reviews your code against your project's rules |
| `/aif-ship` | When ready to push | Runs lint, review, updates docs, commits |
| `/aif-learn` | When you discover something | Saves gotchas so Claude remembers next time |
| `/aif-analyze` | When curious | Finds missing tests, circular dependencies |
| `/aif-evolve` | Weekly | Improves your CLAUDE.md based on accumulated learnings |
| `/aif-pulse` | Monthly | Discovers new Claude Code features you can adopt |

Your configs auto-refresh on every `git push` &mdash; you never need to manually keep them in sync.

---

## CLI Reference

```
$ aiframework <command> [options]

  run            full pipeline: discover, generate, verify
  discover       scan repo into manifest.json + code-index.json
  generate       read manifest, generate all files
  verify         validate generated files (5 validators)
  refresh        re-discover + generate only if drift detected
  update         self-update + refresh all bootstrapped repos

  --target <path>       target repo (default: cwd)
  --non-interactive     skip user context questions
  --no-index            skip code indexing
  --dry-run             preview without writing
  --verbose             detailed output
```

---

## Upgrading

```bash
aiframework update
```

Auto-detects install method (git/homebrew/tarball) and does the right thing. Also updates all bootstrapped repos. Aliases: `upgrade`, `self-update`.

---

## Knowledge Graph

Every source file gets a wiki page in `vault/wiki/`. Every import becomes a bidirectional link. Claude Code can traverse the graph to understand any part of the codebase without reading every file.

```
vault/wiki/
├── index.md                          master registry
├── concepts/
│   └── architecture.md               module graph + top files by PageRank
└── entities/
    ├── src-api-auth-controller-ts.md  symbols, imports, imported-by
    ├── src-api-auth-service-ts.md     [[src-api-auth-controller-ts]] link
    └── ...                            one page per source file
```

200 files produces ~220 pages, ~800 wikilinks. Auto-updates on every `git push`.

---

## Ecosystem

aiframework handles **setup-time** intelligence. Two optional tools extend it:

| Tool | What | Install |
|:-----|:-----|:--------|
| [gstack](https://github.com/garrytan/gstack) | 37 skills: `/ship`, `/qa`, `/review`, `/investigate`, `/cso`, browser automation | `git clone ... ~/.claude/skills/gstack && ./setup` |
| [sheal](https://www.npmjs.com/package/@liwala/sheal) | Runtime session intelligence: watches sessions, extracts learnings, detects drift | Auto-installed with `make install` (needs Node.js) |

Both are optional. aiframework works fully standalone.

<details>
<summary>gstack skills (37)</summary>

**Ship & Debug:** `/ship` `/review` `/land-and-deploy` `/investigate` `/health` `/retro` `/codex`

**QA & Browser:** `/qa` `/browse` `/design-review` `/benchmark` `/canary` `/cso`

**Plan & Design:** `/plan-ceo-review` `/plan-eng-review` `/plan-design-review` `/autoplan` `/design-shotgun` `/design-html`

**Utilities:** `/office-hours` `/checkpoint` `/guard` `/freeze` `/pair-agent`

</details>

<details>
<summary>sheal workflow</summary>

```
Session start → health check (auto via hook)
During work   → /aif-learn captures gotchas (dual-writes to sheal + JSONL)
Session end   → /sheal-retro extracts patterns
Weekly        → /sheal-drift promotes learnings to permanent rules
```

sheal is optional. Without it, nothing changes &mdash; no extra output, no extra files.

</details>

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

## Telemetry

Anonymous usage stats (event type, version, OS, language detected). No source code, file paths, or personal data. [Details](docs/KNOWN_GAPS.md).

```bash
# Opt out
mkdir -p ~/.aiframework && echo "telemetry: false" >> ~/.aiframework/config
```

---

## Known Gaps

| Area | Status |
|:-----|:-------|
| Core pipeline | Production-ready (needs real-world repo validation) |
| Knowledge graph | Production-ready (needs large repo validation) |
| macOS / Linux | Tested (CI + local) |
| Windows (Git Bash) | CI-tested (needs community validation) |

[Full testing checklist](docs/KNOWN_GAPS.md). If you test on your project, [open an issue](https://github.com/evergonlabs/aiframework/issues).

---

<div align="center">

**[Evergon Labs](https://github.com/evergonlabs)** &middot; [MIT License](LICENSE)

[![GitHub stars](https://img.shields.io/github/stars/evergonlabs/aiframework?style=social)](https://github.com/evergonlabs/aiframework)

</div>
