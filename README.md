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

[![version](https://img.shields.io/badge/v1.1.0-blue?style=flat-square&label=version)](https://github.com/evergonlabs/aiframework/releases)
[![license](https://img.shields.io/badge/MIT-green?style=flat-square&label=license)](LICENSE)
[![tests](https://img.shields.io/badge/92_passing-brightgreen?style=flat-square&label=tests)]()
[![Bash](https://img.shields.io/badge/bash-1f425f?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/3.10+-3776AB?style=flat-square&logo=python&logoColor=white)](https://python.org)
[![Claude Code](https://img.shields.io/badge/compatible-cc785c?style=flat-square&logo=anthropic&logoColor=white&label=claude%20code)](https://docs.anthropic.com/en/docs/claude-code)
[![gstack](https://img.shields.io/badge/37_skills-blueviolet?style=flat-square&label=gstack)](https://github.com/garrytan/gstack)

<br>

[Quick Start](#quick-start) · [What You Get](#what-you-get) · [Skills](#52-skills) · [Languages](#20-languages--57-frameworks) · [Architecture](#architecture) · [gstack](#gstack-included)

</div>

<br>

---

<br>

## Quick Start

### Step 1: Install (once)

```bash
git clone https://github.com/evergonlabs/aiframework.git && cd aiframework && make install
git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup --no-prefix
```

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

> **Requirements:** `bash` 3.2+ &nbsp;·&nbsp; `jq` 1.6+ &nbsp;·&nbsp; `git` 2.0+ &nbsp;·&nbsp; `python3` 3.10+ *(recommended, bash fallback available)*

<br>

---

<br>

## What You Get

aiframework reads your repo the way a senior engineer would on their first day &mdash; except it takes 60 seconds instead of a week, and it writes everything down.

```
  $ aiframework run --target .

  DISCOVER  ████████████████████ 12 scanners
    typescript / nextjs / api-service
    47 endpoints, 209 symbols, 4 domains detected

  GENERATE  ████████████████████ 23 files written
    CLAUDE.md · .claude/rules/ · .claude/skills/ · vault/
    .githooks/ · .github/workflows/ · docs/ · AGENTS.md

  VERIFY    ████████████████████ 34 checks — ALL PASSED

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
vault/                   → knowledge base (31 files)
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

## 52 Skills

aiframework generates **15 project-specific skills**. [gstack](https://github.com/garrytan/gstack) adds **37 more**. Together, Claude Code goes from a chatbot to a full engineering team.

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

<br>

### gstack skills (37 &mdash; included with install)

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
│   └── skill_suggest   what workflows would help?
│   │
│   ╰──→  manifest.json + code-index.json
│
│   GENERATE ─────────────────────── deterministic, reproducible
│   │
│   ├── CLAUDE.md           80-150 lines, lean, high-signal
│   ├── .claude/rules/      auto-loaded by path pattern
│   ├── .claude/skills/     10 slash commands
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
╰──→  PASS / FAIL / WARN  (34 checks)
```

<br>

---

<br>

## Self-Evolution

Your CLAUDE.md gets smarter over time &mdash; most of it happens automatically.

| What | How | When |
|:-----|:----|:-----|
| **Auto-refresh** | Pre-push hook detects config drift, re-runs `aiframework refresh`, auto-commits | Every `git push` |
| **Learning capture** | `/aif-learn "description"` persists gotchas to JSONL | When you discover something |
| **Rule evolution** | `/aif-evolve` reads all learnings, proposes CLAUDE.md improvements | Weekly |
| **Ecosystem pulse** | `/aif-pulse` discovers new Claude Code features, suggests adoption | Monthly |

The auto-refresh hook means you never have to think about keeping CLAUDE.md in sync &mdash; change a dependency, push, and it updates itself.

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

## CLI Reference

```
$ aiframework <command> [options]

  run            full pipeline: discover → generate → verify → report
  discover       scan repo → manifest.json + code-index.json
  generate       read manifest → generate all files
  verify         validate generated files (46+ checks)
  refresh        re-discover + generate only if drift detected
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

<br>

---

<div align="center">

<br>

**[Evergon Labs](https://github.com/evergonlabs)** · [MIT License](LICENSE)

*Your repo already knows everything.<br>Now Claude does too.*

<br>

[![GitHub stars](https://img.shields.io/github/stars/evergonlabs/aiframework?style=social)](https://github.com/evergonlabs/aiframework)

</div>
