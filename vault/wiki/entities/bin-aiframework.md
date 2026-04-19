---
title: "bin / aiframework"
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

# aiframework

> `bin/aiframework` — bash, 1304 lines

| Property | Value |
|----------|-------|
| Path | `bin/aiframework` |
| Language | bash |
| Lines | 1304 |
| Size | 45644 bytes |
| Symbols | 37 |
| PageRank | — |

## Symbols (37)

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
| `_aiframework_cleanup` | function | 54 | private | Cleanup trap — remove temp files on exit |
| `_aif_timeout` | function | 63 | private | Cross-platform timeout wrapper
Priority: GNU timeout → gtime... |
| `_aif_telemetry_enabled` | function | 125 | private | — |
| `_aif_telemetry_base` | function | 132 | private | Build the base properties common to all events |
| `_aif_telemetry` | function | 172 | private | Send a telemetry event via PostHog — fire-and-forget, never ... |
| `_aif_telemetry_error` | function | 217 | private | Record an error for inclusion in the next telemetry event |
| `check_dependencies` | function | 230 | public | Dependency check — validate required tools are available |
| `_aif_timer_start` | function | 273 | private | — |
| `_aif_timer_elapsed` | function | 274 | private | — |
| `log_info` | function | 287 | public | — |
| `log_ok` | function | 288 | public | — |
| `log_warn` | function | 289 | public | — |
| `log_error` | function | 290 | public | — |
| `log_step` | function | 292 | public | — |
| `log_phase` | function | 308 | public | — |
| `log_phase_done` | function | 324 | public | — |
| `banner` | function | 331 | public | — |
| `_aif_summary` | function | 344 | private | Completion summary box |
| `usage` | function | 365 | public | — |
| `parse_args` | function | 412 | public | — |
| `cmd_discover` | function | 476 | public | — |
| `_run_scanner` | function | 506 | private | — |
| `cmd_generate` | function | 611 | public | — |
| `cmd_verify` | function | 737 | public | — |
| `cmd_index` | function | 812 | public | — |

> Showing 25 of 37 symbols.

## Imports (33)

- [[lib-freshness-track-sh|track.sh]] (`lib/freshness/track.sh`)
- [[lib-generators-agents-md-sh|agents_md.sh]] (`lib/generators/agents_md.sh`)
- [[lib-generators-ci-sh|ci.sh]] (`lib/generators/ci.sh`)
- [[lib-generators-claude-md-sh|claude_md.sh]] (`lib/generators/claude_md.sh`)
- [[lib-generators-cursor-rules-sh|cursor_rules.sh]] (`lib/generators/cursor_rules.sh`)
- [[lib-generators-docs-sh|docs.sh]] (`lib/generators/docs.sh`)
- [[lib-generators-hooks-sh|hooks.sh]] (`lib/generators/hooks.sh`)
- [[lib-generators-preserve-sh|preserve.sh]] (`lib/generators/preserve.sh`)
- [[lib-generators-report-sh|report.sh]] (`lib/generators/report.sh`)
- [[lib-generators-sheal-sh|sheal.sh]] (`lib/generators/sheal.sh`)
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
- [[lib-scanners-sheal-sh|sheal.sh]] (`lib/scanners/sheal.sh`)
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
