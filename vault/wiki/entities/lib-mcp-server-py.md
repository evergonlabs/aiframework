---
title: "lib / mcp / server.py"
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

# server.py

> `lib/mcp/server.py` — python, 347 lines

| Property | Value |
|----------|-------|
| Path | `lib/mcp/server.py` |
| Language | python |
| Lines | 347 |
| Size | 13099 bytes |
| Symbols | 21 |
| PageRank | — |

## Symbols (21)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `_find_project_root` | function | 22 | private | Walk up from cwd to find .aiframework/manifest.json. |
| `_load_json` | function | 32 | private | Load JSON file, return None on failure. |
| `AifMcpServer` | class | 41 | public | — |
| `__init__` | method | 42 | private | — |
| `manifest` | method | 49 | public | — |
| `code_index` | method | 55 | public | — |
| `handle_initialize` | method | 62 | public | — |
| `handle_initialized` | method | 75 | public | — |
| `handle_resources_list` | method | 80 | public | — |
| `handle_resources_read` | method | 115 | public | — |
| `handle_tools_list` | method | 138 | public | — |
| `handle_tools_call` | method | 171 | public | — |
| `_tool_analyze_file` | method | 190 | private | — |
| `_tool_find_tests` | method | 211 | private | — |
| `_tool_check_invariants` | method | 235 | private | — |
| `_tool_refresh` | method | 238 | private | — |
| `_extract_invariants` | method | 254 | private | — |
| `_extract_architecture` | method | 274 | private | — |
| `dispatch` | method | 286 | public | — |
| `run` | method | 320 | public | Main loop: read JSON-RPC from stdin, write to stdout. |
| `main` | function | 341 | public | — |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[lib-mcp|lib/mcp]]

## Related

- [[architecture]]
