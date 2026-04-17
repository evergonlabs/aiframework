---
title: "Architecture — Module Graph"
type: concept
created: 2026-04-17
updated: 2026-04-17
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
| `lib/indexers/parsers` | — | — |
| `lib/scanners` | — | — |
| `lib/validators` | — | — |
| `tests` | — | — |
| `vault/.vault/scripts` | — | — |

## Hot Spots (highest fan-in)

- `lib/indexers` — fan_in: 3

## Entry Points (fan-in = 0)


- `.`
- `lib/generators`
- `lib/indexers/parsers`
- `lib/scanners`
- `lib/validators`
- `tests`
- `vault/.vault/scripts`

## Related

- [[tech-stack]]
- [[project-overview]]
