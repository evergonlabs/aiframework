# AGENTS.md — aiframework

> Make Claude Code understand your project instantly. Single Rust binary, zero deps.

**Stack:** Rust
**Build:** `cd rust && cargo build --release`
**Test:** `cd rust && cargo test`
**Lint:** `cd rust && cargo clippy`

## Commands

```bash
aiframework run --target .        # Full pipeline
aiframework index --target .      # Code index only
aiframework verify --target .     # Validate outputs
aiframework refresh               # Re-scan if changed
```

## Key Files

- `rust/src/cli.rs` — CLI (clap)
- `rust/src/scanner/` — 13 scanners
- `rust/src/indexer/` — code indexer + 13 parsers (8 tree-sitter)
- `rust/src/generator/` — 14 generators
- `rust/src/validator/` — 5 validators
- `rust/src/mcp/` — MCP JSON-RPC server
- `rust/data/languages.json` — language registry

## Conventions

- All output is JSON (`serde_json`)
- Tree-sitter AST parsing with regex fallback
- Generators never overwrite user content
- Tier system: lean < standard < full < enterprise
