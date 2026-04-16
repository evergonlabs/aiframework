<div align="center">

<br>

# `>_ aiframework`

### One command. Any repo. Zero config.

The open-source autopilot for AI-assisted development with [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

<br>

[![version](https://img.shields.io/badge/version-1.1.0-blue?style=for-the-badge)](https://github.com/evergonlabs/aiframework/releases)
[![license](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)](LICENSE)
[![Made with Bash](https://img.shields.io/badge/Bash-1f425f?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Python_3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Claude Code](https://img.shields.io/badge/Claude_Code-cc785c?style=for-the-badge&logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code)
[![tests](https://img.shields.io/badge/36_tests_passing-brightgreen?style=for-the-badge)]()
[![gstack](https://img.shields.io/badge/gstack-37_skills-blueviolet?style=for-the-badge)](https://github.com/garrytan/gstack)

<br>

[Quick Start](#-quick-start) &bull; [What It Generates](#-what-it-generates) &bull; [Skills](#-skills-reference) &bull; [gstack](#-supercharged-with-gstack) &bull; [Languages](#-supported-languages) &bull; [How It Works](#-how-it-works) &bull; [Self-Evolution](#-self-evolution)

<br>

```
   ┌──────────────────────────────────────────────────────────────────┐
   │                                                                  │
   │   aiframework run --target .                                     │
   │                                                                  │
   │   > Scanning 847 files across 12 scanners...                     │
   │   > Indexed 209 symbols in 13 languages                          │
   │   > Detected: typescript / nextjs / api-service                  │
   │   > Domains: auth, database, ai-llm, graphql                     │
   │                                                                  │
   │   > Generated 23 files:                                          │
   │     CLAUDE.md, .claude/rules/, .claude/skills/,                  │
   │     .githooks/, .github/workflows/, vault/, docs/                │
   │                                                                  │
   │   > Verification: 46 checks — ALL PASSED                        │
   │                                                                  │
   │   Claude Code now knows your entire project.                     │
   │                                                                  │
   └──────────────────────────────────────────────────────────────────┘
```

</div>

<br>

## The Problem

You open Claude Code on a new repo. Claude doesn't know your stack, your conventions, your invariants, your test commands, or where anything lives. You spend the first 10 minutes of every session explaining context. Multiply that by every developer on the team.

**aiframework fixes this in one command.**

It scans your repo &mdash; every file, every symbol, every dependency &mdash; and generates a complete Claude Code configuration that makes Claude an expert on *your* project from the first prompt.

## What You Get

```
Before aiframework             After aiframework
─────────────────────          ──────────────────────────────────────
Claude: "What framework        Claude: "This is a FastAPI app with
 do you use?"                   auth middleware, PostgreSQL via
                                SQLAlchemy, 47 endpoints, and a
You: *explains for              custom permission system. I have
 10 minutes*                    47 skills ready — /review, /ship,
                                /qa, /cso, /investigate...
Claude: "Can you show           Let me check the pre-push gate
 me the test command?"          before we start."
```

<br>

## &#9889; Quick Start

```bash
# 1. Install aiframework
git clone https://github.com/evergonlabs/aiframework.git
cd aiframework && make install

# 2. Install gstack (browser automation, QA, security, design — 37 skills)
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup --no-prefix

# 3. Run on any project
aiframework run --target /path/to/your-project

# 4. Open Claude Code — it just works
cd /path/to/your-project && claude
```

> aiframework generates your project configuration (10 skills, 23+ files). gstack adds 37 more skills for browser QA, security audits, design systems, and deploy automation. Together they give Claude Code the full picture &mdash; from your first prompt.

<br>

## &#128230; What It Generates

**23+ files** across 7 generators. Everything is deterministic &mdash; same repo always produces same output.

<table>
<tr>
<td width="50%">

**Claude Code Configuration**
| File | Purpose |
|:-----|:--------|
| `CLAUDE.md` | Project brain &mdash; commands, invariants, architecture |
| `.claude/rules/` | Path-scoped rules (workflow, testing, security) |
| `.claude/settings.json` | Permissions &amp; tool config |
| `.claude/skills/` | Slash commands (`/review`, `/ship`, `/learn`) |
| `AGENTS.md` | Cross-tool agent configuration |

</td>
<td width="50%">

**DevOps & Knowledge**
| File | Purpose |
|:-----|:--------|
| `.githooks/` | Pre-commit lint + pre-push quality gates |
| `.github/workflows/ci.yml` | CI pipeline for your language |
| `vault/` | Persistent knowledge base (31 files) |
| `docs/` | Documentation scaffold (Diataxis) |
| `CHANGELOG.md` + `VERSION` | Release tracking |

</td>
</tr>
</table>

<details>
<summary><strong>Generated <code>.claude/</code> directory structure</strong></summary>

```
.claude/
├── rules/
│   ├── workflow.md       # Always loaded — dev process, git safety, verification
│   ├── testing.md        # Loaded for **/*.test.*, **/tests/** — test conventions
│   └── security.md       # Loaded for **/auth/**, **/api/** — security rules
├── settings.json         # Pre-approves: Read, Glob, Grep, WebSearch
└── skills/
    ├── <name>-review/    # /name-review → invariant checks
    ├── <name>-ship/      # /name-ship → lint → review → commit
    └── <name>-learn/     # /name-learn → persist learnings
```

</details>

<br>

## &#128295; Skills Reference

10 slash commands generated per project. Use them inside Claude Code:

| Skill | Trigger | What it does |
|:------|:--------|:-------------|
| `/aif-review` | Before merging | Code review against project invariants |
| `/aif-ship` | Ready to push | Full pipeline: lint &rarr; review &rarr; docs &rarr; changelog &rarr; commit |
| `/aif-learn` | Found a gotcha | Capture pattern/gotcha to persistent JSONL storage |
| `/aif-enhance` | After first scan | Research gaps, find framework conventions, enrich vault |
| `/aif-research` | Unknown patterns | Search official docs for conventions and invariants |
| `/aif-analyze` | Code quality | Find missing tests, circular deps, god modules |
| `/aif-evolve` | Weekly | Synthesize learnings into CLAUDE.md improvements |
| `/aif-pulse` | Weekly | Research latest Claude Code features, suggest adoption |
| `/aif-feedback` | After runs | Collect structured feedback for `/aif-evolve` |
| `/aif-ingest` | New docs | Deposit documents into vault knowledge base |

<br>

## &#127760; Supported Languages

<table>
<tr>
<td>

| Language | Symbols | Frameworks |
|:---------|:--------|:-----------|
| **TypeScript/JS** | Functions, classes, types, imports | Next.js, NestJS, React, Vue, Express, Hono, Svelte |
| **Python** | Functions, classes, methods, imports | FastAPI, Django, Flask, Starlette |
| **Go** | Functions, types, imports | Gin, Echo, Chi, Fiber |
| **Rust** | Functions, structs, enums, imports | Actix, Axum, Rocket, Warp |

</td>
</tr>
<tr>
<td>

| Language | Symbols | Frameworks |
|:---------|:--------|:-----------|
| **Ruby** | Methods, classes, modules | Rails, Sinatra |
| **Java** | Classes, methods, interfaces | Spring Boot, Quarkus |
| **C#, PHP, Kotlin, Swift, Elixir** | Full symbol extraction | Major frameworks |
| **+ 20 more** | Detection via marker files | Extensible via JSON registry |

</td>
</tr>
</table>

**18 domain detectors**: Auth, Database, API, AI/LLM, Frontend, Workers, File Upload, Financial, GraphQL, Messaging, Caching, Search, Observability, Realtime, Email, Storage, Sandbox, External APIs

**11 archetypes**: `library` &middot; `cli-tool` &middot; `web-app` &middot; `api-service` &middot; `full-stack` &middot; `monorepo` &middot; `data-pipeline` &middot; `ml-project` &middot; `mobile-app` &middot; `infrastructure` &middot; `documentation-site`

<br>

## &#9881; How It Works

```
aiframework run --target /path/to/repo
│
├── DISCOVER ─────────────────────────────────── 12 scanners, deterministic
│   ├── identity      → name, version, short name
│   ├── stack         → language, framework, monorepo detection
│   ├── commands      → package manager, install, lint, test, build
│   ├── structure     → files, dirs, source roots, test files
│   ├── ci/deploy     → GitHub Actions, Docker, Vercel, Fly.io...
│   ├── env           → environment variables from .env, config
│   ├── quality       → linter, formatter, type checker, test runner
│   ├── domain        → auth, database, AI/LLM, GraphQL... (18 types)
│   ├── code_index    → symbols, imports, edges (13 languages)
│   ├── archetype     → library / api-service / monorepo / ... (11 types)
│   └── skill_suggest → deploy, migrations, Docker, E2E...
│   ╰─→ manifest.json + code-index.json
│
├── GENERATE ─────────────────────────────────── 7 generators, 23+ files
│   ├── CLAUDE.md          (lean 80-150 lines, high-signal)
│   ├── .claude/rules/     (path-scoped, auto-loaded)
│   ├── .claude/skills/    (10 slash commands)
│   ├── .githooks/         (pre-commit + pre-push gates)
│   ├── .github/workflows/ (CI pipeline)
│   ├── vault/             (31 files, wiki, memory, learnings)
│   └── docs/              (Diataxis scaffold)
│
└── VERIFY ───────────────────────────────────── 5 validators, 46+ checks
    ├── files         → all expected files exist
    ├── consistency   → commands match across CLAUDE.md, hooks, CI
    ├── security      → no secrets in source, .gitignore coverage
    ├── quality_gate  → lint/test commands configured and working
    └── freshness     → manifest age, file drift, index staleness
    ╰─→ PASS / FAIL / WARN report
```

<br>

## &#9889; Self-Evolution

aiframework-generated projects get smarter over time:

```
                    ┌─────────────┐
                    │  Developer   │
                    │  writes code │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  git push   │◄──── pre-push hook detects drift
                    └──────┬──────┘      auto-refreshes if needed
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ /aif-    │ │ /aif-    │ │ /aif-    │
        │  learn   │ │  evolve  │ │  pulse   │
        │          │ │          │ │          │
        │ captures │ │ reads    │ │ discovers│
        │ gotchas  │ │ learnings│ │ new CC   │
        │ to JSONL │ │ → updates│ │ features │
        └──────────┘ │ CLAUDE.md│ └──────────┘
                     └──────────┘
```

| Mechanism | What it does | Trigger |
|:----------|:-------------|:--------|
| **Drift detection** | Detects changed deps/config, re-generates | `aiframework refresh` or auto on push |
| **Update notifications** | Checks for new aiframework versions, notifies in Claude Code session | Every session start |
| **Learning capture** | Persists gotchas/patterns to JSONL | `/aif-learn` |
| **Feedback loop** | Structured quality/accuracy feedback | `/aif-feedback` |
| **Rule evolution** | Synthesizes learnings into CLAUDE.md updates | `/aif-evolve` |
| **Ecosystem pulse** | Discovers latest Claude Code capabilities | `/aif-pulse` |

<br>

## &#128218; Your Workflow

### Day 1 &mdash; One-time setup (5 minutes)

```bash
aiframework run --target .          # Scan + generate + verify
claude                               # Open Claude Code — it just works
/aif-enhance                         # (Optional) Research gaps, add conventions
```

### Daily Development

```bash
/aif-review                          # Code review with invariant checks
/aif-ship                            # Lint → review → docs → changelog → commit
/aif-learn "gotcha description"      # Capture to persistent storage
```

### Weekly Maintenance

```bash
/aif-evolve                          # Analyze learnings → improve CLAUDE.md
/aif-pulse                           # Check for new Claude Code features
aiframework refresh                  # Re-generate if deps changed
```

<br>

## &#128187; CLI Reference

```
aiframework <command> [options]

Commands:
  run              Full pipeline: discover → generate → verify → report
  discover         Scan repo → manifest.json + code-index.json
  generate         Read manifest → generate all files
  verify           Validate generated files (46+ checks)
  refresh          Re-discover + generate only if drift detected
  report           Human-readable report of everything detected
  index            Build code index only
  stats            Cross-repo learning patterns

Options:
  --target <path>       Target repo (default: current directory)
  --non-interactive     Skip user context questions
  --no-index            Skip code indexing
  --dry-run             Preview without writing
  --verbose             Detailed output
```

<br>

## &#128736; Data-Driven & Extensible

All detection logic reads from JSON registries. Add a language, domain, or archetype by editing one file:

| Registry | Entries | Location |
|:---------|:--------|:---------|
| Languages | 20 | `lib/data/languages.json` |
| Domains | 18 | `lib/data/domains.json` |
| Deploy targets | 24 | `lib/data/deploy_targets.json` |
| Archetypes | 11 | `lib/data/archetypes.json` |

<br>

## &#128196; Requirements

| Dependency | Version | Required | Install |
|:-----------|:--------|:---------|:--------|
| `bash` | 3.2+ (4+ recommended) | Yes | Pre-installed on macOS/Linux |
| `jq` | 1.6+ | Yes | `brew install jq` / `apt install jq` |
| `git` | 2.0+ | Yes | Pre-installed |
| `python3` | 3.10+ | Recommended | For code indexer (bash fallback available) |

<br>

## &#127918; Included: gstack (37 Skills)

aiframework ships with [gstack](https://github.com/garrytan/gstack) integration out of the box. When you install both (see [Quick Start](#-quick-start)), you get **47 total skills** &mdash; 10 project-specific from aiframework + 37 from gstack covering browser automation, security, design, QA, and deploy.

aiframework auto-detects gstack at `~/.claude/skills/gstack/` during generation and injects the full `$B` browser command reference and all skill routing into your `CLAUDE.md`.

<table>
<tr>
<td width="50%">

**Development & Shipping**
| Skill | What it does |
|:------|:-------------|
| `/review` | Pre-landing PR review (SQL safety, trust boundaries) |
| `/ship` | Detect base, test, review, bump, PR &mdash; one command |
| `/land-and-deploy` | Merge PR, wait for CI, verify production health |
| `/investigate` | 4-phase root cause debugging (no fixes without cause) |
| `/health` | Composite 0-10 code quality dashboard |
| `/retro` | Weekly engineering retrospective with trends |

</td>
<td width="50%">

**QA & Browser Automation**
| Skill | What it does |
|:------|:-------------|
| `/qa` | Test site + iteratively fix bugs with before/after evidence |
| `/browse` | Headless Chromium (~100ms/cmd, ref-based selection) |
| `/design-review` | Visual QA: spacing, hierarchy, AI slop detection |
| `/benchmark` | Core Web Vitals regression detection per PR |
| `/canary` | Post-deploy monitoring with screenshot diffing |
| `/cso` | Infrastructure-first security audit (OWASP + STRIDE) |

</td>
</tr>
<tr>
<td width="50%">

**Planning & Design**
| Skill | What it does |
|:------|:-------------|
| `/plan-ceo-review` | Founder-mode: challenge premises, find 10-star product |
| `/plan-eng-review` | Architecture, data flow, edge cases, test coverage |
| `/plan-design-review` | Rate each design dimension 0-10, fix to get there |
| `/autoplan` | Run all reviews sequentially with auto-decisions |
| `/design-shotgun` | Generate multiple AI design variants, compare |
| `/design-html` | Production-quality HTML/CSS from approved designs |

</td>
<td width="50%">

**Utilities**
| Skill | What it does |
|:------|:-------------|
| `/codex` | Second opinion via OpenAI Codex (review, challenge, consult) |
| `/office-hours` | YC-style forcing questions for new ideas |
| `/checkpoint` | Save/resume working state across sessions |
| `/guard` | Full safety mode for production environments |
| `/pair-agent` | Share browser access with remote AI agents |
| `/gstack-upgrade` | One-command self-update |

</td>
</tr>
</table>

<details>
<summary><strong>The <code>$B</code> browser protocol (20x faster than Playwright MCP)</strong></summary>

gstack runs a persistent Chromium daemon. Commands use ref-based element selection (`@e1`, `@e2`) instead of CSS selectors. Cookies, tabs, and login sessions persist between commands.

```bash
$B goto https://myapp.com        # Navigate
$B snapshot                       # Get page structure with element refs
$B click @e3                      # Click element by ref
$B fill @e5 "hello@test.com"     # Fill input
$B screenshot                     # Capture screenshot
$B chain "click @e1" "fill @e2 text" "screenshot"  # Chain commands
```

</details>

> **Already installed?** Run `aiframework run` again and your `CLAUDE.md` will automatically include the gstack integration. New to gstack? See [Quick Start](#-quick-start) step 2.

<br>

## &#128193; Project Structure

```
aiframework/
├── bin/
│   ├── aiframework                # CLI entry point
│   └── aiframework-update-check   # Version + drift detector
├── lib/
│   ├── scanners/                  # 12 deterministic scanners
│   ├── indexers/                  # Code indexer (Python, 13 languages)
│   ├── generators/                # 7 file generators
│   ├── validators/                # 5 verification modules
│   ├── freshness/                 # Drift detection
│   ├── knowledge/                 # Cross-repo learning store
│   └── data/                      # JSON registries
├── .claude/skills/                # 10 aif-* skill definitions
├── tests/                         # 36 tests (unit + integration)
├── docs/                          # Onboarding, guides, reference
├── vault/                         # Knowledge vault (wiki, memory, rules)
└── Makefile                       # install, uninstall, lint, test
```

<br>

---

<div align="center">

**Built by [Evergon Labs](https://github.com/evergonlabs)** &bull; [MIT License](LICENSE)

*Because AI agents are only as good as the context you give them.*

[![Star History](https://img.shields.io/github/stars/evergonlabs/aiframework?style=social)](https://github.com/evergonlabs/aiframework)

</div>
