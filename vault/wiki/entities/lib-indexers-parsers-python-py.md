---
title: "lib / indexers / parsers / python.py"
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

# python.py

> `lib/indexers/parsers/python.py` — python, 134 lines

| Property | Value |
|----------|-------|
| Path | `lib/indexers/parsers/python.py` |
| Language | python |
| Lines | 134 |
| Size | 4480 bytes |
| Symbols | 4 |
| PageRank | — |

## Symbols (4)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `_first_doc_line` | function | 33 | private | Extract the first line of a docstring following a def/class. |
| `_find_parent_class` | function | 41 | private | Find the class that contains an indented method definition. |
| `parse` | function | 50 | public | Parse a Python file and return (symbols, imports, exports). |
| `parse_python` | function | 131 | public | Legacy interface: returns dict with symbols/imports/exports. |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[lib-indexers-parsers|lib/indexers/parsers]]

## Related

- [[architecture]]
