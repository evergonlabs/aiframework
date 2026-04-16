#!/usr/bin/env bash
# Generator: CLAUDE.md
# Reads manifest.json and produces a complete CLAUDE.md
#
# Architecture:
#   generate_claude_md()          — dispatcher: lean for all, extended rules for complex
#   generate_claude_md_lean()     — 80-150 line high-signal CLAUDE.md (all projects)
#   _generate_extended_rules()    — .claude/rules/ files (complex/enterprise only)
#   _generate_reference_docs()    — docs/reference/architecture.md (complex/enterprise only)
#   generate_claude_md_full()     — [LEGACY] verbose single-file output, kept as reference

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

$(if [[ "$desc" != "NOT_FOUND" && "$desc" != "No description" && -n "$desc" ]]; then echo "> ${desc}. Stack: ${lang}/${fw}."; else echo "> Stack: ${lang}/${fw}."; fi)

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
    top_files=$(jq -r '._meta.top_files // [] | .[:10][] | "- `\(.[0])`"' "$code_index_path" 2>/dev/null)
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

# --- Sub-functions for generate_claude_md_full() decomposition ---
# Each _emit_* function writes its section to $_cm_out using $_cm_* variables.
# They must be called after _extract_claude_md_vars().

_emit_header_and_doc_table() {
  local m="$_cm_m" out="$_cm_out"
  local name="$_cm_name" today="$_cm_today"

  cat > "$out" << CLAUDEMD
# CLAUDE.md — ${name}

**Source of truth for Claude Code in this repository.**
**Update this file after significant decisions, bug fixes, or architectural changes.**

**Last updated: ${today}**

---

## When to Read Which Doc

| You need to... | Read |
|----------------|------|
| Understand how to work in this repo | This file (CLAUDE.md) |
| Debug a recurring issue | \`docs/LESSONS_LEARNED.md\` (if exists) |
CLAUDEMD

  # Generate doc entries from manifest doc_dirs
  local doc_dirs_json
  doc_dirs_json=$(echo "$m" | jq -r '.structure.doc_dirs[]' 2>/dev/null)
  if [[ -n "$doc_dirs_json" ]]; then
    while IFS= read -r ddir; do
      echo "| Find documentation | \`${ddir}/\` |" >> "$out"
    done <<< "$doc_dirs_json"
  fi

  # Generate config file entries
  local config_files_json
  config_files_json=$(echo "$m" | jq -r '.structure.config_files[]' 2>/dev/null)
  if [[ -n "$config_files_json" ]]; then
    while IFS= read -r cfile; do
      case "$cfile" in
        tsconfig*) echo "| Understand TypeScript config | \`${cfile}\` |" >> "$out" ;;
        package.json) echo "| Check dependencies & scripts | \`${cfile}\` |" >> "$out" ;;
        Dockerfile) echo "| Understand container setup | \`${cfile}\` |" >> "$out" ;;
        docker-compose*|compose*) echo "| Understand local infra | \`${cfile}\` |" >> "$out" ;;
        Makefile) echo "| See available make targets | \`${cfile}\` |" >> "$out" ;;
        pyproject.toml) echo "| Check Python config & deps | \`${cfile}\` |" >> "$out" ;;
        Cargo.toml) echo "| Check Rust config & deps | \`${cfile}\` |" >> "$out" ;;
        go.mod) echo "| Check Go module & deps | \`${cfile}\` |" >> "$out" ;;
      esac
    done <<< "$config_files_json"
  fi

  echo "" >> "$out"
  echo "---" >> "$out"
  echo "" >> "$out"
}

_emit_decision_priority_and_workflow() {
  local out="$_cm_out"

  cat >> "$out" << 'CLAUDEMD'
## Decision Priority

When instructions conflict, follow this order:
1. **User's explicit instruction** in the current conversation
2. **Invariants** (below) — these are never overridden
3. **Workflow Rules** (below) — process guardrails
4. **Core Principles** (below) — design philosophy
5. **Reference docs** (\`docs/\`) — context, but code is always the source of truth

When determining system behavior (API shapes, data flow, field names):
1. **Read the code** — schemas, route handlers, models are the source of truth
2. **Verified external docs** — official API docs, confirmed library behavior
3. **Assume nothing** — if you can't verify it, say so

---

## Workflow Rules

### 1. Plan vs Execute
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan — don't keep pushing
- When given a task with clear scope: start executing immediately
- When hitting a wall (3+ failed attempts), stop and re-plan approach

### 2. Autonomous Iteration
- Execute fix → verify with tests → if broken, fix again → loop until clean
- Iterate autonomously: don't ask for hand-holding on fixable issues
- Commit after each logical group of verified fixes

### 3. Verification Before Done
- Never mark a task complete without proving it works
- Run verification commands (Stage 4) — never assume it compiles
- Never claim "done" without running the actual verification command

### 4. Git Safety
- After fixes: \`git add\` + \`git commit\` — but do NOT push until user says so
- NEVER push to main without explicit user confirmation
- NEVER commit after every small change — batch related changes into logical commits
- Prefer fewer, larger commits over many small ones

### 5. Subagent Strategy
- Use subagents for research, exploration, and parallel analysis
- Limit to 6-8 agents per wave maximum
- After each wave: summarize results, commit, then start next wave
- Use \`/compact\` after each major milestone to maintain headroom

### 6. QA Auto-Fix
When QA discovers issues, ALL must be automatically fixed:
1. Run tests — collect all failures
2. Fix each failure: identify root cause → fix implementation (never skip a test)
3. Run type check → must pass
4. Run tests again — all must pass
5. Commit
CLAUDEMD
}

_emit_qa_autofix() {
  local out="$_cm_out" lang="$_cm_lang"

  # Language-specific QA rules — data-driven from languages.json
  local qa_data_file="$ROOT_DIR/lib/data/languages.json"
  if [[ -f "$qa_data_file" ]] && command -v jq &>/dev/null; then
    local qa_rules
    qa_rules=$(jq -r --arg l "$lang" '.languages[$l].qa_rules[]? // empty' "$qa_data_file" 2>/dev/null)
    if [[ -n "$qa_rules" ]]; then
      local lang_display
      lang_display=$(echo "$lang" | awk '{print toupper(substr($0,1,1)) substr($0,2)}' | sed 's/Csharp/C#/; s/Cpp/C++/')
      echo "" >> "$out"
      echo "**${lang_display} QA Rules:**" >> "$out"
      while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        echo "- ${rule}" >> "$out"
      done <<< "$qa_rules"
    fi
  else
    # Fallback: keep existing case block
    case "$lang" in
      typescript|javascript)
        cat >> "$out" << 'QABLOCK'

**TypeScript QA Rules:**
- NEVER use `as any` — use proper types or generics
- NEVER use `@ts-ignore` — fix the underlying type error
- NEVER use `// @ts-expect-error` without a description of why
QABLOCK
        ;;
      rust)
        cat >> "$out" << 'QABLOCK'

**Rust QA Rules:**
- NEVER use `unsafe` blocks without explicit justification in comments
- NEVER use `#[allow(dead_code)]` — remove unused code instead
- NEVER use `unwrap()` in production code — use proper error handling
QABLOCK
        ;;
      python)
        cat >> "$out" << 'QABLOCK'

**Python QA Rules:**
- NEVER use `type: ignore` without a justification comment explaining why
- NEVER use bare `except:` — always catch specific exceptions
- NEVER use `# noqa` without specifying the rule being suppressed
QABLOCK
        ;;
      go)
        cat >> "$out" << 'QABLOCK'

**Go QA Rules:**
- NEVER use `//nolint` without a justification comment explaining why
- NEVER ignore errors — always handle or explicitly document why ignored
- NEVER use `interface{}` without justification — prefer typed alternatives
QABLOCK
        ;;
    esac
  fi

  cat >> "$out" << 'CLAUDEMD'

### 7. Documentation Auto-Sync
After ANY feature implementation, refactor, or significant change — before marking complete:
1. CLAUDE.md — if change adds invariants, new key locations, new commands
2. docs/ — update relevant doc files

### 8. Changelog Update
After marking any feature complete and before pushing:
1. Update CHANGELOG.md with user-facing description of changes
2. Bump VERSION file (PATCH for fixes, MINOR for features, MAJOR for breaking changes)

