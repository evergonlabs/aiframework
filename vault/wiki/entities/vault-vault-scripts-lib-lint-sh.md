---
title: "vault / .vault / scripts / lib-lint.sh"
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

# lib-lint.sh

> `vault/.vault/scripts/lib-lint.sh` — bash, 491 lines

| Property | Value |
|----------|-------|
| Path | `vault/.vault/scripts/lib-lint.sh` |
| Language | bash |
| Lines | 491 |
| Size | 16409 bytes |
| Symbols | 16 |
| PageRank | — |

## Symbols (16)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `lint_hr001_raw_immutability` | function | 9 | public | HR-001: raw/ immutability (check via git — files in raw/ sho... |
| `lint_hr002_frontmatter` | function | 37 | public | HR-002: Mandatory YAML frontmatter |
| `lint_hr003_approved_tags` | function | 77 | public | HR-003: Tags from approved taxonomy only |
| `lint_hr004_wiki_length` | function | 111 | public | HR-004: Wiki page length limit (200 warn / 400 block) |
| `lint_hr005_code_length` | function | 140 | public | HR-005: Code file length limit (400 warn / 600 block) |
| `lint_hr006_unique_titles` | function | 165 | public | HR-006: Unique page titles |
| `lint_hr008_index_registration` | function | 193 | public | HR-008: Index registration required |
| `lint_hr010_binary_quarantine` | function | 222 | public | HR-010: Binary file quarantine |
| `lint_hr011_vault_protection` | function | 251 | public | HR-011: .vault/ protection (check staged changes) |
| `lint_hr012_config_protection` | function | 272 | public | HR-012: Agent config protection (check staged changes) |
| `lint_hr014_no_deletion` | function | 295 | public | HR-014: No file deletion (check staged deletions) |
| `lint_hr007_updated_accuracy` | function | 316 | public | HR-007: Frontmatter 'updated' date accuracy (within 30 days ... |
| `lint_hr009_flat_tags` | function | 361 | public | HR-009: Flat tags must use prefix/value format |
| `lint_hr013_ci_template_protection` | function | 418 | public | HR-013: CI and template file protection (staged changes) |
| `lint_hr015_append_only_logs` | function | 441 | public | HR-015: Append-only logs (log.md line count must not decreas... |
| `lint_all` | function | 470 | public | Composite: Run all lint checks |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[vault-vault-scripts|vault/.vault/scripts]]

## Related

- [[architecture]]
