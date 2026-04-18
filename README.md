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

<br>

**Your repo already knows everything. Claude Code just can't read it yet.**

*Two commands. Any repo. Fully Claude Code-ready.*

<br>

[![version](https://img.shields.io/badge/v1.3.0-blue?style=flat-square&label=version)](https://github.com/evergonlabs/aiframework/releases)
[![license](https://img.shields.io/badge/MIT-green?style=flat-square&label=license)](LICENSE)
[![tests](https://img.shields.io/badge/146_passing-brightgreen?style=flat-square&label=tests)]()
[![Bash](https://img.shields.io/badge/bash-1f425f?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/3.10+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Claude Code](https://img.shields.io/badge/compatible-cc785c?style=flat-square&logo=anthropic&logoColor=white&label=claude%20code)](https://docs.anthropic.com/en/docs/claude-code)
[![gstack](https://img.shields.io/badge/37_skills-blueviolet?style=flat-square&label=gstack)](https://github.com/garrytan/gstack)

<br>

[Quick Start](#quick-start) · [The Ecosystem](#the-ecosystem) · [What You Get](#what-you-get) · [Skills](#skills) · [Languages](#20-languages--57-frameworks) · [Architecture](#architecture) · [Upgrading](#upgrading)

> **[View the interactive ecosystem diagram &rarr;](docs/ecosystem.html)**

</div>

<br>

---

<br>

## Quick Start

### Step 1: Install (once)

**One-line install** (macOS, Linux, WSL, Windows Git Bash):

```bash
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
```

The installer auto-detects your platform, checks dependencies, clones the repo, and sets up your PATH. Run it again to update.

<details>
<summary><b>All install methods</b></summary>

<br>

| Method | Command | Best for |
|:-------|:--------|:---------|
| **curl\|sh** | `curl -fsSL .../install.sh \| sh` | Most users. Auto-detects platform. |
| **Homebrew** | `brew tap evergonlabs/tap && brew install aiframework` | macOS/Linux users who prefer Homebrew. |
| **Manual** | `git clone ... && cd aiframework && make install` | Contributors, custom setups. |
| **Tarball** | Download from [Releases](https://github.com/evergonlabs/aiframework/releases), extract, `make install` | Air-gapped or locked-down environments. |

**Platform-specific notes:**

| Platform | What the installer does |
|:---------|:-----------------------|
| **macOS** | Symlinks to `~/.local/bin`, adds to `.zshrc` |
| **Linux** | Symlinks to `~/.local/bin`, adds to `.bashrc` |
| **WSL** | Same as Linux (auto-detected via `/proc/version`) |
| **Windows (Git Bash / MSYS2)** | Copies to `~/bin` (symlinks need admin on Windows) |

</details>

<details>
<summary><b>Optional: add gstack skills (37 Claude Code skills)</b></summary>

<br>

```bash
git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup --no-prefix
```

</details>

### Step 2: Bootstrap your repo (once per project)

```bash
aiframework run --target ~/your-project
```

### Step 3: Open Claude Code and run one command

```bash
cd ~/your-project && claude
```

Then in Claude Code:

```
/aif-ready
```

**That's it.** `/aif-ready` researches your stack, enhances CLAUDE.md with framework-specific rules, optimizes your settings, and tells you what to do next. No API key needed &mdash; it uses Claude Code's built-in web search.

After that, just code. Claude knows your stack, commands, invariants, and architecture.

### Requirements

| Dependency | Minimum | Check | Required? |
|:-----------|:--------|:------|:----------|
| `bash` | 3.2+ (4.0+ recommended) | `bash --version` | Yes |
| `git` | 2.0+ | `git --version` | Yes |
| `jq` | 1.6+ | `jq --version` | Yes |
| `python3` | 3.10+ | `python3 --version` | Yes (code indexer uses `match/case` syntax) |
| `node` / `npm` | 22+ | `node --version` | Optional (for sheal runtime intelligence) |
| `shellcheck` | any | `shellcheck --version` | Optional (lints generated hooks) |

> **Note:** Python 3.10+ is required because the code indexer uses `match/case` syntax introduced in 3.10. All versions 3.10, 3.11, 3.12, 3.13+ are supported. On Windows, `python` (not `python3`) is detected automatically.

<br>

---

<br>

## The Ecosystem

aiframework is the center of a **4-tool ecosystem** that gives Claude Code complete project intelligence:

```
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                                                                         │
  │   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐              │
  │   │  aiframework │     │    gstack   │     │    sheal    │              │
  │   │  ───────────│     │  ──────────│     │  ──────────│              │
  │   │  Setup-time  │     │  Work-time  │     │  Runtime    │              │
  │   │  Scans repo  │────▶│  Ship, QA,  │────▶│  Watches    │              │
  │   │  Generates   │     │  Review,    │     │  sessions,  │              │
  │   │  configs     │     │  Design     │     │  extracts   │              │
  │   │              │     │  37 skills  │     │  learnings  │              │
  │   └──────┬───────┘     └─────────────┘     └──────┬──────┘              │
  │          │                                         │                    │
  │          │         ┌─────────────────┐             │                    │
  │          └────────▶│  Vault (Memory) │◀────────────┘                    │
  │                    │  ──────────────│                                  │
  │                    │  Persists       │                                  │
  │                    │  decisions,     │                                  │
  │                    │  wiki, retros   │                                  │
  │                    │  across sessions│                                  │
  │                    └─────────────────┘                                  │
  │                                                                         │
  └─────────────────────────────────────────────────────────────────────────┘
```

| Tool | When | What | Install |
|:-----|:-----|:-----|:--------|
| **aiframework** | Setup (once) | Scans repo, generates CLAUDE.md + rules + skills + hooks + vault | `curl \| sh` or `brew install` |
| **gstack** | During work | 37 skills: ship, QA, review, design, security, deploy | `git clone` + `./setup` |
| **sheal** | Every session | Watches sessions, extracts learnings, detects drift | Auto with `make install` (optional) |
| **Vault** | Always | Persistent memory: decisions, wiki, notes, retro insights | Auto-generated by aiframework |

<br>

---

<br>

## What You Get

aiframework reads your repo the way a senior engineer would on their first day &mdash; except it takes 60 seconds instead of a week, and it writes everything down.

```
  $ aiframework run --target .

  DISCOVER  ████████████████████ 13 scanners
    typescript / nextjs / api-service
    47 endpoints, 209 symbols, 4 domains detected

  GENERATE  ████████████████████ 23 files written
    CLAUDE.md · .claude/rules/ · .claude/skills/ · vault/
    .githooks/ · .github/workflows/ · docs/ · AGENTS.md

  VERIFY    ████████████████████ all checks — PASSED

  Claude Code now knows your entire project.
```

<br>

### The files

<table>
<tr>
<td width="50%" valign="top">

**For Claude Code** &mdash; *auto-loaded every session*

```
CLAUDE.md               → project brain
.claude/rules/
  ├── workflow.md        → dev process, git safety
  ├── testing.md         → test conventions
  └── security.md        → auth/api guardrails
.claude/settings.json    → safe permissions
.claude/skills/          → 15 slash commands
AGENTS.md                → cross-tool config
```

</td>
<td width="50%" valign="top">

**For your team** &mdash; *devops, docs, knowledge*

```
.githooks/
  ├── pre-commit         → lint on every commit
  └── pre-push           → full quality gate + auto-refresh
.github/workflows/ci.yml → CI for your language
vault/                   → knowledge graph (per-file wiki)
docs/                    → documentation scaffold
CHANGELOG.md + VERSION   → release tracking
```

</td>
</tr>
</table>

**For any AI agent** &mdash; *universal compatibility*

```
AGENTS.md               → works with Codex, Cursor, Copilot, Gemini
.cursorrules             → Cursor IDE integration
```

Everything is deterministic. Same repo, same output. Every time.
Then `/aif-ready` enhances it with framework-specific knowledge from the web.

<br>

---

<br>

## Skills

aiframework generates **15 project-specific skills**. The ecosystem extends to **37 more** via [gstack](https://github.com/garrytan/gstack). Together, Claude Code goes from a chatbot to a full engineering team.

### Your workflow

```
  /aif-ready          ← run once: research stack, enhance CLAUDE.md, optimize settings
       │
       ▼
  Start coding ──── /aif-review ──── /aif-ship ──── push
       │                                              │
       ├── /aif-learn "discovered X"     hooks auto-refresh ──→ CLAUDE.md stays current
       │
  Weekly: /aif-evolve     ← improve rules from accumulated learnings
  Monthly: /aif-pulse     ← discover new Claude Code features

  ─── with sheal (runtime intelligence) ───

  Session start → update check + health  ← SessionStart hook (auto)
  Session end   → /sheal-retro          ← extract learnings, bridge to JSONL
  Weekly        → /sheal-drift          ← detect unapplied learnings, promote to rules
```

### aiframework skills

| When | Skill | What it does |
|:-----|:------|:-------------|
| **Setup** | **`/aif-ready`** | **Researches your stack, enhances CLAUDE.md, optimizes settings. Run once.** |
| Daily | `/aif-review` | Code review against your project's invariants |
| Daily | `/aif-ship` | lint &rarr; review &rarr; docs &rarr; changelog &rarr; commit |
| Daily | `/aif-learn` | Capture gotchas to persistent JSONL storage |
| On demand | `/aif-analyze` | Find missing tests, circular deps, god modules |
| On demand | `/aif-ingest` | Deposit documents into vault knowledge base |
| Weekly | `/aif-evolve` | Synthesize learnings into CLAUDE.md improvements |
| Monthly | `/aif-pulse` | Discover latest Claude Code features |
| On demand | `/aif-enhance` | Deep-dive: research gaps, find framework conventions |
| On demand | `/aif-research` | Search official docs for specific conventions |
| On demand | `/aif-feedback` | Structured feedback for `/aif-evolve` |
| Session start | `/sheal-check` | Runtime health check (tests, deps, env) |
| Session end | `/sheal-retro` | Extract session learnings, bridge to JSONL |
| Weekly | `/sheal-drift` | Detect unapplied learnings, promote to rules |
| On demand | `/sheal-ask` | Query past session history |

<br>

### gstack skills (37 &mdash; via [gstack](https://github.com/garrytan/gstack))

<table>
<tr>
<td width="50%" valign="top">

**Ship & Debug**

| Skill | |
|:------|:--|
| `/ship` | test, review, bump, PR &mdash; one command |
| `/review` | pre-landing diff review |
| `/land-and-deploy` | merge, wait for CI, verify prod |
| `/investigate` | 4-phase root cause debugging |
| `/health` | 0-10 code quality score |
| `/retro` | weekly eng retrospective |
| `/codex` | second opinion from OpenAI Codex |

</td>
<td width="50%" valign="top">

**QA & Browser**

| Skill | |
|:------|:--|
| `/qa` | find bugs + fix them + verify |
| `/browse` | headless Chromium, ~100ms/cmd |
| `/design-review` | visual QA + auto-fix |
| `/benchmark` | Core Web Vitals per PR |
| `/canary` | post-deploy monitoring |
| `/cso` | security audit (OWASP + STRIDE) |

</td>
</tr>
<tr>
<td width="50%" valign="top">

**Plan & Design**

| Skill | |
|:------|:--|
| `/plan-ceo-review` | founder-mode scope review |
| `/plan-eng-review` | architecture + edge cases |
| `/plan-design-review` | rate each dimension 0-10 |
| `/autoplan` | run all reviews, auto-decide |
| `/design-shotgun` | generate design variants |
| `/design-html` | production HTML/CSS output |
| `/design-consultation` | full design system creation |

</td>
<td width="50%" valign="top">

**Utilities**

| Skill | |
|:------|:--|
| `/office-hours` | YC-style idea validation |
| `/checkpoint` | save/resume working state |
| `/guard` | safety mode for prod |
| `/freeze` | restrict edits to one dir |
| `/pair-agent` | share browser with remote AI |
| `/open-gstack-browser` | launch visible Chromium |
| `/gstack-upgrade` | one-command self-update |

</td>
</tr>
</table>

<br>

---

<br>

## 20 Languages · 57 Frameworks

aiframework's code indexer parses symbols, imports, and dependency edges. It's not guessing &mdash; it's reading your actual AST.

| Language | What it extracts | Frameworks it knows |
|:---------|:-----------------|:--------------------|
| **TypeScript / JavaScript** | functions, classes, types, imports, exports | Next.js, NestJS, React, Vue, Express, Hono, Svelte |
| **Python** | functions, classes, methods, decorators, imports | FastAPI, Django, Flask, Starlette |
| **Go** | functions, types, interfaces, imports | Gin, Echo, Chi, Fiber |
| **Rust** | functions, structs, enums, traits, imports | Actix, Axum, Rocket, Warp |
| **Ruby** | methods, classes, modules | Rails, Sinatra |
| **Java** | classes, methods, interfaces, annotations | Spring Boot, Quarkus |
| **C#** | classes, methods, properties | ASP.NET, Blazor |
| **PHP, Kotlin, Swift, Elixir, Bash** | full symbol extraction | major frameworks |
| **+ 20 more in registry** | detection via marker files | extensible via JSON |

<details>
<summary><b>18 domain detectors</b> &mdash; each adds invariants and security rules to your CLAUDE.md</summary>

<br>

`Auth` · `Database` · `API` · `AI/LLM` · `Frontend` · `Workers` · `File Upload` · `Financial` · `GraphQL` · `Messaging` · `Caching` · `Search` · `Observability` · `Realtime` · `Email` · `Storage` · `Sandbox` · `External APIs`

</details>

<details>
<summary><b>11 project archetypes</b> &mdash; controls CLAUDE.md depth and structure</summary>

<br>

`library` · `cli-tool` · `web-app` · `api-service` · `full-stack` · `monorepo` · `data-pipeline` · `ml-project` · `mobile-app` · `infrastructure` · `documentation-site`

</details>

<br>

---

<br>

## Architecture

```
aiframework run --target /path/to/repo
│
│   DISCOVER ─────────────────────── scan everything, assume nothing
│   │
│   ├── identity        name, version, short name
│   ├── stack           language, framework, monorepo?
│   ├── commands        package manager, lint, test, build
│   ├── structure       files, dirs, source roots, test files
│   ├── ci + deploy     GitHub Actions, Docker, Fly.io, Vercel...
│   ├── env             variables from .env, config files
│   ├── quality         linter, formatter, type checker, test runner
│   ├── domain          18 types (auth, db, ai, graphql...)
│   ├── code_index      symbols + imports + edges (20 languages)
│   ├── archetype       what kind of project is this?
│   ├── skill_suggest   what workflows would help?
│   └── sheal           runtime session intelligence (optional)
│   │
│   ╰──→  manifest.json + code-index.json
│
│   GENERATE ─────────────────────── deterministic, reproducible
│   │
│   ├── CLAUDE.md           80-150 lines, lean, high-signal
│   ├── .claude/rules/      auto-loaded by path pattern
│   ├── .claude/skills/     3 project skills + framework skills
│   ├── .githooks/          pre-commit + pre-push with auto-refresh
│   ├── .github/workflows/  CI pipeline for your language
│   ├── vault/              31-file knowledge base
│   └── docs/               Diataxis scaffold
│
│   VERIFY ───────────────────────── trust, but verify
│   │
│   ├── files           do all expected files exist?
│   ├── consistency     do commands match across CLAUDE.md, hooks, CI?
│   ├── security        any secrets in source? .gitignore coverage?
│   ├── quality_gate    are lint/test commands actually working?
│   └── freshness       is the manifest stale? did files drift?
│
╰──→  PASS / FAIL / WARN
```

<br>

---

<br>

## Self-Evolution

Your CLAUDE.md gets smarter over time &mdash; most of it happens automatically.

| What | How | When |
|:-----|:----|:-----|
| **Update check** | `SessionStart` hook runs `aiframework-update-check`; Claude Code tells you if a new version is available | Every session start |
| **Auto-refresh** | Pre-push hook detects config drift, re-runs `aiframework refresh`, auto-commits | Every `git push` |
| **Update reminder** | Pre-push hook checks for new aiframework versions and shows `Run: aiframework update` | Every `git push` |
| **Learning capture** | `/aif-learn "description"` persists gotchas to JSONL | When you discover something |
| **Rule evolution** | `/aif-evolve` reads all learnings, proposes CLAUDE.md improvements | Weekly |
| **Ecosystem pulse** | `/aif-pulse` discovers new Claude Code features, suggests adoption | Monthly |

You never have to manually check for updates or keep CLAUDE.md in sync &mdash; it all happens through hooks.

### Runtime intelligence with sheal

aiframework handles **setup-time** intelligence &mdash; it scans your repo once and generates configs. But what about learning from actual coding sessions?

[sheal](https://www.npmjs.com/package/@liwala/sheal) handles **runtime** intelligence &mdash; it watches your AI coding sessions, extracts what went wrong, and feeds those learnings back into your configs. Together, they create a complete loop:

```
  ┌─────────────────────────────────────────────────────────────┐
  │                    THE IMPROVEMENT LOOP                      │
  │                                                              │
  │   1. BOOTSTRAP ──→ aiframework scans repo, generates        │
  │      │              CLAUDE.md + rules + skills + vault       │
  │      ▼                                                       │
  │   2. WORK ──────→ you code with Claude Code                 │
  │      │              /aif-learn captures gotchas (dual-write) │
  │      ▼                                                       │
  │   3. RETRO ─────→ /sheal-retro extracts session patterns    │
  │      │              bridge syncs learnings ↔ JSONL           │
  │      ▼                                                       │
  │   4. EVOLVE ────→ /aif-evolve reads both sources            │
  │      │              proposes CLAUDE.md improvements          │
  │      ▼                                                       │
  │   5. DRIFT ─────→ /sheal-drift detects unapplied learnings │
  │      │              promotes to permanent rules              │
  │      ▼                                                       │
  │   └──────────────→ repeat (your CLAUDE.md gets smarter)     │
  └─────────────────────────────────────────────────────────────┘
```

| Phase | What | How |
|:------|:-----|:----|
| **Bootstrap** | aiframework scans repo, generates configs | `aiframework run` |
| **Session start** | Update check + health check run automatically | SessionStart hook |
| **During work** | Both tools capture learnings in their formats | `/aif-learn` dual-writes |
| **Session end** | sheal extracts patterns from the session | `/sheal-retro` |
| **Weekly** | Drift detection promotes learnings to rules | `/sheal-drift` |
| **Evolution** | `/aif-evolve` reads both sources | Bidirectional bridge |

**sheal is optional.** If Node.js or npm is unavailable, aiframework works exactly as before. `make install` attempts to install sheal automatically with graceful fallback. When sheal is absent, the framework produces zero behavioral change &mdash; no extra output, no extra files, no extra steps.

<br>

---

<br>

## gstack Included

[gstack](https://github.com/garrytan/gstack) is installed as part of the [Quick Start](#quick-start). aiframework auto-detects it at `~/.claude/skills/gstack/` and injects the full browser command reference and skill routing into your generated `CLAUDE.md`.

**What it adds**: a persistent Chromium daemon that Claude Code controls directly. ~100ms per command. 20x faster than Playwright MCP. Cookies, tabs, and login sessions persist across commands.

<details>
<summary><b>The <code>$B</code> browser protocol</b></summary>

<br>

```bash
$B goto https://myapp.com                          # navigate
$B snapshot                                         # get page structure with element refs
$B click @e3                                        # click by ref (not CSS selector)
$B fill @e5 "hello@test.com"                       # fill input
$B screenshot                                       # capture
$B chain "click @e1" "fill @e2 text" "screenshot"  # chain multiple commands
$B console                                          # read browser logs
$B network                                          # read network requests
$B responsive 375                                   # mobile viewport
$B diff                                             # compare with previous snapshot
```

</details>

<br>

---

<br>

## Vault Knowledge Graph

Every source file in your repo gets its own wiki page. Every import becomes a bidirectional link. The result is a navigable knowledge graph that Claude Code can traverse to understand any part of the codebase without reading every file.

```
  $ aiframework run --target .

  vault/wiki/
  ├── index.md                          ← master registry (all pages)
  ├── concepts/
  │   └── architecture.md               ← module graph + top files by PageRank
  └── entities/
      ├── src-api-auth-controller-ts.md  ← symbols, imports, imported-by
      ├── src-api-auth-service-ts.md     ← [[src-api-auth-controller-ts]] link
      ├── src-db-migrations-ts.md        ← who calls this, what it calls
      ├── src-lib-utils-ts.md            ← PageRank: 0.0089 (high fan-in)
      └── ...                            ← one page per source file
```

**What each page contains:**

| Section | What it shows |
|:--------|:-------------|
| Symbols | Every function, class, type with line number, kind, visibility |
| Imports | Files this file depends on, as `[[wikilinks]]` |
| Imported By | Files that depend on this file, as `[[wikilinks]]` |
| Module | Parent module link |
| PageRank | Architectural importance score |

**Numbers for a typical project:** 200 files produces ~220 pages, ~800 wikilinks, avg 50 lines per page. All pages stay under 200 lines. Incremental updates via content hashing &mdash; only changed pages are rewritten.

The wiki auto-updates on every `git push` via the pre-push hook. Change a file, push, and its wiki page (plus all pages that reference it) update automatically.

<br>

---

<br>

## Upgrading

One command, works regardless of how you installed:

```bash
aiframework update
```

**Auto-detects your install method** and does the right thing:

| Install method | What `update` does |
|:---|:---|
| **curl\|sh / git clone** | `git pull --ff-only` on the cloned repo |
| **Homebrew** | `brew upgrade aiframework` |
| **Release tarball** | Downloads latest release, verifies SHA256 checksum, extracts |

After updating itself, it automatically:
1. Updates sheal to latest (if npm available)
2. Finds all repos you've bootstrapped (tracked in `~/.aiframework/knowledge/`)
3. Runs `aiframework refresh` on each &mdash; only regenerates what changed

**Aliases:** `aiframework upgrade`, `aiframework self-update` &mdash; all do the same thing.

**Check for updates without applying:**

```bash
aiframework-update-check           # prints UPGRADE_AVAILABLE or UP_TO_DATE
aiframework-update-check --json    # machine-readable JSON output
aiframework-update-check --apply   # check and immediately update if available
aiframework-update-check --snooze  # silence notification for this version
```

<br>

---

<br>

## CLI Reference

```
$ aiframework <command> [options]

  run            full pipeline: discover → generate → verify → report
  discover       scan repo → manifest.json + code-index.json
  generate       read manifest → generate all files
  verify         validate generated files (5 validators)
  refresh        re-discover + generate only if drift detected
  update         auto-detect install method + update + refresh all repos
  upgrade        alias for update
  report         human-readable report
  index          build code index only
  stats          cross-repo learning patterns

  --target <path>       target repo (default: cwd)
  --non-interactive     skip user context questions
  --no-index            skip code indexing
  --dry-run             preview without writing
  --verbose             detailed output
```

<br>

## Extensible

All detection is data-driven. Add a language, domain, or archetype by editing one JSON file:

| Registry | Entries | File |
|:---------|:--------|:-----|
| Languages | 20 | `lib/data/languages.json` |
| Domains | 18 | `lib/data/domains.json` |
| Deploy targets | 24 | `lib/data/deploy_targets.json` |
| Archetypes | 11 | `lib/data/archetypes.json` |

### Integration modules

| Module | Purpose | File |
|:-------|:--------|:-----|
| Wiki graph | Dense per-file knowledge graph with bidirectional links | `lib/generators/wiki_graph.py` |
| Sheal scanner | Detect sheal installation and state | `lib/scanners/sheal.sh` |
| Sheal generator | Generate `.self-heal.json`, init, inject rules | `lib/generators/sheal.sh` |
| Learning bridge | Bidirectional JSONL ↔ markdown sync | `lib/bridge/sheal_learnings.sh` |

<br>

---

<br>

## Telemetry

aiframework collects anonymous usage data to understand adoption and prioritize features.

**What is collected:**

| Data | Example | Why |
|:-----|:--------|:----|
| Event type | `run`, `refresh`, `upgrade`, `verify_failed` | Know which commands are used |
| Version, OS, bash, Python, jq | `1.3.0`, `macos`, `5.2`, `3.12`, `1.7` | Know what environments to support |
| Anonymous machine ID | SHA-256 hash (not reversible) | Count unique users, not sessions |
| Pipeline outcome | `lang=python`, `framework=fastapi`, `archetype=api-service` | Know what stacks to prioritize |
| Integration status | `sheal=true`, `gstack=true`, `node=true` | Know which integrations matter |
| Error phase and message | `verify: failed=2 passed=8` | Fix the most common failures |
| Vault stats | `vault_pages=87`, `total_symbols=335` | Understand scale and usage |
| CLAUDE.md quality | `claude_md_lines=142`, `invariant_count=3` | Measure and improve generated output |
| Learning volume | `learnings_count=12`, `category=gotcha` | Identify which stacks need better templates |
| Duration | `12s` | Detect performance regressions |

**What is never collected:** source code, file contents, file paths, project names, git history, commit messages, personal data, IP addresses, usernames.

**Opt out:**

```bash
mkdir -p ~/.aiframework && echo "telemetry: false" >> ~/.aiframework/config
```

<br>

---

## Known Gaps & Testing

We believe in transparency. The core pipeline has been extensively self-tested with automated checks passing. But some things can only be validated by real-world usage.

**[Full testing checklist &rarr;](docs/KNOWN_GAPS.md)**

| Area | Status | What needs validation |
|:-----|:-------|:---------------------|
| Core pipeline | Production-ready | Tested on synthetic fixtures; needs real-world repo validation |
| Knowledge graph | Production-ready | Verified with completeness checker; needs large repo validation |
| sheal CLI flags | Unverified | Integration coded against assumed flags; needs live binary testing |
| macOS (arm64 + x86) | Tested | CI + local testing on arm64 |
| Linux (Ubuntu) | Tested | CI on ubuntu-latest |
| Windows (Git Bash/MSYS2) | CI-tested | Installer tests pass on windows-latest; core pipeline needs community validation |
| WSL | Supported | Auto-detected via `/proc/version`; treated as Linux |
| Automation hooks | Verified in output | `SessionStart`/`Stop`/`PostToolUse` generated correctly; needs Claude Code runtime validation |

If you test on your project and it works (or doesn't), [open an issue](https://github.com/evergonlabs/aiframework/issues) &mdash; it helps everyone.

<br>

---

<div align="center">

<br>

**[Evergon Labs](https://github.com/evergonlabs)** &middot; [MIT License](LICENSE)

*Your repo already knows everything.<br>Now Claude does too.*

<br>

[![GitHub stars](https://img.shields.io/github/stars/evergonlabs/aiframework?style=social)](https://github.com/evergonlabs/aiframework)

</div>
