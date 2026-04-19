---
title: "lib / bridge / sheal_learnings.sh"
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

# sheal_learnings.sh

> `lib/bridge/sheal_learnings.sh` — bash, 287 lines

| Property | Value |
|----------|-------|
| Path | `lib/bridge/sheal_learnings.sh` |
| Language | bash |
| Lines | 287 |
| Size | 10214 bytes |
| Symbols | 4 |
| PageRank | 0.0016 |

## Symbols (4)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `bridge_jsonl_to_sheal` | function | 10 | public | Convert aiframework JSONL learnings → sheal markdown learnin... |
| `bridge_sheal_to_jsonl` | function | 114 | public | Convert sheal markdown learnings → aiframework JSONL
Usage: ... |
| `bridge_sync` | function | 214 | public | Bidirectional dedup sync
Usage: bridge_sync [target_dir] |
| `bridge_retros_to_vault` | function | 225 | public | Convert sheal retro files to vault entries
Usage: bridge_ret... |

## Imports

*No internal imports detected.*

## Imported By (1)

- [[tests-test-sheal-sh|test_sheal.sh]] (`tests/test_sheal.sh`)

## Module

- [[lib-bridge|lib/bridge]]

## Related

- [[architecture]]
