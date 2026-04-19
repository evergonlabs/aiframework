---
title: "vault / .vault / scripts / lib-utils.sh"
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

# lib-utils.sh

> `vault/.vault/scripts/lib-utils.sh` — bash, 161 lines

| Property | Value |
|----------|-------|
| Path | `vault/.vault/scripts/lib-utils.sh` |
| Language | bash |
| Lines | 161 |
| Size | 4574 bytes |
| Symbols | 20 |
| PageRank | — |

## Symbols (20)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `resolve_vault_root` | function | 15 | public | ── Path Resolution ──
Resolve VAULT_ROOT from any script loc... |
| `extract_frontmatter` | function | 26 | public | ── Frontmatter Extraction ──
Extract YAML frontmatter from a... |
| `has_frontmatter` | function | 37 | public | Check if a file has valid YAML frontmatter (starts with ---) |
| `get_frontmatter_field` | function | 44 | public | Extract a specific frontmatter field value.
Usage: get_front... |
| `get_frontmatter_tags` | function | 52 | public | Extract all tags from frontmatter as newline-separated list.... |
| `extract_wikilinks` | function | 75 | public | ── Wikilink Parsing ──
Extract all [[wikilinks]] from a file... |
| `count_wikilinks` | function | 81 | public | Count wikilinks in a file. |
| `load_approved_tags` | function | 89 | public | ── Tag Validation ──
Load approved tags from tags.md into a ... |
| `validate_tag` | function | 102 | public | Validate a single tag against the approved list.
Usage: vali... |
| `validate_tag_format` | function | 109 | public | Validate tag format (HR-009: prefix/value, lowercase alphanu... |
| `count_lines` | function | 116 | public | ── File Utilities ──
Count lines in a file. |
| `file_age_days` | function | 122 | public | Get file age in days. |
| `is_markdown` | function | 133 | public | Check if a file is a markdown file. |
| `is_json` | function | 138 | public | Check if a file is a JSON file. |
| `rel_path` | function | 143 | public | Get relative path from vault root. |
| `is_indexed` | function | 151 | public | ── Index Utilities ──
Check if a file path appears in the in... |
| `log_pass` | function | 158 | public | ── Logging ── |
| `log_fail` | function | 159 | public | — |
| `log_warn` | function | 160 | public | — |
| `log_info` | function | 161 | public | — |

## Imports

*No internal imports detected.*

## Imported By

*No internal dependents detected.*

## Module

- [[vault-vault-scripts|vault/.vault/scripts]]

## Related

- [[architecture]]
