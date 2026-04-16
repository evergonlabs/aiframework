#!/usr/bin/env bash
# Generator: CLAUDE.md
# Reads manifest.json and produces a complete CLAUDE.md
#
# Architecture:
#   generate_claude_md()          — dispatcher: lean for all, extended rules for moderate+
#   generate_claude_md_lean()     — 80-150 line high-signal CLAUDE.md (all projects)
#   _generate_extended_rules()    — .claude/rules/ files (moderate/complex/enterprise)
#   _generate_reference_docs()    — docs/reference/architecture.md (moderate/complex/enterprise)

# --- Shared variable extraction (called by both lean and full) ---
_extract_claude_md_vars() {
  _cm_m="$MANIFEST"
  _cm_out="$TARGET_DIR/CLAUDE.md"

  _cm_name=$(echo "$_cm_m" | jq -r '.identity.name')
  _cm_desc=$(echo "$_cm_m" | jq -r '.identity.description // "No description"')
  _cm_version=$(echo "$_cm_m" | jq -r '.identity.version // "0.1.0"')
  _cm_short=$(echo "$_cm_m" | jq -r '.identity.short_name')
  _cm_lang=$(echo "$_cm_m" | jq -r '.stack.language')
  _cm_fw=$(echo "$_cm_m" | jq -r '.stack.framework // "none"')
  _cm_is_mono=$(echo "$_cm_m" | jq -r '.stack.is_monorepo')
  _cm_gh_url=$(echo "$_cm_m" | jq -r '.commands.github_url // "NOT_FOUND"')
  _cm_local_path=$(echo "$_cm_m" | jq -r '.commands.local_path')
  _cm_install=$(echo "$_cm_m" | jq -r '.commands.install // "NOT_CONFIGURED"')
  _cm_dev_cmd=$(echo "$_cm_m" | jq -r '.commands.dev // "NOT_CONFIGURED"')
  _cm_build_cmd=$(echo "$_cm_m" | jq -r '.commands.build // "NOT_CONFIGURED"')
  _cm_lint_cmd=$(echo "$_cm_m" | jq -r '.commands.lint // "NOT_CONFIGURED"')
  _cm_format_cmd=$(echo "$_cm_m" | jq -r '.commands.format // "NOT_CONFIGURED"')
  _cm_typecheck=$(echo "$_cm_m" | jq -r '.commands.typecheck // "NOT_CONFIGURED"')
  _cm_test_cmd=$(echo "$_cm_m" | jq -r '.commands.test // "NOT_CONFIGURED"')
  _cm_dev_port=$(echo "$_cm_m" | jq -r '.commands.dev_port // empty')
  _cm_deploy=$(echo "$_cm_m" | jq -r '.ci.deploy_target // "none"')
  _cm_ci_provider=$(echo "$_cm_m" | jq -r '.ci.provider // "none"')
  _cm_today=$(date +%Y-%m-%d)
  _cm_complexity=$(echo "$_cm_m" | jq -r '.archetype.complexity // "moderate"')
  _cm_domain_count=$(echo "$_cm_m" | jq '.domain.detected_domains | length' 2>/dev/null || echo "0")
  _cm_key_deps=$(echo "$_cm_m" | jq -r '.stack.key_dependencies | if length > 10 then .[0:10] | join(", ") + "..." else join(", ") end // "none"' 2>/dev/null || echo "none")
  _cm_arch_type=$(echo "$_cm_m" | jq -r '.archetype.type // "unknown"')
  _cm_arch_maturity=$(echo "$_cm_m" | jq -r '.archetype.maturity // "unknown"')
}

# --- Generate .claude/rules/workflow.md ---
_generate_workflow_rules() {
  local rules_dir="$TARGET_DIR/.claude/rules"
  mkdir -p "$rules_dir"
  local rules_out="$rules_dir/workflow.md"

  # Language-specific QA rules
  local qa_rules_block=""
  local qa_data_file="$ROOT_DIR/lib/data/languages.json"
  if [[ -f "$qa_data_file" ]] && command -v jq &>/dev/null; then
    local qa_rules
    qa_rules=$(jq -r --arg l "$_cm_lang" '.languages[$l].qa_rules[]? // empty' "$qa_data_file" 2>/dev/null)
    if [[ -n "$qa_rules" ]]; then
      local lang_display
      lang_display=$(echo "$_cm_lang" | awk '{print toupper(substr($0,1,1)) substr($0,2)}' | sed 's/Csharp/C#/; s/Cpp/C++/')
      qa_rules_block=$'\n'"### ${lang_display} QA Rules"$'\n'
      while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        qa_rules_block+="- ${rule}"$'\n'
      done <<< "$qa_rules"
    fi
  fi

  cat > "$rules_out" << 'WORKFLOW_RULES'
---
description: "Workflow rules for development process — auto-loaded by Claude"
globs: "**/*"
---

# Workflow Rules

## Plan vs Execute
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan — don't keep pushing
- When given a task with clear scope: start executing immediately
- When hitting a wall (3+ failed attempts), stop and re-plan approach

## Autonomous Iteration
- Execute fix → verify with tests → if broken, fix again → loop until clean
- Iterate autonomously: don't ask for hand-holding on fixable issues
- Commit after each logical group of verified fixes

## Git Safety
- After fixes: `git add` + `git commit` — do NOT push until user says so
- NEVER push to main without explicit user confirmation
- NEVER commit after every small change — batch related changes into logical commits
- Prefer fewer, larger commits over many small ones

## Verification Before Done
- Never mark a task complete without proving it works
- Run verification commands — never assume it compiles
- Never claim "done" without running the actual verification command

## Subagent Strategy
- Use subagents for research, exploration, and parallel analysis
- Limit to 6-8 agents per wave maximum
- After each wave: summarize results, commit, then start next wave

## QA Auto-Fix
When QA discovers issues, ALL must be automatically fixed:
1. Run tests — collect all failures
2. Fix each failure: identify root cause → fix implementation (never skip a test)
3. Run type check → must pass
4. Run tests again — all must pass
5. Commit

## Documentation Auto-Sync
After ANY feature implementation, refactor, or significant change:
1. CLAUDE.md — if change adds invariants, new key locations, new commands
2. docs/ — update relevant doc files

## Changelog Update
After marking any feature complete and before pushing:
1. Update CHANGELOG.md with user-facing description of changes
2. Bump VERSION file (PATCH for fixes, MINOR for features, MAJOR for breaking)

## New Feature Checklist
- [ ] Feature works as specified
- [ ] Edge cases handled
- [ ] Error states covered
- [ ] Tests added for new functionality
- [ ] Documentation updated if needed
- [ ] No regressions in existing functionality
WORKFLOW_RULES

  # Append language-specific QA rules if any
  if [[ -n "$qa_rules_block" ]]; then
    echo "$qa_rules_block" >> "$rules_out"
  fi

  log_ok ".claude/rules/workflow.md written"

  # Generate path-scoped testing rules (only if test framework detected)
  if [[ "$_cm_test_cmd" != "NOT_CONFIGURED" ]]; then
    local testing_rules="$rules_dir/testing.md"
    if [[ ! -f "$testing_rules" ]]; then
      cat > "$testing_rules" << 'TESTING_RULES'
---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/test_*"
  - "**/tests/**"
---

# Testing Rules

- Tests must be deterministic — no flaky tests
- Mock external services, not internal modules
- Each test file tests one module
- Test names describe the expected behavior
TESTING_RULES
      log_ok ".claude/rules/testing.md written"
    fi
  fi

  # Generate path-scoped security rules (only if auth/api domain detected)
  local all_domains=""
  all_domains=$(echo "$_cm_m" | jq -r '.domain.detected_domains[]? | .name' 2>/dev/null || true)
  if echo "$all_domains" | grep -qE '(auth|api)'; then
    local security_rules="$rules_dir/security.md"
    if [[ ! -f "$security_rules" ]]; then
      cat > "$security_rules" << 'SECURITY_RULES'
---
paths:
  - "**/auth/**"
  - "**/api/**"
  - "**/middleware/**"
---

# Security Rules

- Never log sensitive data (tokens, passwords, PII)
- Validate all input at system boundaries
- Use parameterized queries — never string concatenation for SQL
- API keys must come from environment variables
SECURITY_RULES
      log_ok ".claude/rules/security.md written"
    fi
  fi
}

