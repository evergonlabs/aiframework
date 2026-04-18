---
title: "lib / indexers / graph.py"
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

# graph.py

> `lib/indexers/graph.py` — python, 228 lines

| Property | Value |
|----------|-------|
| Path | `lib/indexers/graph.py` |
| Language | python |
| Lines | 228 |
| Size | 8008 bytes |
| Symbols | 4 |
| PageRank | 0.0024 |

## Symbols (4)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `_resolve_import_to_file` | function | 47 | private | Best-effort resolve an import string to a known relative fil... |
| `_role_for_directory` | function | 96 | private | Assign a heuristic role based on the directory name. |
| `build_graph` | function | 102 | public | Build dependency edges and module groupings from parsed file... |
| `compute_pagerank` | function | 189 | public | Compute PageRank scores for files based on import edges. |

## Imports

*No internal imports detected.*

## Imported By (1)

- [[lib-indexers-parse-py|parse.py]] (`lib/indexers/parse.py`)

## Module

- [[lib-indexers|lib/indexers]]

## Related

- [[architecture]]
