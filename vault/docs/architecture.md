---
title: "Vault Architecture"
type: architecture
created: "2026-04-15"
updated: "2026-04-15"
status: current
tags:
  - type/architecture
  - audience/developer
  - audience/agent
owner: system
confidence: high
---

# Vault Architecture — Three-Layer Model

## Overview

The vault implements a three-layer knowledge architecture designed for
agentic workflows. Each layer has distinct integrity guarantees and
access patterns.

```
┌─────────────────────────────────────────────────┐
│                   CONSUMERS                      │
│         (agents, humans, CI pipelines)           │
├──────────┬──────────────────┬───────────────────┤
│  memory/ │      wiki/       │    raw/           │
│ Layer 3  │    Layer 2       │   Layer 1         │
│ Decisions│ Processed Know.  │ Immutable Sources │
│ & Ops    │ & Synthesis      │ & Documents       │
├──────────┴──────────────────┴───────────────────┤
│              .vault/ (infrastructure)            │
│     rules, schemas, scripts, hooks               │
└─────────────────────────────────────────────────┘
```

## Layer 1: raw/ — Immutable Sources

**Purpose**: Audit trail of all ingested source material.

- Files deposited here are **never modified** (HR-001).
- Supports any file type: PDFs, screenshots, text dumps, API responses.
- Each file gets a corresponding summary in `wiki/sources/`.
- Provenance chain: raw file -> source summary -> concept/entity pages.

**Why immutability?** If summaries drift from sources, you can always
re-derive. The raw layer is your ground truth.

## Layer 2: wiki/ — Processed Knowledge

**Purpose**: Synthesized, interlinked knowledge base.

- **sources/**: One summary per ingested document (links back to raw/).
- **concepts/**: Topic pages synthesizing multiple sources.
- **entities/**: Pages about specific things (APIs, services, people, tools).
- **comparisons/**: Structured comparisons between alternatives.
- **index.md**: Master catalog — every page must appear here (HR-008).
- **log.md**: Append-only operations log (HR-015).

**Access pattern**: Agents read `index.md` first, then navigate to
specific pages via wikilinks (`[[slug]]`). This index-first approach
is more reliable than directory traversal at scale.

## Layer 3: memory/ — Decisions and Operations

**Purpose**: Operational memory and decision records.

- **decisions/**: ADR-format records of architectural and process decisions.
- **notes/**: Short-lived operational notes (7-day staleness by default).
- **status.md**: Living dashboard of current focus and recent actions.

**Why separate from wiki?** Wiki content is knowledge (relatively stable).
Memory content is operational (frequently changing). Different staleness
thresholds and review cadences apply.

## Infrastructure: .vault/

**Purpose**: Rules, tooling, and schemas that govern the vault.

- **rules/**: Hard rules (immutable constraints), soft rules (guidelines),
  and the approved tag taxonomy.
- **schemas/**: JSON Schema definitions for frontmatter validation,
  security policy, and content integrity.
- **scripts/**: Vault tooling (`vault-tools.sh`, `lib-utils.sh`, `lib-lint.sh`).
- **hooks/**: Git hooks for pre-commit enforcement.

**Protection**: .vault/ is protected by HR-011. Agents cannot modify
infrastructure files — changes require human review.

## Why Index-Based Retrieval?

Traditional file-system browsing scales poorly:
- Agents waste tokens listing directories and reading irrelevant files.
- No way to assess relevance without opening each file.

Index-based approach:
1. Read `wiki/index.md` — see all pages with types, dates, and tags.
2. Select relevant slugs based on the task.
3. Read only the pages needed.
4. Follow `[[wikilinks]]` to discover related content.

This reduces token usage by 60-80% compared to directory traversal
on vaults with 50+ pages.

## Scale Considerations

| Vault Size | Pages | Recommended Actions |
|-----------|-------|-------------------|
| Small     | < 50  | Manual management sufficient |
| Medium    | 50-200 | Run `vault-tools.sh doctor` weekly |
| Large     | 200-500 | Consider splitting into domain sub-vaults |
| Very Large| 500+  | Implement search indexing, consider database backing |

**Splitting strategy**: When a single domain exceeds 100 pages, extract
it into a dedicated sub-vault with its own index. The parent vault keeps
a pointer page.
