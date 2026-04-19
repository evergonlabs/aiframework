---
title: "rust / src / validator / mod.rs"
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

# mod.rs

> `rust/src/validator/mod.rs` — rust, 206 lines

| Property | Value |
|----------|-------|
| Path | `rust/src/validator/mod.rs` |
| Language | rust |
| Lines | 206 |
| Size | 6767 bytes |
| Symbols | 8 |
| PageRank | — |

## Symbols (8)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `CheckStatus` | enum | 5 | public | — |
| `CheckResult` | struct | 13 | public | — |
| `verify` | function | 30 | public | Run all verification checks against a target directory. |
| `check_file_exists` | function | 44 | private | Check if a file exists and report its line count. |
| `check_claude_md_wellformed` | function | 72 | private | Check that CLAUDE.md has a ## Commands section (well-formed)... |
| `check_manifest_json` | function | 99 | private | Check that manifest.json exists and is valid JSON. |
| `check_githooks` | function | 123 | private | Check that .githooks directory has pre-commit and pre-push. |
| `check_commands_configured` | function | 161 | private | Check that lint/test commands are configured (not NOT_CONFIG... |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[rust-src-validator|rust/src/validator]]

## Related

- [[architecture]]
