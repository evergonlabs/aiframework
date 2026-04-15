---
title: "Git Workflow"
type: architecture
created: "2026-04-15"
updated: "2026-04-15"
status: current
tags:
  - type/architecture
  - audience/developer
  - audience/agent
  - tool/git
owner: system
confidence: high
---

# Git Workflow for Vault Operations

## Branch Naming

All vault branches follow the pattern:

```
agent/<agent-id>/<task>
```

Examples:
- `agent/claude/ingest-api-docs`
- `agent/claude/update-auth-concepts`
- `agent/system/weekly-lint`
- `agent/human/review-decisions`

**Rules**:
- `<agent-id>`: lowercase, identifies the actor (`claude`, `human`, `ci`, `system`)
- `<task>`: lowercase, hyphen-separated, describes the work
- Never push directly to `main` — always use branches + PRs

## Commit Message Format

```
<type>(vault): <short description>

<body — what changed and why>

Refs: <related pages or issues>
```

**Types**:
- `ingest`: New source ingested and summarized
- `create`: New wiki/memory page created
- `update`: Existing page updated
- `fix`: Correction to existing content
- `lint`: Lint fixes or structural corrections
- `archive`: Page archived (HR-014: no deletion)
- `meta`: Index rebuild, log entry, status update

**Examples**:
```
ingest(vault): add OAuth 2.0 specification summary

Ingested RFC 6749 into raw/ and created source summary.
Cross-referenced with existing auth concept pages.

Refs: wiki/sources/oauth2-rfc6749.md, wiki/concepts/auth.md
```

```
update(vault): refresh API rate-limiting documentation

Updated rate limit thresholds after v2.3 release.
Previous values were from v2.0 (stale per SR-008).

Refs: wiki/concepts/api-rate-limits.md
```

## PR Checklist

Before merging any vault PR, verify:

### Hard Rule Compliance
- [ ] No modifications to `raw/` files (HR-001)
- [ ] All new/changed `.md` files have valid YAML frontmatter (HR-002)
- [ ] All tags are from approved taxonomy (HR-003)
- [ ] No wiki page exceeds 400 lines (HR-004)
- [ ] No code file exceeds 600 lines (HR-005)
- [ ] No duplicate titles (HR-006)
- [ ] `updated` fields reflect actual changes (HR-007)
- [ ] All new wiki pages registered in index (HR-008)
- [ ] Tags use `prefix/value` format (HR-009)
- [ ] No binary files in wiki/ or memory/ (HR-010)
- [ ] No changes to .vault/ infrastructure (HR-011)
- [ ] No changes to CLAUDE.md/AGENTS.md (HR-012)
- [ ] No changes to CI/templates (HR-013)
- [ ] No file deletions (HR-014)
- [ ] Log.md only appended to (HR-015)

### Quality Checks
- [ ] `vault-tools.sh lint` passes
- [ ] `vault-tools.sh tag-audit` passes
- [ ] `vault-tools.sh content-audit` passes
- [ ] New pages have >= 3 wikilinks (SR-003)
- [ ] Page lengths are in target range (SR-002)

### Process
- [ ] Changes logged in `wiki/log.md`
- [ ] `memory/status.md` updated if significant
- [ ] Draft pages marked `status: draft` (SR-010)
