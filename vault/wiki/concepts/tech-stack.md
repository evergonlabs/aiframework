---
title: "Technology Stack"
type: concept
created: 2026-04-15
updated: 2026-04-16
status: current
tags: [domain/engineering, type/concept, lifecycle/active]
confidence: high
---

# Technology Stack

## Language & Framework

- **Primary**: bash / none
- **Key dependencies**: none

## Quality Tools

- **Linter**: find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs shellcheck
- **Type checker**: find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n
- **Test framework**: NOT_CONFIGURED

## Symbol Counts by Language

> Auto-populated from code index (`_meta.languages`).

| Language | Symbol Count |
|----------|-------------|
| bash | 39 |
| python | 10 |


## Related

- [[project-overview]]