### 9. CLAUDE.md Auto-Evolution
This file is a living document that grows with the project. After ANY session with code changes:
- **New service/module added** → add to Key Locations
- **New env var added** → add to Environment Variables table
- **Non-obvious bug fixed** → add to Session Learnings via \`/learn\`
- **New invariant discovered** → add to Invariants section
- **Structural change** → update Project Structure
- NEVER delete content — only add, refine, or mark as deprecated

### 10. New Feature Checklist
Before marking any new feature complete, verify ALL applicable items:
- [ ] Feature works as specified
- [ ] Edge cases handled
- [ ] Error states covered
- [ ] Tests added for new functionality
- [ ] Documentation updated if needed
- [ ] No regressions in existing functionality

---

## Core Principles

CLAUDEMD
}

_emit_project_identity() {
  local m="$_cm_m" out="$_cm_out"
  local name="$_cm_name" desc="$_cm_desc" lang="$_cm_lang" fw="$_cm_fw"
  local is_mono="$_cm_is_mono" gh_url="$_cm_gh_url" local_path="$_cm_local_path"
  local deploy="$_cm_deploy" dev_port="$_cm_dev_port" key_deps="$_cm_key_deps"
  local domain_count="$_cm_domain_count"

  # Check manifest for core_principles
  local core_principles
  core_principles=$(echo "$m" | jq -r '.domain.core_principles[]?' 2>/dev/null)
  if [[ -n "$core_principles" ]]; then
    local cp_num=1
    while IFS= read -r principle; do
      [[ -z "$principle" ]] && continue
      echo "${cp_num}. ${principle}" >> "$out"
      cp_num=$((cp_num + 1))
    done <<< "$core_principles"
  else
    echo "*Core principles will emerge as the project matures. Add principles here when patterns are established.*" >> "$out"
    echo "" >> "$out"
    local cp_num=1
    echo "${cp_num}. Code must pass all configured quality gates before merge" >> "$out"
    cp_num=$((cp_num + 1))
    if [[ -n "$lang" && "$lang" != "unknown" ]]; then
      echo "${cp_num}. Follow ${lang} community conventions and idioms" >> "$out"
      cp_num=$((cp_num + 1))
    else
      echo "${cp_num}. Keep scripts simple, readable, and well-documented" >> "$out"
      cp_num=$((cp_num + 1))
    fi
    # Ensure at least 3 core principles
    if [[ "$cp_num" -lt 4 ]]; then
      echo "${cp_num}. Never commit secrets, credentials, or API keys — use environment variables" >> "$out"
      cp_num=$((cp_num + 1))
    fi
  fi

  # READ_ONLY_REPOS section
  local read_only_dirs
  read_only_dirs=$(echo "$m" | jq -r '.structure.read_only_dirs[]?' 2>/dev/null)
  if [[ -n "$read_only_dirs" ]]; then
    echo "" >> "$out"
    echo "---" >> "$out"
    echo "" >> "$out"
    echo "## READ_ONLY_REPOS" >> "$out"
    echo "" >> "$out"
    echo "The following directories are **read-only** — do NOT modify files in these paths:" >> "$out"
    echo "" >> "$out"
    while IFS= read -r ro_dir; do
      echo "- \`${ro_dir}/\`" >> "$out"
    done <<< "$read_only_dirs"
  fi

  cat >> "$out" << CLAUDEMD

---

## Project Identity

**${name}** — ${desc}

**Stack:** ${lang} / ${fw}$(if [[ -n "$key_deps" && "$key_deps" != "none" ]]; then echo " / ${key_deps}"; fi)
CLAUDEMD

  # Conditional sections
  [[ "$deploy" != "none" ]] && echo "**Deploy:** ${deploy}" >> "$out"
  [[ -n "$dev_port" ]] && echo "**Port:** ${dev_port}" >> "$out"

  cat >> "$out" << CLAUDEMD

---

## Repository

**GitHub:** \`${gh_url}\`
**Local path:** \`${local_path}\`

---

CLAUDEMD

  # --- Project Structure ---
  echo "## Project Structure" >> "$out"
  echo "" >> "$out"
  echo '```' >> "$out"
  # Generate tree from manifest — include subdirectories for key dirs
  echo "$m" | jq -r '.structure.directories[]' 2>/dev/null | while IFS= read -r dir; do
    echo "├── ${dir}/"
    # Show subdirectories (1 level deep) for source-code dirs
    if [[ -d "$TARGET_DIR/$dir" ]]; then
      local subdirs
      subdirs=$(find "$TARGET_DIR/$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | sed "s|$TARGET_DIR/$dir/||")
      if [[ -n "$subdirs" ]]; then
        while IFS= read -r subdir; do
          echo "│   ├── ${subdir}/"
        done <<< "$subdirs"
      fi
    fi
  done >> "$out"
  echo "$m" | jq -r '.structure.config_files[]' 2>/dev/null | while IFS= read -r f; do
    echo "├── ${f}"
  done >> "$out"
  echo '```' >> "$out"
  echo "" >> "$out"

  # Architecture diagram if 3+ domains
  if [[ "$domain_count" -ge 3 ]]; then
    echo "### Architecture Overview" >> "$out"
    echo "" >> "$out"
    echo '```' >> "$out"
    # Build ASCII diagram from detected domains
    local domain_names_list
    domain_names_list=$(echo "$m" | jq -r '.domain.detected_domains[].display' 2>/dev/null)
    local has_frontend=false has_api=false has_db=false has_auth=false has_ai=false has_workers=false
    while IFS= read -r dname; do
      case "$dname" in
        *Frontend*) has_frontend=true ;;
        *API*) has_api=true ;;
        *Database*) has_db=true ;;
        *Auth*) has_auth=true ;;
        *AI*|*LLM*) has_ai=true ;;
        *Worker*|*Job*) has_workers=true ;;
      esac
    done <<< "$domain_names_list"

    if $has_frontend; then
      echo "  [Client/Browser]" >> "$out"
      echo "        |" >> "$out"
      echo "        v" >> "$out"
    fi
    if $has_auth; then
      echo "  [Auth Layer] ──> [API Endpoints]" >> "$out"
    elif $has_api; then
      echo "  [API Endpoints]" >> "$out"
    fi
    if $has_api || $has_auth; then
      echo "        |" >> "$out"
      echo "        v" >> "$out"
    fi
    if $has_ai && $has_db; then
      echo "  [Business Logic]" >> "$out"
      echo "     /        \\" >> "$out"
      echo "    v          v" >> "$out"
      echo "  [Database]  [AI/LLM Service]" >> "$out"
    elif $has_db; then
      echo "  [Business Logic]" >> "$out"
      echo "        |" >> "$out"
      echo "        v" >> "$out"
      echo "  [Database]" >> "$out"
    elif $has_ai; then
      echo "  [Business Logic]" >> "$out"
      echo "        |" >> "$out"
      echo "        v" >> "$out"
      echo "  [AI/LLM Service]" >> "$out"
    fi
    if $has_workers; then
      echo "        |" >> "$out"
      echo "        v" >> "$out"
      echo "  [Background Workers/Jobs]" >> "$out"
    fi
    echo '```' >> "$out"
    echo "" >> "$out"
  fi

  # Monorepo section
  if [[ "$is_mono" == "true" ]]; then
    echo "### Monorepo Layout" >> "$out"
    echo "" >> "$out"
    echo "$m" | jq -r '.stack.monorepo_apps[]' 2>/dev/null | while IFS= read -r app; do
      echo "- \`apps/${app}/\`"
    done >> "$out"
    echo "$m" | jq -r '.stack.monorepo_libs[]' 2>/dev/null | while IFS= read -r lib; do
      echo "- \`libs/${lib}/\`"
    done >> "$out"
    echo "" >> "$out"

    # Shared Libraries / Path Aliases
    local mono_libs_list
    mono_libs_list=$(echo "$m" | jq -r '.stack.monorepo_libs[]' 2>/dev/null)
    if [[ -n "$mono_libs_list" ]]; then
      echo "### Shared Libraries" >> "$out"
      echo "" >> "$out"
      while IFS= read -r slib; do
        echo "- \`libs/${slib}/\` — shared library" >> "$out"
      done <<< "$mono_libs_list"
      echo "" >> "$out"
    fi

    # tsconfig path aliases
    if [[ -f "$TARGET_DIR/tsconfig.json" ]]; then
      local ts_paths
      ts_paths=$(jq -r '.compilerOptions.paths // empty | to_entries[] | "- \`\(.key)\` → \`\(.value[0])\`"' "$TARGET_DIR/tsconfig.json" 2>/dev/null)
      if [[ -n "$ts_paths" ]]; then
        echo "### Path Aliases (tsconfig)" >> "$out"
        echo "" >> "$out"
        echo "$ts_paths" >> "$out"
        echo "" >> "$out"
      fi
    elif [[ -f "$TARGET_DIR/tsconfig.base.json" ]]; then
      local ts_paths
      ts_paths=$(jq -r '.compilerOptions.paths // empty | to_entries[] | "- \`\(.key)\` → \`\(.value[0])\`"' "$TARGET_DIR/tsconfig.base.json" 2>/dev/null)
      if [[ -n "$ts_paths" ]]; then
        echo "### Path Aliases (tsconfig)" >> "$out"
        echo "" >> "$out"
        echo "$ts_paths" >> "$out"
        echo "" >> "$out"
      fi
    fi
  fi

}

