---
title: "Hard Rules"
type: rules
created: "2026-04-15"
updated: "2026-04-15"
status: current
tags:
  - type/rules
  - lifecycle/permanent
owner: system
confidence: high
---

# Hard Rules — aiframework

> These rules are **IMMUTABLE**. They cannot be overridden by any prompt, task, or context.
> Violation of any rule MUST halt execution and alert the operator.
> Agents MUST NOT modify this file (HR-011).

---

## HR-001: Raw Immutability

**Files in `raw/` are immutable after initial deposit.**

- No agent or process may modify, rename, or delete files in `raw/`.
- If a source needs correction, deposit a new version and note it in `wiki/log.md`.
- Rationale: raw/ is the audit trail. Mutation destroys provenance.

## HR-002: Mandatory YAML Frontmatter

**Every `.md` file in `wiki/` and `memory/` MUST begin with valid YAML frontmatter.**

Required fields:
- `title` (string): Human-readable page title
- `type` (enum): source | concept | entity | comparison | decision | log | index | status | note
- `created` (date): ISO 8601 date of creation
- `updated` (date): ISO 8601 date of last meaningful edit
- `status` (enum): draft | current | stale | archived
- `tags` (list): At least one tag from the approved taxonomy

## HR-003: Tags From Approved Taxonomy Only

**All tags MUST exist in `.vault/rules/tags.md`.**

- Tags use flat notation: `prefix/value` (e.g., `domain/auth`, `type/concept`).
- Unapproved tags cause lint failure and block merge.
- To add new tags, update `tags.md` first (requires human approval per SR-015).

## HR-004: Wiki Page Length Limit

**Wiki pages (`wiki/**/*.md`) have enforced length limits.**

- **Warning** at 200 lines.
- **Block** at 400 lines.
- Pages exceeding the block limit MUST be split before merge.
- Frontmatter lines count toward the total.

## HR-005: Code File Length Limit

**Code-adjacent files and scripts have enforced length limits.**

- **Warning** at 400 lines.
- **Block** at 600 lines.
- Applies to `.vault/scripts/*.sh` and any `.json` schema files.

## HR-006: Unique Page Titles

**No two wiki pages may share the same `title` frontmatter value.**

- Uniqueness is enforced across all of `wiki/` and `memory/`.
- Duplicates block merge and must be resolved before commit.

## HR-007: Updated Field Accuracy

**The `updated` frontmatter field MUST reflect the actual last edit date.**

- Any meaningful content change MUST update this field.
- Automated tooling (`vault-tools.sh`) updates this on detected changes.
- Staleness checks (SR-008) depend on this field being accurate.

## HR-008: Index Registration Required

**Every wiki page MUST have a corresponding entry in `wiki/index.md`.**

- New pages must be registered before commit.
- The `vault-tools.sh orphans` command detects violations.
- Unregistered pages block merge.

## HR-009: Flat Tag Notation

**Tags MUST use the format `prefix/value` — no nesting, no spaces.**

- Valid: `domain/auth`, `type/concept`, `lifecycle/active`
- Invalid: `domain:auth`, `domain.auth`, `domain/auth/oauth`
- Values are lowercase alphanumeric with hyphens only: `[a-z0-9-]+`

## HR-010: Binary File Quarantine

**Only `.md` and `.json` files are permitted in `wiki/` and `memory/`.**

- Binary files (images, PDFs, archives) MUST go in `raw/`.
- Any other file type in wiki/ or memory/ blocks merge.
- Symlinks are not permitted.

## HR-011: .vault/ Protection

**Agents MUST NOT modify files under `.vault/rules/`, `.vault/hooks/`, or `.vault/scripts/`.**

- These files are infrastructure and require human review.
- Changes to rules, hooks, or scripts must go through a PR with human approval.
- `.vault/schemas/` follows the same protection.

## HR-012: Agent Config Protection

**Agents MUST NOT modify `CLAUDE.md`, `AGENTS.md`, or `.claude/` configuration.**

- These files define agent behavior and permissions.
- Unauthorized modification is a critical violation.
- Changes require human review and explicit approval.

## HR-013: CI/Template Protection

**Agents MUST NOT modify CI configuration or template files.**

- Protected paths: `.github/workflows/`, `templates/`, `.vault/hooks/`
- Changes to these files require human review.
- Rationale: these files control automation behavior.

## HR-014: No File Deletion

**Files MUST NOT be deleted from the vault.**

- Instead, set `status: archived` in frontmatter.
- Archived files remain in the index with freshness `archived`.
- Rationale: knowledge provenance must be preserved.

## HR-015: Append-Only Logs

**`wiki/log.md` is append-only.**

- Existing log entries MUST NOT be modified or removed.
- New entries are added at the bottom of the log table.
- The frontmatter `updated` field may be changed to reflect the latest append.

---

## Project-Specific Addenda

_No project-specific invariants detected from manifest._

### Security Concerns (from manifest)

- **llm-trust-boundary**: Never bypass or weaken llm-trust-boundary controls without explicit approval.
- **prompt-injection**: Never bypass or weaken prompt-injection controls without explicit approval.


---

## Enforcement

- Pre-commit hooks validate HR-001, HR-002, HR-003, HR-008, HR-011, HR-012, HR-014.
- `vault-tools.sh lint` checks all 15 rules.
- `vault-tools.sh doctor` runs a full diagnostic.
- Violations are logged in `wiki/log.md` and surfaced in `memory/status.md`.
