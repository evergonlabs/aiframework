---
title: "install.sh"
type: entity
created: "2026-04-19"
updated: "2026-04-19"
status: current
tags:
  - type/entity
  - scope/file
  - domain/bash
  - source-type/code-index
confidence: medium
---

# install.sh

> `install.sh` — bash, 623 lines

| Property | Value |
|----------|-------|
| Path | `install.sh` |
| Language | bash |
| Lines | 623 |
| Size | 19987 bytes |
| Symbols | 17 |
| PageRank | — |

## Symbols (17)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `info` | function | 27 | public | — |
| `ok` | function | 28 | public | — |
| `warn` | function | 29 | public | — |
| `err` | function | 30 | public | — |
| `die` | function | 31 | public | — |
| `tildify` | function | 34 | public | Replace $HOME with ~ in paths for cleaner output |
| `detect_platform` | function | 40 | public | — |
| `set_default_paths` | function | 74 | public | — |
| `check_command` | function | 125 | public | — |
| `detect_pkg_manager` | function | 130 | public | Detect Linux package manager |
| `pkg_install_hint` | function | 142 | public | Generate install command for a package per distro |
| `try_auto_install` | function | 189 | public | Auto-install a missing dependency (only with --auto-deps) |
| `check_dependencies` | function | 248 | public | — |
| `install_aiframework` | function | 344 | public | — |
| `ensure_path` | function | 418 | public | — |
| `uninstall_aiframework` | function | 473 | public | — |
| `main` | function | 506 | public | — |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[root-module|.]]

## Related

- [[architecture]]
