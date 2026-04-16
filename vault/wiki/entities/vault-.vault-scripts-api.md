---
title: "API Reference: vault/.vault/scripts"
type: entity
created: 2026-04-16
updated: 2026-04-16
status: current
tags:
  - type/entity
  - domain/bash
  - source-type/code-index
  - format/reference
confidence: medium
---

# API Reference: vault/.vault/scripts

> Function and class reference for `vault/.vault/scripts` (47 symbols).

## Symbols

| Name | Kind | File | Description |
|------|------|------|-------------|
| `cmd_content_audit` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `cmd_doctor` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `cmd_index_rebuild` | function | `vault/.vault/scripts/lib-commands.sh` | — |
| `cmd_init_hooks` | function | `vault/.vault/scripts/lib-commands.sh` | — |
| `cmd_lint` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `cmd_orphans` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `cmd_stale` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `cmd_stats` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `cmd_status` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `cmd_tag_audit` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `cmd_validate` | function | `vault/.vault/scripts/vault-tools.sh` | — |
| `count_lines` | function | `vault/.vault/scripts/lib-utils.sh` | ── File Utilities ── |
| `count_wikilinks` | function | `vault/.vault/scripts/lib-utils.sh` | Count wikilinks in a file. |
| `extract_frontmatter` | function | `vault/.vault/scripts/lib-utils.sh` | ── Frontmatter Extraction ── |
| `extract_wikilinks` | function | `vault/.vault/scripts/lib-utils.sh` | ── Wikilink Parsing ── |
| `file_age_days` | function | `vault/.vault/scripts/lib-utils.sh` | Get file age in days. |
| `get_frontmatter_field` | function | `vault/.vault/scripts/lib-utils.sh` | Extract a specific frontmatter field value. |
| `get_frontmatter_tags` | function | `vault/.vault/scripts/lib-utils.sh` | Extract all tags from frontmatter as newline-separated list. |
| `has_frontmatter` | function | `vault/.vault/scripts/lib-utils.sh` | Check if a file has valid YAML frontmatter (starts with ---) |
| `is_indexed` | function | `vault/.vault/scripts/lib-utils.sh` | ── Index Utilities ── |
| `is_json` | function | `vault/.vault/scripts/lib-utils.sh` | Check if a file is a JSON file. |
| `is_markdown` | function | `vault/.vault/scripts/lib-utils.sh` | Check if a file is a markdown file. |
| `lint_all` | function | `vault/.vault/scripts/lib-lint.sh` | Composite: Run all lint checks |
| `lint_hr001_raw_immutability` | function | `vault/.vault/scripts/lib-lint.sh` | HR-001: raw/ immutability (check via git — files in raw/ should not appear in st |
| `lint_hr002_frontmatter` | function | `vault/.vault/scripts/lib-lint.sh` | HR-002: Mandatory YAML frontmatter |
| `lint_hr003_approved_tags` | function | `vault/.vault/scripts/lib-lint.sh` | HR-003: Tags from approved taxonomy only |
| `lint_hr004_wiki_length` | function | `vault/.vault/scripts/lib-lint.sh` | HR-004: Wiki page length limit (200 warn / 400 block) |
| `lint_hr005_code_length` | function | `vault/.vault/scripts/lib-lint.sh` | HR-005: Code file length limit (400 warn / 600 block) |
| `lint_hr006_unique_titles` | function | `vault/.vault/scripts/lib-lint.sh` | HR-006: Unique page titles |
| `lint_hr007_updated_accuracy` | function | `vault/.vault/scripts/lib-lint.sh` | HR-007: Frontmatter 'updated' date accuracy (within 30 days of git last-modified |
| `lint_hr008_index_registration` | function | `vault/.vault/scripts/lib-lint.sh` | HR-008: Index registration required |
| `lint_hr009_flat_tags` | function | `vault/.vault/scripts/lib-lint.sh` | HR-009: Flat tags must use prefix/value format |
| `lint_hr010_binary_quarantine` | function | `vault/.vault/scripts/lib-lint.sh` | HR-010: Binary file quarantine |
| `lint_hr011_vault_protection` | function | `vault/.vault/scripts/lib-lint.sh` | HR-011: .vault/ protection (check staged changes) |
| `lint_hr012_config_protection` | function | `vault/.vault/scripts/lib-lint.sh` | HR-012: Agent config protection (check staged changes) |
| `lint_hr013_ci_template_protection` | function | `vault/.vault/scripts/lib-lint.sh` | HR-013: CI and template file protection (staged changes) |
| `lint_hr014_no_deletion` | function | `vault/.vault/scripts/lib-lint.sh` | HR-014: No file deletion (check staged deletions) |
| `lint_hr015_append_only_logs` | function | `vault/.vault/scripts/lib-lint.sh` | HR-015: Append-only logs (log.md line count must not decrease) |
| `load_approved_tags` | function | `vault/.vault/scripts/lib-utils.sh` | ── Tag Validation ── |
| `log_fail` | function | `vault/.vault/scripts/lib-utils.sh` | — |
| `log_info` | function | `vault/.vault/scripts/lib-utils.sh` | --- Logging stubs for generator modules --- |
| `log_pass` | function | `vault/.vault/scripts/lib-utils.sh` | ── Logging ── |
| `log_warn` | function | `vault/.vault/scripts/lib-utils.sh` | — |
| `rel_path` | function | `vault/.vault/scripts/lib-utils.sh` | Get relative path from vault root. |
| `resolve_vault_root` | function | `vault/.vault/scripts/lib-utils.sh` | ── Path Resolution ── |
| `validate_tag` | function | `vault/.vault/scripts/lib-utils.sh` | Validate a single tag against the approved list. |
| `validate_tag_format` | function | `vault/.vault/scripts/lib-utils.sh` | Validate tag format (HR-009: prefix/value, lowercase alphanumeric with hyphens). |

## Related

- [[vault-.vault-scripts]]
- [[architecture]]
- [[tech-stack]]
