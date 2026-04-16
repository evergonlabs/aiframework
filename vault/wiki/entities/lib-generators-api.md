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

> Function and class reference for `lib/generators` (36 symbols).

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
| `generate_ci` | function | `lib/generators/ci.sh` | — |
| `generate_claude_md` | function | `lib/generators/claude_md.sh` | --- Dispatcher: picks lean vs full based on project complexity --- |
| `generate_claude_md_full` | function | `lib/generators/claude_md.sh` | --- Full CLAUDE.md generator (verbose, for complex/enterprise projects) --- |
| `generate_claude_md_lean` | function | `lib/generators/claude_md.sh` | --- Lean CLAUDE.md generator (80-150 lines, high-signal only) --- |
| `generate_docs` | function | `lib/generators/docs.sh` | — |
| `generate_hooks` | function | `lib/generators/hooks.sh` | — |
| `generate_report` | function | `lib/generators/report.sh` | — |
| `generate_skills` | function | `lib/generators/skills.sh` | — |
| `generate_tracking` | function | `lib/generators/tracking.sh` | — |
| `merge_claude_md_user_content` | function | `lib/generators/preserve.sh` | After CLAUDE.md is generated, append preserved user content |
| `preserve_ci` | function | `lib/generators/preserve.sh` | --- CI workflow --- |
| `preserve_claude_md` | function | `lib/generators/preserve.sh` | --- CLAUDE.md merge strategy --- |
| `preserve_doc` | function | `lib/generators/preserve.sh` | --- Documentation files --- |
| `preserve_hook` | function | `lib/generators/preserve.sh` | --- Git hooks --- |
| `preserve_rule` | function | `lib/generators/preserve.sh` | --- .claude/rules/ --- |
| `preserve_skill` | function | `lib/generators/preserve.sh` | --- Skills --- |
| `preserve_specialist` | function | `lib/generators/preserve.sh` | --- Review specialists --- |
| `preserve_tracking` | function | `lib/generators/preserve.sh` | --- Tracking files (CHANGELOG, VERSION, STATUS) --- |
| `print_preserve_summary` | function | `lib/generators/preserve.sh` | --- Summary of what was preserved --- |
| `vault_auto_ingest` | function | `lib/generators/vault_ingest.sh` | — |

## Related

- [[lib-generators]]
- [[architecture]]
- [[tech-stack]]
