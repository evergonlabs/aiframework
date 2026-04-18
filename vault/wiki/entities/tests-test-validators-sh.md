---
title: "tests / test_validators.sh"
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

# test_validators.sh

> `tests/test_validators.sh` — bash, 648 lines

| Property | Value |
|----------|-------|
| Path | `tests/test_validators.sh` |
| Language | bash |
| Lines | 648 |
| Size | 19852 bytes |
| Symbols | 31 |
| PageRank | — |

## Symbols (31)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `pass` | function | 31 | public | — |
| `fail` | function | 37 | public | — |
| `setup_fixture` | function | 46 | public | — |
| `teardown_fixture` | function | 121 | public | — |
| `reset_counters` | function | 133 | public | — |
| `test_files_happy` | function | 144 | public | ============================================================... |
| `test_files_missing` | function | 162 | public | ============================================================... |
| `test_security_happy` | function | 181 | public | ============================================================... |
| `test_security_detects_secrets` | function | 200 | public | ============================================================... |
| `test_security_detects_stripe` | function | 220 | public | ============================================================... |
| `test_consistency_happy` | function | 240 | public | ============================================================... |
| `test_consistency_placeholders` | function | 260 | public | ============================================================... |
| `test_quality_gate_happy` | function | 280 | public | ============================================================... |
| `test_freshness_happy` | function | 301 | public | ============================================================... |
| `log_info` | function | 318 | public | --- Logging stubs for generator modules --- |
| `log_ok` | function | 319 | public | — |
| `log_warn` | function | 320 | public | — |
| `test_preserve_tracking_skip` | function | 325 | public | ============================================================... |
| `test_preserve_tracking_create` | function | 342 | public | ============================================================... |
| `test_preserve_doc_skip` | function | 359 | public | ============================================================... |
| `test_preserve_hook_skip` | function | 376 | public | ============================================================... |
| `test_backup_file_creates_backup` | function | 393 | public | ============================================================... |
| `test_backup_file_skips_symlink` | function | 415 | public | ============================================================... |
| `test_sanitize_strips_backticks` | function | 438 | public | ============================================================... |
| `test_sanitize_strips_dollar_parens` | function | 457 | public | ============================================================... |

> Showing 25 of 31 symbols.

## Imports (8)

- [[lib-generators-preserve-sh|preserve.sh]] (`lib/generators/preserve.sh`)
- [[lib-generators-skills-sh|skills.sh]] (`lib/generators/skills.sh`)
- [[lib-scanners-skill-suggest-sh|skill_suggest.sh]] (`lib/scanners/skill_suggest.sh`)
- [[lib-validators-consistency-sh|consistency.sh]] (`lib/validators/consistency.sh`)
- [[lib-validators-files-sh|files.sh]] (`lib/validators/files.sh`)
- [[lib-validators-freshness-sh|freshness.sh]] (`lib/validators/freshness.sh`)
- [[lib-validators-quality-gate-sh|quality_gate.sh]] (`lib/validators/quality_gate.sh`)
- [[lib-validators-security-sh|security.sh]] (`lib/validators/security.sh`)

## Imported By

*No internal dependents detected.*

## Module

- [[tests|tests]]

## Related

- [[architecture]]
