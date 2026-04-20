<div align="center">

# aiframework

Make [Claude Code](https://docs.anthropic.com/en/docs/claude-code) understand your project instantly.

[![version](https://img.shields.io/badge/v2.0.0-blue?style=flat-square&label=version)](https://github.com/evergonlabs/aiframework/releases)
[![license](https://img.shields.io/badge/MIT-green?style=flat-square&label=license)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/evergonlabs/aiframework/ci.yml?style=flat-square&label=CI)](https://github.com/evergonlabs/aiframework/actions)
[![Rust](https://img.shields.io/badge/rust-8.9MB_binary-orange?style=flat-square)](rust/)
[![Claude Code](https://img.shields.io/badge/compatible-cc785c?style=flat-square&logo=anthropic&logoColor=white&label=claude%20code)](https://docs.anthropic.com/en/docs/claude-code)

</div>

---

## What it does

aiframework scans your repo — language, framework, dependencies, file structure, domains — and generates a `CLAUDE.md` plus supporting configs that Claude Code reads automatically.

**Before:** Claude asks "what framework is this?" and guesses wrong commands.
**After:** Claude knows your lint/test/build commands, architecture, security rules, and can navigate your codebase through a knowledge graph of every file.

```
$ aiframework run --target .

  ┌─────────────────────────────────────┐
  │  ▓▓▓ aiframework v2               │
  └─────────────────────────────────────┘

  DISCOVER  ████████████████████
  │ typescript / nextjs / web-app
  │ domains: Auth, Database, API

  INDEX  ████████████████████
  │ 209 files, 1,247 symbols, 186 edges

  GENERATE  ████████████████████
  ✓ CLAUDE.md
  ✓ AGENTS.md
  ✓ .cursorrules
  ✓ .githooks/pre-commit
  ✓ .github/workflows/ci.yml

  VERIFY  ████████████████████
  ✓ 12/12 checks passed

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✓ Pipeline complete in 0.3s
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Single binary. Zero runtime dependencies. 8.9 MB.

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
```

Downloads a pre-built binary for your platform. If no binary is available, falls back to `git clone + cargo build`.

```bash
# Preview what will be installed
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh -s -- --dry-run
```

<details>
<summary>Other install methods</summary>

| Method | Command |
|:-------|:--------|
| **Homebrew** | `brew tap evergonlabs/tap && brew install aiframework` |
| **Cargo** | `cd rust && cargo install --path .` |
| **Manual** | `git clone https://github.com/evergonlabs/aiframework && cd aiframework && make install` |

</details>

### Requirements

**None.** The binary is self-contained. No Python, no Node, no jq.

To build from source: [Rust 1.75+](https://rustup.rs).

### Platforms

| Platform | Binary |
|:---------|:-------|
| macOS (Intel) | `x86_64-apple-darwin` |
| macOS (ARM) | `aarch64-apple-darwin` |
| Linux (x86) | `x86_64-unknown-linux-gnu` |
| Linux (ARM) | `aarch64-unknown-linux-gnu` |
| Linux (musl) | `x86_64-unknown-linux-musl` |
| Windows | `x86_64-pc-windows-msvc` |

---

## Quick start

```bash
# 1. Scan your project (takes ~0.3 seconds)
aiframework run --target ~/your-project

# 2. Open Claude Code
cd ~/your-project && claude

# 3. Run the setup skill (once per project)
/aif-ready
```

That's it. Claude now knows your stack.

---

## What gets generated

| File | Purpose |
|:-----|:--------|
| `CLAUDE.md` | Main config — stack, commands, rules, architecture |
| `AGENTS.md` | Works with Cursor, Copilot, Codex, Gemini |
| `.cursorrules` | Cursor IDE rules |
| `.claude/rules/` | Auto-loaded instructions by path pattern |
| `.claude/skills/` | Slash commands (`/aif-review`, `/aif-ship`) |
| `.githooks/` | Pre-commit lint + pre-push tests |
| `.github/workflows/ci.yml` | CI pipeline for your language |
| `vault/wiki/` | Knowledge graph — one page per file |
| `docs/` | Architecture documentation |

**Tier system** controls what's generated:
- **Lean**: CLAUDE.md + AGENTS.md (simple projects)
- **Standard**: + hooks, CI, skills, rules, docs (default)
- **Full**: + vault, knowledge graph, session intelligence

Override with `--tier lean|standard|full|enterprise`.

---

## Architecture

```
aiframework run --target /path/to/repo
│
│  DISCOVER (13 scanners)
│  ├── identity       name, version, description
│  ├── stack          language, framework, monorepo
│  ├── commands       lint, test, build, package manager
│  ├── structure      dirs, files, entry points
│  ├── ci             GitHub Actions, deploy targets
│  ├── env            variables from .env, Dockerfile
│  ├── domain         auth, db, api, ai, frontend...
│  ├── quality        linters, formatters, test frameworks
│  ├── archetype      cli-tool, web-app, api-service, library
│  └── ...            user_context, skills, sheal, code_index
│
│  INDEX (tree-sitter + regex, 13 languages)
│  ├── symbols        functions, classes, types, methods
│  ├── imports        file-to-file dependency edges
│  ├── PageRank       importance scoring
│  └── metrics        complexity, logical LOC, patterns
│
│  GENERATE (tier-gated, 14 generators)
│  └── CLAUDE.md, rules, skills, hooks, CI, vault...
│
│  VERIFY (5 validators)
│  ├── files          expected outputs exist
│  ├── consistency    commands match across files
│  ├── security       no secrets, .gitignore coverage
│  ├── quality_gate   lint/test commands configured
│  └── freshness      manifest up to date
```

### Language support

20 languages. 8 use tree-sitter (AST parsing), 5 use regex:

| Language | Parser | Frameworks |
|:---------|:-------|:-----------|
| Python | tree-sitter | FastAPI, Django, Flask |
| TypeScript / JavaScript | tree-sitter | Next.js, React, Vue, Express, NestJS |
| Go | tree-sitter | Gin, Echo, Chi, Fiber |
| Rust | tree-sitter | Actix, Axum, Rocket |
| Ruby | tree-sitter | Rails, Sinatra |
| Java | tree-sitter | Spring Boot, Quarkus |
| Bash | tree-sitter | — |
| C# | regex | ASP.NET, Blazor |
| PHP | regex | Laravel, Symfony |
| Kotlin, Swift, Elixir | regex | Major frameworks |
| + 7 more | extensible | via `rust/data/languages.json` |

---

## CLI reference

```
aiframework <command> [options]

Commands:
  run         Full pipeline: discover + index + generate + verify
  discover    Scan repo → manifest.json + code-index.json
  generate    Manifest → all config files
  verify      Validate generated files
  index       Build code index (standalone)
  refresh     Re-scan only if drift detected
  report      Human-readable discovery summary
  stats       Cross-repo knowledge statistics
  update      Self-update (git/homebrew/binary)
  mcp         MCP server for Claude Code integration

Options:
  --target <path>         Target repo (default: cwd)
  --tier <tier>           lean | standard | full | enterprise
  --dry-run               Preview without writing
  --non-interactive       Skip prompts
  --no-index              Skip code indexing
  --verbose               Detailed output
```

---

## Slash commands

Available in Claude Code after `/aif-ready`:

| Command | What it does |
|:--------|:-------------|
| `/aif-ready` | One-time setup — researches stack, enhances configs |
| `/aif-review` | Pre-commit review against project rules |
| `/aif-ship` | Lint + review + changelog + commit |
| `/aif-learn` | Save a gotcha for Claude to remember |
| `/aif-analyze` | Find missing tests, circular deps |
| `/aif-evolve` | Promote learnings into permanent rules |

---

## MCP server

Expose repo context to any MCP-compatible client:

```bash
aiframework mcp --target .
```

**Resources**: manifest, code-index, commands, invariants, architecture
**Tools**: `get_top_files`, `get_file_symbols`, `search_symbols`, `analyze_file`, `find_tests`, `check_invariants`, `refresh`

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
cargo test
```

Binary size: ~8.9 MB (stripped, LTO).

---

## Extending

Language detection is data-driven. Add a language by editing `rust/data/languages.json`:

```json
{
  "languages": {
    "your-language": {
      "marker_files": ["your-language.config"],
      "extensions": [".yl"],
      "frameworks": {
        "your-framework": {
          "marker_content": "your-framework"
        }
      }
    }
  }
}
```

---

## Telemetry

Anonymous usage data (event type, version, OS, language detected). Never collects source code, file paths, or personal information.

Opt out:

```bash
mkdir -p ~/.aiframework && echo "telemetry: false" >> ~/.aiframework/config
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

<div align="center">

**[Evergon Labs](https://github.com/evergonlabs)** · [MIT License](LICENSE) · [Report an issue](https://github.com/evergonlabs/aiframework/issues)

[![GitHub stars](https://img.shields.io/github/stars/evergonlabs/aiframework?style=social)](https://github.com/evergonlabs/aiframework)

</div>
