---
title: "lib / generators / wiki_graph.py"
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

# wiki_graph.py

> `lib/generators/wiki_graph.py` — python, 904 lines

| Property | Value |
|----------|-------|
| Path | `lib/generators/wiki_graph.py` |
| Language | python |
| Lines | 904 |
| Size | 30063 bytes |
| Symbols | 14 |
| PageRank | — |

## Symbols (14)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `file_to_slug` | function | 29 | public | Convert a file path to a wiki-safe slug. |
| `module_to_slug` | function | 47 | public | Convert a module directory path to a wiki-safe slug. |
| `_build_lookups` | function | 67 | private | Build all lookup tables from the code index. |
| `_render_file_page` | function | 143 | private | Render a wiki entity page for a single source file. |
| `_render_module_page` | function | 284 | private | Render a wiki summary page for a module (directory). |
| `_render_architecture_page` | function | 416 | private | Render the architecture concept page with module graph and f... |
| `_render_index` | function | 505 | private | Render index.md from all generated pages. |
| `_page_rel_path` | function | 591 | private | Determine the relative path within vault for a given slug. |
| `_content_hash` | function | 604 | private | — |
| `_load_hashes` | function | 608 | private | — |
| `_save_hashes` | function | 619 | private | — |
| `generate_wiki_graph` | function | 630 | public | Generate the full wiki graph from a code index. |
| `verify_wiki_graph` | function | 757 | public | Verify that the wiki graph is complete and correct. |
| `main` | function | 856 | public | — |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[lib-generators|lib/generators]]

## Related

- [[architecture]]
