---
title: "Architecture — Module Graph"
type: concept
created: "2026-04-18"
updated: "2026-04-18"
status: current
tags:
  - type/concept
  - type/architecture
  - domain/bash
  - source-type/code-index
confidence: medium
---

# Architecture — Module Graph

> Auto-generated from code index. 70 files, 335 symbols, 61 edges.

## Modules

| Module | Role | Files | Fan-in | Fan-out |
|--------|------|-------|--------|---------|
| [[root-module|.]] | general | 4 | 0 | 0 |
| [[githooks|.githooks]] | general | 2 | 0 | 0 |
| [[bin|bin]] | entrypoint | 3 | 0 | 37 |
| [[lib|lib]] | library | 1 | 0 | 0 |
| [[lib-freshness|lib/freshness]] | general | 1 | 1 | 0 |
| [[lib-generators|lib/generators]] | generation | 12 | 22 | 0 |
| [[lib-indexers|lib/indexers]] | general | 10 | 0 | 0 |
| [[lib-indexers-contrib|lib/indexers/contrib]] | general | 1 | 0 | 0 |
| [[lib-indexers-parsers|lib/indexers/parsers]] | general | 7 | 0 | 0 |
| [[lib-knowledge|lib/knowledge]] | general | 1 | 1 | 0 |
| [[lib-mcp|lib/mcp]] | general | 2 | 0 | 0 |
| [[lib-scanners|lib/scanners]] | discovery | 12 | 16 | 0 |
| [[lib-validators|lib/validators]] | verification | 5 | 18 | 0 |
| [[tests|tests]] | testing | 4 | 0 | 21 |
| [[vault-vault-hooks|vault/.vault/hooks]] | general | 1 | 0 | 0 |
| [[vault-vault-scripts|vault/.vault/scripts]] | tooling | 4 | 0 | 0 |

## Most Important Files (by PageRank)

| File | Path | Score |
|------|------|-------|
| [[lib-indexers-init-py|__init__.py]] | `lib/indexers/__init__.py` | 0.0027 |
| [[lib-indexers-graph-py|graph.py]] | `lib/indexers/graph.py` | 0.0027 |
| [[lib-indexers-registry-py|registry.py]] | `lib/indexers/registry.py` | 0.0027 |
| [[lib-validators-files-sh|files.sh]] | `lib/validators/files.sh` | 0.0024 |
| [[lib-validators-quality-gate-sh|quality_gate.sh]] | `lib/validators/quality_gate.sh` | 0.0024 |
| [[lib-scanners-skill-suggest-sh|skill_suggest.sh]] | `lib/scanners/skill_suggest.sh` | 0.0024 |
| [[lib-validators-security-sh|security.sh]] | `lib/validators/security.sh` | 0.0024 |
| [[lib-generators-preserve-sh|preserve.sh]] | `lib/generators/preserve.sh` | 0.0024 |
| [[lib-generators-skills-sh|skills.sh]] | `lib/generators/skills.sh` | 0.0024 |
| [[lib-validators-freshness-sh|freshness.sh]] | `lib/validators/freshness.sh` | 0.0024 |
| [[lib-validators-consistency-sh|consistency.sh]] | `lib/validators/consistency.sh` | 0.0024 |
| [[lib-generators-vault-sh|vault.sh]] | `lib/generators/vault.sh` | 0.0022 |
| [[lib-scanners-user-context-sh|user_context.sh]] | `lib/scanners/user_context.sh` | 0.0022 |
| [[lib-scanners-code-index-sh|code_index.sh]] | `lib/scanners/code_index.sh` | 0.0022 |
| [[lib-generators-vault-ingest-sh|vault_ingest.sh]] | `lib/generators/vault_ingest.sh` | 0.0022 |

## Entry Points (fan-in = 0)

- [[bin|bin]]
- [[tests|tests]]

## Related

- [[tech-stack]]
- [[project-overview]]
