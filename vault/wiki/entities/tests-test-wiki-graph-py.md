---
title: "tests / test_wiki_graph.py"
type: entity
created: "2026-04-19"
updated: "2026-04-19"
status: current
tags:
  - type/entity
  - scope/file
  - domain/python
  - source-type/code-index
confidence: medium
---

# test_wiki_graph.py

> `tests/test_wiki_graph.py` — python, 236 lines

| Property | Value |
|----------|-------|
| Path | `tests/test_wiki_graph.py` |
| Language | python |
| Lines | 236 |
| Size | 9249 bytes |
| Symbols | 6 |
| PageRank | — |

## Symbols (6)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `test_file_to_slug` | function | 19 | public | — |
| `test_module_to_slug` | function | 28 | public | — |
| `_make_fixture` | function | 35 | private | Create a minimal code-index.json for testing. |
| `test_generate_and_verify` | function | 107 | public | Full integration test: generate pages, verify completeness. |
| `test_incremental_update` | function | 164 | public | Second run should produce no writes when nothing changed. |
| `test_stale_page_archival` | function | 189 | public | Removed files should get archived, not deleted (HR-014). |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[tests|tests]]

## Related

- [[architecture]]
