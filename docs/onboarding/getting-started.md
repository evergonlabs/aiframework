# Getting Started with aiframework

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
```

No dependencies required. The installer downloads a pre-built binary for your platform.

To build from source: install [Rust 1.75+](https://rustup.rs), then `cd rust && cargo build --release`.

## Bootstrap your project

```bash
aiframework run --target ~/your-project
```

This scans your repo (13 scanners), indexes code (tree-sitter + regex, 13 languages), generates config files, and validates everything. Takes about 0.3 seconds.

## Open Claude Code

```bash
cd ~/your-project && claude
```

Type `/aif-ready` to enhance the generated configs with stack-specific knowledge. This is a one-time step.

## What was generated

After running `aiframework run`, your project has:

- `CLAUDE.md` — main config file Claude Code reads automatically
- `AGENTS.md` — works with Cursor, Copilot, Codex, Gemini
- `.claude/rules/` — auto-loaded rules by path pattern
- `.claude/skills/` — slash commands like `/aif-review`, `/aif-ship`
- `.githooks/` — pre-commit (lint) + pre-push (test)
- `.github/workflows/ci.yml` — CI pipeline for your language

## Daily workflow

| Command | When |
|:--------|:-----|
| `aiframework refresh` | After major code changes — re-scans if drift detected |
| `aiframework verify` | Before shipping — validates all generated files |
| `aiframework update` | Periodically — updates aiframework itself |
| `/aif-review` | In Claude Code — pre-commit code review |
| `/aif-ship` | In Claude Code — lint + review + commit |

## CLI overview

```bash
aiframework run          # Full pipeline
aiframework discover     # Scan only
aiframework index        # Code index only
aiframework verify       # Validate outputs
aiframework refresh      # Re-scan if changed
aiframework report       # Show discovery summary
aiframework stats        # Cross-repo statistics
aiframework update       # Self-update
aiframework mcp          # Start MCP server
```

Use `aiframework --help` for full options.
