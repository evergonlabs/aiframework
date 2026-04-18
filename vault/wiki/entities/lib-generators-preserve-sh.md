---
title: "lib / generators / preserve.sh"
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

# preserve.sh

> `lib/generators/preserve.sh` — bash, 273 lines

| Property | Value |
|----------|-------|
| Path | `lib/generators/preserve.sh` |
| Language | bash |
| Lines | 273 |
| Size | 8628 bytes |
| Symbols | 13 |
| PageRank | 0.0024 |

## Symbols (13)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `_init_preserve` | function | 17 | private | — |
| `_file_exists` | function | 22 | private | Check if a file exists and is non-empty |
| `_backup_file` | function | 27 | private | Backup a file before overwriting |
| `preserve_claude_md` | function | 52 | public | --- CLAUDE.md merge strategy ---
If CLAUDE.md exists, extrac... |
| `merge_claude_md_user_content` | function | 105 | public | After CLAUDE.md is generated, append preserved user content |
| `preserve_tracking` | function | 120 | public | --- Tracking files (CHANGELOG, VERSION, STATUS) ---
CHANGELO... |
| `preserve_doc` | function | 135 | public | --- Documentation files ---
docs/README.md: skip if exists
S... |
| `preserve_skill` | function | 150 | public | --- Skills ---
.claude/skills/NAME-review/SKILL.md: backup +... |
| `preserve_ci` | function | 180 | public | --- CI workflow ---
Skip if exists — user's CI is sacred |
| `preserve_hook` | function | 192 | public | --- Git hooks ---
Skip if exists — user may have custom hook... |
| `preserve_specialist` | function | 206 | public | --- Review specialists ---
These are generated checklists — ... |
| `preserve_rule` | function | 231 | public | --- .claude/rules/ ---
workflow.md: backup + overwrite (we g... |
| `print_preserve_summary` | function | 262 | public | --- Summary of what was preserved --- |

## Imports

*No internal imports detected.*

## Imported By (2)

- [[bin-aiframework|aiframework]] (`bin/aiframework`)
- [[tests-test-validators-sh|test_validators.sh]] (`tests/test_validators.sh`)

## Module

- [[lib-generators|lib/generators]]

## Related

- [[architecture]]
