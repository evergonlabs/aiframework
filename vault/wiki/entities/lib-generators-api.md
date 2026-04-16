---
title: "API Reference: lib/generators"
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

# API Reference: lib/generators

> Function and class reference for `lib/generators` (85 symbols).

## Symbols

| Name | Kind | File | Description |
|------|------|------|-------------|
| `_backup_file` | function | `lib/generators/preserve.sh` | Backup a file before overwriting |
| `_emit_ci_and_key_locations` | function | `lib/generators/claude_md.sh` | — |
| `_emit_decision_priority_and_workflow` | function | `lib/generators/claude_md.sh` | — |
| `_emit_header_and_doc_table` | function | `lib/generators/claude_md.sh` | — |
| `_emit_invariants_and_config` | function | `lib/generators/claude_md.sh` | — |
| `_emit_key_commands` | function | `lib/generators/claude_md.sh` | — |
| `_emit_pipeline_and_routing` | function | `lib/generators/claude_md.sh` | — |
| `_emit_project_identity` | function | `lib/generators/claude_md.sh` | — |
| `_emit_project_structure` | function | `lib/generators/claude_md.sh` | — |
| `_emit_qa_autofix` | function | `lib/generators/claude_md.sh` | — |
| `_emit_skills_vault_and_footer` | function | `lib/generators/claude_md.sh` | — |
| `_extract_claude_md_vars` | function | `lib/generators/claude_md.sh` | --- Shared variable extraction (called by both lean and full) --- |
| `_file_exists` | function | `lib/generators/preserve.sh` | Check if a file exists and is non-empty |
| `_generate_workflow_rules` | function | `lib/generators/claude_md.sh` | --- Generate .claude/rules/workflow.md --- |
| `_init_preserve` | function | `lib/generators/preserve.sh` | — |
| `_sanitize_manifest_val` | function | `lib/generators/skills.sh` | Sanitize manifest values for safe use in heredocs and echo statements. |
| `cmd_content_audit` | function | `lib/generators/vault.sh` | — |
| `cmd_doctor` | function | `lib/generators/vault.sh` | — |
| `cmd_index_rebuild` | function | `lib/generators/vault.sh` | — |
| `cmd_init_hooks` | function | `lib/generators/vault.sh` | — |
| `cmd_lint` | function | `lib/generators/vault.sh` | — |
| `cmd_orphans` | function | `lib/generators/vault.sh` | — |
| `cmd_stale` | function | `lib/generators/vault.sh` | — |
| `cmd_stats` | function | `lib/generators/vault.sh` | — |
| `cmd_status` | function | `lib/generators/vault.sh` | — |
| `cmd_tag_audit` | function | `lib/generators/vault.sh` | — |
| `cmd_validate` | function | `lib/generators/vault.sh` | — |
| `count_lines` | function | `lib/generators/vault.sh` | ── File Utilities ── |
| `count_wikilinks` | function | `lib/generators/vault.sh` | Count wikilinks in a file. |
| `extract_frontmatter` | function | `lib/generators/vault.sh` | ── Frontmatter Extraction ── |
| `extract_wikilinks` | function | `lib/generators/vault.sh` | ── Wikilink Parsing ── |
| `file_age_days` | function | `lib/generators/vault.sh` | Get file age in days. |
| `find_vault_root` | function | `lib/generators/vault.sh` | Locate vault root (this hook may be in .git/hooks/ or .vault/hooks/) |
| `generate_ci` | function | `lib/generators/ci.sh` | — |
| `generate_claude_md` | function | `lib/generators/claude_md.sh` | --- Dispatcher: picks lean vs full based on project complexity --- |
| `generate_claude_md_full` | function | `lib/generators/claude_md.sh` | --- Full CLAUDE.md generator (verbose, for complex/enterprise projects) --- |
| `generate_claude_md_lean` | function | `lib/generators/claude_md.sh` | --- Lean CLAUDE.md generator (80-150 lines, high-signal only) --- |
| `generate_docs` | function | `lib/generators/docs.sh` | — |
| `generate_hooks` | function | `lib/generators/hooks.sh` | — |
| `generate_report` | function | `lib/generators/report.sh` | — |
| `generate_skills` | function | `lib/generators/skills.sh` | — |
| `generate_tracking` | function | `lib/generators/tracking.sh` | — |
| `generate_vault` | function | `lib/generators/vault.sh` | — |
| `get_frontmatter_field` | function | `lib/generators/vault.sh` | Extract a specific frontmatter field value. |
| `get_frontmatter_tags` | function | `lib/generators/vault.sh` | Extract all tags from frontmatter as newline-separated list. |
| `has_frontmatter` | function | `lib/generators/vault.sh` | Check if a file has valid YAML frontmatter (starts with ---) |
| `is_indexed` | function | `lib/generators/vault.sh` | ── Index Utilities ── |
| `is_json` | function | `lib/generators/vault.sh` | Check if a file is a JSON file. |
| `is_markdown` | function | `lib/generators/vault.sh` | Check if a file is a markdown file. |
| `lint_all` | function | `lib/generators/vault.sh` | Composite: Run all lint checks |
| `lint_hr001_raw_immutability` | function | `lib/generators/vault.sh` | HR-001: raw/ immutability (check via git — files in raw/ should not appear in st |
| `lint_hr002_frontmatter` | function | `lib/generators/vault.sh` | HR-002: Mandatory YAML frontmatter |
| `lint_hr003_approved_tags` | function | `lib/generators/vault.sh` | HR-003: Tags from approved taxonomy only |
| `lint_hr004_wiki_length` | function | `lib/generators/vault.sh` | HR-004: Wiki page length limit (200 warn / 400 block) |
| `lint_hr005_code_length` | function | `lib/generators/vault.sh` | HR-005: Code file length limit (400 warn / 600 block) |
| `lint_hr006_unique_titles` | function | `lib/generators/vault.sh` | HR-006: Unique page titles |
| `lint_hr008_index_registration` | function | `lib/generators/vault.sh` | HR-008: Index registration required |
| `lint_hr010_binary_quarantine` | function | `lib/generators/vault.sh` | HR-010: Binary file quarantine |
| `lint_hr011_vault_protection` | function | `lib/generators/vault.sh` | HR-011: .vault/ protection (check staged changes) |
| `lint_hr012_config_protection` | function | `lib/generators/vault.sh` | HR-012: Agent config protection (check staged changes) |
| `lint_hr014_no_deletion` | function | `lib/generators/vault.sh` | HR-014: No file deletion (check staged deletions) |
| `load_approved_tags` | function | `lib/generators/vault.sh` | ── Tag Validation ── |
| `log_fail` | function | `lib/generators/vault.sh` | — |
| `log_info` | function | `lib/generators/vault.sh` | --- Logging stubs for generator modules --- |
| `log_pass` | function | `lib/generators/vault.sh` | ── Logging ── |
| `log_warn` | function | `lib/generators/vault.sh` | — |
| `merge_claude_md_user_content` | function | `lib/generators/preserve.sh` | After CLAUDE.md is generated, append preserved user content |
| `populate_vault_from_index` | function | `lib/generators/vault.sh` | ══════════════════════════════════════════════════════════════════ |
| `preserve_ci` | function | `lib/generators/preserve.sh` | --- CI workflow --- |
| `preserve_claude_md` | function | `lib/generators/preserve.sh` | --- CLAUDE.md merge strategy --- |
| `preserve_doc` | function | `lib/generators/preserve.sh` | --- Documentation files --- |
| `preserve_hook` | function | `lib/generators/preserve.sh` | --- Git hooks --- |
| `preserve_rule` | function | `lib/generators/preserve.sh` | --- .claude/rules/ --- |
| `preserve_skill` | function | `lib/generators/preserve.sh` | --- Skills --- |
| `preserve_specialist` | function | `lib/generators/preserve.sh` | --- Review specialists --- |
| `preserve_tracking` | function | `lib/generators/preserve.sh` | --- Tracking files (CHANGELOG, VERSION, STATUS) --- |
| `print_preserve_summary` | function | `lib/generators/preserve.sh` | --- Summary of what was preserved --- |
| `rel_path` | function | `lib/generators/vault.sh` | Get relative path from vault root. |
| `resolve_vault_root` | function | `lib/generators/vault.sh` | ── Path Resolution ── |
| `validate_tag` | function | `lib/generators/vault.sh` | Validate a single tag against the approved list. |
| `validate_tag_format` | function | `lib/generators/vault.sh` | Validate tag format (HR-009: prefix/value, lowercase alphanumeric with hyphens). |
| `vault_auto_ingest` | function | `lib/generators/vault_ingest.sh` | — |

## Related

- [[lib-generators]]
- [[architecture]]
- [[tech-stack]]
