---
title: "Architecture — Module Graph"
type: concept
created: 2026-04-16
updated: 2026-04-16
status: current
tags:
  - type/concept
  - type/architecture
  - domain/bash
  - source-type/code-index
confidence: medium
---

# Architecture — Module Graph

> Auto-generated from code index. Shows module dependencies and structure.

## Module Dependency Table

| Module | Depends On | Depended By |
|--------|-----------|-------------|
| `.` | — | — |
| `lib/generators` | — | — |
| `lib/indexers` | lib/indexers | lib/indexers |
| `lib/scanners` | — | — |
| `lib/validators` | — | — |
| `tests` | — | — |
| `vault/.vault/scripts` | — | — |

## Hot Spots (highest fan-in)

- `lib/indexers` — fan_in: 8

## Entry Points (fan-in = 0)


- `.`
- `lib/generators`
- `lib/scanners`
- `lib/validators`
- `tests`
- `vault/.vault/scripts`

## Related

- [[tech-stack]]
- [[project-overview]]
