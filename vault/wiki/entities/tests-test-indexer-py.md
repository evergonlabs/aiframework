---
title: "tests / test_indexer.py"
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

# test_indexer.py

> `tests/test_indexer.py` — python, 201 lines

| Property | Value |
|----------|-------|
| Path | `tests/test_indexer.py` |
| Language | python |
| Lines | 201 |
| Size | 8129 bytes |
| Symbols | 27 |
| PageRank | — |

## Symbols (27)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `TestIndexRepo` | class | 15 | public | — |
| `test_indexes_this_repo` | method | 16 | public | Smoke test: index the aiframework repo itself. |
| `test_output_schema_complete` | method | 25 | public | Verify all required top-level keys present. |
| `test_empty_directory` | method | 31 | public | Indexing an empty directory produces empty results. |
| `TestParsers` | class | 39 | public | — |
| `test_python_parser` | method | 40 | public | Python parser detects functions and classes. |
| `test_bash_parser` | method | 52 | public | Bash parser detects functions. |
| `test_binary_file_skipped` | method | 62 | public | Binary files produce empty results. |
| `test_large_file_skipped` | method | 71 | public | Files > 512KB get file-level only, no symbols. |
| `TestGraph` | class | 82 | public | — |
| `test_build_graph_empty` | method | 83 | public | Empty files dict produces empty graph. |
| `test_module_grouping` | method | 89 | public | Files in same directory are grouped into a module. |
| `TestNewParsers` | class | 100 | public | Tests for newly added language parsers. |
| `_parse` | method | 103 | private | — |
| `test_java_parser` | method | 111 | public | — |
| `test_csharp_parser` | method | 118 | public | — |
| `test_php_parser` | method | 124 | public | — |
| `test_kotlin_parser` | method | 130 | public | — |
| `test_swift_parser` | method | 137 | public | — |
| `test_elixir_parser` | method | 144 | public | — |
| `test_typescript_parser` | method | 151 | public | — |
| `test_go_parser` | method | 158 | public | — |
| `test_rust_parser` | method | 165 | public | — |
| `test_ruby_parser` | method | 172 | public | — |
| `TestEdgeCases` | class | 180 | public | Edge case tests. |

> Showing 25 of 27 symbols.

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[tests|tests]]

## Related

- [[architecture]]
