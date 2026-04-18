---
title: "API Reference: tests (legacy)"
type: entity
created: 2026-04-17
updated: 2026-04-17
status: archived
tags:
  - type/entity
  - domain/bash
  - source-type/code-index
  - format/reference
confidence: medium
---

# API Reference: tests

> Function and class reference for `tests` (75 symbols).

## Symbols

| Name | Kind | File | Description |
|------|------|------|-------------|
| `TestEdgeCases` | class | `tests/test_indexer.py` | Edge case tests. |
| `TestGraph` | class | `tests/test_indexer.py` | — |
| `TestIndexRepo` | class | `tests/test_indexer.py` | — |
| `TestMcpServer` | class | `tests/test_mcp.py` | Test the MCP server dispatch and handlers. |
| `TestNewParsers` | class | `tests/test_indexer.py` | Tests for newly added language parsers. |
| `TestParsers` | class | `tests/test_indexer.py` | — |
| `_dispatch` | method | `tests/test_mcp.py` | — |
| `_parse` | method | `tests/test_indexer.py` | — |
| `fail` | function | `tests/test_e2e.sh` | — |
| `log_info` | function | `tests/test_validators.sh` | — |
| `log_ok` | function | `tests/test_validators.sh` | — |
| `log_warn` | function | `tests/test_validators.sh` | — |
| `pass` | function | `tests/test_e2e.sh` | — |
| `reset_counters` | function | `tests/test_validators.sh` | — |
| `setUp` | method | `tests/test_mcp.py` | Create a temp project with manifest. |
| `setup_fixture` | function | `tests/test_e2e.sh` | — |
| `tearDown` | method | `tests/test_mcp.py` | — |
| `teardown_fixture` | function | `tests/test_validators.sh` | — |
| `test_backup_file_creates_backup` | function | `tests/test_validators.sh` | ============================================================ |
| `test_backup_file_skips_symlink` | function | `tests/test_validators.sh` | ============================================================ |
| `test_bash_parser` | method | `tests/test_indexer.py` | Bash parser detects functions. |
| `test_binary_file_skipped` | method | `tests/test_indexer.py` | Binary files produce empty results. |
| `test_build_graph_empty` | method | `tests/test_indexer.py` | Empty files dict produces empty graph. |
| `test_consistency_happy` | function | `tests/test_validators.sh` | ============================================================ |
| `test_consistency_placeholders` | function | `tests/test_validators.sh` | ============================================================ |
| `test_csharp_parser` | method | `tests/test_indexer.py` | — |
| `test_elixir_parser` | method | `tests/test_indexer.py` | — |
| `test_empty_directory` | method | `tests/test_indexer.py` | Indexing an empty directory produces empty results. |
| `test_empty_file` | method | `tests/test_indexer.py` | — |
| `test_files_happy` | function | `tests/test_validators.sh` | ============================================================ |
| `test_files_missing` | function | `tests/test_validators.sh` | ============================================================ |
| `test_freshness_happy` | function | `tests/test_validators.sh` | ============================================================ |
| `test_go_parser` | method | `tests/test_indexer.py` | — |
| `test_indexes_this_repo` | method | `tests/test_indexer.py` | Smoke test: index the aiframework repo itself. |
| `test_initialize` | method | `tests/test_mcp.py` | — |
| `test_java_parser` | method | `tests/test_indexer.py` | — |
| `test_kotlin_parser` | method | `tests/test_indexer.py` | — |
| `test_large_file_skipped` | method | `tests/test_indexer.py` | Files > 100KB get file-level only, no symbols. |
| `test_module_grouping` | method | `tests/test_indexer.py` | Files in same directory are grouped into a module. |
| `test_notification_no_response` | method | `tests/test_mcp.py` | — |
| `test_output_schema_complete` | method | `tests/test_indexer.py` | Verify all required top-level keys present. |
| `test_php_parser` | method | `tests/test_indexer.py` | — |
| `test_preserve_doc_skip` | function | `tests/test_validators.sh` | ============================================================ |
| `test_preserve_hook_skip` | function | `tests/test_validators.sh` | ============================================================ |
| `test_preserve_tracking_create` | function | `tests/test_validators.sh` | ============================================================ |
| `test_preserve_tracking_skip` | function | `tests/test_validators.sh` | ============================================================ |
| `test_python_parser` | method | `tests/test_indexer.py` | Python parser detects functions and classes. |
| `test_quality_gate_happy` | function | `tests/test_validators.sh` | ============================================================ |
| `test_resources_list` | method | `tests/test_mcp.py` | — |
| `test_resources_read_architecture` | method | `tests/test_mcp.py` | — |
| `test_resources_read_commands` | method | `tests/test_mcp.py` | — |
| `test_resources_read_invariants` | method | `tests/test_mcp.py` | — |
| `test_resources_read_manifest` | method | `tests/test_mcp.py` | — |
| `test_ruby_parser` | method | `tests/test_indexer.py` | — |
| `test_rust_parser` | method | `tests/test_indexer.py` | — |
| `test_sanitize_preserves_normal` | function | `tests/test_validators.sh` | ============================================================ |
| `test_sanitize_strips_backticks` | function | `tests/test_validators.sh` | ============================================================ |
| `test_sanitize_strips_dollar_braces` | function | `tests/test_validators.sh` | ============================================================ |
| `test_sanitize_strips_dollar_parens` | function | `tests/test_validators.sh` | ============================================================ |
| `test_security_detects_secrets` | function | `tests/test_validators.sh` | ============================================================ |
| `test_security_detects_stripe` | function | `tests/test_validators.sh` | ============================================================ |
| `test_security_happy` | function | `tests/test_validators.sh` | ============================================================ |
| `test_skill_suggest_deploy` | function | `tests/test_validators.sh` | ============================================================ |
| `test_skill_suggest_docker` | function | `tests/test_validators.sh` | ============================================================ |
| `test_skill_suggest_empty` | function | `tests/test_validators.sh` | ============================================================ |
| `test_swift_parser` | method | `tests/test_indexer.py` | — |
| `test_tool_analyze_file` | method | `tests/test_mcp.py` | — |
| `test_tool_check_invariants` | method | `tests/test_mcp.py` | — |
| `test_tools_list` | method | `tests/test_mcp.py` | — |
| `test_typescript_parser` | method | `tests/test_indexer.py` | — |
| `test_unknown_language` | method | `tests/test_indexer.py` | — |
| `test_unknown_method` | method | `tests/test_mcp.py` | — |

## Related

- [[tests]]
- [[architecture]]
- [[tech-stack]]
