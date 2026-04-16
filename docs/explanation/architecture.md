# Architecture

A conceptual explanation of how aiframework works and why it is designed this way.

## The 3-Stage Pipeline

aiframework processes any repository through three sequential stages:

```
discover → generate → verify
```

### Stage 1: Discover

Twelve bash scanners read the target repository and produce `manifest.json` -- a structured JSON document containing every fact about the project. A Python-based code indexer runs in parallel to produce `code-index.json` with file listings, symbol tables, import edges, and module groupings.

**Key constraint:** Discovery is deterministic. Given the same repo state, it produces the same manifest. No network calls, no randomness, no AI. Every value in the manifest is traced to a specific file in the repo.

### Stage 2: Generate

Seven generators read the manifest and code index, then write 19+ files plus 22+ vault files. Generators are pure functions of the manifest -- they do not re-scan the repo or make network calls.

### Stage 3: Verify

Five validators run 46+ checks against the generated files to ensure consistency: files exist, commands match across CLAUDE.md / hooks / CI, no secrets are hardcoded, and quality gates pass. Verification catches drift between the manifest and generated output.

## Why Manifest-Driven?

The central design decision in aiframework is the manifest: a single JSON file that sits between scanning and generation.

**Without a manifest**, scanners and generators would be coupled. Every change to detection logic would require updating generators. Every new output format would require re-scanning.

**With a manifest:**

- **Determinism.** The manifest is a snapshot of repo facts. You can inspect it, diff it across runs, and verify that nothing was invented.
- **Reproducibility.** Given the same manifest, generation always produces the same files. This makes debugging straightforward -- if the output is wrong, either the manifest is wrong (scanner bug) or the generator misreads it (generator bug).
- **Extensibility.** New scanners add keys to the manifest. New generators read keys from it. Neither needs to know about the other.
- **Auditability.** The manifest is a plain JSON file you can read. Every value has a traceable origin in the target repo's files.

## Why a Knowledge Vault?

AI coding agents start every session from scratch. They read the codebase, build a mental model, and lose it when the session ends. The vault solves this by providing persistent, structured memory.

The vault implements a three-layer architecture:

| Layer | Path | Purpose | Lifetime |
|-------|------|---------|----------|
| Raw | `vault/raw/` | Immutable source documents (human-owned) | Permanent |
| Wiki | `vault/wiki/` | Processed knowledge (concepts, entities, comparisons) | Long-lived |
| Memory | `vault/memory/` | Operational state (decisions, notes, status) | Variable |

**Data flows strictly downward:** raw materials are processed into wiki pages, which inform operational memory. This prevents circular dependencies and ensures the wiki is always grounded in source material.

The vault is not a database. It is a set of markdown files with YAML frontmatter, linked via `[[wikilinks]]`, stored in git. This means:

- It is versioned alongside the code.
- It is readable by humans and AI agents alike.
- It requires no external services.
- It survives across sessions, machines, and team members.

## Why a Code Indexer?

Scanners use heuristics: they look for known file patterns, parse config files, and check directory names. This works well for project-level metadata (language, framework, CI provider) but misses the internal structure of the code itself.

The code indexer fills this gap by parsing actual source files to extract:

- **Symbols** -- every function, class, type, and method with its signature, location, and visibility.
- **Edges** -- import relationships between files, showing which modules depend on which.
- **Modules** -- directory-level groupings with fan-in/fan-out metrics and circular dependency detection.

This structured view feeds into CLAUDE.md (module maps, architecture hot spots), vault wiki pages (module entities, architecture concepts), and the enhance stage (identifying missing tests, god modules, orphan files).

The indexer supports seven languages with full symbol extraction (Bash, Python, TypeScript, JavaScript, Go, Rust, Ruby); the language registry (`lib/data/languages.json`) supports 20 languages for detection via marker files. It runs deterministically in under 50ms for medium-sized repos.

## The Enhance Layer

Enhancement exists because some things cannot be detected by reading files alone:

- A project uses Supabase, but the only evidence is an environment variable name.
- A Next.js project uses the App Router, which requires different invariants than the Pages Router.
- A monorepo has 200 files but the scanner only found 3 components, suggesting detection gaps.

Enhancement is handled by the `/aif-enhance` skill, which runs directly inside Claude Code using its native tools (WebSearch, Read, Grep, Write). This means:

- **No API key needed** -- Claude Code provides the LLM context natively.
- **No Python dependency** -- the old Agent SDK (`claude-agent-sdk`) has been removed.
- **No external process** -- enhancement runs in the same Claude Code session as the rest of your workflow.

The skill researches gaps in the manifest, identifies framework conventions, and enriches the vault with concept pages -- all using Claude Code's built-in capabilities.

## Security Model

aiframework generates files that run in developer environments (git hooks, CI workflows) and AI agent contexts (CLAUDE.md, skills). Security is addressed at multiple levels:

### Scan-Time Security

- Scanners never execute code from the target repo. They read files only.
- The code indexer parses source files with regex, not by importing/executing them.
- No network calls during discovery.

### Generate-Time Security

- Generated hooks use `set -euo pipefail` and validate inputs.
- CI workflows pin action versions and use minimal permissions.
- CLAUDE.md includes invariants that enforce security patterns (auth middleware, input validation, ORM-only database access).

### Vault Security

- **Three-tier permissions:** Always allowed (lint, log, cite), ask first (promote, bulk changes), never allowed (modify raw/, delete files).
- **Content integrity:** 8 injection detection patterns (prompt injection, command injection, data exfiltration).
- **Skill hardening:** SHA-256 manifest verification, three security tiers (strict/moderate/permissive).
- **No-deletion architecture:** Files are archived (`status: archived`), never deleted.
- **Append-only logs:** The operations log cannot be rewritten.

### Enhance-Time Security

Enhancement runs as a Claude Code skill (`/aif-enhance`), which inherits Claude Code's built-in permission model. The skill writes only to `vault/` and the manifest -- no arbitrary file system access.
