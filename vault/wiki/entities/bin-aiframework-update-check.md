---
title: "bin / aiframework-update-check"
type: entity
created: "2026-04-18"
updated: "2026-04-18"
status: current
tags:
  - type/entity
  - scope/file
  - domain/bash
  - source-type/code-index
confidence: medium
---

# aiframework-update-check

> `bin/aiframework-update-check` — bash, 281 lines

| Property | Value |
|----------|-------|
| Path | `bin/aiframework-update-check` |
| Language | bash |
| Lines | 281 |
| Size | 7584 bytes |
| Symbols | 14 |
| PageRank | — |

## Symbols (14)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `now_epoch` | function | 29 | public | — |
| `local_version` | function | 33 | public | — |
| `version_lt` | function | 38 | public | Compare semver: returns 0 if $1 < $2 |
| `is_check_disabled` | function | 51 | public | — |
| `is_auto_upgrade` | function | 55 | public | — |
| `is_snoozed` | function | 61 | public | — |
| `write_snooze` | function | 90 | public | — |
| `check_cache` | function | 103 | public | — |
| `write_cache` | function | 123 | public | — |
| `fetch_remote_version` | function | 130 | public | — |
| `check_drift` | function | 147 | public | — |
| `main` | function | 164 | public | — |
| `_json_escape` | function | 253 | private | — |
| `_output_json` | function | 258 | private | — |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[bin|bin]]

## Related

- [[architecture]]
