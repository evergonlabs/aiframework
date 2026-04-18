---
title: "lib / indexers / parse.py"
type: entity
created: "2026-04-18"
updated: "2026-04-18"
status: current
tags:
  - type/entity
  - scope/file
  - domain/python
  - source-type/code-index
confidence: medium
---

# parse.py

> `lib/indexers/parse.py` — python, 744 lines

| Property | Value |
|----------|-------|
| Path | `lib/indexers/parse.py` |
| Language | python |
| Lines | 744 |
| Size | 23000 bytes |
| Symbols | 10 |
| PageRank | — |

## Symbols (10)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `_lang_java` | function | 70 | private | — |
| `_lang_csharp` | function | 150 | private | — |
| `_lang_php` | function | 220 | private | — |
| `_lang_kotlin` | function | 282 | private | — |
| `_lang_swift` | function | 347 | private | — |
| `_lang_elixir` | function | 402 | private | — |
| `_parse_file` | function | 474 | private | Parse a single file and return its file-entry dict plus symb... |
| `_detect_shebang_language` | function | 577 | private | Read the first line of a file and detect language from sheba... |
| `index_repo` | function | 612 | public | Index a repository and optionally write the result to a JSON... |
| `main` | function | 713 | public | — |

## Imports (3)

- [[lib-indexers-init-py|__init__.py]] (`lib/indexers/__init__.py`) — ``
- [[lib-indexers-graph-py|graph.py]] (`lib/indexers/graph.py`) — `graph`
- [[lib-indexers-registry-py|registry.py]] (`lib/indexers/registry.py`) — `registry`

## Imported By

*No internal dependents detected.*

## Module

- [[lib-indexers|lib/indexers]]

## Related

- [[architecture]]