# --- Lean CLAUDE.md generator (80-150 lines, high-signal only) ---
generate_claude_md_lean() {
  _extract_claude_md_vars

  local m="$_cm_m" out="$_cm_out"
  local name="$_cm_name" desc="$_cm_desc" short="$_cm_short"
  local lang="$_cm_lang" fw="$_cm_fw"
  local install="$_cm_install" dev_cmd="$_cm_dev_cmd" build_cmd="$_cm_build_cmd"
  local lint_cmd="$_cm_lint_cmd" format_cmd="$_cm_format_cmd" typecheck="$_cm_typecheck"
  local test_cmd="$_cm_test_cmd" dev_port="$_cm_dev_port"
  local deploy="$_cm_deploy" today="$_cm_today"
  local domain_count="$_cm_domain_count" key_deps="$_cm_key_deps"
  local arch_type="$_cm_arch_type" arch_maturity="$_cm_arch_maturity"
  local complexity="$_cm_complexity"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would write lean CLAUDE.md to $out"
    return 0
  fi

  # Preserve existing CLAUDE.md content for merge
  preserve_claude_md

  # --- Generate .claude/rules/workflow.md (offload workflow rules) ---
  _generate_workflow_rules

  # --- Build lean CLAUDE.md ---
  cat > "$out" << CLAUDEMD
# CLAUDE.md — ${name}

$(if [[ "$desc" != "NOT_FOUND" && "$desc" != "No description" && "$desc" != "<"* && -n "$desc" ]]; then echo "> ${desc}. Stack: ${lang}/${fw}."; else echo "> Stack: ${lang}/${fw}."; fi)

## Commands

\`\`\`bash
CLAUDEMD

  # Only emit configured commands
  [[ "$install" != "NOT_CONFIGURED" ]] && echo "# Install"$'\n'"${install}"$'\n' >> "$out"
  [[ "$lint_cmd" != "NOT_CONFIGURED" ]] && echo "# Lint"$'\n'"${lint_cmd}"$'\n' >> "$out"
  [[ "$typecheck" != "NOT_CONFIGURED" ]] && echo "# Type check"$'\n'"${typecheck}"$'\n' >> "$out"
  [[ "$test_cmd" != "NOT_CONFIGURED" ]] && echo "# Test"$'\n'"${test_cmd}"$'\n' >> "$out"
  [[ "$build_cmd" != "NOT_CONFIGURED" ]] && echo "# Build"$'\n'"${build_cmd}"$'\n' >> "$out"
  [[ "$dev_cmd" != "NOT_CONFIGURED" ]] && echo "# Dev"$'\n'"${dev_cmd}"$'\n' >> "$out"
  [[ "$format_cmd" != "NOT_CONFIGURED" ]] && echo "# Format"$'\n'"${format_cmd}"$'\n' >> "$out"

  # If nothing configured
  local _any_cmd=false
  [[ "$install" != "NOT_CONFIGURED" || "$lint_cmd" != "NOT_CONFIGURED" || "$typecheck" != "NOT_CONFIGURED" || "$test_cmd" != "NOT_CONFIGURED" || "$build_cmd" != "NOT_CONFIGURED" ]] && _any_cmd=true
  if [[ "$_any_cmd" == false ]]; then
    echo "# No commands configured yet" >> "$out"
  fi

  echo '```' >> "$out"
  echo "" >> "$out"

  # --- Invariants ---
  echo "## Invariants" >> "$out"
  echo "" >> "$out"

  if [[ "$domain_count" -gt 0 ]]; then
    local inv_num=1
    echo "$m" | jq -r '.domain.detected_domains[] | .name' 2>/dev/null | while IFS= read -r domain; do
      case "$domain" in
        auth)
          echo "- **INV-${inv_num}**: Auth guards on all protected endpoints"
          ;;
        database)
          local orm_val
          orm_val=$(echo "$m" | jq -r '.domain.detected_domains[] | select(.name == "database") | .orm // "unknown"')
          echo "- **INV-${inv_num}**: Database access through ORM only (${orm_val})"
          ;;
        api)
          echo "- **INV-${inv_num}**: Input validation on all API endpoints"
          ;;
        ai)
          echo "- **INV-${inv_num}**: LLM trust boundary — validate all AI output"
          ;;
        sandbox)
          echo "- **INV-${inv_num}**: Sandbox isolation for code execution"
          ;;
      esac
      inv_num=$((inv_num + 1))
    done >> "$out"
  fi

  # Ensure at least 1 invariant
  local inv_count
  inv_count=$(grep -c 'INV-' "$out" 2>/dev/null || echo "0")
  if [[ "$inv_count" -lt 1 ]]; then
    echo "- **INV-1**: No secrets in source code — use environment variables" >> "$out"
  fi

  echo "" >> "$out"

  # --- Architecture one-liner ---
  echo "## Architecture" >> "$out"
  echo "" >> "$out"

  if [[ "$arch_type" != "unknown" && "$arch_type" != "null" ]]; then
    echo "- **Archetype**: ${arch_type} (${arch_maturity}, ${complexity})" >> "$out"
  fi

  # Entry points
  local entries
  entries=$(echo "$m" | jq -r '.structure.entry_points[]' 2>/dev/null)
  if [[ -n "$entries" ]]; then
    local entries_inline
    entries_inline=$(echo "$entries" | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
    echo "- **Entry points**: ${entries_inline}" >> "$out"
  fi

  echo "" >> "$out"

  # --- Key Locations (top 10, compact) ---
  echo "## Key Locations" >> "$out"
  echo "" >> "$out"

  local loc_count=0

  # Domain-specific locations (top paths)
  echo "$m" | jq -r '.domain.detected_domains[]? | "- **\(.display)**: \(.paths[:3][]? // empty)"' 2>/dev/null >> "$out" || true
  loc_count=$((loc_count + $(echo "$m" | jq '[.domain.detected_domains[]?.paths[:3][]?] | length' 2>/dev/null || echo "0")))

  # Script dirs
  local kl_script_dirs
  kl_script_dirs=$(echo "$m" | jq -r '.structure.script_dirs[]' 2>/dev/null)
  if [[ -n "$kl_script_dirs" ]] && [[ "$loc_count" -lt 10 ]]; then
    while IFS= read -r sdir; do
      [[ -z "$sdir" ]] && continue
      echo "- **Scripts**: \`${sdir}/\`" >> "$out"
      ((loc_count++)) || true
      [[ "$loc_count" -ge 10 ]] && break
    done <<< "$kl_script_dirs"
  fi

  # CI dirs
  local kl_ci_dirs
  kl_ci_dirs=$(echo "$m" | jq -r '.structure.ci_dirs[]' 2>/dev/null)
  if [[ -n "$kl_ci_dirs" ]] && [[ "$loc_count" -lt 10 ]]; then
    while IFS= read -r cidir; do
      [[ -z "$cidir" ]] && continue
      echo "- **CI**: \`${cidir}/\`" >> "$out"
      ((loc_count++)) || true
      [[ "$loc_count" -ge 10 ]] && break
    done <<< "$kl_ci_dirs"
  fi

  # Repo Map (PageRank top files) — compact
  local code_index_path="${OUTPUT_DIR}/code-index.json"
  if [[ -f "$code_index_path" ]] && command -v jq &>/dev/null; then
    local top_files
    top_files=$(jq -r '._meta.top_files // [] | [.[] | select(.[0] | test("__init__\\.py$") | not)] | .[:10][] | "- `\(.[0])`"' "$code_index_path" 2>/dev/null)
    if [[ -n "$top_files" ]]; then
      echo "" >> "$out"
      echo "**Most important files** (by dependency rank):" >> "$out"
      echo "$top_files" >> "$out"
    fi
  fi

  if [[ "$loc_count" == "0" ]]; then
    echo "*Key locations will be added as the project develops.*" >> "$out"
  fi

  echo "" >> "$out"

  # --- Environment Variables ---
  echo "## Environment Variables" >> "$out"
  echo "" >> "$out"

  local env_count
  env_count=$(echo "$m" | jq '.env.variables | length' 2>/dev/null || echo "0")

  if [[ "$env_count" -gt 0 ]]; then
    echo "| Variable | Required | Description |" >> "$out"
    echo "|----------|----------|-------------|" >> "$out"
    echo "$m" | jq -r '.env.variables[] | "| \(.name) | \(if .required then "Yes" else "No" end) | \(.description // "-") |"' 2>/dev/null >> "$out"
  else
    echo "*None discovered. Add variables here when .env.example is created.*" >> "$out"
  fi

  echo "" >> "$out"

  # --- Gotchas / Learnings ---
  echo "## Gotchas" >> "$out"
  echo "" >> "$out"

  local learnings_file="$TARGET_DIR/tools/learnings/${short}-learnings.jsonl"
  if [[ -f "$learnings_file" ]] && [[ -s "$learnings_file" ]]; then
    # Show last 5 learnings as bullet points
    tail -5 "$learnings_file" | while IFS= read -r line; do
      local summary
      summary=$(echo "$line" | jq -r '.summary // empty' 2>/dev/null)
      [[ -n "$summary" ]] && echo "- ${summary}"
    done >> "$out"
  else
    echo "*No gotchas captured yet. Use \`/${short}-learn\` to record non-obvious discoveries.*" >> "$out"
  fi

  echo "" >> "$out"

  # --- Testing ---
  local test_tool
  test_tool=$(echo "$m" | jq -r '.quality.test_framework.tool // empty')
  if [[ -n "$test_tool" ]]; then
    local test_count
    test_count=$(echo "$m" | jq -r '.structure.test_file_count // 0')
    local test_pattern
    test_pattern=$(echo "$m" | jq -r '.structure.test_pattern // "NOT_FOUND"')
    echo "## Testing" >> "$out"
    echo "" >> "$out"
    echo "- **Framework:** ${test_tool} | **Run:** \`${test_cmd}\` | **Pattern:** ${test_pattern} | **Files:** ${test_count}" >> "$out"
    echo "" >> "$out"
  fi

  # --- Deploy ---
  if [[ "$deploy" != "none" ]]; then
    echo "## Deploy" >> "$out"
    echo "" >> "$out"
    echo "**Target:** ${deploy}" >> "$out"
    echo "" >> "$out"
  fi

  # --- Makefile targets ---
  local makefile_targets_json
  makefile_targets_json=$(echo "$m" | jq -r '.commands.makefile_targets[]?' 2>/dev/null)
  if [[ -n "$makefile_targets_json" ]]; then
    echo "## Makefile" >> "$out"
    echo "" >> "$out"
    echo '```bash' >> "$out"
    while IFS= read -r target; do
      echo "make ${target}" >> "$out"
    done <<< "$makefile_targets_json"
    echo '```' >> "$out"
    echo "" >> "$out"
  fi

  # --- Custom Skills ---
  cat >> "$out" << SKILLS
## Custom Skills

- \`/${short}-review\` — Project-specific code review
- \`/${short}-ship\` — Full shipping workflow
- \`/${short}-learn\` — Capture learnings to persistent storage

SKILLS

  # --- Vault quick reference (compact) ---
  cat >> "$out" << 'VAULT'
## Vault

Knowledge persists in `vault/` across sessions. Check `vault/memory/status.md` at session start.

```bash
vault/.vault/scripts/vault-tools.sh doctor   # Full diagnostic
vault/.vault/scripts/vault-tools.sh lint     # Quality scan
```

VAULT

  # --- Doc Sync reference (needed for E8 validator) ---
  if [[ "$complexity" == "moderate" || "$complexity" == "complex" || "$complexity" == "enterprise" ]]; then
    cat >> "$out" << 'DOCSYNC'
## Doc Sync

After structural changes, update docs per `.claude/rules/pipeline.md` matrix.
See `docs/reference/architecture.md` for module map and structure tree.

DOCSYNC

    # Session start one-liner for complex projects
    cat >> "$out" << SESSIONREF
## Session Start

At session start: read \`vault/memory/status.md\`, check \`git log --oneline -10\`, check \`git status\`.
Full protocol in \`.claude/rules/session-protocol.md\`.

SESSIONREF
  fi

  # --- Self-evolution instructions ---
  cat >> "$out" << FOOTER
## Self-Evolution

This file auto-evolves. Rules of thumb:
- **Same mistake twice** → add to Invariants above
- **Applies only to certain files** → create \`.claude/rules/<domain>.md\` with \`paths:\` frontmatter
- **Multi-step workflow** → create \`.claude/skills/<name>/SKILL.md\`
- **Run \`/aif-evolve\` periodically** to synthesize learnings into rules
- **This file should get shorter** — migrate content to rules and skills as patterns stabilize
- **Run \`aiframework refresh\`** when dependencies or structure change

---

*Generated: ${today} by aiframework v$(cat "$ROOT_DIR/VERSION"). Run \`aiframework refresh\` to update. Lean mode (${complexity}).*
FOOTER

  # Merge back any user-added content
  merge_claude_md_user_content

  log_ok "CLAUDE.md (lean) written to $out"
}

# --- Extended rules generator (complex/enterprise projects) ---
# Writes pipeline, session protocol, invariants, and review checklists
# to .claude/rules/ files — auto-loaded by Claude Code.
_generate_extended_rules() {
  _extract_claude_md_vars
  local m="$_cm_m" short="$_cm_short" today="$_cm_today"
  local lint_cmd="$_cm_lint_cmd" typecheck="$_cm_typecheck"
  local test_cmd="$_cm_test_cmd" build_cmd="$_cm_build_cmd"
  local dev_port="$_cm_dev_port" domain_count="$_cm_domain_count"
  local deploy="$_cm_deploy" dev_cmd="$_cm_dev_cmd"
  local rules_dir="$TARGET_DIR/.claude/rules"
  mkdir -p "$rules_dir"

  # ── pipeline.md ──────────────────────────────────────────────
  local pipeline_out="$rules_dir/pipeline.md"
  if preserve_rule "$pipeline_out"; then
    cat > "$pipeline_out" << 'PIPEHEADER'
# Pipeline & Skill Routing

PIPEHEADER

    # 12-stage pipeline
    cat >> "$pipeline_out" << 'PIPE1'
## Autonomous Pipeline (12 Stages)

### Stage 1: INVESTIGATE (before writing any code)
When: User reports a bug or asks to fix something.
```
/investigate "description of the issue"
```

### Stage 2: PLAN (before major features)
When: User asks for a significant feature or architectural change.
```
/plan-eng-review "description of the feature"
```

### Stage 3: BUILD (write the code)
Rules: No secrets in code — use environment variables.

### Stage 4: VERIFY (after every code change — ALWAYS)
PIPE1

    echo '```bash' >> "$pipeline_out"
    local _has_verify_cmd=false
    if [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then echo "${lint_cmd}              # Must pass with 0 errors" >> "$pipeline_out"; _has_verify_cmd=true; fi
    if [[ "$typecheck" != "NOT_CONFIGURED" ]]; then echo "${typecheck}         # Must pass" >> "$pipeline_out"; _has_verify_cmd=true; fi
    if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then echo "${test_cmd}              # Must pass" >> "$pipeline_out"; _has_verify_cmd=true; fi
    if [[ "$build_cmd" != "NOT_CONFIGURED" ]]; then echo "${build_cmd}             # Must compile/build" >> "$pipeline_out"; _has_verify_cmd=true; fi
    if [[ "$_has_verify_cmd" == false ]]; then
      echo "# No quality gate commands configured yet." >> "$pipeline_out"
    fi
    echo '```' >> "$pipeline_out"
    echo "" >> "$pipeline_out"
    echo "> Run \`vault/.vault/scripts/vault-tools.sh lint\` to verify vault integrity." >> "$pipeline_out"

    cat >> "$pipeline_out" << 'PIPE2'

### Stage 5: REVIEW
```
/review
```

### Stage 6: SECURITY (when touching auth/security/API)
```
/cso
```

### Stage 6.5: CHANGELOG UPDATE
After completing any feature, fix, or significant change:
1. Update `CHANGELOG.md` with user-facing description
2. Bump `VERSION` file (PATCH for fixes, MINOR for features, MAJOR for breaking)
3. Commit changelog + version bump with the feature commit

### Stage 7: DOCS (after structural changes)
PIPE2

    # Doc-Sync matrix
    echo "Run doc-sync check against this matrix:" >> "$pipeline_out"
    echo "" >> "$pipeline_out"
    echo "| Change Type | Files to Update |" >> "$pipeline_out"
    echo "|-------------|----------------|" >> "$pipeline_out"
    echo "| New endpoint/route | CLAUDE.md (Key Locations), API docs |" >> "$pipeline_out"
    echo "| New env variable | CLAUDE.md (Env Variables), .env.example |" >> "$pipeline_out"
    echo "| New invariant | CLAUDE.md (Invariants) |" >> "$pipeline_out"
    echo "| Schema change | CLAUDE.md (Key Locations), migration docs |" >> "$pipeline_out"
    echo "| New dependency | CLAUDE.md (Project Identity), package manifest |" >> "$pipeline_out"
    echo "| New service/module | CLAUDE.md (Key Locations, Project Structure) |" >> "$pipeline_out"

    local doc_sync_dirs
    doc_sync_dirs=$(echo "$m" | jq -r '.structure.doc_dirs[]' 2>/dev/null)
    if [[ -n "$doc_sync_dirs" ]]; then
      while IFS= read -r dsdir; do
        echo "| Architectural change | \`${dsdir}/\` architecture docs |" >> "$pipeline_out"
      done <<< "$doc_sync_dirs"
    fi
    echo "" >> "$pipeline_out"

    # Stage 8
    echo "### Stage 8: QA (before every deploy)" >> "$pipeline_out"
    echo '```' >> "$pipeline_out"
    if [[ -n "$dev_port" ]]; then
      echo "/qa http://localhost:${dev_port}" >> "$pipeline_out"
    else
      echo "/qa" >> "$pipeline_out"
    fi
    echo '```' >> "$pipeline_out"

    cat >> "$pipeline_out" << 'PIPE3'

### Stage 9: SHIP
```
/ship
```

### Stage 10: POST-DEPLOY
```
/canary
```

### Stage 11: LEARN
```
/learn "description of what was learned"
```

### Stage 12: RETRO (weekly)
```
/retro
```

---

## Skill Routing Table

| User says something like... | Claude's action |
|-----------------------------|----------------|
| "there's a bug", "it's broken", "fix this" | Start with `/investigate` before coding |
| "add feature", "build X" (big scope) | `/plan-eng-review` then build |
| "add feature", "change X" (small, clear) | Build directly, then verify + `/review` |
| "check security", "audit" | Run `/cso` immediately |
| "review the code", "check quality" | Run `/review` immediately |
| "test the app", "QA", "does it work" | Run `/qa` on the app URL |
| "deploy", "push", "ship it", "create PR" | Full pipeline: verify → `/review` → `/cso` → `/qa` → `/ship` |
| "what do we know about X", "previous decisions" | Check vault: `vault/wiki/index.md` and `vault/memory/decisions/` |
| "vault health", "check vault" | Run `vault/.vault/scripts/vault-tools.sh doctor` |
| "refactor", "clean up", "simplify" | Build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` |
| "update docs", "fix docs" | Update docs directly, then verify + `/review` |
| "performance", "optimize", "too slow" | `/investigate` → profile → fix → verify → `/review` |
| "CI", "tests failing", "pipeline broken" | `/investigate` the CI/test failure, fix, verify locally |
| "what changed recently", "catch me up" | Check `git log --oneline -20` + `vault/memory/status.md` |
| "give feedback", "rate the output" | Run `/aif-feedback` to collect structured feedback |

---

## Quick Reference Matrix

| Trigger | Skills to run (in order) |
|---------|------------------------|
| Bug reported | `/investigate` → fix → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| New feature | `/plan-eng-review` → build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| Small fix | build → verify → `/review` → docs → `/ship` |
| Refactor | build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` |

---

## Doc-Sync Matrix

When any file in a domain's key files changes, update the corresponding docs.

PIPE3

    # Domain-specific doc-sync rows
    if [[ "$domain_count" -gt 0 ]]; then
      echo "| Domain | Key Files | Doc Impact |" >> "$pipeline_out"
      echo "|--------|-----------|------------|" >> "$pipeline_out"
      echo "$m" | jq -r '.domain.detected_domains[] | "| \(.display) | \(.paths[:2] | join(", ") // "-") | CLAUDE.md, docs/ |"' 2>/dev/null >> "$pipeline_out" || true
      echo "" >> "$pipeline_out"
    fi

    log_ok "Written .claude/rules/pipeline.md"
  fi

  # ── session-protocol.md ──────────────────────────────────────
  local session_out="$rules_dir/session-protocol.md"
  if preserve_rule "$session_out"; then
    cat > "$session_out" << SESSIONHEAD
# Session Protocol & Execution Matrices

## Session Start Protocol

At the start of each session:
1. Read \`vault/memory/status.md\` — check for ongoing work and operational context
2. Read \`vault/wiki/index.md\` — scan domain concepts and knowledge pages
3. Read \`tools/learnings/${short}-learnings.jsonl\` — surface relevant learnings
4. Check \`git log --oneline -10\` — understand recent work
5. Check \`git status\` — understand current state
6. If a STATUS.md file exists — read it for multi-phase task progress
7. Run \`aiframework-update-check\` — notify developer of updates or drift
8. Decision Priority: User > Invariants > Workflow Rules > Core Principles > Docs

## End-of-Session Checklist

Before ending ANY session where code was changed, Claude MUST complete:

- [ ] **Verify**: Did I run lint + test + build? All pass?
- [ ] **Review**: Did I run \`/review\` on the changes?
- [ ] **Security**: If I touched auth/API/permissions → did I run \`/cso\`?
- [ ] **Docs**: Did any structural change happen? → Update docs
- [ ] **Learn**: Did I discover something non-obvious? → \`/learn\`
- [ ] **CHANGELOG**: Did I update CHANGELOG.md + VERSION?
- [ ] **Commit**: Are all changes committed with a descriptive message?
- [ ] **STATUS.md**: Did I update STATUS.md with current progress for multi-phase tasks?
- [ ] **Push**: Ready to push? Confirm with user before pushing.
- [ ] **Vault**: Did I update vault/memory/status.md with session progress?
- [ ] **Decisions**: Any significant decisions? → Log in vault/memory/decisions/

---

## Execution Matrices

### Bug Fix Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | \`/investigate\` — reproduce & understand | Can reproduce? |
| 2 | Plan fix approach | Root cause identified? |
| 3 | Implement fix | Code change minimal & correct? |
| 4 | Verify: lint + typecheck + test + build | All pass? |
| 5 | \`/review\` | No issues? |
| 6 | \`/cso\` (if security-related) | No vulnerabilities? |
| 7 | Update docs + CHANGELOG | Docs accurate? |
| 8 | \`/qa\` | App works? |
| 9 | \`/ship\` | PR/deploy clean? |
| 10 | \`/learn\` | Lesson captured? |

### Feature Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | \`/plan-eng-review\` | Plan approved? |
| 2 | Build — implement feature | Code complete? |
| 3 | Write tests | Coverage adequate? |
| 4 | Verify: lint + typecheck + test + build | All pass? |
| 5 | \`/review\` | No issues? |
| 6 | \`/cso\` | No security gaps? |
| 7 | Update docs + CHANGELOG + VERSION | Docs accurate? |
| 8 | \`/qa\` | Feature works end-to-end? |
| 9 | \`/ship\` | PR/deploy clean? |
| 10 | \`/canary\` | No regressions? |
| 11 | \`/learn\` | Lessons captured? |

### Deploy Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | Verify: lint + typecheck + test + build | All pass? |
| 2 | \`/review\` | No issues? |
| 3 | \`/cso\` | Secure? |
| 4 | \`/qa\` | QA pass? |
| 5 | Update CHANGELOG + VERSION | Done? |
| 6 | \`/ship\` | Deploy triggered? |
| 7 | \`/canary\` — monitor post-deploy | Healthy? |

### Weekly Cadence

| Day | Task |
|-----|------|
| Monday | Review open PRs, triage issues |
| Wednesday | \`/retro\` — mid-week check |
| Friday | \`/retro\` — weekly retrospective, update CLAUDE.md, run \`vault-tools.sh doctor\` |

### Failure Recovery Table

| Failure | Recovery Action |
|---------|----------------|
| Test fails after code change | Revert change, re-investigate, fix root cause |
| Build fails | Check compiler errors, fix type/syntax issues |
| Lint fails | Auto-fix with formatter, then manual review |
| Deploy fails | Rollback, check logs, fix and re-deploy |
| \`/cso\` finds vulnerability | Block deploy, fix immediately, re-run \`/cso\` |
| QA regression | Investigate with \`/investigate\`, add regression test |

---

## Session Learnings

Stored in \`tools/learnings/${short}-learnings.jsonl\`. Use \`/learn\` to add new entries.

### Format (JSONL)
\`\`\`json
{"date": "2026-04-15", "category": "bug|gotcha|pattern|decision", "summary": "One-line summary", "detail": "Full explanation", "files": ["path/to/relevant/file"]}
\`\`\`

To query: \`grep "keyword" tools/learnings/${short}-learnings.jsonl\`
To add: \`/${short}-learn "description"\` or append a JSON line manually.
SESSIONHEAD

    # gstack browser integration (conditional)
    if [[ -d "$HOME/.claude/skills/gstack" ]]; then
      cat >> "$session_out" << 'GSTACK_RULES'

---

## gstack Browser Integration

Use `$B` commands for browser interactions (~20x faster than Playwright MCP):
- `$B goto <url>` — navigate | `$B snapshot` — page structure | `$B click @e1` — click
- `$B fill @e1 "text"` — fill input | `$B screenshot` — capture | `$B diff` — compare
- `$B console` — logs | `$B network` — requests | `$B chain "cmd1" "cmd2"` — chain
GSTACK_RULES
    fi

    log_ok "Written .claude/rules/session-protocol.md"
  fi

  # ── invariants.md ────────────────────────────────────────────
  local inv_out="$rules_dir/invariants.md"
  if preserve_rule "$inv_out"; then
    cat > "$inv_out" << 'INVHEAD'
# Invariants & Project Profile

INVHEAD

    # Domain-based invariants
    if [[ "$domain_count" -gt 0 ]]; then
      local inv_num=1
      echo "$m" | jq -r '.domain.detected_domains[] | .name' 2>/dev/null | while IFS= read -r domain; do
        case "$domain" in
          auth)
            echo "## INV-${inv_num}: Authentication guards on all protected endpoints"
            echo "Every endpoint handling user data must have auth middleware/guards applied."
            echo ""
            ;;
          database)
            local orm_val
            orm_val=$(echo "$m" | jq -r '.domain.detected_domains[] | select(.name == "database") | .orm // "unknown"')
            echo "## INV-${inv_num}: Database access through ORM only (${orm_val})"
            echo "No raw SQL queries — all database access through the ORM layer."
            echo ""
            ;;
          api)
            echo "## INV-${inv_num}: Input validation on all API endpoints"
            echo "Every endpoint accepting user input must validate and sanitize before processing."
            echo ""
            ;;
          ai)
            echo "## INV-${inv_num}: LLM trust boundary enforcement"
            echo "Never trust LLM output as safe — validate, sanitize, and scope all AI-generated content."
            echo ""
            ;;
          sandbox)
            echo "## INV-${inv_num}: Sandbox isolation for code execution"
            echo "All user code execution must run in an isolated sandbox with resource limits."
            echo ""
            ;;
        esac
        inv_num=$((inv_num + 1))
      done >> "$inv_out"
    fi

    # Ensure minimum invariants
    local inv_count
    inv_count=$(grep -c '^## INV-' "$inv_out" 2>/dev/null || echo "0")
    if [[ "$inv_count" -lt 2 ]]; then
      local next_inv=$((inv_count + 1))
      echo "" >> "$inv_out"
      echo "## INV-${next_inv}: No secrets in source code" >> "$inv_out"
      echo "Never commit API keys, passwords, tokens, or credentials." >> "$inv_out"
      echo "" >> "$inv_out"
    fi

    # Archetype section
    local arch_type arch_maturity
    arch_type=$(echo "$m" | jq -r '.archetype.type // "unknown"')
    arch_maturity=$(echo "$m" | jq -r '.archetype.maturity // "unknown"')
    if [[ "$arch_type" != "unknown" && "$arch_type" != "null" ]]; then
      echo "---" >> "$inv_out"
      echo "" >> "$inv_out"
      echo "## Project Profile" >> "$inv_out"
      echo "" >> "$inv_out"
      echo "- **Archetype**: ${arch_type}" >> "$inv_out"
      echo "- **Maturity**: ${arch_maturity}" >> "$inv_out"
      echo "- **Complexity**: $(echo "$m" | jq -r '.archetype.complexity // "unknown"')" >> "$inv_out"
      echo "" >> "$inv_out"

      # Archetype invariants
      local arch_data="$ROOT_DIR/lib/data/archetypes.json"
      if [[ -f "$arch_data" ]]; then
        local extra_inv
        extra_inv=$(jq -r --arg a "$arch_type" '.archetypes[$a].extra_invariants[]? | if type == "object" then "[\(.id // "-")]: \(.rule // "-")" else . end // empty' "$arch_data" 2>/dev/null)
        if [[ -n "$extra_inv" ]]; then
          echo "### Archetype Invariants" >> "$inv_out"
          echo "" >> "$inv_out"
          while IFS= read -r inv; do
            [[ -z "$inv" ]] && continue
            echo "- ${inv}" >> "$inv_out"
          done <<< "$extra_inv"
          echo "" >> "$inv_out"
        fi
      fi
    fi

    # Enhancement Summary (from _enhance)
    local enhance_count
    enhance_count=$(echo "$m" | jq '._enhance.enhancements | length' 2>/dev/null || echo "0")
    if [[ "$enhance_count" -gt 0 ]]; then
      echo "---" >> "$inv_out"
      echo "" >> "$inv_out"
      echo "## Enhancement Summary" >> "$inv_out"
      echo "" >> "$inv_out"
      echo "> Manifest enriched by AI-powered analysis (\`aiframework enhance\`)." >> "$inv_out"
      local enh_date enh_gaps
      enh_date=$(echo "$m" | jq -r '._enhance.enhanced_at // "unknown"' 2>/dev/null)
      enh_gaps=$(echo "$m" | jq -r '._enhance.gaps_analyzed // 0' 2>/dev/null)
      echo "- Enhanced: ${enh_date} | Gaps: ${enh_gaps} | Findings: ${enhance_count}" >> "$inv_out"
      echo "" >> "$inv_out"
    fi

    # Review specialists
    if [[ "$domain_count" -gt 0 ]]; then
      echo "---" >> "$inv_out"
      echo "" >> "$inv_out"
      echo "## Review Specialists" >> "$inv_out"
      echo "" >> "$inv_out"

      echo "$m" | jq -r '.domain.detected_domains[] | .name' 2>/dev/null | while IFS= read -r spec_domain; do
        local spec_display
        spec_display=$(echo "$m" | jq -r --arg n "$spec_domain" '.domain.detected_domains[] | select(.name == $n) | .display' 2>/dev/null)
        local spec_paths
        spec_paths=$(echo "$m" | jq -r --arg n "$spec_domain" '.domain.detected_domains[] | select(.name == $n) | .paths[:3] | join(", ") // "N/A"' 2>/dev/null)
        echo "### ${spec_display}" >> "$inv_out"
        echo "Trigger paths: ${spec_paths}" >> "$inv_out"
        echo "" >> "$inv_out"

        case "$spec_domain" in
          auth)
            echo "- [ ] All protected endpoints have auth middleware" >> "$inv_out"
            echo "- [ ] Session tokens are validated on every request" >> "$inv_out"
            echo "- [ ] Password hashing uses bcrypt/argon2 (never MD5/SHA1)" >> "$inv_out"
            echo "- [ ] JWT secrets are not hardcoded" >> "$inv_out"
            echo "- [ ] Rate limiting on login/register endpoints" >> "$inv_out"
            echo "- [ ] CSRF protection enabled for state-changing operations" >> "$inv_out"
            echo "- [ ] Logout invalidates session/token server-side" >> "$inv_out"
            ;;
          database)
            echo "- [ ] All queries go through ORM — no raw SQL" >> "$inv_out"
            echo "- [ ] Migrations are reversible (up + down)" >> "$inv_out"
            echo "- [ ] Indexes exist for frequently queried columns" >> "$inv_out"
            echo "- [ ] N+1 query patterns avoided" >> "$inv_out"
            echo "- [ ] Sensitive data is encrypted at rest" >> "$inv_out"
            echo "- [ ] Connection pooling configured" >> "$inv_out"
            echo "- [ ] Schema changes have migration files" >> "$inv_out"
            ;;
          api)
            echo "- [ ] All inputs validated before processing" >> "$inv_out"
            echo "- [ ] Error responses use consistent format" >> "$inv_out"
            echo "- [ ] Rate limiting configured for public endpoints" >> "$inv_out"
            echo "- [ ] CORS policy is restrictive (not wildcard)" >> "$inv_out"
            echo "- [ ] Response types are explicitly defined" >> "$inv_out"
            echo "- [ ] No sensitive data in URL parameters" >> "$inv_out"
            echo "- [ ] Pagination on list endpoints" >> "$inv_out"
            echo "- [ ] API versioning strategy documented" >> "$inv_out"
            ;;
          ai)
            echo "- [ ] LLM outputs are sanitized before use" >> "$inv_out"
            echo "- [ ] Prompt injection defenses in place" >> "$inv_out"
            echo "- [ ] Token limits enforced per request" >> "$inv_out"
            echo "- [ ] API keys stored in env vars, not code" >> "$inv_out"
            echo "- [ ] Fallback behavior when LLM is unavailable" >> "$inv_out"
            echo "- [ ] Cost monitoring/alerting configured" >> "$inv_out"
            echo "- [ ] Output validation before displaying to users" >> "$inv_out"
            ;;
          sandbox)
            echo "- [ ] Code execution isolated in sandbox" >> "$inv_out"
            echo "- [ ] Resource limits (CPU, memory, time) enforced" >> "$inv_out"
            echo "- [ ] Network access restricted in sandbox" >> "$inv_out"
            echo "- [ ] Filesystem access scoped to workspace" >> "$inv_out"
            echo "- [ ] Process cleanup after execution" >> "$inv_out"
            ;;
          frontend)
            echo "- [ ] XSS prevention — no dangerouslySetInnerHTML without sanitization" >> "$inv_out"
            echo "- [ ] Forms have proper validation" >> "$inv_out"
            echo "- [ ] Loading and error states handled" >> "$inv_out"
            echo "- [ ] Accessibility: semantic HTML, ARIA labels" >> "$inv_out"
            echo "- [ ] Responsive design tested" >> "$inv_out"
            echo "- [ ] Images optimized and lazy-loaded" >> "$inv_out"
            ;;
          external-apis)
            echo "- [ ] API keys in env vars, not code" >> "$inv_out"
            echo "- [ ] Retry logic with exponential backoff" >> "$inv_out"
            echo "- [ ] Timeout configuration on all HTTP calls" >> "$inv_out"
            echo "- [ ] Error handling for rate limits (429)" >> "$inv_out"
            echo "- [ ] Response validation before use" >> "$inv_out"
            ;;
          workers)
            echo "- [ ] Idempotent job processing" >> "$inv_out"
            echo "- [ ] Dead letter queue for failed jobs" >> "$inv_out"
            echo "- [ ] Job timeout configured" >> "$inv_out"
            echo "- [ ] Concurrency limits set" >> "$inv_out"
            echo "- [ ] Monitoring/alerting on job failures" >> "$inv_out"
            ;;
          *)
            echo "- [ ] Code follows project conventions" >> "$inv_out"
            echo "- [ ] Tests cover critical paths" >> "$inv_out"
            echo "- [ ] No hardcoded secrets" >> "$inv_out"
            ;;
        esac
        echo "" >> "$inv_out"
      done
    fi

    log_ok "Written .claude/rules/invariants.md"
  fi
}

# --- Reference architecture doc (complex/enterprise projects) ---
_generate_reference_docs() {
  _extract_claude_md_vars
  local m="$_cm_m" name="$_cm_name" lang="$_cm_lang" fw="$_cm_fw"
  local domain_count="$_cm_domain_count" is_mono="$_cm_is_mono"
  local desc="$_cm_desc" deploy="$_cm_deploy" key_deps="$_cm_key_deps"

  local ref_dir="$TARGET_DIR/docs/reference"
  mkdir -p "$ref_dir"
  local arch_out="$ref_dir/architecture.md"

  # Skip if user-created (not generated by us)
  if [[ -f "$arch_out" ]] && ! grep -q 'Generated by aiframework' "$arch_out" 2>/dev/null; then
    log_info "Preserved existing docs/reference/architecture.md"
    return 0
  fi

  cat > "$arch_out" << ARCHHEAD
# Architecture Reference — ${name}

> **Stack:** ${lang} / ${fw}$(if [[ -n "$key_deps" && "$key_deps" != "none" ]]; then echo " / ${key_deps}"; fi)
$(if [[ "$deploy" != "none" ]]; then echo "> **Deploy:** ${deploy}"; fi)

ARCHHEAD

  # Project structure tree
  echo "## Project Structure" >> "$arch_out"
  echo "" >> "$arch_out"
  echo '```' >> "$arch_out"
  echo "$m" | jq -r '.structure.directories[]' 2>/dev/null | while IFS= read -r dir; do
    echo "├── ${dir}/"
    if [[ -d "$TARGET_DIR/$dir" ]]; then
      local subdirs
      subdirs=$(find "$TARGET_DIR/$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | sed "s|$TARGET_DIR/$dir/||")
      if [[ -n "$subdirs" ]]; then
        while IFS= read -r subdir; do
          echo "│   ├── ${subdir}/"
        done <<< "$subdirs"
      fi
    fi
  done >> "$arch_out"
  echo "$m" | jq -r '.structure.config_files[]' 2>/dev/null | while IFS= read -r f; do
    echo "├── ${f}"
  done >> "$arch_out"
  echo '```' >> "$arch_out"
  echo "" >> "$arch_out"

  # Module map from code-index
  local code_index_path="${OUTPUT_DIR}/code-index.json"
  if [[ -f "$code_index_path" ]] && command -v jq >/dev/null 2>&1; then
    local module_count
    module_count=$(jq '.modules | length' "$code_index_path" 2>/dev/null || echo "0")
    if [[ "$module_count" -gt 0 ]]; then
      echo "## Module Map" >> "$arch_out"
      echo "" >> "$arch_out"
      echo "| Module | Role | Files | Key Symbols | Depends On |" >> "$arch_out"
      echo "|--------|------|-------|-------------|------------|" >> "$arch_out"
      jq -r '
        . as $root |
        .modules | to_entries[] | select(.key != ".") |
        .key as $mod |
        .value as $data |
        ($data.files | length) as $fcount |
        ([$root.files | to_entries[] | select(.key | startswith($mod + "/")) | .value.symbols[]? | if type == "object" then .name else empty end] | unique | .[0:3] | join(", ")) as $syms |
        ([$root.edges[] | select(.source | startswith($mod + "/")) | .target | split("/")[0:2] | join("/")] | unique | .[0:3] | join(", ")) as $deps |
        "| \($mod) | \($data.role // "-") | \($fcount) | \(if $syms == "" then "-" else $syms end) | \(if $deps == "" then "-" else $deps end) |"
      ' "$code_index_path" 2>/dev/null >> "$arch_out"
      echo "" >> "$arch_out"

      # Hot spots
      echo "### Architecture Hot Spots" >> "$arch_out"
      echo "" >> "$arch_out"
      local highest_fan_in
      highest_fan_in=$(jq -r '.modules | to_entries | sort_by(-.value.fan_in) | .[0] | if .value.fan_in > 0 then "- **Highest fan-in**: `\(.key)` (imported by \(.value.fan_in) modules)" else empty end' "$code_index_path" 2>/dev/null)
      [[ -n "$highest_fan_in" ]] && echo "$highest_fan_in" >> "$arch_out"
      local most_complex
      most_complex=$(jq -r '.modules | to_entries | sort_by(-.value.total_symbols) | .[0] | if .value.total_symbols > 0 then "- **Most complex**: `\(.key)` (\(.value.total_symbols) symbols across \(.value.files | length) files)" else empty end' "$code_index_path" 2>/dev/null)
      [[ -n "$most_complex" ]] && echo "$most_complex" >> "$arch_out"
      echo "" >> "$arch_out"
    fi

    # Repo map
    local top_files
    top_files=$(jq -r '._meta.top_files // [] | [.[] | select(.[0] | test("__init__\\.py$") | not)] | .[:15][] | "- `\(.[0])`"' "$code_index_path" 2>/dev/null)
    if [[ -n "$top_files" ]]; then
      echo "## Repo Map (Most Important Files)" >> "$arch_out"
      echo "" >> "$arch_out"
      echo "> Files ranked by architectural importance (how many other files depend on them)." >> "$arch_out"
      echo "" >> "$arch_out"
      echo "$top_files" >> "$arch_out"
      echo "" >> "$arch_out"
    fi
  fi

  # Architecture diagram if 3+ domains
  if [[ "$domain_count" -ge 3 ]]; then
    echo "## Architecture Overview" >> "$arch_out"
    echo "" >> "$arch_out"
    echo '```' >> "$arch_out"
    local has_frontend=false has_api=false has_db=false has_auth=false has_ai=false has_workers=false
    echo "$m" | jq -r '.domain.detected_domains[].display' 2>/dev/null | while IFS= read -r dname; do
      case "$dname" in
        *Frontend*) has_frontend=true ;; *API*) has_api=true ;; *Database*) has_db=true ;;
        *Auth*) has_auth=true ;; *AI*|*LLM*) has_ai=true ;; *Worker*|*Job*) has_workers=true ;;
      esac
    done
    # Simplified diagram
    echo "  [Client] → [API/Auth] → [Business Logic] → [Data/Services]" >> "$arch_out"
    echo '```' >> "$arch_out"
    echo "" >> "$arch_out"
  fi

  # Monorepo layout
  if [[ "$is_mono" == "true" ]]; then
    echo "## Monorepo Layout" >> "$arch_out"
    echo "" >> "$arch_out"
    echo "$m" | jq -r '.stack.monorepo_apps[]' 2>/dev/null | while IFS= read -r app; do
      echo "- \`apps/${app}/\`"
    done >> "$arch_out"
    echo "$m" | jq -r '.stack.monorepo_libs[]' 2>/dev/null | while IFS= read -r lib; do
      echo "- \`libs/${lib}/\`"
    done >> "$arch_out"
    echo "" >> "$arch_out"
  fi

  # Core Principles
  echo "## Core Principles" >> "$arch_out"
  echo "" >> "$arch_out"
  local core_principles
  core_principles=$(echo "$m" | jq -r '.domain.core_principles[]?' 2>/dev/null)
  if [[ -n "$core_principles" ]]; then
    local cp_num=1
    while IFS= read -r principle; do
      [[ -z "$principle" ]] && continue
      echo "${cp_num}. ${principle}" >> "$arch_out"
      cp_num=$((cp_num + 1))
    done <<< "$core_principles"
  else
    echo "1. Code must pass all configured quality gates before merge" >> "$arch_out"
    local _lang_ref="$lang"
    if [[ -n "$_lang_ref" && "$_lang_ref" != "unknown" ]]; then
      echo "2. Follow ${_lang_ref} community conventions and idioms" >> "$arch_out"
    fi
    echo "3. Never commit secrets, credentials, or API keys — use environment variables" >> "$arch_out"
  fi
  echo "" >> "$arch_out"

  # CI Workflows
  local ci_workflow_count
  ci_workflow_count=$(echo "$m" | jq '.ci.workflows | length' 2>/dev/null || echo "0")
  if [[ "$ci_workflow_count" -gt 0 ]]; then
    echo "## CI Workflows" >> "$arch_out"
    echo "" >> "$arch_out"
    echo "| Workflow | Purpose | Trigger |" >> "$arch_out"
    echo "|----------|---------|---------|" >> "$arch_out"
    echo "$m" | jq -r '.ci.workflows[]? | "| `\(.file)` | \(.purpose // "-") | \(.trigger // "-") |"' 2>/dev/null >> "$arch_out" || true
    echo "" >> "$arch_out"
  fi

  # GitHub Secrets
  local secrets_count
  secrets_count=$(echo "$m" | jq '.ci.github_secrets | length' 2>/dev/null || echo "0")
  if [[ "$secrets_count" -gt 0 ]]; then
    echo "## GitHub Secrets" >> "$arch_out"
    echo "" >> "$arch_out"
    echo "| Secret | Used By |" >> "$arch_out"
    echo "|--------|---------|" >> "$arch_out"
    echo "$m" | jq -r '.ci.github_secrets[]' 2>/dev/null | while IFS= read -r secret; do
      local used_by
      used_by=$(echo "$m" | jq -r --arg s "$secret" '.ci.workflows[]? | select(.secrets != null and (.secrets | contains($s))) | .file' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
      [[ -z "$used_by" ]] && used_by="-"
      echo "| ${secret} | \`${used_by}\` |"
    done >> "$arch_out"
    echo "" >> "$arch_out"
  fi

  # API contract rules
  local has_api_domain
  has_api_domain=$(echo "$m" | jq -r '.domain.detected_domains[] | select(.name == "api") | .name' 2>/dev/null)
  if [[ -n "$has_api_domain" ]]; then
    echo "## API Contract Rules" >> "$arch_out"
    echo "" >> "$arch_out"
    echo "- All API endpoints MUST validate input before processing" >> "$arch_out"
    echo "- Response shapes must be consistent — use typed response wrappers" >> "$arch_out"
    echo "- Never expose internal errors to clients — use error codes" >> "$arch_out"
    echo "- Breaking API changes require version bump and migration plan" >> "$arch_out"
    echo "" >> "$arch_out"
  fi

  echo "---" >> "$arch_out"
  echo "" >> "$arch_out"
  echo "*Generated by aiframework. Run \`aiframework refresh\` to update.*" >> "$arch_out"

  log_ok "Written docs/reference/architecture.md"
}

# --- Dispatcher: picks lean vs full based on project complexity ---
generate_claude_md() {
  local complexity
  complexity=$(echo "$MANIFEST" | jq -r '.archetype.complexity // "moderate"')

  # All projects get the lean CLAUDE.md (~120 lines)
  generate_claude_md_lean

  # Moderate+ projects get extended rules + reference docs
  if [[ "$complexity" == "moderate" || "$complexity" == "complex" || "$complexity" == "enterprise" ]]; then
    _generate_extended_rules
    _generate_reference_docs
  fi
}
