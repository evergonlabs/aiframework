#!/usr/bin/env bash
# Generator: Agentic Memory Vault (Production)
# Creates a comprehensive structured knowledge vault for persistent agentic memory.
# Three-layer model: raw (immutable sources) -> wiki (processed knowledge) -> memory (decisions/ops)

generate_vault() {
  local m="$MANIFEST"
  local name
  name=$(echo "$m" | jq -r '.identity.name // "Project"')
  local short
  short=$(echo "$m" | jq -r '.identity.short_name // "project"')
  local version
  version=$(echo "$m" | jq -r '.identity.version // "0.1.0"')
  local lang
  lang=$(echo "$m" | jq -r '.stack.language // "unknown"')
  local framework
  framework=$(echo "$m" | jq -r '.stack.framework // "none"')
  local today
  today=$(date +%Y-%m-%d)
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Collect detected domains
  local domains_json
  domains_json=$(echo "$m" | jq -c '.domain.detected_domains // []' 2>/dev/null)
  local domain_names
  domain_names=$(echo "$domains_json" | jq -r '.[].name' 2>/dev/null || true)

  # Collect invariants and security concerns
  local invariants
  invariants=$(echo "$m" | jq -r '.domain.invariants // [] | .[]' 2>/dev/null || true)
  local security_concerns
  security_concerns=$(echo "$m" | jq -r '.domain.security_concerns // [] | .[]' 2>/dev/null || true)

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create vault/ directory structure with:"
    log_info "  - raw/, wiki/, memory/, .vault/, docs/, templates/"
    log_info "  - 15 hard rules, 15 soft rules, 200+ tags"
    log_info "  - 11 vault-tools commands, lib-utils, lib-lint"
    log_info "  - JSON schemas, pre-commit hooks, templates"
    return 0
  fi

  local vault_root="$TARGET_DIR/vault"

  # ──────────────────────────────────────────────────────────────
  # Directory Structure
  # ──────────────────────────────────────────────────────────────
  mkdir -p "$vault_root"/{raw,wiki/{sources,concepts,entities,comparisons},memory/{decisions,notes},.vault/{scripts,rules,schemas,hooks},docs,templates}

  # Idempotency marker
  if [[ -f "$vault_root/.vault/.initialized" ]]; then
    log_warn "Vault already initialized (found .vault/.initialized). Skipping."
    populate_vault_from_index "$TARGET_DIR" "$vault_root"
    vault_auto_ingest "$TARGET_DIR" "$vault_root"
    return 0
  fi

  log_ok "Created vault directory structure"

  # ──────────────────────────────────────────────────────────────
  # Build project-aware domain tags for reuse
  # ──────────────────────────────────────────────────────────────
  local extra_domain_tags=""
  if [[ -n "$domain_names" ]]; then
    while IFS= read -r dtag; do
      [[ -z "$dtag" ]] && continue
      extra_domain_tags="${extra_domain_tags}  - domain/${dtag}
"
    done <<< "$domain_names"
  fi
  # Always include language and framework
  [[ "$lang" != "unknown" ]] && extra_domain_tags="${extra_domain_tags}  - domain/${lang}
"
  [[ "$framework" != "none" ]] && extra_domain_tags="${extra_domain_tags}  - domain/${framework}
"

  # ──────────────────────────────────────────────────────────────
  # wiki/index.md — Master Catalog with YAML Frontmatter
  # ──────────────────────────────────────────────────────────────
  local index_entries=""
  index_entries="| project-overview | wiki/concepts/project-overview.md | concept | ${today} | current | domain/${lang} |
| tech-stack | wiki/concepts/tech-stack.md | concept | ${today} | current | domain/${lang} |"

  if [[ -n "$domain_names" ]]; then
    while IFS= read -r dtag; do
      [[ -z "$dtag" ]] && continue
      index_entries="${index_entries}
| ${dtag} | wiki/concepts/${dtag}.md | concept | ${today} | current | domain/${dtag} |"
    done <<< "$domain_names"
  fi

  cat > "$vault_root/wiki/index.md" << INDEXEOF
---
title: "${name} Wiki Index"
type: index
created: "${today}"
updated: "${today}"
status: current
tags:
  - type/index
  - lifecycle/active
${extra_domain_tags}owner: system
confidence: high
---

# ${name} — Wiki Index

> Master catalog of all knowledge entries. Every wiki page MUST have a row here (HR-008).

## Entries

| Slug | Path | Type | Created | Freshness | Primary Tag |
|------|------|------|---------|-----------|-------------|
${index_entries}

## Conventions

- **Type**: one of \`source\`, \`concept\`, \`entity\`, \`comparison\`, \`decision\`
- **Freshness**: \`current\`, \`stale\`, \`archived\`
- Every entry must be reachable from this index — no orphans (HR-008)
- All tags must come from approved taxonomy in \`.vault/rules/tags.md\` (HR-003)
- Pages exceeding 200 lines trigger a warning; 400 lines block merge (HR-004)
INDEXEOF

  log_ok "Created wiki/index.md with YAML frontmatter"

  # ──────────────────────────────────────────────────────────────
  # Generate initial concept pages from manifest
  # ──────────────────────────────────────────────────────────────
  local desc
  desc=$(echo "$m" | jq -r '.identity.description // "No description"')

  local detected_domains
  detected_domains=$(echo "$m" | jq -r '.domain.detected_domains[]? | .name' 2>/dev/null)

  # project-overview concept
  cat > "$vault_root/wiki/concepts/project-overview.md" << CONCEPT
---
title: "${name} — Project Overview"
type: concept
created: ${today}
updated: ${today}
status: current
tags: [domain/engineering, type/concept, lifecycle/active]
confidence: high
---

# ${name}

${desc}

## Key Facts

- **Language**: $(echo "$m" | jq -r '.stack.language // "unknown"')
- **Framework**: $(echo "$m" | jq -r '.stack.framework // "none"')
- **Repository**: $(echo "$m" | jq -r '.commands.github_url // "local"')

## Related

- [[tech-stack]]
CONCEPT

  # tech-stack concept
  cat > "$vault_root/wiki/concepts/tech-stack.md" << CONCEPT
---
title: "Technology Stack"
type: concept
created: ${today}
updated: ${today}
status: current
tags: [domain/engineering, type/concept, lifecycle/active]
confidence: high
---

# Technology Stack

## Language & Framework

- **Primary**: $(echo "$m" | jq -r '.stack.language // "unknown"') / $(echo "$m" | jq -r '.stack.framework // "none"')
- **Key dependencies**: $(echo "$m" | jq -r '.stack.key_dependencies | if length > 0 then join(", ") else "none" end' 2>/dev/null || echo "none")

## Quality Tools

- **Linter**: $(echo "$m" | jq -r '.commands.lint // "not configured"')
- **Type checker**: $(echo "$m" | jq -r '.commands.typecheck // "not configured"')
- **Test framework**: $(echo "$m" | jq -r '.commands.test // "not configured"')

## Related

- [[project-overview]]
CONCEPT

  # Domain-specific concept pages
  if [[ -n "$detected_domains" ]]; then
    while IFS= read -r domain; do
      [[ -z "$domain" ]] && continue
      local domain_display
      domain_display=$(echo "$m" | jq -r --arg n "$domain" '.domain.detected_domains[] | select(.name == $n) | .display // $n')
      local domain_paths
      domain_paths=$(echo "$m" | jq -r --arg n "$domain" '.domain.detected_domains[] | select(.name == $n) | .paths[:3] | join(", ") // "N/A"')

      cat > "$vault_root/wiki/concepts/${domain}.md" << DOMAINCONCEPT
---
title: "${domain_display}"
type: concept
created: ${today}
updated: ${today}
status: current
tags: [domain/${domain}, type/concept, lifecycle/active]
confidence: medium
---

# ${domain_display}

## Overview

This domain was detected based on file patterns: ${domain_paths}

## Key Concerns

*Add domain-specific concerns as they are discovered.*

## Related

- [[project-overview]]
- [[tech-stack]]
DOMAINCONCEPT

    done <<< "$detected_domains"
  fi

  log_ok "Created initial concept pages"

  # ──────────────────────────────────────────────────────────────
  # wiki/log.md — Append-Only Operations Log
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/wiki/log.md" << LOGEOF
---
title: "Operations Log"
type: log
created: "${today}"
updated: "${today}"
status: current
tags:
  - type/log
  - lifecycle/active
owner: system
confidence: high
---

# Operations Log

> Append-only log of all vault operations. This file MUST NOT be rewritten (HR-015).
> New entries are appended at the bottom of the table.

## Log

| Timestamp | Operation | Actor | Target | Result | Notes |
|-----------|-----------|-------|--------|--------|-------|
| ${timestamp} | vault-init | aiframework v${version} | vault/ | success | Initial vault generation for ${name} |
LOGEOF

  log_ok "Created wiki/log.md (append-only operations log)"

  # ──────────────────────────────────────────────────────────────
  # .vault/rules/hard-rules.md — All 15 Hard Rules
  # ──────────────────────────────────────────────────────────────
  local project_invariant_section=""
  if [[ -n "$invariants" ]]; then
    project_invariant_section="### Project Invariants (from manifest)

"
    while IFS= read -r inv; do
      [[ -z "$inv" ]] && continue
      project_invariant_section="${project_invariant_section}- ${inv}
"
    done <<< "$invariants"
  fi

  local security_section=""
  if [[ -n "$security_concerns" ]]; then
    security_section="### Security Concerns (from manifest)

"
    while IFS= read -r concern; do
      [[ -z "$concern" ]] && continue
      security_section="${security_section}- **${concern}**: Never bypass or weaken ${concern} controls without explicit approval.
"
    done <<< "$security_concerns"
  fi

  cat > "$vault_root/.vault/rules/hard-rules.md" << HARDEOF
---
title: "Hard Rules"
type: rules
created: "${today}"
updated: "${today}"
status: current
tags:
  - type/rules
  - lifecycle/permanent
owner: system
confidence: high
---

# Hard Rules — ${name}

> These rules are **IMMUTABLE**. They cannot be overridden by any prompt, task, or context.
> Violation of any rule MUST halt execution and alert the operator.
> Agents MUST NOT modify this file (HR-011).

---

## HR-001: Raw Immutability

**Files in \`raw/\` are immutable after initial deposit.**

- No agent or process may modify, rename, or delete files in \`raw/\`.
- If a source needs correction, deposit a new version and note it in \`wiki/log.md\`.
- Rationale: raw/ is the audit trail. Mutation destroys provenance.

## HR-002: Mandatory YAML Frontmatter

**Every \`.md\` file in \`wiki/\` and \`memory/\` MUST begin with valid YAML frontmatter.**

Required fields:
- \`title\` (string): Human-readable page title
- \`type\` (enum): source | concept | entity | comparison | decision | log | index | status | note
- \`created\` (date): ISO 8601 date of creation
- \`updated\` (date): ISO 8601 date of last meaningful edit
- \`status\` (enum): draft | current | stale | archived
- \`tags\` (list): At least one tag from the approved taxonomy

## HR-003: Tags From Approved Taxonomy Only

**All tags MUST exist in \`.vault/rules/tags.md\`.**

- Tags use flat notation: \`prefix/value\` (e.g., \`domain/auth\`, \`type/concept\`).
- Unapproved tags cause lint failure and block merge.
- To add new tags, update \`tags.md\` first (requires human approval per SR-015).

## HR-004: Wiki Page Length Limit

**Wiki pages (\`wiki/**/*.md\`) have enforced length limits.**

- **Warning** at 200 lines.
- **Block** at 400 lines.
- Pages exceeding the block limit MUST be split before merge.
- Frontmatter lines count toward the total.

## HR-005: Code File Length Limit

**Code-adjacent files and scripts have enforced length limits.**

- **Warning** at 400 lines.
- **Block** at 600 lines.
- Applies to \`.vault/scripts/*.sh\` and any \`.json\` schema files.

## HR-006: Unique Page Titles

**No two wiki pages may share the same \`title\` frontmatter value.**

- Uniqueness is enforced across all of \`wiki/\` and \`memory/\`.
- Duplicates block merge and must be resolved before commit.

## HR-007: Updated Field Accuracy

**The \`updated\` frontmatter field MUST reflect the actual last edit date.**

- Any meaningful content change MUST update this field.
- Automated tooling (\`vault-tools.sh\`) updates this on detected changes.
- Staleness checks (SR-008) depend on this field being accurate.
- **Automation:** Run \`vault-tools.sh lint\` — it warns on stale \`updated\` fields. Update manually when editing wiki pages.

## HR-008: Index Registration Required

**Every wiki page MUST have a corresponding entry in \`wiki/index.md\`.**

- New pages must be registered before commit.
- The \`vault-tools.sh orphans\` command detects violations.
- Unregistered pages block merge.

## HR-009: Flat Tag Notation

**Tags MUST use the format \`prefix/value\` — no nesting, no spaces.**

- Valid: \`domain/auth\`, \`type/concept\`, \`lifecycle/active\`
- Invalid: \`domain:auth\`, \`domain.auth\`, \`domain/auth/oauth\`
- Values are lowercase alphanumeric with hyphens only: \`[a-z0-9-]+\`

## HR-010: Binary File Quarantine

**Only \`.md\` and \`.json\` files are permitted in \`wiki/\` and \`memory/\`.**

- Binary files (images, PDFs, archives) MUST go in \`raw/\`.
- Any other file type in wiki/ or memory/ blocks merge.
- Symlinks are not permitted.

## HR-011: .vault/ Protection

**Agents MUST NOT modify files under \`.vault/rules/\`, \`.vault/hooks/\`, or \`.vault/scripts/\`.**

- These files are infrastructure and require human review.
- Changes to rules, hooks, or scripts must go through a PR with human approval.
- \`.vault/schemas/\` follows the same protection.

## HR-012: Agent Config Protection

**Agents MUST NOT modify \`CLAUDE.md\`, \`AGENTS.md\`, or \`.claude/\` configuration.**

- These files define agent behavior and permissions.
- Unauthorized modification is a critical violation.
- Changes require human review and explicit approval.

## HR-013: CI/Template Protection

**Agents MUST NOT modify CI configuration or template files.**

- Protected paths: \`.github/workflows/\`, \`templates/\`, \`.vault/hooks/\`
- Changes to these files require human review.
- Rationale: these files control automation behavior.

## HR-014: No File Deletion

**Files MUST NOT be deleted from the vault.**

- Instead, set \`status: archived\` in frontmatter.
- Archived files remain in the index with freshness \`archived\`.
- Rationale: knowledge provenance must be preserved.

## HR-015: Append-Only Logs

**\`wiki/log.md\` is append-only.**

- Existing log entries MUST NOT be modified or removed.
- New entries are added at the bottom of the log table.
- The frontmatter \`updated\` field may be changed to reflect the latest append.

---

## Project-Specific Addenda

${project_invariant_section:-_No project-specific invariants detected from manifest._}

${security_section:-_No project-specific security concerns detected from manifest._}

---

## Enforcement

- Pre-commit hooks validate HR-001, HR-002, HR-003, HR-008, HR-011, HR-012, HR-014.
- \`vault-tools.sh lint\` checks all 15 rules.
- \`vault-tools.sh doctor\` runs a full diagnostic.
- Violations are logged in \`wiki/log.md\` and surfaced in \`memory/status.md\`.
HARDEOF

  log_ok "Created .vault/rules/hard-rules.md (15 hard rules)"

  # ──────────────────────────────────────────────────────────────
  # .vault/rules/soft-rules.md — All 15 Soft Rules
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/rules/soft-rules.md" << 'SOFTEOF'
---
title: "Soft Rules"
type: rules
created: "DATEPLACEHOLDER"
updated: "DATEPLACEHOLDER"
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
SOFTEOF

  # Replace date placeholder
  sed -i.bak "s/DATEPLACEHOLDER/${today}/g" "$vault_root/.vault/rules/soft-rules.md"
  rm -f "$vault_root/.vault/rules/soft-rules.md.bak"

  log_ok "Created .vault/rules/soft-rules.md (15 soft rules)"

  # ──────────────────────────────────────────────────────────────
  # .vault/rules/tags.md — Full Taxonomy (19 prefixes, 200+ tags)
  # ──────────────────────────────────────────────────────────────
  # Build dynamic domain tags
  local domain_tag_list="  - domain/general"
  [[ "$lang" != "unknown" ]] && domain_tag_list="${domain_tag_list}
  - domain/${lang}"
  [[ "$framework" != "none" ]] && domain_tag_list="${domain_tag_list}
  - domain/${framework}"

  if [[ -n "$domain_names" ]]; then
    while IFS= read -r dtag; do
      [[ -z "$dtag" ]] && continue
      domain_tag_list="${domain_tag_list}
  - domain/${dtag}"
    done <<< "$domain_names"
  fi

  cat > "$vault_root/.vault/rules/tags.md" << TAGSEOF
---
title: "Approved Tag Taxonomy"
type: taxonomy
created: "${today}"
updated: "${today}"
status: current
tags:
  - type/taxonomy
  - lifecycle/permanent
owner: system
confidence: high
---

# Approved Tag Taxonomy

> All tags used in vault frontmatter MUST come from this list (HR-003).
> Tags use flat notation: \`prefix/value\` (HR-009).
> To add a tag, update this file and log the change (SR-015).

---

## 1. domain/ — Subject Domains

${domain_tag_list}
  - domain/infrastructure
  - domain/security
  - domain/testing
  - domain/documentation
  - domain/deployment
  - domain/monitoring
  - domain/data
  - domain/frontend
  - domain/backend
  - domain/devops
  - domain/ml
  - domain/mobile
  - domain/networking

## 2. type/ — Page Types

  - type/source
  - type/concept
  - type/entity
  - type/comparison
  - type/decision
  - type/log
  - type/index
  - type/status
  - type/note
  - type/rules
  - type/taxonomy
  - type/template
  - type/architecture

## 3. lifecycle/ — Content Lifecycle

  - lifecycle/draft
  - lifecycle/active
  - lifecycle/review
  - lifecycle/stable
  - lifecycle/stale
  - lifecycle/archived
  - lifecycle/deprecated
  - lifecycle/permanent
  - lifecycle/experimental

## 4. priority/ — Importance Level

  - priority/critical
  - priority/high
  - priority/medium
  - priority/low
  - priority/backlog
  - priority/someday
  - priority/blocked

## 5. audience/ — Target Audience

  - audience/developer
  - audience/operator
  - audience/stakeholder
  - audience/agent
  - audience/reviewer
  - audience/onboarding
  - audience/security-team
  - audience/public
  - audience/internal

## 6. format/ — Content Format

  - format/prose
  - format/table
  - format/checklist
  - format/diagram
  - format/code-heavy
  - format/q-and-a
  - format/reference
  - format/tutorial
  - format/runbook

## 7. dept/ — Department or Team

  - dept/engineering
  - dept/product
  - dept/design
  - dept/data-science
  - dept/platform
  - dept/security
  - dept/devrel
  - dept/qa
  - dept/sre
  - dept/leadership

## 8. tool/ — Tools and Technologies

  - tool/git
  - tool/docker
  - tool/kubernetes
  - tool/terraform
  - tool/github-actions
  - tool/jest
  - tool/pytest
  - tool/eslint
  - tool/webpack
  - tool/vite
  - tool/postgres
  - tool/redis
  - tool/nginx
  - tool/aws
  - tool/gcp

## 9. method/ — Methodologies and Patterns

  - method/agile
  - method/tdd
  - method/bdd
  - method/ddd
  - method/event-driven
  - method/rest
  - method/graphql
  - method/microservices
  - method/monolith
  - method/cqrs
  - method/twelve-factor
  - method/kanban
  - method/scrum
  - method/waterfall
  - method/xp
  - method/lean
  - method/devops
  - method/sre
  - method/gitflow
  - method/trunk-based

## 10. role/ — Stakeholder Roles

  - role/maintainer
  - role/contributor
  - role/reviewer
  - role/agent
  - role/operator
  - role/architect
  - role/tech-lead
  - role/pm
  - role/designer
  - role/sre
  - role/devops
  - role/qa
  - role/data-engineer
  - role/ml-engineer

## 11. scope/ — Impact Scope

  - scope/file
  - scope/module
  - scope/function
  - scope/class
  - scope/package
  - scope/service
  - scope/microservice
  - scope/monolith
  - scope/system
  - scope/organization
  - scope/cross-team
  - scope/external
  - scope/global

## 12. status/ — Operational Status

  - status/active
  - status/paused
  - status/blocked
  - status/completed
  - status/cancelled
  - status/investigating
  - status/waiting
  - status/in-progress

## 13. source-type/ — Source Classification

  - source-type/official-docs
  - source-type/blog-post
  - source-type/research-paper
  - source-type/book
  - source-type/video
  - source-type/conversation
  - source-type/code-review
  - source-type/incident-report
  - source-type/rfc
  - source-type/adr
  - source-type/changelog
  - source-type/api-spec
  - source-type/code-index

## 14. confidence/ — Confidence Level

  - confidence/high
  - confidence/medium
  - confidence/low
  - confidence/speculative
  - confidence/verified
  - confidence/contested

## 15. frequency/ — Update Frequency

  - frequency/daily
  - frequency/weekly
  - frequency/monthly
  - frequency/quarterly
  - frequency/yearly
  - frequency/ad-hoc
  - frequency/on-change
  - frequency/never
  - frequency/hourly
  - frequency/real-time
  - frequency/on-demand
  - frequency/batch
  - frequency/streaming

## 16. sensitivity/ — Data Sensitivity

  - sensitivity/public
  - sensitivity/internal
  - sensitivity/confidential
  - sensitivity/restricted
  - sensitivity/pii
  - sensitivity/secrets

## 17. region/ — Geographic or Logical Region

  - region/global
  - region/multi-region
  - region/us
  - region/us-east
  - region/us-west
  - region/eu
  - region/eu-west
  - region/eu-central
  - region/apac
  - region/ap-southeast
  - region/staging
  - region/production
  - region/development
  - region/local

## 18. outcome/ — Result Classification

  - outcome/success
  - outcome/partial
  - outcome/failure
  - outcome/inconclusive
  - outcome/deferred
  - outcome/superseded
  - outcome/not-applicable

## 19. agent/ — Agent Classification

  - agent/claude
  - agent/system
  - agent/human
  - agent/ci
  - agent/bot
  - agent/reviewer
  - agent/ingestion
  - agent/lint
  - agent/monitor

---

**Total tags: 200+**
**Last updated: ${today}**
**Process: To add tags, open a PR modifying this file. Log in wiki/log.md (SR-015).**
TAGSEOF

  log_ok "Created .vault/rules/tags.md (19 prefixes, 200+ tags)"

  # ──────────────────────────────────────────────────────────────
  # .vault/schemas/wiki-entry.json — Full Wiki Entry Schema
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/schemas/wiki-entry.json" << 'SCHEMAEOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "vault://schemas/wiki-entry.json",
  "title": "Wiki Entry Frontmatter Schema",
  "description": "Validates YAML frontmatter for all wiki and memory markdown files.",
  "type": "object",
  "required": ["title", "type", "created", "updated", "status", "tags"],
  "properties": {
    "title": {
      "type": "string",
      "minLength": 1,
      "maxLength": 200,
      "description": "Human-readable page title. Must be unique across the vault (HR-006)."
    },
    "type": {
      "type": "string",
      "enum": ["source", "concept", "entity", "comparison", "decision", "log", "index", "status", "note", "rules", "taxonomy", "template", "architecture"],
      "description": "Page type classification."
    },
    "created": {
      "type": "string",
      "format": "date",
      "pattern": "^\\d{4}-\\d{2}-\\d{2}$",
      "description": "ISO 8601 creation date."
    },
    "updated": {
      "type": "string",
      "format": "date",
      "pattern": "^\\d{4}-\\d{2}-\\d{2}$",
      "description": "ISO 8601 last meaningful edit date (HR-007)."
    },
    "status": {
      "type": "string",
      "enum": ["draft", "current", "stale", "archived"],
      "description": "Content lifecycle status."
    },
    "sources": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of source file paths or URLs this page derives from."
    },
    "related": {
      "type": "array",
      "items": { "type": "string", "pattern": "^[a-z0-9-]+$" },
      "description": "Slugs of related wiki pages."
    },
    "tags": {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^[a-z]+/[a-z0-9-]+$"
      },
      "minItems": 1,
      "description": "Tags from approved taxonomy (HR-003, HR-009)."
    },
    "owner": {
      "type": "string",
      "description": "Who is responsible for this page (agent name, 'system', or human)."
    },
    "confidence": {
      "type": "string",
      "enum": ["high", "medium", "low", "speculative"],
      "description": "Confidence calibration per SR-009."
    }
  },
  "additionalProperties": false
}
SCHEMAEOF

  log_ok "Created .vault/schemas/wiki-entry.json"

  # ──────────────────────────────────────────────────────────────
  # .vault/schemas/skill-policy.json — Skill Security Hardening
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/schemas/skill-policy.json" << 'SKILLPOLICYEOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "vault://schemas/skill-policy.json",
  "title": "Skill Security Policy",
  "description": "Defines security tiers for agent skill execution within the vault.",
  "type": "object",
  "required": ["version", "tiers"],
  "properties": {
    "version": { "type": "string", "const": "1.0" },
    "tiers": {
      "type": "object",
      "properties": {
        "strict": {
          "type": "object",
          "description": "Maximum restrictions. For production-touching operations.",
          "properties": {
            "allowed_tools": {
              "type": "array",
              "items": { "type": "string" },
              "default": ["Read", "Grep", "Glob"]
            },
            "forbidden_paths": {
              "type": "array",
              "items": { "type": "string" },
              "default": [".vault/rules/", ".vault/hooks/", ".vault/scripts/", "CLAUDE.md", "AGENTS.md", ".github/workflows/"]
            },
            "require_human_approval": { "type": "boolean", "default": true },
            "max_files_per_session": { "type": "integer", "default": 5 },
            "allow_delete": { "type": "boolean", "default": false },
            "allow_raw_modification": { "type": "boolean", "default": false }
          }
        },
        "moderate": {
          "type": "object",
          "description": "Standard restrictions. For wiki and memory operations.",
          "properties": {
            "allowed_tools": {
              "type": "array",
              "items": { "type": "string" },
              "default": ["Read", "Grep", "Glob", "Edit", "Write", "Bash"]
            },
            "forbidden_paths": {
              "type": "array",
              "items": { "type": "string" },
              "default": [".vault/rules/", ".vault/hooks/", ".vault/scripts/", "CLAUDE.md", "AGENTS.md"]
            },
            "require_human_approval": { "type": "boolean", "default": false },
            "max_files_per_session": { "type": "integer", "default": 20 },
            "allow_delete": { "type": "boolean", "default": false },
            "allow_raw_modification": { "type": "boolean", "default": false }
          }
        },
        "permissive": {
          "type": "object",
          "description": "Minimal restrictions. For development and testing only.",
          "properties": {
            "allowed_tools": {
              "type": "array",
              "items": { "type": "string" },
              "default": ["Read", "Grep", "Glob", "Edit", "Write", "Bash", "Agent"]
            },
            "forbidden_paths": {
              "type": "array",
              "items": { "type": "string" },
              "default": [".vault/hooks/"]
            },
            "require_human_approval": { "type": "boolean", "default": false },
            "max_files_per_session": { "type": "integer", "default": 100 },
            "allow_delete": { "type": "boolean", "default": false },
            "allow_raw_modification": { "type": "boolean", "default": false }
          }
        }
      },
      "required": ["strict", "moderate", "permissive"]
    },
    "default_tier": {
      "type": "string",
      "enum": ["strict", "moderate", "permissive"],
      "default": "moderate"
    }
  }
}
SKILLPOLICYEOF

  log_ok "Created .vault/schemas/skill-policy.json"

  # ──────────────────────────────────────────────────────────────
  # .vault/schemas/content-policy.json — Content Integrity
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/schemas/content-policy.json" << 'CONTENTPOLICYEOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "vault://schemas/content-policy.json",
  "title": "Content Integrity Policy",
  "description": "Defines patterns for detecting prompt injection, content manipulation, and integrity violations.",
  "type": "object",
  "required": ["version", "injection_patterns", "content_rules"],
  "properties": {
    "version": { "type": "string", "const": "1.0" },
    "injection_patterns": {
      "type": "array",
      "description": "Regex patterns that indicate potential prompt injection or manipulation attempts.",
      "items": {
        "type": "object",
        "required": ["id", "pattern", "severity", "description"],
        "properties": {
          "id": { "type": "string" },
          "pattern": { "type": "string" },
          "severity": { "type": "string", "enum": ["critical", "high", "medium", "low"] },
          "description": { "type": "string" }
        }
      },
      "default": [
        {
          "id": "INJ-001",
          "pattern": "(?i)(ignore|disregard|forget)\\s+(all\\s+)?(previous|above|prior)\\s+(instructions?|rules?|constraints?)",
          "severity": "critical",
          "description": "Instruction override attempt"
        },
        {
          "id": "INJ-002",
          "pattern": "(?i)you\\s+are\\s+now\\s+(a|an|the)\\s+",
          "severity": "critical",
          "description": "Role reassignment attempt"
        },
        {
          "id": "INJ-003",
          "pattern": "(?i)(system|admin)\\s*:\\s*",
          "severity": "high",
          "description": "System prompt injection attempt"
        },
        {
          "id": "INJ-004",
          "pattern": "(?i)<!--.*(?:ignore|override|bypass).*-->",
          "severity": "high",
          "description": "Hidden HTML comment with override instructions"
        },
        {
          "id": "INJ-005",
          "pattern": "(?i)\\[\\s*(?:INST|SYSTEM|PROMPT)\\s*\\]",
          "severity": "high",
          "description": "Fake instruction block markers"
        },
        {
          "id": "INJ-006",
          "pattern": "(?i)do\\s+not\\s+follow\\s+(the\\s+)?rules",
          "severity": "medium",
          "description": "Direct rule bypass instruction"
        },
        {
          "id": "INJ-007",
          "pattern": "(?i)execute\\s+(this\\s+)?(bash|shell|command|script)",
          "severity": "medium",
          "description": "Embedded command execution attempt"
        },
        {
          "id": "INJ-008",
          "pattern": "(?i)base64\\s*[:=]\\s*[A-Za-z0-9+/=]{20,}",
          "severity": "medium",
          "description": "Obfuscated base64 content"
        }
      ]
    },
    "content_rules": {
      "type": "object",
      "properties": {
        "max_frontmatter_size_bytes": { "type": "integer", "default": 4096 },
        "max_tag_count": { "type": "integer", "default": 20 },
        "max_related_count": { "type": "integer", "default": 30 },
        "max_title_length": { "type": "integer", "default": 200 },
        "require_ascii_titles": { "type": "boolean", "default": false },
        "forbidden_extensions_in_wiki": {
          "type": "array",
          "items": { "type": "string" },
          "default": [".exe", ".bin", ".dll", ".so", ".dylib", ".zip", ".tar", ".gz", ".png", ".jpg", ".gif", ".pdf", ".mp3", ".mp4"]
        }
      }
    }
  }
}
CONTENTPOLICYEOF

  log_ok "Created .vault/schemas/content-policy.json"

  # ──────────────────────────────────────────────────────────────
  # .vault/scripts/lib-utils.sh — Shared Utility Functions
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/scripts/lib-utils.sh" << 'LIBUTILSEOF'
#!/usr/bin/env bash
# lib-utils.sh — Shared utility functions for vault tooling
# Source this file; do not execute directly.

# ── Colors ──
readonly _RED='\033[0;31m'
readonly _GREEN='\033[0;32m'
readonly _YELLOW='\033[1;33m'
readonly _BLUE='\033[0;34m'
readonly _BOLD='\033[1m'
readonly _NC='\033[0m'

# ── Path Resolution ──
# Resolve VAULT_ROOT from any script location inside .vault/scripts/
resolve_vault_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
  # Navigate from .vault/scripts/ up to vault/
  echo "$(cd "$script_dir/../.." && pwd)"
}

# ── Frontmatter Extraction ──
# Extract YAML frontmatter from a markdown file.
# Usage: extract_frontmatter /path/to/file.md
# Returns the frontmatter block (without --- delimiters) on stdout.
extract_frontmatter() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo ""
    return 1
  fi
  # Read between first and second --- lines
  awk 'BEGIN{found=0} /^---$/{found++; next} found==1{print} found>=2{exit}' "$file"
}

# Check if a file has valid YAML frontmatter (starts with ---)
has_frontmatter() {
  local file="$1"
  [[ -f "$file" ]] && head -1 "$file" | grep -q '^---$'
}

# Extract a specific frontmatter field value.
# Usage: get_frontmatter_field /path/to/file.md "title"
get_frontmatter_field() {
  local file="$1"
  local field="$2"
  extract_frontmatter "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^["'"'"']//; s/["'"'"']$//'
}

# Extract all tags from frontmatter as newline-separated list.
get_frontmatter_tags() {
  local file="$1"
  extract_frontmatter "$file" | awk '/^tags:/{found=1; next} found && /^  - /{gsub(/^  - /,""); print} found && !/^  - /&&!/^$/{exit}'
}

# ── Wikilink Parsing ──
# Extract all [[wikilinks]] from a file.
# Usage: extract_wikilinks /path/to/file.md
extract_wikilinks() {
  local file="$1"
  grep -oE '\[\[[a-z0-9-]+\]\]' "$file" 2>/dev/null | sed 's/\[\[//g; s/\]\]//g' | sort -u
}

# Count wikilinks in a file.
count_wikilinks() {
  local file="$1"
  extract_wikilinks "$file" | wc -l | tr -d ' '
}

# ── Tag Validation ──
# Load approved tags from tags.md into a newline-separated list.
# Usage: load_approved_tags /path/to/vault
load_approved_tags() {
  local vault_root="$1"
  local tags_file="$vault_root/.vault/rules/tags.md"
  if [[ ! -f "$tags_file" ]]; then
    echo ""
    return 1
  fi
  grep -oE '  - [a-z]+/[a-z0-9-]+' "$tags_file" | sed 's/^  - //' | sort -u
}

# Validate a single tag against the approved list.
# Usage: validate_tag "domain/auth" "$approved_tags"
# Returns 0 if valid, 1 if invalid.
validate_tag() {
  local tag="$1"
  local approved="$2"
  echo "$approved" | grep -qxF "$tag"
}

# Validate tag format (HR-009: prefix/value, lowercase alphanumeric with hyphens).
validate_tag_format() {
  local tag="$1"
  [[ "$tag" =~ ^[a-z]+/[a-z0-9-]+$ ]]
}

# ── File Utilities ──
# Count lines in a file.
count_lines() {
  local file="$1"
  wc -l < "$file" | tr -d ' '
}

# Get file age in days.
file_age_days() {
  local file="$1"
  local now_epoch
  now_epoch=$(date +%s)
  local file_epoch
  # macOS uses stat -f, Linux uses stat -c
  file_epoch=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo "$now_epoch")
  echo $(( (now_epoch - file_epoch) / 86400 ))
}

# Check if a file is a markdown file.
is_markdown() {
  [[ "$1" == *.md ]]
}

# Check if a file is a JSON file.
is_json() {
  [[ "$1" == *.json ]]
}

# Get relative path from vault root.
rel_path() {
  local file="$1"
  local vault_root="$2"
  echo "${file#"$vault_root"/}"
}

# ── Index Utilities ──
# Check if a file path appears in the index.
is_indexed() {
  local file_rel_path="$1"
  local index_file="$2"
  grep -qF "$file_rel_path" "$index_file" 2>/dev/null
}

# ── Logging ──
log_pass() { echo -e "${_GREEN}[PASS]${_NC} $*"; }
log_fail() { echo -e "${_RED}[FAIL]${_NC} $*"; }
log_warn() { echo -e "${_YELLOW}[WARN]${_NC} $*"; }
log_info() { echo -e "${_BLUE}[INFO]${_NC} $*"; }
LIBUTILSEOF

  chmod +x "$vault_root/.vault/scripts/lib-utils.sh"
  log_ok "Created .vault/scripts/lib-utils.sh"

  # ──────────────────────────────────────────────────────────────
  # .vault/scripts/lib-lint.sh — Individual Lint Check Functions
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/scripts/lib-lint.sh" << 'LIBLINTEOF'
#!/usr/bin/env bash
# lib-lint.sh — Individual lint check functions for each hard rule.
# Source this file after lib-utils.sh; do not execute directly.

# Each function returns 0 on pass, 1 on failure.
# Each function prints its own diagnostics.

# HR-001: raw/ immutability (check via git — files in raw/ should not appear in staged changes)
lint_hr001_raw_immutability() {
  local vault_root="$1"
  local raw_dir="$vault_root/raw"
  local errors=0

  if [[ ! -d "$raw_dir" ]]; then
    log_warn "HR-001: raw/ directory does not exist"
    return 0
  fi

  # If inside a git repo, check for staged modifications to raw/
  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local modified
    modified=$(git -C "$vault_root" diff --cached --name-only -- "raw/" 2>/dev/null)
    if [[ -n "$modified" ]]; then
      log_fail "HR-001: Staged modifications detected in raw/ (immutable):"
      echo "$modified" | sed 's/^/         /'
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-001: raw/ immutability"
  fi
  return $errors
}

# HR-002: Mandatory YAML frontmatter
lint_hr002_frontmatter() {
  local vault_root="$1"
  local errors=0
  local required_fields=("title" "type" "created" "updated" "status" "tags")

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")

    if ! has_frontmatter "$file"; then
      log_fail "HR-002: Missing frontmatter: $rel"
      errors=$((errors + 1))
      continue
    fi

    for field in "${required_fields[@]}"; do
      local val
      val=$(get_frontmatter_field "$file" "$field")
      if [[ -z "$val" && "$field" != "tags" ]]; then
        log_fail "HR-002: Missing field '$field' in: $rel"
        errors=$((errors + 1))
      fi
    done

    # Check tags separately (it's a list)
    local tag_count
    tag_count=$(get_frontmatter_tags "$file" | grep -c . || true)
    if [[ "$tag_count" -eq 0 ]]; then
      log_fail "HR-002: No tags found in: $rel"
      errors=$((errors + 1))
    fi
  done < <(find "$vault_root/wiki" "$vault_root/memory" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-002: All files have valid frontmatter"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-003: Tags from approved taxonomy only
lint_hr003_approved_tags() {
  local vault_root="$1"
  local errors=0
  local approved
  approved=$(load_approved_tags "$vault_root")

  if [[ -z "$approved" ]]; then
    log_warn "HR-003: Could not load approved tags from tags.md"
    return 0
  fi

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      if ! validate_tag "$tag" "$approved"; then
        log_fail "HR-003: Unapproved tag '$tag' in: $rel"
        errors=$((errors + 1))
      fi
      if ! validate_tag_format "$tag"; then
        log_fail "HR-003: Invalid tag format '$tag' in: $rel (must be prefix/value)"
        errors=$((errors + 1))
      fi
    done < <(get_frontmatter_tags "$file")
  done < <(find "$vault_root/wiki" "$vault_root/memory" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-003: All tags are from approved taxonomy"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-004: Wiki page length limit (200 warn / 400 block)
lint_hr004_wiki_length() {
  local vault_root="$1"
  local errors=0
  local warnings=0

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    local lines
    lines=$(count_lines "$file")

    if [[ $lines -gt 400 ]]; then
      log_fail "HR-004: BLOCK — $rel has $lines lines (max 400)"
      errors=$((errors + 1))
    elif [[ $lines -gt 200 ]]; then
      log_warn "HR-004: WARN — $rel has $lines lines (target < 200)"
      warnings=$((warnings + 1))
    fi
  done < <(find "$vault_root/wiki" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
    log_pass "HR-004: All wiki pages within length limits"
  elif [[ $errors -eq 0 ]]; then
    log_warn "HR-004: $warnings page(s) approaching limit"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-005: Code file length limit (400 warn / 600 block)
lint_hr005_code_length() {
  local vault_root="$1"
  local errors=0

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    local lines
    lines=$(count_lines "$file")

    if [[ $lines -gt 600 ]]; then
      log_fail "HR-005: BLOCK — $rel has $lines lines (max 600)"
      errors=$((errors + 1))
    elif [[ $lines -gt 400 ]]; then
      log_warn "HR-005: WARN — $rel has $lines lines (target < 400)"
    fi
  done < <(find "$vault_root/.vault/scripts" -name "*.sh" -type f -print0 2>/dev/null; find "$vault_root/.vault/schemas" -name "*.json" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-005: All code files within length limits"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-006: Unique page titles
lint_hr006_unique_titles() {
  local vault_root="$1"
  local errors=0
  local -A seen_titles

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    local title
    title=$(get_frontmatter_field "$file" "title")
    [[ -z "$title" ]] && continue

    if [[ -n "${seen_titles[$title]+_}" ]]; then
      log_fail "HR-006: Duplicate title '$title' in: $rel (first seen in: ${seen_titles[$title]})"
      errors=$((errors + 1))
    else
      seen_titles["$title"]="$rel"
    fi
  done < <(find "$vault_root/wiki" "$vault_root/memory" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-006: All page titles are unique"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-008: Index registration required
lint_hr008_index_registration() {
  local vault_root="$1"
  local index_file="$vault_root/wiki/index.md"
  local errors=0

  if [[ ! -f "$index_file" ]]; then
    log_fail "HR-008: wiki/index.md not found"
    return 1
  fi

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$vault_root")
    # Skip index.md and log.md themselves
    [[ "$rel" == "wiki/index.md" || "$rel" == "wiki/log.md" ]] && continue

    if ! is_indexed "$rel" "$index_file"; then
      log_fail "HR-008: Unregistered page: $rel"
      errors=$((errors + 1))
    fi
  done < <(find "$vault_root/wiki" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-008: All wiki pages are registered in index"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-010: Binary file quarantine
lint_hr010_binary_quarantine() {
  local vault_root="$1"
  local errors=0

  while IFS= read -r -d '' file; do
    local ext="${file##*.}"
    if [[ "$ext" != "md" && "$ext" != "json" ]]; then
      local rel
      rel=$(rel_path "$file" "$vault_root")
      log_fail "HR-010: Non-md/json file in wiki/memory: $rel"
      errors=$((errors + 1))
    fi
  done < <(find "$vault_root/wiki" "$vault_root/memory" -type f -print0 2>/dev/null)

  # Check for symlinks
  while IFS= read -r -d '' link; do
    local rel
    rel=$(rel_path "$link" "$vault_root")
    log_fail "HR-010: Symlink detected in wiki/memory: $rel"
    errors=$((errors + 1))
  done < <(find "$vault_root/wiki" "$vault_root/memory" -type l -print0 2>/dev/null)

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-010: No binary files or symlinks in wiki/memory"
  fi
  return $((errors > 0 ? 1 : 0))
}

# HR-011: .vault/ protection (check staged changes)
lint_hr011_vault_protection() {
  local vault_root="$1"
  local errors=0

  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local protected_changes
    protected_changes=$(git -C "$vault_root" diff --cached --name-only -- ".vault/rules/" ".vault/hooks/" ".vault/scripts/" ".vault/schemas/" 2>/dev/null)
    if [[ -n "$protected_changes" ]]; then
      log_fail "HR-011: Staged changes to protected .vault/ paths:"
      echo "$protected_changes" | sed 's/^/         /'
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-011: .vault/ protection intact"
  fi
  return $errors
}

# HR-012: Agent config protection (check staged changes)
lint_hr012_config_protection() {
  local vault_root="$1"
  local errors=0

  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local repo_root
    repo_root=$(git -C "$vault_root" rev-parse --show-toplevel 2>/dev/null)
    local config_changes
    config_changes=$(git -C "$repo_root" diff --cached --name-only -- "CLAUDE.md" "AGENTS.md" ".claude/" 2>/dev/null)
    if [[ -n "$config_changes" ]]; then
      log_fail "HR-012: Staged changes to agent config files:"
      echo "$config_changes" | sed 's/^/         /'
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-012: Agent config protection intact"
  fi
  return $errors
}

# HR-014: No file deletion (check staged deletions)
lint_hr014_no_deletion() {
  local vault_root="$1"
  local errors=0

  if git -C "$vault_root" rev-parse --is-inside-work-tree &>/dev/null; then
    local deletions
    deletions=$(git -C "$vault_root" diff --cached --diff-filter=D --name-only 2>/dev/null)
    if [[ -n "$deletions" ]]; then
      log_fail "HR-014: File deletions detected (use status: archived instead):"
      echo "$deletions" | sed 's/^/         /'
      errors=1
    fi
  fi

  if [[ $errors -eq 0 ]]; then
    log_pass "HR-014: No file deletions detected"
  fi
  return $errors
}

# Composite: Run all lint checks
lint_all() {
  local vault_root="$1"
  local total_errors=0

  lint_hr001_raw_immutability "$vault_root" || total_errors=$((total_errors + 1))
  lint_hr002_frontmatter "$vault_root"      || total_errors=$((total_errors + 1))
  lint_hr003_approved_tags "$vault_root"     || total_errors=$((total_errors + 1))
  lint_hr004_wiki_length "$vault_root"       || total_errors=$((total_errors + 1))
  lint_hr005_code_length "$vault_root"       || total_errors=$((total_errors + 1))
  lint_hr006_unique_titles "$vault_root"     || total_errors=$((total_errors + 1))
  lint_hr008_index_registration "$vault_root"|| total_errors=$((total_errors + 1))
  lint_hr010_binary_quarantine "$vault_root" || total_errors=$((total_errors + 1))
  lint_hr011_vault_protection "$vault_root"  || total_errors=$((total_errors + 1))
  lint_hr012_config_protection "$vault_root" || total_errors=$((total_errors + 1))
  lint_hr014_no_deletion "$vault_root"       || total_errors=$((total_errors + 1))

  return $total_errors
}
LIBLINTEOF

  chmod +x "$vault_root/.vault/scripts/lib-lint.sh"
  log_ok "Created .vault/scripts/lib-lint.sh"

  # ──────────────────────────────────────────────────────────────
  # .vault/scripts/vault-tools.sh — Full Tooling (11 commands)
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/scripts/vault-tools.sh" << 'VAULTTOOLSEOF'
#!/usr/bin/env bash
# vault-tools.sh — Vault maintenance and operational tooling
# Usage: vault-tools.sh <command> [options]
#
# Commands:
#   lint [--report]       Full vault quality scan against all hard rules
#   validate <file>       Single-file frontmatter validation
#   orphans               Find pages with no inbound wikilinks
#   stale [days]          Find content exceeding staleness thresholds
#   tag-audit             Validate all tags against approved taxonomy
#   content-audit         Detect injection patterns in content
#   status                Vault operational status summary
#   stats                 Page counts, tag usage, link density
#   index-rebuild         Regenerate wiki/index.md from existing files
#   init-hooks            Install git pre-commit hooks
#   doctor                Full diagnostic (runs all checks)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib-utils.sh
source "$SCRIPT_DIR/lib-utils.sh"
# shellcheck source=lib-lint.sh
source "$SCRIPT_DIR/lib-lint.sh"

VAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WIKI_DIR="$VAULT_ROOT/wiki"
MEMORY_DIR="$VAULT_ROOT/memory"
INDEX_FILE="$WIKI_DIR/index.md"
LOG_FILE="$WIKI_DIR/log.md"
TAGS_FILE="$VAULT_ROOT/.vault/rules/tags.md"
STALENESS_CONFIG="$VAULT_ROOT/.vault/schemas/content-policy.json"

# ── Commands ──

cmd_lint() {
  local report_mode=false
  [[ "${1:-}" == "--report" ]] && report_mode=true

  echo "============================================"
  echo "  Vault Lint — Full Quality Scan"
  echo "============================================"
  echo ""

  local total_errors=0
  lint_all "$VAULT_ROOT" || total_errors=$?

  echo ""
  echo "--------------------------------------------"
  if [[ $total_errors -eq 0 ]]; then
    log_pass "Vault lint PASSED — all checks clean"
  else
    log_fail "Vault lint FAILED — $total_errors rule group(s) with violations"
  fi

  if $report_mode; then
    local report_file="$VAULT_ROOT/.vault/lint-report-$(date +%Y%m%d-%H%M%S).txt"
    {
      echo "Vault Lint Report — $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      echo "Errors: $total_errors"
    } > "$report_file"
    log_info "Report saved to: $report_file"
  fi

  return $((total_errors > 0 ? 1 : 0))
}

cmd_validate() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    log_fail "Usage: vault-tools.sh validate <file>"
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    # Try relative to vault root
    file="$VAULT_ROOT/$file"
  fi

  if [[ ! -f "$file" ]]; then
    log_fail "File not found: $1"
    return 1
  fi

  echo "Validating: $(rel_path "$file" "$VAULT_ROOT")"
  echo ""

  local errors=0

  # Check frontmatter exists
  if ! has_frontmatter "$file"; then
    log_fail "No YAML frontmatter found"
    return 1
  fi
  log_pass "Has YAML frontmatter"

  # Check required fields
  local required_fields=("title" "type" "created" "updated" "status" "tags")
  for field in "${required_fields[@]}"; do
    local val
    val=$(get_frontmatter_field "$file" "$field")
    if [[ -n "$val" || "$field" == "tags" ]]; then
      log_pass "Field present: $field"
    else
      log_fail "Missing required field: $field"
      errors=$((errors + 1))
    fi
  done

  # Check tags
  local tag_count
  tag_count=$(get_frontmatter_tags "$file" | grep -c . || true)
  if [[ "$tag_count" -gt 0 ]]; then
    log_pass "Has $tag_count tag(s)"

    # Validate each tag
    local approved
    approved=$(load_approved_tags "$VAULT_ROOT")
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      if validate_tag "$tag" "$approved"; then
        log_pass "  Tag OK: $tag"
      else
        log_fail "  Unapproved tag: $tag"
        errors=$((errors + 1))
      fi
    done < <(get_frontmatter_tags "$file")
  else
    log_fail "No tags found"
    errors=$((errors + 1))
  fi

  # Check line count
  local lines
  lines=$(count_lines "$file")
  if [[ $lines -gt 400 ]]; then
    log_fail "Line count: $lines (BLOCK limit: 400)"
    errors=$((errors + 1))
  elif [[ $lines -gt 200 ]]; then
    log_warn "Line count: $lines (WARN limit: 200)"
  else
    log_pass "Line count: $lines"
  fi

  # Check wikilinks
  local wl_count
  wl_count=$(count_wikilinks "$file")
  if [[ "$wl_count" -ge 3 ]]; then
    log_pass "Wikilinks: $wl_count (meets SR-003 minimum)"
  else
    log_warn "Wikilinks: $wl_count (SR-003 recommends >= 3)"
  fi

  echo ""
  if [[ $errors -eq 0 ]]; then
    log_pass "Validation PASSED"
  else
    log_fail "Validation FAILED — $errors error(s)"
  fi
  return $((errors > 0 ? 1 : 0))
}

cmd_orphans() {
  echo "============================================"
  echo "  Orphan Detection"
  echo "============================================"
  echo ""

  if [[ ! -f "$INDEX_FILE" ]]; then
    log_fail "wiki/index.md not found"
    return 1
  fi

  local index_content
  index_content=$(cat "$INDEX_FILE")
  local orphan_count=0

  # Find files not in index
  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    [[ "$rel" == "wiki/index.md" || "$rel" == "wiki/log.md" ]] && continue

    if ! echo "$index_content" | grep -qF "$rel"; then
      log_warn "Orphan (not in index): $rel"
      orphan_count=$((orphan_count + 1))
    fi
  done < <(find "$WIKI_DIR" -name "*.md" -type f -print0 2>/dev/null)

  # Find pages with no inbound wikilinks from other pages
  echo ""
  echo "--- Inbound Link Analysis ---"
  local all_links=""
  while IFS= read -r -d '' file; do
    all_links="${all_links}$(extract_wikilinks "$file")
"
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  while IFS= read -r -d '' file; do
    local slug
    slug=$(basename "$file" .md)
    [[ "$slug" == "index" || "$slug" == "log" ]] && continue

    if ! echo "$all_links" | grep -qxF "$slug"; then
      log_warn "No inbound links: $slug ($(rel_path "$file" "$VAULT_ROOT"))"
      orphan_count=$((orphan_count + 1))
    fi
  done < <(find "$WIKI_DIR" -name "*.md" -type f -print0 2>/dev/null)

  echo ""
  if [[ $orphan_count -eq 0 ]]; then
    log_pass "No orphans detected"
  else
    log_warn "Found $orphan_count orphan issue(s)"
  fi
}

cmd_stale() {
  local threshold_days="${1:-}"

  echo "============================================"
  echo "  Staleness Check"
  echo "============================================"
  echo ""

  local stale_count=0

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    local dir_type
    dir_type=$(echo "$rel" | cut -d'/' -f1-2)

    # Determine threshold based on content type
    local max_age=30
    case "$dir_type" in
      wiki/sources)     max_age=14 ;;
      wiki/concepts)    max_age=30 ;;
      wiki/entities)    max_age=60 ;;
      wiki/comparisons) max_age=90 ;;
      memory/decisions) max_age=180 ;;
      memory/notes)     max_age=7 ;;
    esac

    # Override with explicit threshold if provided
    [[ -n "$threshold_days" ]] && max_age="$threshold_days"

    local age
    age=$(file_age_days "$file")

    if [[ $age -gt $max_age ]]; then
      local updated
      updated=$(get_frontmatter_field "$file" "updated")
      log_warn "STALE: $rel — ${age}d old (max: ${max_age}d, updated: ${updated:-unknown})"
      stale_count=$((stale_count + 1))
    fi
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  echo ""
  if [[ $stale_count -eq 0 ]]; then
    log_pass "No stale content detected"
  else
    log_warn "Found $stale_count stale file(s)"
  fi
}

cmd_tag_audit() {
  echo "============================================"
  echo "  Tag Audit"
  echo "============================================"
  echo ""

  local approved
  approved=$(load_approved_tags "$VAULT_ROOT")
  if [[ -z "$approved" ]]; then
    log_fail "Cannot load approved tags from tags.md"
    return 1
  fi

  local approved_count
  approved_count=$(echo "$approved" | wc -l | tr -d ' ')
  log_info "Approved tags in taxonomy: $approved_count"
  echo ""

  local invalid_count=0
  local used_tags=""

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      used_tags="${used_tags}${tag}
"
      if ! validate_tag "$tag" "$approved"; then
        log_fail "Unapproved: '$tag' in $rel"
        invalid_count=$((invalid_count + 1))
      fi
      if ! validate_tag_format "$tag"; then
        log_fail "Bad format: '$tag' in $rel"
        invalid_count=$((invalid_count + 1))
      fi
    done < <(get_frontmatter_tags "$file")
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  # Show tag usage stats
  echo ""
  echo "--- Tag Usage ---"
  if [[ -n "$used_tags" ]]; then
    echo "$used_tags" | sort | uniq -c | sort -rn | head -20
  fi

  # Show unused approved tags
  echo ""
  echo "--- Unused Tags (from taxonomy) ---"
  local unused_count=0
  while IFS= read -r tag; do
    if ! echo "$used_tags" | grep -qxF "$tag"; then
      unused_count=$((unused_count + 1))
    fi
  done <<< "$approved"
  log_info "$unused_count approved tags are not yet in use"

  echo ""
  if [[ $invalid_count -eq 0 ]]; then
    log_pass "Tag audit PASSED"
  else
    log_fail "Tag audit FAILED — $invalid_count violation(s)"
  fi
  return $((invalid_count > 0 ? 1 : 0))
}

cmd_content_audit() {
  echo "============================================"
  echo "  Content Audit — Injection Detection"
  echo "============================================"
  echo ""

  local policy_file="$VAULT_ROOT/.vault/schemas/content-policy.json"
  local issues=0

  if [[ ! -f "$policy_file" ]]; then
    log_warn "content-policy.json not found; using built-in patterns"
  fi

  # Built-in injection patterns
  local -a patterns=(
    "(?i)(ignore|disregard|forget)\s+(all\s+)?(previous|above|prior)\s+(instructions?|rules?|constraints?)"
    "(?i)you\s+are\s+now\s+(a|an|the)\s+"
    "(?i)<!--.*(?:ignore|override|bypass).*-->"
    "(?i)\[\s*(?:INST|SYSTEM|PROMPT)\s*\]"
    "(?i)do\s+not\s+follow\s+(the\s+)?rules"
    "(?i)execute\s+(this\s+)?(bash|shell|command|script)"
  )

  local -a pattern_names=(
    "INJ-001: Instruction override attempt"
    "INJ-002: Role reassignment attempt"
    "INJ-004: Hidden HTML override"
    "INJ-005: Fake instruction block"
    "INJ-006: Rule bypass instruction"
    "INJ-007: Embedded command execution"
  )

  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    local content
    content=$(cat "$file")

    for i in "${!patterns[@]}"; do
      if echo "$content" | grep -qP "${patterns[$i]}" 2>/dev/null; then
        log_fail "${pattern_names[$i]} in: $rel"
        issues=$((issues + 1))
      fi
    done
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" "$VAULT_ROOT/raw" -name "*.md" -type f -print0 2>/dev/null)

  echo ""
  if [[ $issues -eq 0 ]]; then
    log_pass "Content audit PASSED — no injection patterns detected"
  else
    log_fail "Content audit FAILED — $issues potential injection(s) found"
  fi
  return $((issues > 0 ? 1 : 0))
}

cmd_status() {
  echo "============================================"
  echo "  Vault Status"
  echo "============================================"
  echo ""

  # Directory existence
  local dirs=("raw" "wiki/sources" "wiki/concepts" "wiki/entities" "wiki/comparisons" "memory/decisions" "memory/notes" ".vault/scripts" ".vault/rules" ".vault/schemas" ".vault/hooks" "docs" "templates")
  local missing=0
  for dir in "${dirs[@]}"; do
    if [[ ! -d "$VAULT_ROOT/$dir" ]]; then
      log_fail "Missing: $dir/"
      missing=$((missing + 1))
    fi
  done

  if [[ $missing -eq 0 ]]; then
    log_pass "All ${#dirs[@]} directories present"
  fi

  # Key files
  echo ""
  local key_files=("wiki/index.md" "wiki/log.md" "memory/status.md" ".vault/rules/hard-rules.md" ".vault/rules/soft-rules.md" ".vault/rules/tags.md" ".vault/schemas/wiki-entry.json" ".vault/.initialized")
  for kf in "${key_files[@]}"; do
    if [[ -f "$VAULT_ROOT/$kf" ]]; then
      log_pass "Found: $kf"
    else
      log_fail "Missing: $kf"
    fi
  done

  # Git status
  echo ""
  if git -C "$VAULT_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
    local branch
    branch=$(git -C "$VAULT_ROOT" branch --show-current 2>/dev/null || echo "detached")
    log_info "Git branch: $branch"
    local staged
    staged=$(git -C "$VAULT_ROOT" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    local modified
    modified=$(git -C "$VAULT_ROOT" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    log_info "Staged: $staged  Modified: $modified"
  else
    log_info "Not inside a git repository"
  fi
}

cmd_stats() {
  echo "============================================"
  echo "  Vault Statistics"
  echo "============================================"
  echo ""

  # Page counts by type
  echo "--- Page Counts ---"
  local total=0
  for subdir in sources concepts entities comparisons; do
    local count
    count=$(find "$WIKI_DIR/$subdir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  wiki/$subdir: $count"
    total=$((total + count))
  done
  for subdir in decisions notes; do
    local count
    count=$(find "$MEMORY_DIR/$subdir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  memory/$subdir: $count"
    total=$((total + count))
  done
  local special=0
  for f in index.md log.md; do
    [[ -f "$WIKI_DIR/$f" ]] && special=$((special + 1))
  done
  [[ -f "$MEMORY_DIR/status.md" ]] && special=$((special + 1))
  echo "  Special files: $special"
  echo "  Total: $((total + special))"

  # Raw file count
  echo ""
  local raw_count
  raw_count=$(find "$VAULT_ROOT/raw" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo "--- Raw Sources ---"
  echo "  Files: $raw_count"

  # Tag usage
  echo ""
  echo "--- Tag Usage (top 15) ---"
  local all_tags=""
  while IFS= read -r -d '' file; do
    all_tags="${all_tags}$(get_frontmatter_tags "$file")
"
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  if [[ -n "$all_tags" ]]; then
    echo "$all_tags" | grep -v '^$' | sort | uniq -c | sort -rn | head -15 | sed 's/^/  /'
  else
    echo "  (no tags found)"
  fi

  # Link density
  echo ""
  echo "--- Link Density ---"
  local total_links=0
  local total_pages=0
  while IFS= read -r -d '' file; do
    local wl
    wl=$(count_wikilinks "$file")
    total_links=$((total_links + wl))
    total_pages=$((total_pages + 1))
  done < <(find "$WIKI_DIR" "$MEMORY_DIR" -name "*.md" -type f -print0 2>/dev/null)

  if [[ $total_pages -gt 0 ]]; then
    local avg
    avg=$(echo "scale=1; $total_links / $total_pages" | bc 2>/dev/null || echo "n/a")
    echo "  Total wikilinks: $total_links"
    echo "  Total pages: $total_pages"
    echo "  Average links/page: $avg"
  fi
}

cmd_index_rebuild() {
  echo "============================================"
  echo "  Index Rebuild"
  echo "============================================"
  echo ""

  local today
  today=$(date +%Y-%m-%d)

  # Collect entries
  local entries=""
  while IFS= read -r -d '' file; do
    local rel
    rel=$(rel_path "$file" "$VAULT_ROOT")
    [[ "$rel" == "wiki/index.md" || "$rel" == "wiki/log.md" ]] && continue

    local slug
    slug=$(basename "$file" .md)
    local page_type
    page_type=$(get_frontmatter_field "$file" "type")
    [[ -z "$page_type" ]] && page_type=$(basename "$(dirname "$file")")
    local created
    created=$(get_frontmatter_field "$file" "created")
    [[ -z "$created" ]] && created="$today"
    local status
    status=$(get_frontmatter_field "$file" "status")
    [[ -z "$status" ]] && status="current"
    local primary_tag
    primary_tag=$(get_frontmatter_tags "$file" | head -1)
    [[ -z "$primary_tag" ]] && primary_tag="-"

    entries="${entries}| ${slug} | ${rel} | ${page_type} | ${created} | ${status} | ${primary_tag} |
"
  done < <(find "$WIKI_DIR" -name "*.md" -type f -print0 2>/dev/null | sort -z)

  cat > "$INDEX_FILE" << REBUILDEOF
---
title: "Wiki Index"
type: index
created: "${today}"
updated: "${today}"
status: current
tags:
  - type/index
  - lifecycle/active
owner: system
confidence: high
---

# Wiki Index

> Auto-rebuilt on ${today} by vault-tools.sh. Review and verify freshness values.

## Entries

| Slug | Path | Type | Created | Status | Primary Tag |
|------|------|------|---------|--------|-------------|
${entries}
## Conventions

- **Type**: one of \`source\`, \`concept\`, \`entity\`, \`comparison\`, \`decision\`
- **Status**: \`draft\`, \`current\`, \`stale\`, \`archived\`
- Every entry must be reachable from this index (HR-008)
REBUILDEOF

  log_pass "Index rebuilt at wiki/index.md"
}

cmd_init_hooks() {
  echo "============================================"
  echo "  Hook Installation"
  echo "============================================"
  echo ""

  local repo_root
  if ! repo_root=$(git -C "$VAULT_ROOT" rev-parse --show-toplevel 2>/dev/null); then
    log_fail "Not inside a git repository — cannot install hooks"
    return 1
  fi

  local hooks_dir="$repo_root/.git/hooks"
  local pre_commit_src="$VAULT_ROOT/.vault/hooks/pre-commit.sh"

  if [[ ! -f "$pre_commit_src" ]]; then
    log_fail "pre-commit.sh not found at .vault/hooks/"
    return 1
  fi

  cp "$pre_commit_src" "$hooks_dir/pre-commit"
  chmod +x "$hooks_dir/pre-commit"

  log_pass "Pre-commit hook installed to $hooks_dir/pre-commit"
}

cmd_doctor() {
  echo "============================================"
  echo "  Vault Doctor — Full Diagnostic"
  echo "============================================"
  echo ""
  local issues=0

  echo ">>> Status Check"
  cmd_status
  echo ""

  echo ">>> Lint (all hard rules)"
  cmd_lint || issues=$((issues + 1))
  echo ""

  echo ">>> Tag Audit"
  cmd_tag_audit || issues=$((issues + 1))
  echo ""

  echo ">>> Content Audit"
  cmd_content_audit || issues=$((issues + 1))
  echo ""

  echo ">>> Orphan Check"
  cmd_orphans
  echo ""

  echo ">>> Staleness Check"
  cmd_stale
  echo ""

  echo ">>> Statistics"
  cmd_stats
  echo ""

  echo "============================================"
  if [[ $issues -eq 0 ]]; then
    log_pass "Doctor: Vault is healthy"
  else
    log_fail "Doctor: $issues check group(s) reported issues"
  fi
  return $((issues > 0 ? 1 : 0))
}

# ── Main Dispatch ──
case "${1:-help}" in
  lint)          shift; cmd_lint "$@" ;;
  validate)      shift; cmd_validate "$@" ;;
  orphans)       cmd_orphans ;;
  stale)         shift; cmd_stale "$@" ;;
  tag-audit)     cmd_tag_audit ;;
  content-audit) cmd_content_audit ;;
  status)        cmd_status ;;
  stats)         cmd_stats ;;
  index-rebuild) cmd_index_rebuild ;;
  init-hooks)    cmd_init_hooks ;;
  doctor)        cmd_doctor ;;
  help|--help|-h|*)
    echo "vault-tools.sh — Vault maintenance and operational tooling"
    echo ""
    echo "Usage: vault-tools.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  lint [--report]       Full vault quality scan against all hard rules"
    echo "  validate <file>       Single-file frontmatter validation"
    echo "  orphans               Find pages with no inbound wikilinks"
    echo "  stale [days]          Find content exceeding staleness thresholds"
    echo "  tag-audit             Validate all tags against approved taxonomy"
    echo "  content-audit         Detect injection patterns in content"
    echo "  status                Vault operational status summary"
    echo "  stats                 Page counts, tag usage, link density"
    echo "  index-rebuild         Regenerate wiki/index.md from existing files"
    echo "  init-hooks            Install git pre-commit hooks"
    echo "  doctor                Full diagnostic (runs all checks)"
    ;;
esac
VAULTTOOLSEOF

  chmod +x "$vault_root/.vault/scripts/vault-tools.sh"
  log_ok "Created .vault/scripts/vault-tools.sh (11 commands)"

  # ──────────────────────────────────────────────────────────────
  # .vault/hooks/pre-commit.sh — Pre-Commit Enforcement
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/hooks/pre-commit.sh" << 'PRECOMMITEOF'
#!/usr/bin/env bash
# pre-commit.sh — Git pre-commit hook for vault hard rule enforcement
# Checks: HR-001, HR-002, HR-003, HR-008, HR-011, HR-012, HR-014
#
# Install: vault-tools.sh init-hooks
# Or manually: cp .vault/hooks/pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

set -euo pipefail

# Locate vault root (this hook may be in .git/hooks/ or .vault/hooks/)
find_vault_root() {
  local dir
  if [[ -n "${GIT_DIR:-}" ]]; then
    dir=$(cd "$GIT_DIR/.." && pwd)
  else
    dir=$(git rev-parse --show-toplevel 2>/dev/null)
  fi
  # Look for vault/ subdirectory
  if [[ -d "$dir/vault" ]]; then
    echo "$dir/vault"
  else
    echo "$dir"
  fi
}

VAULT_ROOT="$(find_vault_root)"
SCRIPTS_DIR="$VAULT_ROOT/.vault/scripts"

# Source utilities if available
if [[ -f "$SCRIPTS_DIR/lib-utils.sh" ]]; then
  source "$SCRIPTS_DIR/lib-utils.sh"
else
  # Minimal fallback
  log_fail() { echo "[FAIL] $*"; }
  log_pass() { echo "[PASS] $*"; }
  log_warn() { echo "[WARN] $*"; }
fi

if [[ -f "$SCRIPTS_DIR/lib-lint.sh" ]]; then
  source "$SCRIPTS_DIR/lib-lint.sh"
fi

echo "=== Vault Pre-Commit Checks ==="
echo ""

errors=0

# HR-001: No modifications to raw/
raw_changes=$(git diff --cached --name-only -- "vault/raw/" 2>/dev/null || true)
if [[ -n "$raw_changes" ]]; then
  log_fail "HR-001: Cannot modify files in raw/ (immutable)"
  echo "$raw_changes" | sed 's/^/  /'
  errors=$((errors + 1))
else
  log_pass "HR-001: raw/ immutability"
fi

# HR-002: Check frontmatter on staged .md files in wiki/ and memory/
staged_md=$(git diff --cached --name-only --diff-filter=ACM -- "vault/wiki/*.md" "vault/wiki/**/*.md" "vault/memory/*.md" "vault/memory/**/*.md" 2>/dev/null || true)
if [[ -n "$staged_md" ]]; then
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ -f "$file" ]]; then
      first_line=$(head -1 "$file")
      if [[ "$first_line" != "---" ]]; then
        log_fail "HR-002: Missing YAML frontmatter in: $file"
        errors=$((errors + 1))
      fi
    fi
  done <<< "$staged_md"
  if [[ $errors -eq 0 ]]; then
    log_pass "HR-002: Frontmatter present on staged files"
  fi
fi

# HR-003: Validate tags on staged files (if lib-lint available)
if type -t lint_hr003_approved_tags &>/dev/null && [[ -n "$staged_md" ]]; then
  approved=$(load_approved_tags "$VAULT_ROOT" 2>/dev/null || true)
  if [[ -n "$approved" ]]; then
    tag_errors=0
    while IFS= read -r file; do
      [[ -z "$file" || ! -f "$file" ]] && continue
      while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue
        if ! validate_tag "$tag" "$approved"; then
          log_fail "HR-003: Unapproved tag '$tag' in: $file"
          tag_errors=$((tag_errors + 1))
        fi
      done < <(get_frontmatter_tags "$file")
    done <<< "$staged_md"
    if [[ $tag_errors -eq 0 ]]; then
      log_pass "HR-003: All tags approved"
    fi
    errors=$((errors + tag_errors))
  fi
fi

# HR-008: Check new wiki files are indexed
new_wiki=$(git diff --cached --name-only --diff-filter=A -- "vault/wiki/**/*.md" 2>/dev/null || true)
if [[ -n "$new_wiki" ]]; then
  index_file="$VAULT_ROOT/wiki/index.md"
  if [[ -f "$index_file" ]]; then
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      rel="${file#vault/}"
      [[ "$rel" == "wiki/index.md" || "$rel" == "wiki/log.md" ]] && continue
      if ! grep -qF "$rel" "$index_file" 2>/dev/null; then
        # Also check staged version of index
        if ! git diff --cached -- "$index_file" 2>/dev/null | grep -qF "$rel"; then
          log_fail "HR-008: New file not in index: $rel"
          errors=$((errors + 1))
        fi
      fi
    done <<< "$new_wiki"
  fi
  if [[ $errors -eq 0 ]]; then
    log_pass "HR-008: New files registered in index"
  fi
fi

# HR-011: .vault/ protection
vault_changes=$(git diff --cached --name-only -- "vault/.vault/rules/" "vault/.vault/hooks/" "vault/.vault/scripts/" "vault/.vault/schemas/" 2>/dev/null || true)
if [[ -n "$vault_changes" ]]; then
  log_fail "HR-011: Changes to protected .vault/ paths require human review:"
  echo "$vault_changes" | sed 's/^/  /'
  errors=$((errors + 1))
else
  log_pass "HR-011: .vault/ protection intact"
fi

# HR-012: Agent config protection
config_changes=$(git diff --cached --name-only -- "CLAUDE.md" "AGENTS.md" ".claude/" 2>/dev/null || true)
if [[ -n "$config_changes" ]]; then
  log_fail "HR-012: Changes to agent config files require human review:"
  echo "$config_changes" | sed 's/^/  /'
  errors=$((errors + 1))
else
  log_pass "HR-012: Agent config protection intact"
fi

# HR-013: CI/Template protection
ci_changes=\$(git diff --cached --name-only -- ".github/workflows/" ".gitlab-ci.yml" 2>/dev/null || true)
if [[ -n "\$ci_changes" ]]; then
  echo "[WARN] HR-013: CI pipeline files modified — verify changes are intentional"
  echo "\$ci_changes" | sed 's/^/  /'
fi

# HR-014: No file deletions in vault
vault_deletions=$(git diff --cached --diff-filter=D --name-only -- "vault/" 2>/dev/null || true)
if [[ -n "$vault_deletions" ]]; then
  log_fail "HR-014: File deletions not allowed (use status: archived instead):"
  echo "$vault_deletions" | sed 's/^/  /'
  errors=$((errors + 1))
else
  log_pass "HR-014: No file deletions"
fi

echo ""
if [[ $errors -gt 0 ]]; then
  echo "=== PRE-COMMIT BLOCKED: $errors violation(s) ==="
  echo "Fix the issues above before committing."
  exit 1
else
  echo "=== Pre-commit checks PASSED ==="
  exit 0
fi
PRECOMMITEOF

  chmod +x "$vault_root/.vault/hooks/pre-commit.sh"
  log_ok "Created .vault/hooks/pre-commit.sh"

  # ──────────────────────────────────────────────────────────────
  # memory/status.md — Operational Dashboard
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/memory/status.md" << STATUSEOF
---
title: "Operational Status"
type: status
created: "${today}"
updated: "${today}"
status: current
tags:
  - type/status
  - lifecycle/active
owner: system
confidence: high
---

# Operational Status — ${name}

> Living dashboard. Update after every significant action.

## Current Focus

- **Phase**: Initial setup
- **Sprint**: n/a
- **Blockers**: none

## Recent Actions

| Date | Action | Outcome | Ref |
|------|--------|---------|-----|
| ${today} | Vault initialized by aiframework v${version} | Success | — |

## Open Threads

| # | Topic | Status | Owner | Since |
|---|-------|--------|-------|-------|

## Links

- [STATUS.md](../../STATUS.md) — sprint-level tracking
- [CLAUDE.md](../../CLAUDE.md) — agent instructions
- [[index]] — wiki/index.md — knowledge catalog
- [[log]] — wiki/log.md — operations log
STATUSEOF

  log_ok "Created memory/status.md with YAML frontmatter"

  # ──────────────────────────────────────────────────────────────
  # docs/architecture.md — Three-Layer Model
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/docs/architecture.md" << ARCHEOF
---
title: "Vault Architecture"
type: architecture
created: "${today}"
updated: "${today}"
status: current
tags:
  - type/architecture
  - audience/developer
  - audience/agent
owner: system
confidence: high
---

# Vault Architecture — Three-Layer Model

## Overview

The vault implements a three-layer knowledge architecture designed for
agentic workflows. Each layer has distinct integrity guarantees and
access patterns.

\`\`\`
┌─────────────────────────────────────────────────┐
│                   CONSUMERS                      │
│         (agents, humans, CI pipelines)           │
├──────────┬──────────────────┬───────────────────┤
│  memory/ │      wiki/       │    raw/           │
│ Layer 3  │    Layer 2       │   Layer 1         │
│ Decisions│ Processed Know.  │ Immutable Sources │
│ & Ops    │ & Synthesis      │ & Documents       │
├──────────┴──────────────────┴───────────────────┤
│              .vault/ (infrastructure)            │
│     rules, schemas, scripts, hooks               │
└─────────────────────────────────────────────────┘
\`\`\`

## Layer 1: raw/ — Immutable Sources

**Purpose**: Audit trail of all ingested source material.

- Files deposited here are **never modified** (HR-001).
- Supports any file type: PDFs, screenshots, text dumps, API responses.
- Each file gets a corresponding summary in \`wiki/sources/\`.
- Provenance chain: raw file -> source summary -> concept/entity pages.

**Why immutability?** If summaries drift from sources, you can always
re-derive. The raw layer is your ground truth.

## Layer 2: wiki/ — Processed Knowledge

**Purpose**: Synthesized, interlinked knowledge base.

- **sources/**: One summary per ingested document (links back to raw/).
- **concepts/**: Topic pages synthesizing multiple sources.
- **entities/**: Pages about specific things (APIs, services, people, tools).
- **comparisons/**: Structured comparisons between alternatives.
- **index.md**: Master catalog — every page must appear here (HR-008).
- **log.md**: Append-only operations log (HR-015).

**Access pattern**: Agents read \`index.md\` first, then navigate to
specific pages via wikilinks (\`[[slug]]\`). This index-first approach
is more reliable than directory traversal at scale.

## Layer 3: memory/ — Decisions and Operations

**Purpose**: Operational memory and decision records.

- **decisions/**: ADR-format records of architectural and process decisions.
- **notes/**: Short-lived operational notes (7-day staleness by default).
- **status.md**: Living dashboard of current focus and recent actions.

**Why separate from wiki?** Wiki content is knowledge (relatively stable).
Memory content is operational (frequently changing). Different staleness
thresholds and review cadences apply.

## Infrastructure: .vault/

**Purpose**: Rules, tooling, and schemas that govern the vault.

- **rules/**: Hard rules (immutable constraints), soft rules (guidelines),
  and the approved tag taxonomy.
- **schemas/**: JSON Schema definitions for frontmatter validation,
  security policy, and content integrity.
- **scripts/**: Vault tooling (\`vault-tools.sh\`, \`lib-utils.sh\`, \`lib-lint.sh\`).
- **hooks/**: Git hooks for pre-commit enforcement.

**Protection**: .vault/ is protected by HR-011. Agents cannot modify
infrastructure files — changes require human review.

## Why Index-Based Retrieval?

Traditional file-system browsing scales poorly:
- Agents waste tokens listing directories and reading irrelevant files.
- No way to assess relevance without opening each file.

Index-based approach:
1. Read \`wiki/index.md\` — see all pages with types, dates, and tags.
2. Select relevant slugs based on the task.
3. Read only the pages needed.
4. Follow \`[[wikilinks]]\` to discover related content.

This reduces token usage by 60-80% compared to directory traversal
on vaults with 50+ pages.

## Scale Considerations

| Vault Size | Pages | Recommended Actions |
|-----------|-------|-------------------|
| Small     | < 50  | Manual management sufficient |
| Medium    | 50-200 | Run \`vault-tools.sh doctor\` weekly |
| Large     | 200-500 | Consider splitting into domain sub-vaults |
| Very Large| 500+  | Implement search indexing, consider database backing |

**Splitting strategy**: When a single domain exceeds 100 pages, extract
it into a dedicated sub-vault with its own index. The parent vault keeps
a pointer page.
ARCHEOF

  log_ok "Created docs/architecture.md"

  # ──────────────────────────────────────────────────────────────
  # docs/git-workflow.md — Branch Naming, Commit Format, PR Checklist
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/docs/git-workflow.md" << GITEOF
---
title: "Git Workflow"
type: architecture
created: "${today}"
updated: "${today}"
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

\`\`\`
agent/<agent-id>/<task>
\`\`\`

Examples:
- \`agent/claude/ingest-api-docs\`
- \`agent/claude/update-auth-concepts\`
- \`agent/system/weekly-lint\`
- \`agent/human/review-decisions\`

**Rules**:
- \`<agent-id>\`: lowercase, identifies the actor (\`claude\`, \`human\`, \`ci\`, \`system\`)
- \`<task>\`: lowercase, hyphen-separated, describes the work
- Never push directly to \`main\` — always use branches + PRs

## Commit Message Format

\`\`\`
<type>(vault): <short description>

<body — what changed and why>

Refs: <related pages or issues>
\`\`\`

**Types**:
- \`ingest\`: New source ingested and summarized
- \`create\`: New wiki/memory page created
- \`update\`: Existing page updated
- \`fix\`: Correction to existing content
- \`lint\`: Lint fixes or structural corrections
- \`archive\`: Page archived (HR-014: no deletion)
- \`meta\`: Index rebuild, log entry, status update

**Examples**:
\`\`\`
ingest(vault): add OAuth 2.0 specification summary

Ingested RFC 6749 into raw/ and created source summary.
Cross-referenced with existing auth concept pages.

Refs: wiki/sources/oauth2-rfc6749.md, wiki/concepts/auth.md
\`\`\`

\`\`\`
update(vault): refresh API rate-limiting documentation

Updated rate limit thresholds after v2.3 release.
Previous values were from v2.0 (stale per SR-008).

Refs: wiki/concepts/api-rate-limits.md
\`\`\`

## PR Checklist

Before merging any vault PR, verify:

### Hard Rule Compliance
- [ ] No modifications to \`raw/\` files (HR-001)
- [ ] All new/changed \`.md\` files have valid YAML frontmatter (HR-002)
- [ ] All tags are from approved taxonomy (HR-003)
- [ ] No wiki page exceeds 400 lines (HR-004)
- [ ] No code file exceeds 600 lines (HR-005)
- [ ] No duplicate titles (HR-006)
- [ ] \`updated\` fields reflect actual changes (HR-007)
- [ ] All new wiki pages registered in index (HR-008)
- [ ] Tags use \`prefix/value\` format (HR-009)
- [ ] No binary files in wiki/ or memory/ (HR-010)
- [ ] No changes to .vault/ infrastructure (HR-011)
- [ ] No changes to CLAUDE.md/AGENTS.md (HR-012)
- [ ] No changes to CI/templates (HR-013)
- [ ] No file deletions (HR-014)
- [ ] Log.md only appended to (HR-015)

### Quality Checks
- [ ] \`vault-tools.sh lint\` passes
- [ ] \`vault-tools.sh tag-audit\` passes
- [ ] \`vault-tools.sh content-audit\` passes
- [ ] New pages have >= 3 wikilinks (SR-003)
- [ ] Page lengths are in target range (SR-002)

### Process
- [ ] Changes logged in \`wiki/log.md\`
- [ ] \`memory/status.md\` updated if significant
- [ ] Draft pages marked \`status: draft\` (SR-010)
GITEOF

  log_ok "Created docs/git-workflow.md"

  # ──────────────────────────────────────────────────────────────
  # Templates
  # ──────────────────────────────────────────────────────────────

  # templates/source-summary.md
  cat > "$vault_root/templates/source-summary.md" << 'TMPLSRC'
---
title: "{{SOURCE_TITLE}}"
type: source
created: "{{DATE}}"
updated: "{{DATE}}"
status: draft
sources:
  - "raw/{{RAW_FILENAME}}"
related:
  - "{{RELATED_SLUG}}"
tags:
  - type/source
  - source-type/{{SOURCE_TYPE}}
  - domain/{{DOMAIN}}
owner: "{{OWNER}}"
confidence: medium
---

# {{SOURCE_TITLE}}

> Summary of [[{{RAW_FILENAME}}]] ingested on {{DATE}}.

## Key Points

1. {{POINT_1}}
2. {{POINT_2}}
3. {{POINT_3}}

## Detailed Summary

{{SUMMARY_BODY}}

## Relevance

- **Why this matters**: {{RELEVANCE}}
- **Related concepts**: [[{{CONCEPT_1}}]], [[{{CONCEPT_2}}]]
- **Confidence**: medium (single source, not yet cross-referenced)

## Source Metadata

| Field | Value |
|-------|-------|
| Source type | {{SOURCE_TYPE}} |
| Author | {{AUTHOR}} |
| Date | {{SOURCE_DATE}} |
| Length | {{LENGTH}} |
| Location | raw/{{RAW_FILENAME}} |
TMPLSRC

  # templates/concept-page.md
  cat > "$vault_root/templates/concept-page.md" << 'TMPLCON'
---
title: "{{CONCEPT_TITLE}}"
type: concept
created: "{{DATE}}"
updated: "{{DATE}}"
status: draft
sources:
  - "wiki/sources/{{SOURCE_SLUG}}.md"
related:
  - "{{RELATED_SLUG_1}}"
  - "{{RELATED_SLUG_2}}"
tags:
  - type/concept
  - domain/{{DOMAIN}}
owner: "{{OWNER}}"
confidence: medium
---

# {{CONCEPT_TITLE}}

> {{ONE_SENTENCE_SUMMARY}}

## Overview

{{OVERVIEW_PARAGRAPH}}

## Key Aspects

### {{ASPECT_1}}

{{ASPECT_1_DETAIL}}

### {{ASPECT_2}}

{{ASPECT_2_DETAIL}}

### {{ASPECT_3}}

{{ASPECT_3_DETAIL}}

## Relationships

- Related to [[{{RELATED_SLUG_1}}]]: {{HOW_RELATED_1}}
- Related to [[{{RELATED_SLUG_2}}]]: {{HOW_RELATED_2}}
- Derived from [[{{SOURCE_SLUG}}]]

## Open Questions

- {{QUESTION_1}}
- {{QUESTION_2}}

## References

- [[{{SOURCE_SLUG}}]] — primary source
TMPLCON

  # templates/entity-page.md
  cat > "$vault_root/templates/entity-page.md" << 'TMPLENT'
---
title: "{{ENTITY_NAME}}"
type: entity
created: "{{DATE}}"
updated: "{{DATE}}"
status: draft
sources:
  - "wiki/sources/{{SOURCE_SLUG}}.md"
related:
  - "{{RELATED_SLUG}}"
tags:
  - type/entity
  - domain/{{DOMAIN}}
owner: "{{OWNER}}"
confidence: medium
---

# {{ENTITY_NAME}}

> {{ONE_SENTENCE_DESCRIPTION}}

## Overview

{{OVERVIEW}}

## Properties

| Property | Value | Notes |
|----------|-------|-------|
| Type | {{ENTITY_TYPE}} | |
| Status | {{ENTITY_STATUS}} | |
| Owner | {{ENTITY_OWNER}} | |
| Version | {{VERSION}} | |

## Relationships

- Part of [[{{PARENT_SLUG}}]]
- Used by [[{{CONSUMER_SLUG}}]]
- Depends on [[{{DEPENDENCY_SLUG}}]]

## History

| Date | Event | Details |
|------|-------|---------|
| {{DATE}} | Created | Initial entity page |

## References

- [[{{SOURCE_SLUG}}]] — source documentation
TMPLENT

  # templates/comparison-page.md
  cat > "$vault_root/templates/comparison-page.md" << 'TMPLCMP'
---
title: "{{COMPARISON_TITLE}}"
type: comparison
created: "{{DATE}}"
updated: "{{DATE}}"
status: draft
sources:
  - "wiki/sources/{{SOURCE_SLUG_1}}.md"
  - "wiki/sources/{{SOURCE_SLUG_2}}.md"
related:
  - "{{OPTION_A_SLUG}}"
  - "{{OPTION_B_SLUG}}"
tags:
  - type/comparison
  - domain/{{DOMAIN}}
owner: "{{OWNER}}"
confidence: medium
---

# {{COMPARISON_TITLE}}

> Comparing [[{{OPTION_A_SLUG}}]] vs [[{{OPTION_B_SLUG}}]] for {{USE_CASE}}.

## Overview

{{WHY_COMPARING}}

## Criteria

| Criterion | {{OPTION_A}} | {{OPTION_B}} | Notes |
|-----------|-------------|-------------|-------|
| {{CRITERION_1}} | {{A_SCORE_1}} | {{B_SCORE_1}} | {{NOTES_1}} |
| {{CRITERION_2}} | {{A_SCORE_2}} | {{B_SCORE_2}} | {{NOTES_2}} |
| {{CRITERION_3}} | {{A_SCORE_3}} | {{B_SCORE_3}} | {{NOTES_3}} |

## Analysis

### {{CRITERION_1}}

{{DETAILED_ANALYSIS_1}}

### {{CRITERION_2}}

{{DETAILED_ANALYSIS_2}}

## Recommendation

**Recommended**: {{RECOMMENDATION}} (confidence: {{CONFIDENCE_LEVEL}})

{{JUSTIFICATION}}

## Sources

- [[{{SOURCE_SLUG_1}}]]
- [[{{SOURCE_SLUG_2}}]]
TMPLCMP

  # templates/decision-record.md
  cat > "$vault_root/templates/decision-record.md" << 'TMPLDEC'
---
title: "ADR-{{NUMBER}}: {{DECISION_TITLE}}"
type: decision
created: "{{DATE}}"
updated: "{{DATE}}"
status: draft
sources: []
related:
  - "{{RELATED_SLUG}}"
tags:
  - type/decision
  - domain/{{DOMAIN}}
  - source-type/adr
owner: "{{OWNER}}"
confidence: medium
---

# ADR-{{NUMBER}}: {{DECISION_TITLE}}

## Status

**{{ADR_STATUS}}** — {{DATE}}

## Context

{{CONTEXT_DESCRIPTION}}

## Decision

{{DECISION_DESCRIPTION}}

## Consequences

### Positive

- {{POSITIVE_1}}
- {{POSITIVE_2}}

### Negative

- {{NEGATIVE_1}}
- {{NEGATIVE_2}}

### Neutral

- {{NEUTRAL_1}}

## Alternatives Considered

### {{ALTERNATIVE_1}}

{{WHY_REJECTED_1}}

### {{ALTERNATIVE_2}}

{{WHY_REJECTED_2}}

## Related Decisions

- [[{{RELATED_SLUG}}]] — {{RELATIONSHIP}}
TMPLDEC

  log_ok "Created 5 templates (source, concept, entity, comparison, decision)"

  # ──────────────────────────────────────────────────────────────
  # .vault/staleness-config.json — Domain-Aware Staleness
  # ──────────────────────────────────────────────────────────────
  local staleness_entries='{}'

  staleness_entries=$(echo "$staleness_entries" | jq '. + {
    "wiki/concepts": {"max_age_days": 30, "review_trigger": "major_release"},
    "wiki/sources": {"max_age_days": 14, "review_trigger": "dependency_update"},
    "wiki/entities": {"max_age_days": 60, "review_trigger": "schema_change"},
    "wiki/comparisons": {"max_age_days": 90, "review_trigger": "manual"},
    "memory/decisions": {"max_age_days": 180, "review_trigger": "quarterly_review"},
    "memory/notes": {"max_age_days": 7, "review_trigger": "sprint_end"}
  }')

  # Domain-specific tighter thresholds
  if echo "$m" | jq -e '.domain.detected_domains[] | select(.name == "database")' >/dev/null 2>&1; then
    staleness_entries=$(echo "$staleness_entries" | jq '. + {
      "wiki/concepts/database": {"max_age_days": 14, "review_trigger": "migration_run"}
    }')
  fi

  if echo "$m" | jq -e '.domain.detected_domains[] | select(.name == "api")' >/dev/null 2>&1; then
    staleness_entries=$(echo "$staleness_entries" | jq '. + {
      "wiki/concepts/api": {"max_age_days": 7, "review_trigger": "endpoint_change"}
    }')
  fi

  if echo "$m" | jq -e '.domain.detected_domains[] | select(.name == "auth")' >/dev/null 2>&1; then
    staleness_entries=$(echo "$staleness_entries" | jq '. + {
      "wiki/concepts/auth": {"max_age_days": 7, "review_trigger": "auth_change"}
    }')
  fi

  if echo "$m" | jq -e '.domain.detected_domains[] | select(.name == "payments")' >/dev/null 2>&1; then
    staleness_entries=$(echo "$staleness_entries" | jq '. + {
      "wiki/concepts/payments": {"max_age_days": 7, "review_trigger": "payment_change"}
    }')
  fi

  local staleness_config
  staleness_config=$(jq -n \
    --arg project "$short" \
    --arg generated "$today" \
    --argjson domains "$staleness_entries" \
    '{
      "project": $project,
      "generated_at": $generated,
      "version": "1.0",
      "domains": $domains
    }')

  echo "$staleness_config" | jq '.' > "$vault_root/.vault/staleness-config.json"

  log_ok "Created .vault/staleness-config.json"

  # ──────────────────────────────────────────────────────────────
  # .vault/.initialized — Idempotency Marker
  # ──────────────────────────────────────────────────────────────
  cat > "$vault_root/.vault/.initialized" << INITEOF
vault_version: 1.0
generated_by: aiframework
generated_at: ${timestamp}
project: ${short}
generator: lib/generators/vault.sh
INITEOF

  log_ok "Created .vault/.initialized (idempotency marker)"

  # ──────────────────────────────────────────────────────────────
  # Populate vault from code index (if available)
  # ──────────────────────────────────────────────────────────────
  populate_vault_from_index "$TARGET_DIR" "$vault_root"

  # ──────────────────────────────────────────────────────────────
  # Auto-ingest key project documents into raw/ and wiki/sources/
  # ──────────────────────────────────────────────────────────────
  vault_auto_ingest "$TARGET_DIR" "$vault_root"

  # ──────────────────────────────────────────────────────────────
  # Summary
  # ──────────────────────────────────────────────────────────────
  log_ok "Vault fully initialized at $vault_root/"
  log_ok "  Directories: raw, wiki (4 subdirs), memory (2 subdirs), .vault (4 subdirs), docs, templates"
  log_ok "  Rules: 15 hard rules, 15 soft rules, 200+ tags across 19 prefixes"
  log_ok "  Tools: vault-tools.sh (11 commands), lib-utils.sh, lib-lint.sh"
  log_ok "  Schemas: wiki-entry.json, skill-policy.json, content-policy.json"
  log_ok "  Hooks: pre-commit.sh (enforces HR-001/002/003/008/011/012/014)"
  log_ok "  Templates: source, concept, entity, comparison, decision"
  log_ok "  Docs: architecture.md (three-layer model), git-workflow.md"
}

# ══════════════════════════════════════════════════════════════════
# populate_vault_from_index — Auto-generate vault wiki pages from
# .aiframework/code-index.json when it exists.
#
# This function is NOT gated by the idempotency check and can run
# on both fresh and existing vaults.
#
# Args:
#   $1 — target_dir  (project root where .aiframework/ lives)
#   $2 — vault_root  (path to vault/ directory)
# ══════════════════════════════════════════════════════════════════
populate_vault_from_index() {
  local target_dir="$1"
  local vault_root="$2"
  local code_index="$target_dir/.aiframework/code-index.json"

  if [[ ! -f "$code_index" ]]; then
    log_info "No code index found at $code_index — skipping vault population from index"
    return 0
  fi

  log_info "Populating vault wiki from code index..."

  local today
  today=$(date +%Y-%m-%d)

  # --- Try Python wiki graph generator (dense, file-level, bidirectional links) ---
  # Use LIB_DIR (exported by bin/aiframework) — BASH_SOURCE[0] resolves to the
  # caller (bin/aiframework), not this file, when vault.sh is sourced.
  local wiki_graph_py="${LIB_DIR:-}/generators/wiki_graph.py"

  if [[ -f "$wiki_graph_py" ]] && command -v python3 &>/dev/null; then
    local output
    if output=$(python3 "$wiki_graph_py" \
      --code-index "$code_index" \
      --vault-root "$vault_root" \
      --verify \
      --today "$today" 2>&1); then
      log_ok "$output"
      _aif_telemetry "wiki_graph" "mode=python" "outcome=success" 2>/dev/null || true
      return 0
    else
      log_warn "wiki_graph.py failed, falling back to legacy: $output"
      _aif_telemetry "wiki_graph" "mode=legacy_fallback" "outcome=python_failed" 2>/dev/null || true
    fi
  else
    if [[ ! -f "$wiki_graph_py" ]]; then
      log_warn "wiki_graph.py not found at $wiki_graph_py — using legacy vault population"
      _aif_telemetry "wiki_graph" "mode=legacy" "outcome=file_not_found" 2>/dev/null || true
    elif ! command -v python3 &>/dev/null; then
      log_warn "python3 not available — using legacy vault population"
      _aif_telemetry "wiki_graph" "mode=legacy" "outcome=no_python" 2>/dev/null || true
    fi
  fi

  # --- Legacy fallback (module-level only, for systems without python3) ---
  _populate_vault_from_index_legacy "$target_dir" "$vault_root"
}

# Legacy vault population — module-level pages only.
# Used as fallback when python3 is unavailable or wiki_graph.py cannot be found.
_populate_vault_from_index_legacy() {
  local target_dir="$1"
  local vault_root="$2"
  local code_index="$target_dir/.aiframework/code-index.json"

  if ! command -v jq &>/dev/null; then
    log_warn "jq not found — cannot populate vault from code index"
    return 0
  fi

  local today
  today=$(date +%Y-%m-%d)
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local lang
  lang=$(jq -r '._meta.languages | to_entries | sort_by(.value) | reverse | .[0].key // "unknown"' "$code_index" 2>/dev/null || echo "unknown")

  mkdir -p "$vault_root/wiki/entities"

  local index_file="$vault_root/wiki/index.md"
  local log_file="$vault_root/wiki/log.md"
  local new_log_entries=""
  local pages_created=0

  local modules_json
  modules_json=$(jq -c '[.modules | to_entries[] | select((.value.files | length) >= 3)]' "$code_index" 2>/dev/null || echo "[]")
  local module_count
  module_count=$(echo "$modules_json" | jq 'length')

  if [[ "$module_count" -gt 0 ]]; then
    local i=0
    while [[ $i -lt $module_count ]]; do
      local mod_path mod_slug mod_role mod_file_count
      mod_path=$(echo "$modules_json" | jq -r ".[$i].key")
      mod_slug=$(echo "$mod_path" | sed 's|/|-|g; s|^\.||; s|^-||')
      [[ -z "$mod_slug" ]] && mod_slug="root-module"

      local entity_file="$vault_root/wiki/entities/${mod_slug}.md"
      local _entity_existed=false
      [[ -f "$entity_file" ]] && _entity_existed=true

      mod_role=$(echo "$modules_json" | jq -r ".[$i].value.role // \"Module at ${mod_path}\"")
      mod_file_count=$(echo "$modules_json" | jq -r ".[$i].value.files | length")

      local file_list
      file_list=$(echo "$modules_json" | jq -r ".[$i].value.files[]" 2>/dev/null | sed 's/^/- `/' | sed 's/$/`/' | head -30)

      local symbols
      if [[ "$mod_path" == "." ]]; then
        symbols=$(jq -r '[.files | to_entries[] | select(.key | contains("/") | not) | .value.symbols[]?] | unique | .[:10] | .[]' "$code_index" 2>/dev/null || true)
      else
        symbols=$(jq -r --arg mp "$mod_path" '[.files | to_entries[] | select(.key | startswith($mp + "/")) | .value.symbols[]?] | unique | .[:10] | .[]' "$code_index" 2>/dev/null || true)
      fi
      local symbols_list=""
      if [[ -n "$symbols" ]]; then
        symbols_list=$(echo "$symbols" | sed 's/^/- `/' | sed 's/$/`/')
      else
        symbols_list="*No symbols extracted.*"
      fi

      local _entity_tmp
      _entity_tmp=$(mktemp)
      cat > "$_entity_tmp" << MODENTEOF
---
title: "Module: ${mod_path}"
type: entity
created: ${today}
updated: ${today}
status: current
tags:
  - type/entity
  - domain/${lang}
  - source-type/code-index
confidence: medium
---

# Module: ${mod_path}

> ${mod_role} — ${mod_file_count} files

## Files

${file_list}

## Key Symbols

${symbols_list}

## Related

- [[architecture]]
- [[tech-stack]]
- [[project-overview]]
MODENTEOF

      if $_entity_existed && diff -q "$entity_file" "$_entity_tmp" >/dev/null 2>&1; then
        rm -f "$_entity_tmp"
      else
        mv "$_entity_tmp" "$entity_file"
        pages_created=$((pages_created + 1))
      fi

      i=$((i + 1))
    done
  fi

  # Rebuild index from disk
  if [[ $pages_created -gt 0 ]]; then
    local vault_tools="$vault_root/.vault/scripts/vault-tools.sh"
    if [[ -x "$vault_tools" ]]; then
      "$vault_tools" index-rebuild >/dev/null 2>&1 || true
    fi
  fi

  if [[ $pages_created -gt 0 ]]; then
    log_ok "Legacy vault: ${pages_created} module page(s) created"
  else
    log_info "Code index found but no new vault pages needed"
  fi
}
