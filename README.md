<div align="center">

# aiframework

The missing bootstrap layer for AI coding assistants.

[![version](https://img.shields.io/badge/v2.0.0-blue?style=flat-square&label=version)](https://github.com/evergonlabs/aiframework/releases)
[![license](https://img.shields.io/badge/MIT-green?style=flat-square&label=license)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/evergonlabs/aiframework/ci.yml?style=flat-square&label=CI)](https://github.com/evergonlabs/aiframework/actions)
[![Rust](https://img.shields.io/badge/rust-8.9MB-orange?style=flat-square&label=binary)](rust/)
[![Claude Code](https://img.shields.io/badge/compatible-cc785c?style=flat-square&logo=anthropic&logoColor=white&label=claude%20code)](https://docs.anthropic.com/en/docs/claude-code)

</div>

---

## The problem

When you open [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (or Cursor, Copilot, Codex) in a project, it doesn't know your stack, your test commands, your coding conventions, or how your files connect. You repeat context every session. It guesses wrong commands. It suggests patterns that don't match your architecture.

## The solution

aiframework scans your repo once and generates a `CLAUDE.md` — the configuration file that Claude Code reads automatically on every session. It also generates rules, skills, git hooks, CI pipelines, and a knowledge graph of your entire codebase.

**The result:** Claude knows your lint/test/build commands, your architecture, your security invariants, and can navigate your codebase through a dependency graph of every file — from the first message.

## The bigger picture

AI coding assistants are powerful, but they start every session blind. They don't know your stack, your conventions, your architecture. You spend the first 10 minutes of every session re-explaining context that should be automatic.

aiframework solves the full lifecycle:

1. **Setup** — scan your repo, generate configs, build a knowledge graph (aiframework)
2. **Runtime** — workflow skills for shipping, reviewing, debugging, QA (gstack)
3. **Learning** — extract what worked, capture gotchas, improve future sessions (sheal)

One install gives you all three. Your AI assistant understands your project from the first message, has tools to do real work, and gets smarter over time.

## Why aiframework

- **Deterministic.** Same repo produces the same output every time. No hallucination, no drift.
- **Deep.** 13 scanners analyze identity, stack, commands, CI/CD, domains, environment, quality tools, archetype, and more. A tree-sitter code indexer extracts every function, class, type, and import across 20 languages.
- **Fast.** Full pipeline runs in ~0.3 seconds. Single Rust binary, 8.9 MB, zero runtime dependencies.
- **Universal.** Works with Claude Code, Cursor, GitHub Copilot, OpenAI Codex, and Google Gemini. One scan, every AI assistant benefits.
- **End-to-end.** Not just config generation — includes 37 workflow skills, session intelligence, persistent memory, and a knowledge graph that grows with your project.

---

## How it works

```
$ aiframework run --target ~/my-project

  ┌─────────────────────────────────────┐
  │  ▓▓▓ aiframework v2               │
  └─────────────────────────────────────┘

  DISCOVER  ████████████████████           ← 13 scanners analyze your repo
  │ typescript / nextjs / web-app          ← language, framework, archetype
  │ domains: Auth, Database, API           ← security-relevant domains detected
  │ tier: standard                         ← controls what gets generated

  INDEX  ████████████████████              ← tree-sitter parses your source code
  │ 209 files, 1,247 symbols, 186 edges   ← functions, classes, imports, PageRank
  │ languages: typescript, javascript      ← multi-language support

  GENERATE  ████████████████████           ← writes config files to your repo
  ✓ CLAUDE.md                              ← main config (Claude reads this)
  ✓ AGENTS.md                              ← works with Cursor, Copilot, Codex
  ✓ .cursorrules                           ← Cursor IDE rules
  ✓ .githooks/pre-commit                   ← lint on every commit
  ✓ .github/workflows/ci.yml              ← CI pipeline for your language

  VERIFY  ████████████████████             ← validates everything is consistent
  ✓ 12/12 checks passed

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Pipeline complete in 0.3s
    5 files generated  ·  1,247 symbols  ·  186 edges
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Four phases. Discover scans everything about your repo. Index parses your source code into a searchable symbol graph. Generate writes configuration files. Verify checks that everything is consistent and correct.

---

## Install

### macOS

```bash
brew tap evergonlabs/tap && brew install aiframework
```

### Linux / macOS / WSL (universal)

```bash
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
```

This detects your platform, downloads the binary, and installs companion tools automatically:
- **aiframework** — the core binary (zero runtime deps)
- **sheal** — session intelligence (if Node.js is available)
- **gstack** — 37 workflow skills for Claude Code (via git clone)

Skip companions with `SKIP_COMPANIONS=1`.

### From source

Requires [Rust 1.75+](https://rustup.rs):

```bash
git clone https://github.com/evergonlabs/aiframework
cd aiframework && make install
```

### Verify installation

```bash
aiframework --help
```

<details>
<summary>Installer options</summary>

```bash
# Preview without making changes
curl -fsSL .../install.sh | sh -s -- --dry-run

# Auto-install missing dependencies
curl -fsSL .../install.sh | sh -s -- --auto-deps

# Don't modify shell PATH
curl -fsSL .../install.sh | sh -s -- --no-modify-rc

# Uninstall
curl -fsSL .../install.sh | sh -s -- --uninstall
```

</details>

<details>
<summary>Supported platforms</summary>

| Platform | Binary target |
|:---------|:-------------|
| macOS Intel | `x86_64-apple-darwin` |
| macOS Apple Silicon | `aarch64-apple-darwin` |
| Linux x86_64 | `x86_64-unknown-linux-gnu` |
| Linux ARM64 | `aarch64-unknown-linux-gnu` |
| Alpine / musl | `x86_64-unknown-linux-musl` |
| Windows (Git Bash) | `x86_64-pc-windows-msvc` |

</details>

---

## Quick start

**1. Bootstrap your project:**

```bash
aiframework run --target ~/your-project
```

This takes about 0.3 seconds. It creates `CLAUDE.md` and supporting configs in your repo.

**2. Open Claude Code and enhance:**

```bash
cd ~/your-project && claude
```

Then type `/aif-ready`. This researches your specific stack online, enhances the generated configs with framework-specific knowledge, and optimizes your Claude Code settings. Run once per project.

**3. Code.**

Claude now knows your stack, commands, architecture, and conventions. Every session, from the first message.

---

## What gets generated

| File | What it does | Who reads it |
|:-----|:-------------|:-------------|
| `CLAUDE.md` | Stack, commands, architecture, invariants, key files | Claude Code |
| `AGENTS.md` | Same data in universal format | Cursor, Copilot, Codex, Gemini |
| `.cursorrules` | IDE-specific rules and conventions | Cursor |
| `.claude/rules/` | Auto-loaded instructions by path pattern | Claude Code |
| `.claude/skills/` | Slash commands: `/aif-review`, `/aif-ship` | Claude Code |
| `.githooks/` | Pre-commit (lint) + pre-push (test) | git |
| `.github/workflows/ci.yml` | CI pipeline matched to your language | GitHub Actions |
| `vault/wiki/` | Knowledge graph — one page per source file, linked by imports | Claude Code |
| `docs/reference/architecture.md` | Module map, top files, language breakdown | Developers |

### Tier system

Controls how much gets generated, based on project complexity:

| Tier | What's generated | When |
|:-----|:-----------------|:-----|
| **Lean** | CLAUDE.md + AGENTS.md | Simple projects, scripts |
| **Standard** | + hooks, CI, skills, rules, docs | Most projects (default) |
| **Full** | + vault, knowledge graph, session intelligence | Complex codebases |
| **Enterprise** | Same as Full + extended invariants | Large orgs |

Auto-detected from your project. Override with `--tier lean` or set in `.aiframework/config.json`.

---

## Architecture

### 13 scanners

Each scanner analyzes one dimension of your repo and contributes to the manifest:

| Scanner | What it detects |
|:--------|:----------------|
| **identity** | Name, version, description, Docker image |
| **stack** | Language, framework, monorepo, Node/Python version |
| **commands** | Package manager, lint, test, build, dev/prod ports |
| **structure** | Directories, file counts, entry points, test patterns |
| **archetype** | cli-tool, web-app, api-service, library, monorepo... |
| **ci** | GitHub Actions, deploy targets, coverage gaps |
| **domain** | Auth, database, API, AI/LLM, financial, file-upload |
| **env** | Environment variables from .env, Dockerfile, docker-compose |
| **quality** | Linters, formatters, type checkers, test frameworks, git hooks |
| **user_context** | Git user, maintenance status |
| **skill_suggest** | Pattern-based skill suggestions (deploy, migrate, e2e...) |
| **code_index** | Code index metadata |
| **sheal** | Session intelligence integration |

### Code indexer

The indexer reads your actual source code using [tree-sitter](https://tree-sitter.github.io/) (AST parsing) with regex fallback. It extracts:

- **Symbols**: every function, class, type, interface, method, constant
- **Imports**: file-to-file dependency edges
- **PageRank**: importance scoring — which files matter most
- **Metrics**: cyclomatic complexity, logical lines of code, code patterns (large files, deep nesting)

20 languages supported:

| Parser | Languages |
|:-------|:----------|
| **tree-sitter** (AST) | Python, TypeScript, JavaScript, Go, Rust, Ruby, Java, Bash |
| **regex** (pattern) | C#, PHP, Kotlin, Swift, Elixir |
| **extensible** | C, C++, Scala, Dart, Zig, Lua, R (via `rust/data/languages.json`) |

---

## Knowledge graph

Most AI coding assistants treat your codebase as flat text. aiframework builds a **knowledge graph** — a wiki of your entire codebase where every file is a page and every import is a bidirectional link.

```
vault/wiki/
├── index.md                              Master registry (all files)
├── concepts/
│   └── architecture.md                   Module graph, top files by PageRank
└── entities/
    ├── src-api-auth-controller-ts.md     Symbols, imports, imported-by, complexity
    ├── src-api-auth-service-ts.md        [[linked]] to controller via import edge
    ├── src-lib-database-ts.md            Referenced by 12 files (high PageRank)
    └── ...                               One page per source file (top 50)
```

**How it helps Claude:** Instead of reading every file to understand your codebase, Claude can traverse the wiki graph. If you ask about authentication, Claude reads `src-api-auth-controller-ts.md`, sees it imports `auth-service`, follows the link, and understands the full auth flow — without reading the raw source.

**What each entity page contains:**
- File path, language, line count
- Cyclomatic complexity score
- PageRank importance (how many files depend on it)
- All symbols (functions, classes, types) with signatures
- Imports (what this file depends on)
- Imported-by (what depends on this file)

The graph updates on every `git push` (via the pre-push hook) or `aiframework refresh`.

---

## Session memory

aiframework creates a persistent memory layer in `vault/memory/`:

```
vault/memory/
├── status.md          Current session state — what's in progress, what's blocked
├── decisions/         ADR-style decision logs
└── notes/             Session-extracted insights
```

**Why this matters:** Claude Code's context resets every session. Without external memory, you re-explain decisions, re-state constraints, re-describe the architecture every time. The vault gives Claude a place to read "what happened last session" and "what decisions were made."

The session protocol (`.claude/rules/session-protocol.md`) instructs Claude to read `vault/memory/status.md` at the start of every session, so it picks up where you left off.

---

## Ecosystem

aiframework handles **setup-time intelligence** — scanning, indexing, generating configs. Two optional companion tools extend it with **runtime intelligence** during your coding sessions:

### gstack — 37 workflow skills

[gstack](https://github.com/garrytan/gstack) adds day-to-day development skills to Claude Code: shipping, QA, security audits, design review, browser automation.

| Category | Skills |
|:---------|:-------|
| **Ship & Debug** | `/ship`, `/review`, `/investigate`, `/health`, `/retro` |
| **QA & Browser** | `/qa`, `/browse`, `/design-review`, `/benchmark`, `/cso` |
| **Plan & Design** | `/plan-ceo-review`, `/plan-eng-review`, `/autoplan`, `/design-shotgun` |
| **Utilities** | `/checkpoint`, `/guard`, `/freeze`, `/pair-agent`, `/codex` |

**Integration:** aiframework detects gstack installation (`~/.claude/skills/gstack/`) and reports it in the manifest. The two tools complement each other — aiframework gives Claude the context, gstack gives Claude the workflows.

```bash
# Install gstack (optional)
git clone https://github.com/garrytan/gstack ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup
```

### sheal — session intelligence

[sheal](https://www.npmjs.com/package/@liwala/sheal) watches your Claude Code sessions, extracts learnings, and bridges them back into your project as persistent knowledge.

| Command | When | What |
|:--------|:-----|:-----|
| `sheal check` | Session start | Health check (auto via hook) |
| `sheal retro` | Session end | Extract learnings from the session |
| `sheal drift` | Weekly | Detect learnings that aren't being applied |
| `sheal ask "question"` | Anytime | Search session history |

**Integration:** aiframework detects sheal automatically (the `sheal` scanner reports version, learning counts, and config status). On `--tier full`, it generates `.sheal/config.json` with your project's test/lint/build commands pre-filled. The installer offers to install sheal via npm.

```bash
# Install sheal (optional, requires Node.js)
npm install -g @liwala/sheal
```

### Agentic memory patterns

The vault system draws from the [agentic-memory-vault](https://github.com/galimba/agentic-memory-vault) pattern — a design for giving AI agents persistent memory across sessions. aiframework implements this pattern with:

- **Status tracking**: `vault/memory/status.md` — a living document Claude reads every session start
- **Decision logging**: `vault/memory/decisions/` — ADR-style records of why things were decided
- **Learning extraction**: sheal retros → JSONL → vault sync (when sheal is installed)
- **Knowledge graph**: wiki pages as navigable context (not just raw files)

The key insight: AI coding agents work better with **structured context** they can read at session start, not just raw source code. The vault provides that structure — and it persists across sessions, across team members, across tools.

All three companions are optional. aiframework works fully standalone.

---

## CLI reference

```
aiframework <command> [options]

Commands:
  run         Full pipeline: discover + index + generate + verify
  discover    Scan repo → manifest.json + code-index.json
  generate    Manifest → CLAUDE.md + all config files
  index       Build code index (standalone symbol extraction)
  verify      Validate generated files (consistency, security, freshness)
  refresh     Re-scan only if drift detected
  report      Human-readable discovery summary
  stats       Cross-repo knowledge statistics
  update      Self-update (detects git/homebrew/binary install method)
  mcp         MCP server for Claude Code integration

Options:
  --target <path>         Target repo (default: current directory)
  --tier <tier>           lean | standard | full | enterprise
  --dry-run               Preview without writing files
  --non-interactive       Skip confirmation prompts
  --no-index              Skip code indexing
  --verbose               Show detailed output
```

---

## Slash commands

After running `/aif-ready` in Claude Code, these commands are available:

| Command | When to use | What it does |
|:--------|:------------|:-------------|
| `/aif-ready` | Once per project | Researches your stack, enhances configs |
| `/aif-review` | Before committing | Reviews code against your project's invariants |
| `/aif-ship` | When ready to push | Lint + review + changelog + commit (never pushes without approval) |
| `/aif-learn` | When you discover something | Saves gotchas so Claude remembers next session |
| `/aif-analyze` | When exploring code | Finds missing tests, circular deps, dead code |
| `/aif-evolve` | Weekly | Promotes accumulated learnings into permanent rules |

---

## MCP server

aiframework includes a built-in [MCP](https://modelcontextprotocol.io/) server that exposes your repo context to any compatible client:

```bash
aiframework mcp --target .
```

| Type | Available |
|:-----|:----------|
| **Resources** | manifest, code-index, commands, invariants, architecture |
| **Tools** | `get_top_files`, `get_file_symbols`, `search_symbols`, `analyze_file`, `find_tests`, `check_invariants`, `refresh` |

---

## Extending language support

Language detection is data-driven via `rust/data/languages.json`. Here's how Elixir is defined — add any language the same way:

```json
{
  "elixir": {
    "display": "Elixir",
    "marker_files": ["mix.exs", "mix.lock"],
    "extensions": [".ex", ".exs"],
    "package_managers": {
      "mix": {
        "manifest": "mix.exs",
        "lock_file": "mix.lock",
        "commands": {
          "install": "mix deps.get",
          "build": "mix compile",
          "test": "mix test",
          "lint": "mix credo",
          "format": "mix format"
        }
      }
    },
    "frameworks": {
      "phoenix": {
        "display": "Phoenix",
        "marker_content": ":phoenix",
        "archetype": "web-app"
      },
      "nerves": {
        "display": "Nerves",
        "marker_content": ":nerves"
      }
    }
  }
}
```

When you add a language entry, aiframework will automatically:
- Detect the language by marker files and extensions
- Detect the framework by marker content in dependency files
- Use the correct package manager commands for lint, test, build
- Generate CI workflows with the right setup steps

---

## Telemetry

aiframework collects **anonymous, aggregate usage data** to improve the tool. This data directly shapes which languages get better detection, which frameworks get better templates, and which bugs get fixed first.

**What we collect:** event type (`run`, `discover`, `refresh`), aiframework version, operating system, detected language and framework, number of files/symbols, pipeline duration.

**What we never collect:** source code, file contents, file names, file paths, project names, git history, environment variables, personal information.

We follow the same principles as [Homebrew](https://docs.brew.sh/Analytics), [Next.js](https://nextjs.org/telemetry), and [VS Code](https://code.visualstudio.com/docs/getstarted/telemetry). Keeping telemetry enabled is the most impactful way to help improve aiframework for everyone.

To opt out:

```bash
mkdir -p ~/.aiframework && echo "telemetry: false" >> ~/.aiframework/config
```

---

## Building from source

```bash
git clone https://github.com/evergonlabs/aiframework
cd aiframework/rust
cargo build --release
./target/release/aiframework --help
```

Run tests:

```bash
cargo test        # 42 tests
cargo clippy      # lint
```

The release binary is ~8.9 MB (stripped, LTO, `opt-level=z`). It statically links 8 tree-sitter grammar libraries — no shared libraries or runtime downloads needed.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, code style, and PR guidelines.

---

<div align="center">

**[Evergon Labs](https://github.com/evergonlabs)** · [MIT License](LICENSE) · [Report an issue](https://github.com/evergonlabs/aiframework/issues)

[![GitHub stars](https://img.shields.io/github/stars/evergonlabs/aiframework?style=social)](https://github.com/evergonlabs/aiframework)

</div>
