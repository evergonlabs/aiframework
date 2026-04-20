# Architecture

A conceptual explanation of how aiframework works and why it is designed this way.

## The 4-Stage Pipeline

```
discover → index → generate → verify
```

### Stage 1: Discover

Thirteen Rust scanners read the target repository and produce `manifest.json` — a structured JSON document containing every fact about the project: identity, stack, commands, structure, CI, domains, environment, quality tools, archetype, and more.

**Key constraint:** Discovery is deterministic. Given the same repo state, it produces the same manifest. No network calls, no randomness, no AI.

### Stage 2: Index

A tree-sitter-based code indexer (with regex fallback) parses every source file across 20 languages. It extracts symbols (functions, classes, types), import edges, and computes PageRank importance scores. Output: `code-index.json`.

### Stage 3: Generate

Fourteen generators read the manifest and code index to produce configuration files: CLAUDE.md, AGENTS.md, .cursorrules, git hooks, CI workflows, skills, rules, vault wiki pages, and more. Generation is gated by tier (lean/standard/full/enterprise).

### Stage 4: Verify

Five validators check that generated files are consistent, complete, and secure: file existence, command consistency across CLAUDE.md/hooks/manifest, secret scanning, quality gate, and freshness.

## Design Principles

- **Data-driven**: Language detection, domain detection, and framework detection are all driven by JSON registries, not hardcoded logic
- **Deterministic**: Same input always produces same output
- **Incremental**: `refresh` only re-runs if source files changed
- **Non-destructive**: Generators never overwrite user-created files
- **Tier-gated**: Simple projects get minimal output, complex projects get full vault/wiki
