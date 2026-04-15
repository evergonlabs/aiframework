---
title: "Soft Rules"
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

# Soft Rules

> These rules are **guidelines**. They represent best practices and can be relaxed
> with justification logged in `wiki/log.md`. Persistent violation should trigger
> a review of whether the rule should be updated or the practice corrected.

---

## SR-001: One Source Per Ingestion Session

**Each ingestion session should process exactly one source document.**

- Rationale: prevents cross-contamination of summaries and ensures clean provenance.
- If multiple sources must be ingested, create separate sessions.
- Exception: closely related sources (e.g., a paper and its errata) may be co-ingested with a log note.

## SR-002: Target Page Length 80–150 Lines

**Wiki pages should target 80–150 lines of content (excluding frontmatter).**

- Under 80 lines: consider whether the page is too thin and should be merged.
- Over 150 lines: consider splitting into sub-pages.
- The hard limit (HR-004) is 400 lines; this soft target keeps pages digestible.

## SR-003: Minimum 3 Wikilinks Per Page

**Each wiki page should contain at least 3 `[[wikilinks]]` to other pages.**

- Wikilinks use the format `[[slug]]` where slug matches the index entry.
- Isolated pages reduce discoverability and knowledge graph density.
- The `vault-tools.sh orphans` command helps identify under-linked pages.

## SR-004: Source Summary Length Tiers

**Source summaries should scale with source complexity.**

| Source Length | Summary Target | Max |
|-------------|---------------|-----|
| < 5 pages   | 30–50 lines   | 80  |
| 5–20 pages  | 50–100 lines  | 150 |
| 20–100 pages| 100–150 lines | 200 |
| > 100 pages | 150–200 lines | 300 |

- These are guidelines; quality matters more than length.

## SR-005: Log Entry Format

**Log entries in `wiki/log.md` should follow a consistent format.**

Each row: `| timestamp | operation | actor | target | result | notes |`

- **timestamp**: ISO 8601 UTC (`YYYY-MM-DDTHH:MM:SSZ`)
- **operation**: verb-noun (e.g., `ingest-source`, `create-concept`, `lint-run`)
- **actor**: who performed it (agent name, `system`, or human name)
- **target**: file path or scope affected
- **result**: `success`, `warning`, `failure`
- **notes**: brief context (keep under 100 chars)

## SR-006: Decision Record ADR Format

**Decision records in `memory/decisions/` should follow ADR format.**

Required sections:
1. **Context**: What situation prompted this decision?
2. **Decision**: What was decided?
3. **Consequences**: What are the expected outcomes?
4. **Status**: proposed | accepted | deprecated | superseded

Optional: Alternatives Considered, Related Decisions.

## SR-007: Lint Frequency

**Run `vault-tools.sh lint` at these intervals:**

- Before every commit (automated via pre-commit hook)
- After every ingestion session
- Weekly full audit (`vault-tools.sh doctor`)
- After any structural change (new directories, schema updates)

## SR-008: Staleness Thresholds

**Content should be reviewed when it exceeds age thresholds.**

| Content Type | Review After | Action |
|-------------|-------------|--------|
| Source summaries | 14 days | Verify accuracy against source |
| Concept pages | 30 days | Check for outdated information |
| Entity pages | 60 days | Verify entity still exists/is relevant |
| Comparisons | 90 days | Re-evaluate conclusions |
| Decision records | 180 days | Confirm decision still holds |
| Operational notes | 7 days | Archive or promote to concept |

- `vault-tools.sh stale` automates detection.
- Stale pages should be updated or have `status` changed to `stale`.

## SR-009: Confidence Calibration

**The `confidence` frontmatter field should be calibrated as follows:**

| Level | Meaning | When to Use |
|-------|---------|-------------|
| `high` | Verified, well-sourced, unlikely to change | Official docs, stable APIs |
| `medium` | Reasonable but not fully verified | Community knowledge, recent changes |
| `low` | Uncertain, needs verification | Inferred, single-source, rapidly changing |
| `speculative` | Hypothesis or guess | Untested theories, forward-looking |

- Default new pages to `medium` unless clearly high or low.
- Promote to `high` after human review.

## SR-010: Review Gates

**Draft pages require human promotion to `current` status.**

- New agent-created pages should have `status: draft`.
- A human reviewer promotes to `status: current` after verification.
- Exception: automated updates to `updated` field and log appends.
- Rationale: prevents hallucinated or low-quality content from becoming canonical.

## SR-011: Cross-Reference on Ingest

**When ingesting a new source, check for related existing pages.**

- Search wiki/ for overlapping topics, entities, or concepts.
- Add `[[wikilinks]]` to and from related pages.
- Update the `related` frontmatter field on both pages.
- Log cross-references in `wiki/log.md`.

## SR-012: Query Filing Policy

**Queries and research questions should be filed as operational notes.**

- File in `memory/notes/` with `type: note` and a descriptive title.
- If the query leads to a lasting insight, promote to a concept page.
- Archive resolved queries within 7 days (per SR-008 staleness for notes).

## SR-013: Entity Page Structure

**Entity pages should follow a consistent structure:**

1. **Overview**: 2–3 sentence summary of the entity
2. **Properties**: Key attributes in a table or list
3. **Relationships**: How this entity connects to others (`[[wikilinks]]`)
4. **History**: Notable changes or events
5. **References**: Links to source summaries

## SR-014: Comparison Page Structure

**Comparison pages should follow a consistent structure:**

1. **Overview**: What is being compared and why
2. **Criteria**: Evaluation dimensions (table format preferred)
3. **Analysis**: Detailed comparison per criterion
4. **Recommendation**: If applicable, with confidence level
5. **Sources**: Links to source summaries used

## SR-015: Custom Tag Naming Conventions

**When proposing new tags for the taxonomy:**

- Use lowercase alphanumeric with hyphens: `prefix/my-new-tag`
- Prefix must be one of the 19 approved prefixes in `tags.md`
- Value should be 1–3 words, hyphen-separated
- Avoid abbreviations unless universally understood
- New tags require human approval before addition to `tags.md`
- Log the addition in `wiki/log.md`
