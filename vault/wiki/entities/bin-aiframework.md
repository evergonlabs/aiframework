---
title: "bin / aiframework"
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

# aiframework

> `bin/aiframework` — bash, 692 lines

| Property | Value |
|----------|-------|
| Path | `bin/aiframework` |
| Language | bash |
| Lines | 692 |
| Size | 21916 bytes |
| Symbols | 24 |
| PageRank | — |

## Symbols (24)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `_aiframework_cleanup` | function | 26 | private | Cleanup trap — remove temp files on exit |
| `check_dependencies` | function | 34 | public | Dependency check — validate required tools are available |
| `_aif_timer_start` | function | 73 | private | — |
| `_aif_timer_elapsed` | function | 74 | private | — |
| `log_info` | function | 87 | public | — |
| `log_ok` | function | 88 | public | — |
| `log_warn` | function | 89 | public | — |
| `log_error` | function | 90 | public | — |
| `log_step` | function | 92 | public | — |
| `log_phase` | function | 108 | public | — |
| `log_phase_done` | function | 124 | public | — |
| `banner` | function | 131 | public | — |
| `_aif_summary` | function | 144 | private | Completion summary box |
| `usage` | function | 165 | public | — |
| `parse_args` | function | 211 | public | — |
| `cmd_discover` | function | 273 | public | — |
| `cmd_generate` | function | 369 | public | — |
| `cmd_verify` | function | 477 | public | — |
| `cmd_index` | function | 527 | public | — |
| `cmd_stats` | function | 539 | public | — |
| `cmd_report` | function | 547 | public | — |
| `cmd_refresh` | function | 574 | public | — |
| `_write_refresh_notice` | function | 607 | private | — |
| `cmd_run` | function | 624 | public | — |

## Imports (31)

- [[lib-freshness-track-sh|track.sh]] (`lib/freshness/track.sh`)
- [[lib-generators-agents-md-sh|agents_md.sh]] (`lib/generators/agents_md.sh`)
- [[lib-generators-ci-sh|ci.sh]] (`lib/generators/ci.sh`)
- [[lib-generators-claude-md-sh|claude_md.sh]] (`lib/generators/claude_md.sh`)
- [[lib-generators-cursor-rules-sh|cursor_rules.sh]] (`lib/generators/cursor_rules.sh`)
- [[lib-generators-docs-sh|docs.sh]] (`lib/generators/docs.sh`)
- [[lib-generators-hooks-sh|hooks.sh]] (`lib/generators/hooks.sh`)
- [[lib-generators-preserve-sh|preserve.sh]] (`lib/generators/preserve.sh`)
- [[lib-generators-report-sh|report.sh]] (`lib/generators/report.sh`)
- [[lib-generators-skills-sh|skills.sh]] (`lib/generators/skills.sh`)
- [[lib-generators-tracking-sh|tracking.sh]] (`lib/generators/tracking.sh`)
- [[lib-generators-vault-sh|vault.sh]] (`lib/generators/vault.sh`)
- [[lib-generators-vault-ingest-sh|vault_ingest.sh]] (`lib/generators/vault_ingest.sh`)
- [[lib-knowledge-store-sh|store.sh]] (`lib/knowledge/store.sh`)
- [[lib-scanners-archetype-sh|archetype.sh]] (`lib/scanners/archetype.sh`)
- [[lib-scanners-ci-sh|ci.sh]] (`lib/scanners/ci.sh`)
- [[lib-scanners-code-index-sh|code_index.sh]] (`lib/scanners/code_index.sh`)
- [[lib-scanners-commands-sh|commands.sh]] (`lib/scanners/commands.sh`)
- [[lib-scanners-domain-sh|domain.sh]] (`lib/scanners/domain.sh`)
- [[lib-scanners-env-sh|env.sh]] (`lib/scanners/env.sh`)
- [[lib-scanners-identity-sh|identity.sh]] (`lib/scanners/identity.sh`)
- [[lib-scanners-quality-sh|quality.sh]] (`lib/scanners/quality.sh`)
- [[lib-scanners-skill-suggest-sh|skill_suggest.sh]] (`lib/scanners/skill_suggest.sh`)
- [[lib-scanners-stack-sh|stack.sh]] (`lib/scanners/stack.sh`)
- [[lib-scanners-structure-sh|structure.sh]] (`lib/scanners/structure.sh`)
- [[lib-scanners-user-context-sh|user_context.sh]] (`lib/scanners/user_context.sh`)
- [[lib-validators-consistency-sh|consistency.sh]] (`lib/validators/consistency.sh`)
- [[lib-validators-files-sh|files.sh]] (`lib/validators/files.sh`)
- [[lib-validators-freshness-sh|freshness.sh]] (`lib/validators/freshness.sh`)
- [[lib-validators-quality-gate-sh|quality_gate.sh]] (`lib/validators/quality_gate.sh`)
- [[lib-validators-security-sh|security.sh]] (`lib/validators/security.sh`)

## Imported By

*No internal dependents detected.*

## Module

- [[bin|bin]]

## Related

- [[architecture]]
