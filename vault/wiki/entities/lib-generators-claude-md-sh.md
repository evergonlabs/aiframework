---
title: "lib / generators / claude_md.sh"
type: entity
created: "2026-04-19"
updated: "2026-04-19"
status: current
tags:
  - type/entity
  - scope/file
  - domain/bash
  - source-type/code-index
confidence: medium
---

# claude_md.sh

> `lib/generators/claude_md.sh` — bash, 1462 lines

| Property | Value |
|----------|-------|
| Path | `lib/generators/claude_md.sh` |
| Language | bash |
| Lines | 1462 |
| Size | 60449 bytes |
| Symbols | 6 |
| PageRank | — |

## Symbols (6)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `_extract_claude_md_vars` | function | 12 | private | --- Shared variable extraction (called by both lean and full... |
| `_generate_workflow_rules` | function | 47 | private | --- Generate .claude/rules/workflow.md --- |
| `generate_claude_md_lean` | function | 228 | public | --- Lean CLAUDE.md generator (80-150 lines, high-signal only... |
| `_generate_extended_rules` | function | 705 | private | --- Extended rules generator (complex/enterprise projects) -... |
| `_generate_reference_docs` | function | 1254 | private | --- Reference architecture doc (complex/enterprise projects)... |
| `generate_claude_md` | function | 1450 | public | --- Dispatcher: picks lean vs full based on project complexi... |

## Imports

*No internal imports detected.*

## Imported By (1)

- [[bin-aiframework|aiframework]] (`bin/aiframework`)

## Module

- [[lib-generators|lib/generators]]

## Related

- [[architecture]]
