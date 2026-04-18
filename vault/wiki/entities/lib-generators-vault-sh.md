---
title: "lib / generators / vault.sh"
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

# vault.sh

> `lib/generators/vault.sh` — bash, 3675 lines

| Property | Value |
|----------|-------|
| Path | `lib/generators/vault.sh` |
| Language | bash |
| Lines | 3675 |
| Size | 120990 bytes |
| Symbols | 49 |
| PageRank | 0.0022 |

## Symbols (49)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `generate_vault` | function | 6 | public | — |
| `resolve_vault_root` | function | 1246 | public | ── Path Resolution ──
Resolve VAULT_ROOT from any script loc... |
| `extract_frontmatter` | function | 1257 | public | ── Frontmatter Extraction ──
Extract YAML frontmatter from a... |
| `has_frontmatter` | function | 1268 | public | Check if a file has valid YAML frontmatter (starts with ---) |
| `get_frontmatter_field` | function | 1275 | public | Extract a specific frontmatter field value.
Usage: get_front... |
| `get_frontmatter_tags` | function | 1282 | public | Extract all tags from frontmatter as newline-separated list. |
| `extract_wikilinks` | function | 1290 | public | ── Wikilink Parsing ──
Extract all [[wikilinks]] from a file... |
| `count_wikilinks` | function | 1296 | public | Count wikilinks in a file. |
| `load_approved_tags` | function | 1304 | public | ── Tag Validation ──
Load approved tags from tags.md into a ... |
| `validate_tag` | function | 1317 | public | Validate a single tag against the approved list.
Usage: vali... |
| `validate_tag_format` | function | 1324 | public | Validate tag format (HR-009: prefix/value, lowercase alphanu... |
| `count_lines` | function | 1331 | public | ── File Utilities ──
Count lines in a file. |
| `file_age_days` | function | 1337 | public | Get file age in days. |
| `is_markdown` | function | 1348 | public | Check if a file is a markdown file. |
| `is_json` | function | 1353 | public | Check if a file is a JSON file. |
| `rel_path` | function | 1358 | public | Get relative path from vault root. |
| `is_indexed` | function | 1366 | public | ── Index Utilities ──
Check if a file path appears in the in... |
| `log_pass` | function | 1373 | public | ── Logging ── |
| `log_fail` | function | 1374 | public | — |
| `log_warn` | function | 1375 | public | — |
| `log_info` | function | 1376 | public | — |
| `lint_hr001_raw_immutability` | function | 1394 | public | HR-001: raw/ immutability (check via git — files in raw/ sho... |
| `lint_hr002_frontmatter` | function | 1422 | public | HR-002: Mandatory YAML frontmatter |
| `lint_hr003_approved_tags` | function | 1462 | public | HR-003: Tags from approved taxonomy only |
| `lint_hr004_wiki_length` | function | 1496 | public | HR-004: Wiki page length limit (200 warn / 400 block) |

> Showing 25 of 49 symbols.

## Imports

*No internal imports detected.*

## Imported By (1)

- [[bin-aiframework|aiframework]] (`bin/aiframework`)

## Module

- [[lib-generators|lib/generators]]

## Related

- [[architecture]]
