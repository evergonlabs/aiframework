# Architecture — aiframework

Single Rust binary. ~13,000 LOC, 8.9 MB, zero runtime dependencies.

## Module Map

```
rust/src/
├── cli.rs              10 CLI commands (clap)
├── config.rs           Tier system + config loading
├── telemetry.rs        PostHog analytics
├── ui.rs               Terminal output (colors, tables)
├── scanner/            13 repo scanners → manifest.json
├── indexer/            Code indexer + 13 language parsers → code-index.json
├── generator/          14 file generators (tier-gated)
├── validator/          5 validation checks
└── mcp/                MCP JSON-RPC server (7 tools)
```

## Data Flow

```
scanner::discover()   → manifest.json
indexer::index_repo() → code-index.json
generator::generate() → CLAUDE.md + 13 other files
validator::verify()   → PASS/FAIL table
```

## Key Dependencies

| Crate | Purpose |
|:------|:--------|
| `clap` | CLI (derive macros) |
| `serde` + `serde_json` | JSON |
| `tree-sitter` + 8 grammars | AST parsing |
| `regex` | Fallback parsers |
| `rayon` | Parallel parsing |
| `ignore` | .gitignore-aware walking |
