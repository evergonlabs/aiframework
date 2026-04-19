---
title: "rust / src / indexer / graph.rs"
type: entity
created: "2026-04-19"
updated: "2026-04-19"
status: current
tags:
  - type/entity
  - scope/file
  - domain/rust
  - source-type/code-index
confidence: medium
---

# graph.rs

> `rust/src/indexer/graph.rs` — rust, 356 lines

| Property | Value |
|----------|-------|
| Path | `rust/src/indexer/graph.rs` |
| Language | rust |
| Lines | 356 |
| Size | 11419 bytes |
| Symbols | 6 |
| PageRank | — |

## Symbols (6)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `build_graph` | function | 7 | public | Build dependency edges from file imports. |
| `compute_pagerank` | function | 164 | public | Compute PageRank scores for files. Returns map of path → sco... |
| `resolve_import` | function | 245 | private | Resolve an import string to a known file path. |
| `common_prefix_len` | function | 320 | private | — |
| `ModuleInfo` | struct | 325 | private | — |
| `infer_role` | function | 333 | private | Infer module role from directory name (matches Python indexe... |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[rust-src-indexer|rust/src/indexer]]

## Related

- [[architecture]]
