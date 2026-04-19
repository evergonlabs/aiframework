---
title: "rust / src / scanner / ci.rs"
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

# ci.rs

> `rust/src/scanner/ci.rs` — rust, 260 lines

| Property | Value |
|----------|-------|
| Path | `rust/src/scanner/ci.rs` |
| Language | rust |
| Lines | 260 |
| Size | 9061 bytes |
| Symbols | 13 |
| PageRank | — |

## Symbols (13)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `scan` | function | 5 | public | Scan for CI/CD configuration: provider, workflows, coverage,... |
| `detect_provider` | function | 28 | private | — |
| `parse_github_workflows` | function | 44 | private | — |
| `extract_yaml_name` | function | 83 | private | — |
| `extract_triggers` | function | 94 | private | — |
| `extract_jobs` | function | 128 | private | — |
| `extract_secrets_from_content` | function | 152 | private | — |
| `derive_purpose` | function | 162 | private | — |
| `collect_ci_content` | function | 180 | private | — |
| `detect_coverage` | function | 195 | private | — |
| `detect_gaps` | function | 206 | private | — |
| `detect_deploy_target` | function | 214 | private | — |
| `collect_github_secrets` | function | 256 | private | — |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[rust-src-scanner|rust/src/scanner]]

## Related

- [[architecture]]