_emit_project_structure() {
  local m="$_cm_m" out="$_cm_out"
  local is_mono="$_cm_is_mono" domain_count="$_cm_domain_count"
  # Note: project structure section is already emitted by _emit_project_identity
  # This function is a placeholder for future expansion
  :
}

_emit_key_commands() {
  local m="$_cm_m" out="$_cm_out"
  local name="$_cm_name" install="$_cm_install" dev_cmd="$_cm_dev_cmd"
  local build_cmd="$_cm_build_cmd" lint_cmd="$_cm_lint_cmd"
  local format_cmd="$_cm_format_cmd" typecheck="$_cm_typecheck"
  local test_cmd="$_cm_test_cmd"

  # --- Key Commands ---
  echo "---" >> "$out"
  echo "" >> "$out"
  echo "## Key Commands" >> "$out"
  echo "" >> "$out"
  echo '```bash' >> "$out"

  # Only show commands that are configured
  if [[ "$install" != "NOT_CONFIGURED" ]]; then
    echo "# Install" >> "$out"
    echo "$install" >> "$out"
    echo "" >> "$out"
  fi
  if [[ "$dev_cmd" != "NOT_CONFIGURED" ]]; then
    echo "# Dev" >> "$out"
    echo "$dev_cmd" >> "$out"
    echo "" >> "$out"
  fi
  if [[ "$build_cmd" != "NOT_CONFIGURED" ]]; then
    echo "# Build" >> "$out"
    echo "$build_cmd" >> "$out"
    echo "" >> "$out"
  fi
  if [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then
    echo "# Lint" >> "$out"
    echo "$lint_cmd" >> "$out"
    echo "" >> "$out"
  fi
  if [[ "$typecheck" != "NOT_CONFIGURED" ]]; then
    echo "# Type check" >> "$out"
    echo "$typecheck" >> "$out"
    echo "" >> "$out"
  fi
  if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then
    echo "# Test" >> "$out"
    echo "$test_cmd" >> "$out"
    echo "" >> "$out"
  fi

  # If nothing is configured, show a note
  local _any_cmd=false
  [[ "$install" != "NOT_CONFIGURED" || "$dev_cmd" != "NOT_CONFIGURED" || "$build_cmd" != "NOT_CONFIGURED" || "$lint_cmd" != "NOT_CONFIGURED" || "$typecheck" != "NOT_CONFIGURED" || "$test_cmd" != "NOT_CONFIGURED" ]] && _any_cmd=true
  if [[ "$_any_cmd" == false ]]; then
    echo "# No commands configured yet" >> "$out"
  fi

  [[ "$format_cmd" != "NOT_CONFIGURED" ]] && echo -e "\n# Format\n${format_cmd}" >> "$out"

  # Docker build command if Dockerfile exists
  local has_dockerfile
  has_dockerfile=$(echo "$m" | jq -r '.structure.config_files[] | select(. == "Dockerfile")' 2>/dev/null)
  if [[ -n "$has_dockerfile" ]]; then
    echo -e "\n# Docker\ndocker build -t ${name} ." >> "$out"
  fi

  echo '```' >> "$out"

  # Missing tools note — filter out tools detected by commands scanner
  local missing_arr=()
  local raw_missing
  raw_missing=$(echo "$m" | jq -r '.quality.missing_tools[]?' 2>/dev/null)
  if [[ -n "$raw_missing" ]]; then
    while IFS= read -r tool; do
      case "$tool" in
        linter) [[ "$lint_cmd" == "NOT_CONFIGURED" ]] && missing_arr+=("$tool") ;;
        type-checker) [[ "$typecheck" == "NOT_CONFIGURED" ]] && missing_arr+=("$tool") ;;
        test-framework) [[ "$test_cmd" == "NOT_CONFIGURED" ]] && missing_arr+=("$tool") ;;
        *) missing_arr+=("$tool") ;;
      esac
    done <<< "$raw_missing"
  fi
  if [[ ${#missing_arr[@]} -gt 0 ]]; then
    local missing_str
    missing_str=$(printf '%s\n' "${missing_arr[@]}" | paste -sd',' - | sed 's/,/, /g')
    echo "" >> "$out"
    echo "> **Note:** The following tools are not yet configured: ${missing_str}." >> "$out"
    echo "> Setting these up is recommended as a first step." >> "$out"
  fi

  echo "" >> "$out"

}

_emit_ci_and_key_locations() {
  local m="$_cm_m" out="$_cm_out" domain_count="$_cm_domain_count"

  # --- CI Workflows Table (F12) ---
  local ci_workflow_count
  ci_workflow_count=$(echo "$m" | jq '.ci.workflows | length' 2>/dev/null || echo "0")
  if [[ "$ci_workflow_count" -gt 0 ]]; then
    echo "---" >> "$out"
    echo "" >> "$out"
    echo "## CI Workflows" >> "$out"
    echo "" >> "$out"
    echo "| Workflow | Purpose | Trigger |" >> "$out"
    echo "|----------|---------|---------|" >> "$out"
    echo "$m" | jq -r '.ci.workflows[]? | "| \`\(.file)\` | \(.purpose // "-") | \(.trigger // "-") |"' 2>/dev/null >> "$out" || true
    echo "" >> "$out"
  fi

  # --- Key Locations ---
  echo "---" >> "$out"
  echo "" >> "$out"
  echo "## Key Locations" >> "$out"
  echo "" >> "$out"

  # Entry points
  local entries
  entries=$(echo "$m" | jq -r '.structure.entry_points[]' 2>/dev/null)
  if [[ -n "$entries" ]]; then
    while IFS= read -r entry; do
      echo "- **Entry point**: \`${entry}\`" >> "$out"
    done <<< "$entries"
  fi

  # Domain-specific locations
  echo "$m" | jq -r '.domain.detected_domains[]? | "- **\(.display)**: \(.paths[:5][]? // empty)"' 2>/dev/null >> "$out" || true

  # Config files from manifest
  local kl_config_files
  kl_config_files=$(echo "$m" | jq -r '.structure.config_files[]' 2>/dev/null)
  if [[ -n "$kl_config_files" ]]; then
    while IFS= read -r cfile; do
      [[ -z "$cfile" ]] && continue
      local cdesc=""
      case "$cfile" in
        package.json) cdesc="Project dependencies and scripts" ;;
        tsconfig*) cdesc="TypeScript compiler options" ;;
        Dockerfile) cdesc="Container image definition" ;;
        docker-compose*|compose*) cdesc="Local infrastructure services" ;;
        Makefile) cdesc="Build targets and automation" ;;
        pyproject.toml) cdesc="Python project config and dependencies" ;;
        Cargo.toml) cdesc="Rust crate config and dependencies" ;;
        go.mod) cdesc="Go module and dependencies" ;;
        .eslintrc*|eslint.config*) cdesc="Linting rules" ;;
        .prettierrc*|prettier.config*) cdesc="Code formatting rules" ;;
        jest.config*|vitest.config*) cdesc="Test runner configuration" ;;
        webpack.config*) cdesc="Webpack bundler config" ;;
        vite.config*) cdesc="Vite bundler config" ;;
        babel.config*|.babelrc*) cdesc="Babel transpiler config" ;;
        *.env*) cdesc="Environment variables template" ;;
        *) cdesc="Project configuration" ;;
      esac
      echo "- **Config**: \`${cfile}\` — ${cdesc}" >> "$out"
    done <<< "$kl_config_files"
  fi

  # Script directories from manifest
  local kl_script_dirs
  kl_script_dirs=$(echo "$m" | jq -r '.structure.script_dirs[]' 2>/dev/null)
  if [[ -n "$kl_script_dirs" ]]; then
    while IFS= read -r sdir; do
      [[ -z "$sdir" ]] && continue
      local sdesc=""
      case "$sdir" in
        bin|bin/) sdesc="CLI entry points and tools" ;;
        scripts|scripts/) sdesc="Automation scripts" ;;
        *) sdesc="Project scripts" ;;
      esac
      echo "- **Scripts**: \`${sdir}/\` — ${sdesc}" >> "$out"
    done <<< "$kl_script_dirs"
  fi

  # CI directories from manifest
  local kl_ci_dirs
  kl_ci_dirs=$(echo "$m" | jq -r '.structure.ci_dirs[]' 2>/dev/null)
  if [[ -n "$kl_ci_dirs" ]]; then
    while IFS= read -r cidir; do
      [[ -z "$cidir" ]] && continue
      echo "- **CI**: \`${cidir}/\` — CI/CD pipeline definitions" >> "$out"
    done <<< "$kl_ci_dirs"
  fi

  # Test directories from manifest
  local kl_test_dirs
  kl_test_dirs=$(echo "$m" | jq -r '.structure.test_dirs[]' 2>/dev/null)
  if [[ -n "$kl_test_dirs" ]]; then
    while IFS= read -r tdir; do
      [[ -z "$tdir" ]] && continue
      echo "- **Tests**: \`${tdir}/\` — Test suite" >> "$out"
    done <<< "$kl_test_dirs"
  fi

  # Additional key files from deep scan
  local kl_key_files
  kl_key_files=$(echo "$m" | jq -r '.structure.key_files[]' 2>/dev/null)
  if [[ -n "$kl_key_files" ]]; then
    while IFS= read -r kfile; do
      [[ -z "$kfile" ]] && continue
      local kfdesc=""
      case "$kfile" in
        *service*|*Service*) kfdesc="Business logic service" ;;
        *controller*|*Controller*) kfdesc="Request handler" ;;
        *model*|*Model*) kfdesc="Data model" ;;
        *schema*|*Schema*) kfdesc="Schema definition" ;;
        *route*|*Route*|*router*) kfdesc="Route definitions" ;;
        *handler*|*Handler*) kfdesc="Event/request handler" ;;
        *middleware*|*Middleware*) kfdesc="Middleware layer" ;;
        *config*|*Config*) kfdesc="Configuration" ;;
        *util*|*Util*|*helper*|*Helper*) kfdesc="Utility functions" ;;
        *README*) kfdesc="Module documentation" ;;
        */scanners/*) kfdesc="Repo analysis scanner" ;;
        */generators/*) kfdesc="File generator" ;;
        */validators/*) kfdesc="Verification module" ;;
        */scripts/*) kfdesc="Automation script" ;;
        *) kfdesc="Source module" ;;
      esac
      echo "- **Source**: \`${kfile}\` — ${kfdesc}" >> "$out"
    done <<< "$kl_key_files"
  fi

  # Component counts from manifest
  local kl_comp_summary
  kl_comp_summary=$(echo "$m" | jq -r '
    .domain.component_counts // {} |
    to_entries | map(select(.value > 0)) |
    if length > 0 then
      map("\(.value) \(.key)") | join(", ")
    else empty end
  ' 2>/dev/null)
  if [[ -n "$kl_comp_summary" ]]; then
    echo "- **Components**: ${kl_comp_summary}" >> "$out"
  fi

  local key_loc_count
  key_loc_count=$(echo "$m" | jq '[.structure.entry_points, (.domain.detected_domains[]?.paths // []), .structure.config_files, .structure.script_dirs, .structure.ci_dirs, .structure.test_dirs] | flatten | length' 2>/dev/null || echo "0")
  if [[ "$key_loc_count" == "0" ]]; then
    echo "*Key locations will be added as the project develops.*" >> "$out"
  fi

  # Component counts (Edit 20)
  local component_counts
  component_counts=$(echo "$m" | jq -r '.domain.detected_domains[]? | select(.components != null or .pages != null) | "- **\(.display)**: \(.file_count) files\(if .pages then ", \(.pages) pages" else "" end)\(if .components then ", \(.components) components" else "" end)"' 2>/dev/null)
  if [[ -n "$component_counts" ]]; then
    echo "" >> "$out"
    echo "### Component Counts" >> "$out"
    echo "" >> "$out"
    echo "$component_counts" >> "$out"
  fi

  echo "" >> "$out"

  # --- Module Map (from code-index.json) ---
  local code_index_path="${OUTPUT_DIR}/code-index.json"
  if [[ -f "$code_index_path" ]] && command -v jq >/dev/null 2>&1; then
    local module_count
    module_count=$(jq '.modules | length' "$code_index_path" 2>/dev/null || echo "0")
    if [[ "$module_count" -gt 0 ]]; then
      echo "---" >> "$out"
      echo "" >> "$out"
      echo "## Module Map" >> "$out"
      echo "" >> "$out"
      echo "| Module | Role | Files | Key Symbols | Depends On |" >> "$out"
      echo "|--------|------|-------|-------------|------------|" >> "$out"

      # Read modules and build table rows
      jq -r '
        . as $root |
        .modules | to_entries[] |
        .key as $mod |
        .value as $data |
        ($data.files | length) as $fcount |
        ([$root.symbols[] | select(.file | startswith($mod + "/")) | .name] | .[0:3] | join(", ")) as $syms |
        ([$root.edges[] | select(.source | startswith($mod + "/")) | .target | split("/")[0:2] | join("/")] | unique | join(", ")) as $deps |
        "| \($mod) | \($data.role // "-") | \($fcount) | \(if $syms == "" then "-" else $syms end) | \(if $deps == "" then "-" else $deps end) |"
      ' "$code_index_path" 2>/dev/null >> "$out"

      echo "" >> "$out"

      # --- Architecture Hot Spots ---
      echo "### Architecture Hot Spots" >> "$out"
      echo "" >> "$out"

      # Highest fan-in: module with most incoming edges
      local highest_fan_in
      highest_fan_in=$(jq -r '
        .modules | to_entries | sort_by(-.value.fan_in) | .[0] |
        if .value.fan_in > 0 then
          "- **Highest fan-in**: `\(.key)` (imported by \(.value.fan_in) modules)"
        else empty end
      ' "$code_index_path" 2>/dev/null)
      if [[ -n "$highest_fan_in" ]]; then
        echo "$highest_fan_in" >> "$out"
      fi

      # Most complex: module with most symbols
      local most_complex
      most_complex=$(jq -r '
        .modules | to_entries | sort_by(-.value.total_symbols) | .[0] |
        if .value.total_symbols > 0 then
          "- **Most complex**: `\(.key)` (\(.value.total_symbols) symbols across \(.value.files | length) files)"
        else empty end
      ' "$code_index_path" 2>/dev/null)
      if [[ -n "$most_complex" ]]; then
        echo "$most_complex" >> "$out"
      fi

      echo "" >> "$out"
    fi
  fi

  # --- Repo Map (from code-index.json PageRank) ---
  local code_index_path_rm="${OUTPUT_DIR}/code-index.json"
  if [[ -f "$code_index_path_rm" ]] && command -v jq &>/dev/null; then
    local top_files
    top_files=$(jq -r '._meta.top_files // [] | .[:15][] | "- `\(.[0])` (score: \(.[1]))"' "$code_index_path_rm" 2>/dev/null)
    if [[ -n "$top_files" ]]; then
      echo "---" >> "$out"
      echo "" >> "$out"
      echo "## Repo Map (Most Important Files)" >> "$out"
      echo "" >> "$out"
      echo "> Files ranked by architectural importance (how many other files depend on them)." >> "$out"
      echo "" >> "$out"
      echo "$top_files" >> "$out"
      echo "" >> "$out"
    fi
  fi

  # --- API Contract Rules (Edit 8) ---
  local has_api_domain
  has_api_domain=$(echo "$m" | jq -r '.domain.detected_domains[] | select(.name == "api") | .name' 2>/dev/null)
  if [[ -n "$has_api_domain" ]]; then
    echo "---" >> "$out"
    echo "" >> "$out"
    echo "## API Contract Rules" >> "$out"
    echo "" >> "$out"

    # Detect validation library
    local validation_lib="unknown"
    if [[ -f "$TARGET_DIR/package.json" ]]; then
      local pkg_content
      pkg_content=$(cat "$TARGET_DIR/package.json" 2>/dev/null)
      if echo "$pkg_content" | jq -e '.dependencies.zod // .devDependencies.zod' >/dev/null 2>&1; then
        validation_lib="zod"
      elif echo "$pkg_content" | jq -e '.dependencies.joi // .devDependencies.joi' >/dev/null 2>&1; then
        validation_lib="joi"
      elif echo "$pkg_content" | jq -e '.dependencies.yup // .devDependencies.yup' >/dev/null 2>&1; then
        validation_lib="yup"
      elif echo "$pkg_content" | jq -e '.dependencies["class-validator"] // .devDependencies["class-validator"]' >/dev/null 2>&1; then
        validation_lib="class-validator"
      fi
    elif [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
      if grep -q 'pydantic' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
        validation_lib="pydantic"
      fi
    fi

    # Get ORM from domain scanner
    local orm_name
    orm_name=$(echo "$m" | jq -r '.domain.detected_domains[] | select(.name == "database") | .orm // "none"' 2>/dev/null)

    echo "- **Validation:** ${validation_lib}" >> "$out"
    [[ -n "$orm_name" && "$orm_name" != "none" && "$orm_name" != "unknown" ]] && echo "- **ORM:** ${orm_name}" >> "$out"
    echo "- All API endpoints MUST validate input before processing" >> "$out"
    echo "- Response shapes must be consistent — use typed response wrappers" >> "$out"
    echo "- Never expose internal errors to clients — use error codes" >> "$out"
    echo "- Breaking API changes require version bump and migration plan" >> "$out"
    echo "" >> "$out"
  fi

  # --- Makefile System (Edit 9) ---
  local makefile_targets_json
  makefile_targets_json=$(echo "$m" | jq -r '.commands.makefile_targets[]?' 2>/dev/null)
  if [[ -n "$makefile_targets_json" ]]; then
    echo "---" >> "$out"
    echo "" >> "$out"
    echo "## Makefile System" >> "$out"
    echo "" >> "$out"
    echo "Available \`make\` targets:" >> "$out"
    echo "" >> "$out"
    echo '```bash' >> "$out"
    while IFS= read -r target; do
      echo "make ${target}" >> "$out"
    done <<< "$makefile_targets_json"
    echo '```' >> "$out"
    echo "" >> "$out"
  fi

}

_emit_pipeline_and_routing() {
  local m="$_cm_m" out="$_cm_out"
  local lint_cmd="$_cm_lint_cmd" typecheck="$_cm_typecheck"
  local test_cmd="$_cm_test_cmd" build_cmd="$_cm_build_cmd"
  local dev_port="$_cm_dev_port"

  # --- Autonomous Pipeline ---
  cat >> "$out" << 'PIPELINE'
---

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
PIPELINE

  echo '```bash' >> "$out"
  local _has_verify_cmd=false
  if [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then echo "${lint_cmd}              # Must pass with 0 errors" >> "$out"; _has_verify_cmd=true; fi
  if [[ "$typecheck" != "NOT_CONFIGURED" ]]; then echo "${typecheck}         # Must pass" >> "$out"; _has_verify_cmd=true; fi
  if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then echo "${test_cmd}              # Must pass" >> "$out"; _has_verify_cmd=true; fi
  if [[ "$build_cmd" != "NOT_CONFIGURED" ]]; then echo "${build_cmd}             # Must compile/build" >> "$out"; _has_verify_cmd=true; fi
  if [[ "$_has_verify_cmd" == false ]]; then
    echo "# No quality gate commands configured yet." >> "$out"
    echo "# Add lint, typecheck, test, and build commands to enable verification." >> "$out"
  fi
  echo '```' >> "$out"

  # Vault lint hint (vault is always generated)
  echo "" >> "$out"
  echo "> Run \`vault/.vault/scripts/vault-tools.sh lint\` to verify vault integrity." >> "$out"

  cat >> "$out" << 'PIPELINE2'

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
PIPELINE2

  # Generate Doc-Sync Matrix from manifest (Edit 11)
  echo "Run doc-sync check against this matrix:" >> "$out"
  echo "" >> "$out"
  echo "| Change Type | Files to Update |" >> "$out"
  echo "|-------------|----------------|" >> "$out"
  echo "| New endpoint/route | CLAUDE.md (Key Locations), API docs |" >> "$out"
  echo "| New env variable | CLAUDE.md (Env Variables), .env.example |" >> "$out"
  echo "| New invariant | CLAUDE.md (Invariants) |" >> "$out"
  echo "| Schema change | CLAUDE.md (Key Locations), migration docs |" >> "$out"
  echo "| New dependency | CLAUDE.md (Project Identity), package manifest |" >> "$out"
  echo "| New service/module | CLAUDE.md (Key Locations, Project Structure) |" >> "$out"

  # Add doc_dirs from manifest
  local doc_sync_dirs
  doc_sync_dirs=$(echo "$m" | jq -r '.structure.doc_dirs[]' 2>/dev/null)
  if [[ -n "$doc_sync_dirs" ]]; then
    while IFS= read -r dsdir; do
      echo "| Architectural change | \`${dsdir}/\` architecture docs |" >> "$out"
    done <<< "$doc_sync_dirs"
  fi

  echo "" >> "$out"

  # Stage 8 with APP_URL (Edit 12)
  echo "### Stage 8: QA (before every deploy)" >> "$out"
  echo '```' >> "$out"
  if [[ -n "$dev_port" ]]; then
    echo "/qa http://localhost:${dev_port}" >> "$out"
  else
    echo "/qa" >> "$out"
  fi
  echo '```' >> "$out"

  cat >> "$out" << 'PIPELINE2'

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

## End-of-Session Checklist

Before ending ANY session where code was changed, Claude MUST complete:

- [ ] **Verify**: Did I run lint + test + build? All pass?
- [ ] **Review**: Did I run `/review` on the changes?
- [ ] **Security**: If I touched auth/API/permissions → did I run `/cso`?
- [ ] **Docs**: Did any structural change happen? → Update docs
- [ ] **Learn**: Did I discover something non-obvious? → `/learn`
- [ ] **CHANGELOG**: Did I update CHANGELOG.md + VERSION?
- [ ] **Commit**: Are all changes committed with a descriptive message?
- [ ] **STATUS.md**: Did I update STATUS.md with current progress for multi-phase tasks?
- [ ] **Push**: Ready to push? Confirm with user before pushing.
- [ ] **Vault**: Did I update vault/memory/status.md with session progress?
- [ ] **Decisions**: Any significant decisions? → Log in vault/memory/decisions/

---

## Quick Reference Matrix

| Trigger | Skills to run (in order) |
|---------|------------------------|
| Bug reported | `/investigate` → fix → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| New feature | `/plan-eng-review` → build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| Small fix | build → verify → `/review` → docs → `/ship` |
| Refactor | build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` |

PIPELINE2

}

_emit_invariants_and_config() {
  local m="$_cm_m" out="$_cm_out"
  local domain_count="$_cm_domain_count" deploy="$_cm_deploy"
  local dev_cmd="$_cm_dev_cmd" test_cmd="$_cm_test_cmd"

  # --- Invariants ---
  echo "---" >> "$out"
  echo "" >> "$out"
  echo "## Invariants" >> "$out"
  echo "" >> "$out"

  if [[ "$domain_count" -gt 0 ]]; then
    local inv_num=1
    # Generate invariants from detected domains
    echo "$m" | jq -r '.domain.detected_domains[] | .name' 2>/dev/null | while IFS= read -r domain; do
      case "$domain" in
        auth)
          echo "### INV-${inv_num}: Authentication guards on all protected endpoints"
          echo "Every endpoint handling user data must have auth middleware/guards applied."
          echo ""
          ;;
        database)
          local orm_val
          orm_val=$(echo "$m" | jq -r '.domain.detected_domains[] | select(.name == "database") | .orm // "unknown"')
          echo "### INV-${inv_num}: Database access through ORM only (${orm_val})"
          echo "No raw SQL queries — all database access through the ORM layer."
          echo ""
          ;;
        api)
          echo "### INV-${inv_num}: Input validation on all API endpoints"
          echo "Every endpoint accepting user input must validate and sanitize before processing."
          echo ""
          ;;
        ai)
          echo "### INV-${inv_num}: LLM trust boundary enforcement"
          echo "Never trust LLM output as safe — validate, sanitize, and scope all AI-generated content."
          echo ""
          ;;
        sandbox)
          echo "### INV-${inv_num}: Sandbox isolation for code execution"
          echo "All user code execution must run in an isolated sandbox with resource limits."
          echo ""
          ;;
      esac
      inv_num=$((inv_num + 1))
    done >> "$out"
  else
    echo "*No invariants discovered yet. As the project matures, invariants will be added here when patterns emerge. Use \`/learn\` to capture rules as they are discovered.*" >> "$out"
  fi

  # Ensure at least 2 invariants (B20)
  local inv_count
  inv_count=$(grep -c '### INV-' "$out" 2>/dev/null || echo "0")
  if [[ "$inv_count" -lt 2 ]]; then
    local next_inv=$((inv_count + 1))
    echo "" >> "$out"
    echo "### INV-${next_inv}: No secrets in source code" >> "$out"
    echo "Never commit API keys, passwords, tokens, or credentials. All secrets must be stored in environment variables or a secrets manager." >> "$out"
    echo "" >> "$out"
  fi

  # --- Enhanced Invariants (from _enhance) ---
  local enhance_invariants
  enhance_invariants=$(echo "$m" | jq -r '._enhance.enhancements[]? | select(.source == "framework-agent") | select(.title != null) | .title + ": " + .description' 2>/dev/null || true)
  if [[ -n "$enhance_invariants" ]]; then
    inv_count=$(grep -c '### INV-' "$out" 2>/dev/null || echo "0")
    echo "" >> "$out"
    echo "> *The following invariants were discovered by AI-powered enhancement:*" >> "$out"
    echo "" >> "$out"
    while IFS= read -r inv_line; do
      inv_count=$((inv_count + 1))
      local inv_title="${inv_line%%:*}"
      local inv_desc="${inv_line#*: }"
      echo "### INV-${inv_count}: ${inv_title}" >> "$out"
      echo "${inv_desc}" >> "$out"
      echo "" >> "$out"
    done <<< "$enhance_invariants"
  fi

  echo "" >> "$out"

  # --- Archetype-specific section ---
  local arch_type
  arch_type=$(echo "$m" | jq -r '.archetype.type // "unknown"')
  local arch_maturity
  arch_maturity=$(echo "$m" | jq -r '.archetype.maturity // "unknown"')
  if [[ "$arch_type" != "unknown" && "$arch_type" != "null" ]]; then
    echo "---" >> "$out"
    echo "" >> "$out"
    echo "## Project Profile" >> "$out"
    echo "" >> "$out"
    echo "- **Archetype**: ${arch_type}" >> "$out"
    echo "- **Maturity**: ${arch_maturity}" >> "$out"
    echo "- **Complexity**: $(echo "$m" | jq -r '.archetype.complexity // "unknown"')" >> "$out"
    echo "" >> "$out"

    # Add archetype-specific invariants from archetypes.json
    local arch_data="$ROOT_DIR/lib/data/archetypes.json"
    if [[ -f "$arch_data" ]]; then
      local extra_inv
      extra_inv=$(jq -r --arg a "$arch_type" '.archetypes[$a].extra_invariants[]? // empty' "$arch_data" 2>/dev/null)
      if [[ -n "$extra_inv" ]]; then
        echo "### Archetype Invariants" >> "$out"
        echo "" >> "$out"
        while IFS= read -r inv; do
          [[ -z "$inv" ]] && continue
          echo "- ${inv}" >> "$out"
        done <<< "$extra_inv"
        echo "" >> "$out"
      fi
    fi
  fi

  # --- Environment Variables ---
  echo "---" >> "$out"
  echo "" >> "$out"
  echo "## Environment Variables" >> "$out"
  echo "" >> "$out"

  local env_count
  env_count=$(echo "$m" | jq '.env.variables | length' 2>/dev/null || echo "0")

  if [[ "$env_count" -gt 0 ]]; then
    local has_public
    has_public=$(echo "$m" | jq -r '.env.has_public_env')

    if [[ "$has_public" == "true" ]]; then
      echo "| Variable | Scope | Required | Description |" >> "$out"
      echo "|----------|-------|----------|-------------|" >> "$out"
      echo "$m" | jq -r '.env.variables[] | "| \(.name) | \(if (.name | startswith("NEXT_PUBLIC_")) then "Client" else "Server" end) | \(if .required then "Yes" else "No" end) | \(.description // "-") |"' 2>/dev/null >> "$out"
    else
      echo "| Variable | Required | Description |" >> "$out"
      echo "|----------|----------|-------------|" >> "$out"
      echo "$m" | jq -r '.env.variables[] | "| \(.name) | \(if .required then "Yes" else "No" end) | \(.description // "-") |"' 2>/dev/null >> "$out"
    fi
  else
    echo "*No environment variables discovered. Add variables here when .env.example is created.*" >> "$out"
  fi

  echo "" >> "$out"

  # --- Deploy ---
  echo "---" >> "$out"
  echo "" >> "$out"

  if [[ "$deploy" != "none" ]]; then
    echo "## Deploy" >> "$out"
    echo "" >> "$out"
    echo "**Target:** ${deploy}" >> "$out"

    local compose
    compose=$(echo "$m" | jq -r '.ci.compose_file // empty')
    if [[ -n "$compose" ]]; then
      echo "" >> "$out"
      echo "### Local Development Infrastructure" >> "$out"
      echo "" >> "$out"
      echo "\`${compose}\` provides:" >> "$out"
      echo "$m" | jq -r '.identity.compose_services[]' 2>/dev/null | while IFS= read -r svc; do
        echo "- ${svc}"
      done >> "$out"
      echo "" >> "$out"
      echo '```bash' >> "$out"
      echo "docker compose up -d    # Start infra" >> "$out"
      echo "${dev_cmd}             # Start app" >> "$out"
      echo '```' >> "$out"
    fi
  else
    echo "## Deploy" >> "$out"
    echo "" >> "$out"
    echo "*No deployment pipeline discovered. Add deploy configuration when ready.*" >> "$out"
  fi

  echo "" >> "$out"

  # --- GitHub Secrets ---
  echo "---" >> "$out"
  echo "" >> "$out"

  local secrets_count
  secrets_count=$(echo "$m" | jq '.ci.github_secrets | length' 2>/dev/null || echo "0")

  if [[ "$secrets_count" -gt 0 ]]; then
    echo "## GitHub Secrets" >> "$out"
    echo "" >> "$out"
    echo "| Secret | Purpose | Used By |" >> "$out"
    echo "|--------|---------|---------|" >> "$out"
    # Match each secret to the workflow file that uses it
    echo "$m" | jq -r '.ci.github_secrets[]' 2>/dev/null | while IFS= read -r secret; do
      local used_by
      used_by=$(echo "$m" | jq -r --arg s "$secret" '.ci.workflows[]? | select(.secrets != null and (.secrets | contains($s))) | .file' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
      [[ -z "$used_by" ]] && used_by="-"
      echo "| ${secret} | - | \`${used_by}\` |"
    done >> "$out"
  else
    echo "## GitHub Secrets" >> "$out"
    echo "" >> "$out"
    echo "*No CI secrets discovered. Add secrets here when CI workflows are configured.*" >> "$out"
  fi

  echo "" >> "$out"

  # --- Testing ---
  echo "---" >> "$out"
  echo "" >> "$out"

  local test_tool
  test_tool=$(echo "$m" | jq -r '.quality.test_framework.tool // empty')

  if [[ -n "$test_tool" ]]; then
    local test_cfg
    test_cfg=$(echo "$m" | jq -r '.quality.test_framework.config // "built-in"')
    local test_count
    test_count=$(echo "$m" | jq -r '.structure.test_file_count // 0')
    local test_pattern
    test_pattern=$(echo "$m" | jq -r '.structure.test_pattern // "NOT_FOUND"')

    echo "## Testing" >> "$out"
    echo "" >> "$out"
    echo "- **Framework:** ${test_tool}" >> "$out"
    echo "- **Config:** ${test_cfg}" >> "$out"
    echo "- **Run:** \`${test_cmd}\`" >> "$out"
    echo "- **Pattern:** ${test_pattern}" >> "$out"
    echo "- **Test files:** ${test_count}" >> "$out"

    if [[ "$test_count" == "0" ]]; then
      echo "" >> "$out"
      echo "> **Note:** Test framework is configured but **no test files exist yet**. Writing tests is a recommended first step." >> "$out"
    fi
  else
    echo "## Testing" >> "$out"
    echo "" >> "$out"
    echo "*No test framework configured. Add testing setup as a priority.*" >> "$out"
  fi

  echo "" >> "$out"
}

_emit_skills_vault_and_footer() {
  local m="$_cm_m" out="$_cm_out"
  local short="$_cm_short" today="$_cm_today"
  local domain_count="$_cm_domain_count" dev_port="$_cm_dev_port"
  local emit_full=true

  # --- Custom Skills ---
  cat >> "$out" << SKILLS
---

## Custom Skills

### \`/${short}-review\`
Project-specific code review checking all invariants.

### \`/${short}-ship\`
Full shipping workflow: verify → review → docs → changelog → commit.

### \`/${short}-learn\`
Capture project learnings to persistent storage (JSONL + vault).

---

## Review Specialists

SKILLS

  # Generate review specialists with inline checklists (Edit 15)
  echo "$m" | jq -r '.domain.detected_domains[] | .name' 2>/dev/null | while IFS= read -r spec_domain; do
    local spec_display
    spec_display=$(echo "$m" | jq -r --arg n "$spec_domain" '.domain.detected_domains[] | select(.name == $n) | .display' 2>/dev/null)
    local spec_paths
    spec_paths=$(echo "$m" | jq -r --arg n "$spec_domain" '.domain.detected_domains[] | select(.name == $n) | .paths[:3] | join(", ") // "N/A"' 2>/dev/null)
    echo "### ${spec_display}" >> "$out"
    echo "Trigger paths: ${spec_paths}" >> "$out"
    echo "" >> "$out"

    case "$spec_domain" in
      auth)
        echo "- [ ] All protected endpoints have auth middleware" >> "$out"
        echo "- [ ] Session tokens are validated on every request" >> "$out"
        echo "- [ ] Password hashing uses bcrypt/argon2 (never MD5/SHA1)" >> "$out"
        echo "- [ ] JWT secrets are not hardcoded" >> "$out"
        echo "- [ ] Rate limiting on login/register endpoints" >> "$out"
        echo "- [ ] CSRF protection enabled for state-changing operations" >> "$out"
        echo "- [ ] Logout invalidates session/token server-side" >> "$out"
        ;;
      database)
        echo "- [ ] All queries go through ORM — no raw SQL" >> "$out"
        echo "- [ ] Migrations are reversible (up + down)" >> "$out"
        echo "- [ ] Indexes exist for frequently queried columns" >> "$out"
        echo "- [ ] N+1 query patterns avoided" >> "$out"
        echo "- [ ] Sensitive data is encrypted at rest" >> "$out"
        echo "- [ ] Connection pooling configured" >> "$out"
        echo "- [ ] Schema changes have migration files" >> "$out"
        ;;
      api)
        echo "- [ ] All inputs validated before processing" >> "$out"
        echo "- [ ] Error responses use consistent format" >> "$out"
        echo "- [ ] Rate limiting configured for public endpoints" >> "$out"
        echo "- [ ] CORS policy is restrictive (not wildcard)" >> "$out"
        echo "- [ ] Response types are explicitly defined" >> "$out"
        echo "- [ ] No sensitive data in URL parameters" >> "$out"
        echo "- [ ] Pagination on list endpoints" >> "$out"
        echo "- [ ] API versioning strategy documented" >> "$out"
        ;;
      ai)
        echo "- [ ] LLM outputs are sanitized before use" >> "$out"
        echo "- [ ] Prompt injection defenses in place" >> "$out"
        echo "- [ ] Token limits enforced per request" >> "$out"
        echo "- [ ] API keys stored in env vars, not code" >> "$out"
        echo "- [ ] Fallback behavior when LLM is unavailable" >> "$out"
        echo "- [ ] Cost monitoring/alerting configured" >> "$out"
        echo "- [ ] Output validation before displaying to users" >> "$out"
        ;;
      sandbox)
        echo "- [ ] Code execution isolated in sandbox" >> "$out"
        echo "- [ ] Resource limits (CPU, memory, time) enforced" >> "$out"
        echo "- [ ] Network access restricted in sandbox" >> "$out"
        echo "- [ ] Filesystem access scoped to workspace" >> "$out"
        echo "- [ ] Process cleanup after execution" >> "$out"
        ;;
      frontend)
        echo "- [ ] XSS prevention — no dangerouslySetInnerHTML without sanitization" >> "$out"
        echo "- [ ] Forms have proper validation" >> "$out"
        echo "- [ ] Loading and error states handled" >> "$out"
        echo "- [ ] Accessibility: semantic HTML, ARIA labels" >> "$out"
        echo "- [ ] Responsive design tested" >> "$out"
        echo "- [ ] Images optimized and lazy-loaded" >> "$out"
        ;;
      external-apis)
        echo "- [ ] API keys in env vars, not code" >> "$out"
        echo "- [ ] Retry logic with exponential backoff" >> "$out"
        echo "- [ ] Timeout configuration on all HTTP calls" >> "$out"
        echo "- [ ] Error handling for rate limits (429)" >> "$out"
        echo "- [ ] Response validation before use" >> "$out"
        ;;
      workers)
        echo "- [ ] Idempotent job processing" >> "$out"
        echo "- [ ] Dead letter queue for failed jobs" >> "$out"
        echo "- [ ] Job timeout configured" >> "$out"
        echo "- [ ] Concurrency limits set" >> "$out"
        echo "- [ ] Monitoring/alerting on job failures" >> "$out"
        ;;
      *)
        echo "- [ ] Code follows project conventions" >> "$out"
        echo "- [ ] Tests cover critical paths" >> "$out"
        echo "- [ ] No hardcoded secrets" >> "$out"
        ;;
    esac
    echo "" >> "$out"
  done

  if [[ "$domain_count" == "0" ]]; then
    echo "*Review specialists will be created when domain-specific code is detected.*" >> "$out"
  fi

  echo "" >> "$out"

  # --- Doc-Sync Matrix section (Edit 16) ---
  if [[ "$domain_count" -gt 0 ]]; then
    echo "---" >> "$out"
    echo "" >> "$out"
    echo "## Doc-Sync Matrix" >> "$out"
    echo "" >> "$out"
    echo "| Domain | Key Files | Doc Impact |" >> "$out"
    echo "|--------|-----------|------------|" >> "$out"
    echo "$m" | jq -r '.domain.detected_domains[] | "| \(.display) | \(.paths[:2] | join(", ") // "-") | CLAUDE.md, docs/ |"' 2>/dev/null >> "$out" || true
    echo "" >> "$out"
    echo "When any file in a domain's key files changes, update the corresponding docs." >> "$out"
    echo "" >> "$out"
  fi

  # --- Enhancement Summary (from _enhance) ---
  local enhance_count
  enhance_count=$(echo "$m" | jq '._enhance.enhancements | length' 2>/dev/null || echo "0")
  if [[ "$enhance_count" -gt 0 ]]; then
    echo "---" >> "$out"
    echo "" >> "$out"
    echo "## Enhancement Summary" >> "$out"
    echo "" >> "$out"
    echo "> This manifest was enriched by AI-powered analysis (\`aiframework enhance\`)." >> "$out"
    echo "" >> "$out"
    local enh_date
    enh_date=$(echo "$m" | jq -r '._enhance.enhanced_at // "unknown"' 2>/dev/null)
    local enh_gaps
    enh_gaps=$(echo "$m" | jq -r '._enhance.gaps_analyzed // 0' 2>/dev/null)
    local enh_cost
    enh_cost=$(echo "$m" | jq -r '._enhance.budget_spent_cents // 0' 2>/dev/null)
    echo "| Metric | Value |" >> "$out"
    echo "|--------|-------|" >> "$out"
    echo "| Enhanced | ${enh_date} |" >> "$out"
    echo "| Gaps analyzed | ${enh_gaps} |" >> "$out"
    echo "| Findings | ${enhance_count} |" >> "$out"
    echo "| Cost | ${enh_cost}c |" >> "$out"
    echo "" >> "$out"

    # List enhancement sources
    local enh_sources
    enh_sources=$(echo "$m" | jq -r '._enhance.enhancements[].source' 2>/dev/null | sort -u)
    if [[ -n "$enh_sources" ]]; then
      echo "**Sources:** ${enh_sources//$'\n'/, }" >> "$out"
      echo "" >> "$out"
    fi
  fi

  # --- Persistent Memory Vault (always included — vault is generated at step 7/7) ---
  cat >> "$out" << 'VAULT_SECTION'
---

## Persistent Memory Vault

Your knowledge persists across sessions in `vault/`. Three-layer architecture:

| Layer | Path | Purpose | Lifetime |
|-------|------|---------|----------|
| **Raw** | `vault/raw/` | Immutable source documents (human-owned) | Permanent |
| **Wiki** | `vault/wiki/` | Processed knowledge (concepts, entities, comparisons) | Long-lived |
| **Memory** | `vault/memory/` | Operational state (decisions, notes, status) | Variable |

**Data flow:** `raw/` → `wiki/` → `memory/` (strictly unidirectional)

### Quick Commands

```bash
vault/.vault/scripts/vault-tools.sh status       # Vault health
vault/.vault/scripts/vault-tools.sh doctor        # Full diagnostic
vault/.vault/scripts/vault-tools.sh lint          # Quality scan
vault/.vault/scripts/vault-tools.sh stale         # Find outdated content
vault/.vault/scripts/vault-tools.sh orphans       # Find unlinked pages
vault/.vault/scripts/vault-tools.sh stats         # Usage metrics
```

### How to Use

- **Session START**: Read `vault/memory/status.md` for ongoing work context
- **During work**: Save insights to `vault/memory/notes/` (auto-archive after 7 days)
- **Significant decisions**: Log to `vault/memory/decisions/` using ADR format
- **Session END**: Update `vault/memory/status.md` with progress
- **New knowledge**: Create wiki pages in `vault/wiki/concepts/` or `vault/wiki/entities/`

### Architecture

See `vault/docs/architecture.md` for the full three-layer model.
See `vault/.vault/rules/hard-rules.md` for 15 integrity rules enforced by pre-commit hooks.

VAULT_SECTION

  # --- Session Learnings ---
  cat >> "$out" << LEARNINGS
---

## Session Learnings

Stored in \`tools/learnings/${short}-learnings.jsonl\`. Use \`/learn\` to add new entries.

*Learnings accumulate over time. After fixing a non-obvious bug or discovering a gotcha, run \`/${short}-learn\` to capture it.*

### Learnings Format (JSONL)

Each line in the learnings file is a JSON object:
\`\`\`json
{"date": "2026-04-15", "category": "bug|gotcha|pattern|decision", "summary": "One-line summary", "detail": "Full explanation", "files": ["path/to/relevant/file"]}
\`\`\`

To query: \`grep "keyword" tools/learnings/${short}-learnings.jsonl\`
To add: \`/${short}-learn "description"\` or append a JSON line manually.

LEARNINGS

  # --- gstack Browser Integration — only if gstack is installed and emit_full ---
  if [[ "$emit_full" == true ]] && [[ -d "$HOME/.claude/skills/gstack" ]]; then
    cat >> "$out" << 'GSTACK'
---

## gstack Browser Integration

If gstack is installed (`~/.claude/skills/gstack/`), use `$B` commands for browser interactions:
- `$B` is ~20x faster than Playwright MCP (~100ms vs ~2-5s)
- Uses ref-based element selection (`@e1`, `@e2`) instead of CSS selectors
- Persistent Chromium daemon — cookies/tabs/login persist between commands

### Command Reference

| Command | Usage | Description |
|---------|-------|-------------|
| `goto` | `$B goto <url>` | Navigate to a URL |
| `snapshot` | `$B snapshot` | Get page structure with element refs |
| `click` | `$B click @e1` | Click an element by ref |
| `fill` | `$B fill @e1 "text"` | Fill an input field |
| `screenshot` | `$B screenshot` | Capture a screenshot |
| `console` | `$B console` | Read browser console logs |
| `network` | `$B network` | Read network requests/responses |
| `text` | `$B text @e1` | Get text content of an element |
| `html` | `$B html @e1` | Get HTML content of an element |
| `responsive` | `$B responsive <width>` | Set viewport width for responsive testing |
| `diff` | `$B diff` | Compare current page with previous snapshot |
| `chain` | `$B chain "click @e1" "fill @e2 text" "screenshot"` | Chain multiple commands |

GSTACK
  fi

  # --- Session Start Protocol — only for moderate/complex/enterprise projects ---
  if [[ "$emit_full" == true ]]; then
    cat >> "$out" << SESSIONPROTO
---

## Session Start Protocol

At the start of each session:
1. Read \`vault/memory/status.md\` — check for ongoing work and operational context
2. Read \`vault/wiki/index.md\` — scan domain concepts and knowledge pages
3. Read \`tools/learnings/${short}-learnings.jsonl\` — surface relevant learnings
4. Check \`git log --oneline -10\` — understand recent work
5. Check \`git status\` — understand current state
6. If a STATUS.md file exists — read it for multi-phase task progress
7. Run \`aiframework-update-check\` — notify developer of updates or drift:
   - \`UPGRADE_AVAILABLE <old> <new>\`: Tell the developer a new aiframework version is available and offer to upgrade (\`cd <aiframework-path> && git pull\`)
   - \`DRIFT_DETECTED <files>\`: Tell the developer generated files are stale and offer to run \`aiframework refresh\`
   - \`UP_TO_DATE\` or empty: No action needed
8. Decision Priority: User > Invariants > Workflow Rules > Core Principles > Docs

SESSIONPROTO
  fi

  # --- Footer ---
  cat >> "$out" << FOOTER
---

*Generated: ${today} by aiframework v$(cat "$ROOT_DIR/VERSION"). Run \`aiframework refresh\` to update.*

<!-- CLAUDE.md Guidance:
- Update this file after significant decisions, bug fixes, or architectural changes
- NEVER delete content — only add, refine, or mark as deprecated
- Use /learn to capture non-obvious discoveries
- Session summary format: "Session YYYY-MM-DD: <what was done>, <key decisions>, <blockers>"
-->

<!-- Previous Session Summary:
Session ${today}: Initial CLAUDE.md generation via aiframework.
Key decisions: Automated project analysis and documentation generation.
Blockers: None.
-->
FOOTER

  # --- Execution Matrices (Edit 19) — only for moderate/complex/enterprise projects ---
  if [[ "$emit_full" == true ]]; then
    cat >> "$out" << 'MATRICES'

---

## Execution Matrices

### Bug Fix Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | `/investigate` — reproduce & understand | Can reproduce? |
| 2 | Plan fix approach | Root cause identified? |
| 3 | Implement fix | Code change minimal & correct? |
| 4 | Verify: lint + typecheck + test + build | All pass? |
| 5 | `/review` | No issues? |
| 6 | `/cso` (if security-related) | No vulnerabilities? |
| 7 | Update docs + CHANGELOG | Docs accurate? |
| 8 | `/qa` | App works? |
| 9 | `/ship` | PR/deploy clean? |
| 10 | `/learn` | Lesson captured? |

### Feature Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | `/plan-eng-review` | Plan approved? |
| 2 | Build — implement feature | Code complete? |
| 3 | Write tests | Coverage adequate? |
| 4 | Verify: lint + typecheck + test + build | All pass? |
| 5 | `/review` | No issues? |
| 6 | `/cso` | No security gaps? |
| 7 | Update docs + CHANGELOG + VERSION | Docs accurate? |
| 8 | `/qa` | Feature works end-to-end? |
| 9 | `/ship` | PR/deploy clean? |
| 10 | `/canary` | No regressions? |
| 11 | `/learn` | Lessons captured? |

### Deploy Flow

| Step | Action | Gate |
|------|--------|------|
| 1 | Verify: lint + typecheck + test + build | All pass? |
| 2 | `/review` | No issues? |
| 3 | `/cso` | Secure? |
| 4 | `/qa` | QA pass? |
| 5 | Update CHANGELOG + VERSION | Done? |
| 6 | `/ship` | Deploy triggered? |
| 7 | `/canary` — monitor post-deploy | Healthy? |

### Weekly Cadence

| Day | Task |
|-----|------|
| Monday | Review open PRs, triage issues |
| Wednesday | `/retro` — mid-week check |
| Friday | `/retro` — weekly retrospective, update CLAUDE.md, run `vault-tools.sh doctor` |

### Failure Recovery Table

| Failure | Recovery Action |
|---------|----------------|
| Test fails after code change | Revert change, re-investigate, fix root cause |
| Build fails | Check compiler errors, fix type/syntax issues |
| Lint fails | Auto-fix with formatter, then manual review |
| Deploy fails | Rollback, check logs, fix and re-deploy |
| `/cso` finds vulnerability | Block deploy, fix immediately, re-run `/cso` |
| QA regression | Investigate with `/investigate`, add regression test |

MATRICES
  fi
}

# --- Full CLAUDE.md generator (verbose, for complex/enterprise projects) ---
# Orchestrator: calls each _emit_* sub-function in sequence.
generate_claude_md_full() {
  _extract_claude_md_vars

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would write CLAUDE.md to $_cm_out"
    return 0
  fi

  # Preserve existing CLAUDE.md content for merge
  preserve_claude_md

  # Generate workflow rules for full mode
  _generate_workflow_rules

  # Emit each section in order
  _emit_header_and_doc_table
  _emit_decision_priority_and_workflow
  _emit_qa_autofix
  _emit_project_identity
  _emit_project_structure
  _emit_key_commands
  _emit_ci_and_key_locations
  _emit_pipeline_and_routing
  _emit_invariants_and_config
  _emit_skills_vault_and_footer

  # Merge back any user-added content from the original CLAUDE.md
  merge_claude_md_user_content

  log_ok "CLAUDE.md (full) written to $_cm_out"
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
        extra_inv=$(jq -r --arg a "$arch_type" '.archetypes[$a].extra_invariants[]? // empty' "$arch_data" 2>/dev/null)
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
        .modules | to_entries[] |
        .key as $mod |
        .value as $data |
        ($data.files | length) as $fcount |
        ([$root.symbols[] | select(.file | startswith($mod + "/")) | .name] | .[0:3] | join(", ")) as $syms |
        ([$root.edges[] | select(.source | startswith($mod + "/")) | .target | split("/")[0:2] | join("/")] | unique | join(", ")) as $deps |
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
    top_files=$(jq -r '._meta.top_files // [] | .[:15][] | "- `\(.[0])` (score: \(.[1]))"' "$code_index_path" 2>/dev/null)
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
