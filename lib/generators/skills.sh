#!/usr/bin/env bash
# Generator: Custom Skills
# Creates project-specific review and ship skills

# Sanitize manifest values for safe use in heredocs and echo statements.
# Allowlist: keep only safe characters for use in heredocs and echo statements.
# Strips shell metacharacters that could enable injection
# from malicious package.json names or descriptions.
_sanitize_manifest_val() {
  local val="$1"
  # Allowlist: keep only safe characters for shell heredocs
  # Note: / excluded to prevent path traversal in directory names
  val=$(printf '%s' "$val" | tr -dc 'a-zA-Z0-9 _.:=@,+^~-')
  printf '%s\n' "$val"
}

generate_skills() {
  local m="$MANIFEST"
  local short
  short=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.identity.short_name')")
  local name
  name=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.identity.name')")
  local lang
  lang=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.stack.language // "unknown"')")
  local fw
  fw=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.stack.framework // "none"')")
  local install
  install=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.commands.install // "NOT_CONFIGURED"')")
  local lint
  lint=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')")
  local typecheck
  typecheck=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.commands.typecheck // "NOT_CONFIGURED"')")
  local test_cmd
  test_cmd=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.commands.test // "NOT_CONFIGURED"')")
  local build
  build=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')")

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create .claude/skills/${short}-review/ and ${short}-ship/"
    return 0
  fi

  # --- Review Skill ---
  mkdir -p "$TARGET_DIR/.claude/skills/${short}-review"
  cat > "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md" << SKILLMD
---
name: ${short}-review
description: |
  ${name} pre-landing code review with project-specific checks.
  Checks all invariants, runs specialist reviews based on changed files.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# /${short}-review — Code Review

## Step 1: CRITICAL Pass

For each changed file (\`git diff --name-only HEAD~1 HEAD\`), check:

SKILLMD

  # Add invariant checks from detected domains
  local inv_num=1
  local _skill_domains
  _skill_domains=$(echo "$m" | jq -r '.domain.detected_domains[] | .name' 2>/dev/null)
  while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    case "$domain" in
      auth)
        echo "### 1.${inv_num} INV-${inv_num}: Authentication Guards" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify all new/modified endpoints have auth middleware applied." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Look for: unprotected routes, missing guards, public endpoints that should be private." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        ;;
      database)
        echo "### 1.${inv_num} INV-${inv_num}: Database Safety" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify no raw SQL, all queries through ORM, migrations are reversible." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Look for: raw SQL strings, missing migrations, schema changes without migration." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        ;;
      api)
        echo "### 1.${inv_num} INV-${inv_num}: Input Validation" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify all API endpoints validate input before processing." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Look for: missing validation, untyped request bodies, direct user input in queries." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        ;;
      ai)
        echo "### 1.${inv_num} INV-${inv_num}: LLM Trust Boundary" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify LLM output is never trusted as safe." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Look for: unsanitized AI output in HTML, eval of AI-generated code, AI output in SQL." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        ;;
      sandbox)
        echo "### 1.${inv_num} INV-${inv_num}: Sandbox Isolation" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify code execution is sandboxed with resource limits." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Look for: unsandboxed exec, missing timeouts, file system access." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        ;;
      frontend)
        echo "### 1.${inv_num} INV-${inv_num}: Frontend Security & Quality" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify no XSS vulnerabilities (dangerouslySetInnerHTML, v-html, innerHTML assignments)." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Check accessibility: proper labels, alt text, ARIA attributes, keyboard navigation." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify loading states exist for all async operations." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        ;;
      external-apis)
        echo "### 1.${inv_num} INV-${inv_num}: External API Safety" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify no API keys or secrets are hardcoded or exposed to client bundles." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Check that all external API calls have proper error handling and timeout configuration." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Look for: missing try/catch, no timeout set, leaked credentials." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        ;;
      workers)
        echo "### 1.${inv_num} INV-${inv_num}: Worker/Job Safety" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Verify job handlers are idempotent — safe to retry without side effects." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Check retry logic and backoff configuration." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "Look for: missing dead letter queue, no idempotency key, unbounded retries." >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        echo "" >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"
        ;;
    esac
    inv_num=$((inv_num + 1))
  done <<< "$_skill_domains"

  # Count how many INV- entries were written and ensure at least 2
  local review_inv_count
  review_inv_count=$(grep -c 'INV-' "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md" 2>/dev/null || echo "0")
  if [[ "$review_inv_count" -lt 2 ]]; then
    local next_inv=$((review_inv_count + 1))
    cat >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md" << GENERAL_INV
### 1.${next_inv} INV-${next_inv}: No Secrets in Source Code
Verify no API keys, passwords, tokens, or credentials are committed.
Look for: hardcoded secrets, .env files committed, credentials in config, tokens in URLs.

GENERAL_INV
  fi

  cat >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md" << 'SKILL2'

## Step 2: Specialist Army (if applicable)

Launch parallel specialists based on what files changed.
Check `tools/review-specialists/` for domain-specific review checklists.

## Step 3: Report

Output a table:
| Check | Status | Details |
|-------|--------|---------|
| ... | PASS/FAIL/WARN | ... |

## Step 4: Vault Check

If vault/ exists, check for related decisions:
- Read `vault/memory/decisions/` for ADRs related to changed files
- Run `vault/.vault/scripts/vault-tools.sh lint` to verify vault integrity
SKILL2

  log_ok "Created .claude/skills/${short}-review/SKILL.md"

  # --- Ship Skill ---
  mkdir -p "$TARGET_DIR/.claude/skills/${short}-ship"
  cat > "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md" << SHIPMD
---
name: ${short}-ship
description: |
  ${name} shipping workflow. Runs lint + test + build, reviews code,
  checks invariants, updates docs + changelog, commits.
  NEVER pushes without explicit approval.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# /${short}-ship — Shipping Workflow

## Step 1: Verify

\`\`\`bash
SHIPMD

  local has_any_cmd=false
  [[ "$lint" != "NOT_CONFIGURED" ]] && { echo "$lint" >> "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md"; has_any_cmd=true; }
  [[ "$typecheck" != "NOT_CONFIGURED" ]] && { echo "$typecheck" >> "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md"; has_any_cmd=true; }
  [[ "$test_cmd" != "NOT_CONFIGURED" ]] && { echo "$test_cmd" >> "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md"; has_any_cmd=true; }
  [[ "$build" != "NOT_CONFIGURED" ]] && { echo "$build" >> "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md"; has_any_cmd=true; }
  [[ "$has_any_cmd" == false ]] && echo "# No lint/typecheck/test/build commands configured yet" >> "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md"

  cat >> "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md" << 'SHIP2'
```

## Step 2: Invariant Scan
Check changed files against all invariants in CLAUDE.md.

## Step 3: Doc Sync
Update any documentation affected by the changes.

## Step 4: CHANGELOG + VERSION bump
- Update CHANGELOG.md with user-facing description
- Bump VERSION (PATCH=fix, MINOR=feature, MAJOR=breaking)

## Step 5: Commit (NEVER push without asking the user)

## Step 5.5: Vault Update

If vault/ exists:
- Update `vault/memory/status.md` with shipping details
- If significant architectural decision was made → create ADR in `vault/memory/decisions/`
- Run `vault/.vault/scripts/vault-tools.sh lint`

## Step 6: Report

Output a summary table:
| Step | Status | Details |
|------|--------|---------|
| Lint | PASS/FAIL | ... |
| Type check | PASS/FAIL | ... |
| Tests | PASS/FAIL | X passed, Y failed |
| Build | PASS/FAIL | ... |
| Invariants | PASS/FAIL | ... |
| Docs | SYNCED/NEEDS UPDATE | ... |
| Changelog | UPDATED | ... |
| Committed | YES/NO | commit hash |
SHIP2

  log_ok "Created .claude/skills/${short}-ship/SKILL.md"

  # --- Review Specialists ---
  mkdir -p "$TARGET_DIR/tools/review-specialists"

  echo "$m" | jq -r '.domain.detected_domains[] | .name' 2>/dev/null | while IFS= read -r domain; do
    case "$domain" in
      auth)
        cat > "$TARGET_DIR/tools/review-specialists/auth.md" << 'SPEC'
# Authentication & Authorization Specialist

Check all changes in auth-related paths for:
1. Every protected endpoint has auth middleware/guard
2. Session tokens are not stored insecurely
3. JWT validation checks expiry and signature
4. Password handling uses bcrypt/argon2 (never plain text)
5. RBAC/ABAC permissions are enforced consistently
6. OAuth flows validate state parameter
7. No auth bypass in error handling paths
SPEC
        ;;
      database)
        cat > "$TARGET_DIR/tools/review-specialists/database.md" << 'SPEC'
# Database & Data Layer Specialist

Check all changes in database-related paths for:
1. No raw SQL — all queries through ORM
2. Migrations are reversible (up + down)
3. Indexes exist for frequent query patterns
4. N+1 query patterns are avoided
5. Transactions used for multi-step operations
6. Sensitive data columns are encrypted at rest
7. Schema changes have corresponding migration files
SPEC
        ;;
      api)
        cat > "$TARGET_DIR/tools/review-specialists/api.md" << 'SPEC'
# API Endpoints Specialist

Check all changes in API-related paths for:
1. Input validation on every endpoint accepting user data
2. Consistent error response format
3. Rate limiting on public endpoints
4. Pagination on list endpoints
5. No sensitive data in error messages
6. Proper HTTP status codes
7. CORS configuration is not overly permissive
SPEC
        ;;
      ai)
        cat > "$TARGET_DIR/tools/review-specialists/ai-llm.md" << 'SPEC'
# AI/LLM Integration Specialist

Check all changes in AI-related paths for:
1. LLM output is never trusted as safe HTML/SQL/code
2. Prompt injection defenses in place
3. Token limits and cost controls configured
4. Fallback behavior when LLM is unavailable
5. User content is sanitized before inclusion in prompts
6. Model responses are validated against expected schema
7. API keys are not hardcoded
SPEC
        ;;
      sandbox)
        cat > "$TARGET_DIR/tools/review-specialists/sandbox.md" << 'SPEC'
# Code Execution / Sandbox Specialist

Check all changes in sandbox-related paths for:
1. All code execution runs in isolated sandbox
2. Resource limits (CPU, memory, time) are enforced
3. File system access is restricted
4. Network access is controlled
5. No escape from sandbox boundary
6. Cleanup after execution completes
SPEC
        ;;
      frontend)
        cat > "$TARGET_DIR/tools/review-specialists/frontend.md" << 'SPEC'
# Frontend UI Specialist

Check all changes in frontend paths for:
1. No XSS vulnerabilities (dangerouslySetInnerHTML, v-html)
2. Accessibility: labels, alt text, keyboard navigation
3. Responsive design works on mobile/tablet/desktop
4. Loading states for async operations
5. Error boundaries catch render failures
6. No hardcoded strings (i18n-ready if applicable)
7. Images are optimized and lazy-loaded
SPEC
        ;;
      external-apis)
        cat > "$TARGET_DIR/tools/review-specialists/external-apis.md" << 'SPEC'
# External APIs Specialist

Check all changes involving external API integrations for:
1. No API keys or secrets hardcoded in source files
2. All HTTP calls have timeout configuration
3. Proper error handling with retries and fallback behavior
4. Rate limiting awareness (respect upstream limits)
5. Response validation — do not trust external data blindly
6. Circuit breaker pattern for critical dependencies
7. Logging of external call latency and failures
SPEC
        ;;
      workers)
        cat > "$TARGET_DIR/tools/review-specialists/workers.md" << 'SPEC'
# Workers & Background Jobs Specialist

Check all changes in worker/job paths for:
1. Job handlers are idempotent — safe to retry
2. Retry logic uses exponential backoff
3. Dead letter queue configured for failed jobs
4. Jobs have timeout limits to prevent hanging
5. Concurrency controls prevent duplicate processing
6. Job payloads are serializable and versioned
7. Monitoring/alerting on queue depth and failure rate
SPEC
        ;;
    esac
  done

  # --- Conditional specialist files for special domains ---
  local all_domains
  all_domains=$(echo "$m" | jq -r '.domain.detected_domains[]? | .name' 2>/dev/null)

  if echo "$all_domains" | grep -q 'financial'; then
    cat > "$TARGET_DIR/tools/review-specialists/financial.md" << 'SPEC'
# Financial Domain Specialist

Check all changes involving financial logic for:
1. Currency calculations use decimal types (never floating point)
2. All monetary operations are wrapped in transactions
3. Audit trail exists for every balance-changing operation
4. Rounding rules are explicit and consistent
5. Tax calculation logic matches jurisdiction requirements
6. Refund/reversal flows are fully tested
7. PCI compliance: no card numbers in logs or error messages
SPEC
  fi

  if echo "$all_domains" | grep -qE '(web3|blockchain)'; then
    cat > "$TARGET_DIR/tools/review-specialists/web3.md" << 'SPEC'
# Web3 / Blockchain Specialist

Check all changes involving blockchain or smart contract interactions for:
1. Private keys are never hardcoded or logged
2. Transaction signing happens in secure context
3. Gas estimation with appropriate limits and fallbacks
4. Reentrancy guards on state-changing operations
5. Contract addresses are validated (checksum format)
6. Chain ID / network verification before transactions
7. Wallet connection handles disconnects gracefully
SPEC
  fi

  # Check for monorepo
  local is_monorepo
  is_monorepo=$(echo "$m" | jq -r '.structure.monorepo // false')
  if [[ "$is_monorepo" == "true" ]]; then
    cat > "$TARGET_DIR/tools/review-specialists/monorepo.md" << 'SPEC'
# Monorepo Specialist

Check all cross-package changes for:
1. Dependency versions are consistent across packages
2. Changes in shared packages update all consumers
3. Package boundaries are respected (no reaching into internals)
4. Build order respects dependency graph
5. Workspace scripts run from correct package root
6. Lock file is updated when dependencies change
7. CI runs only affected packages (not entire repo)
SPEC
  fi

  local specialist_count
  specialist_count=$(ls "$TARGET_DIR/tools/review-specialists/" 2>/dev/null | wc -l | tr -d '[:space:]')
  log_ok "Created ${specialist_count} review specialists"

  # --- Learn Skill ---
  mkdir -p "$TARGET_DIR/.claude/skills/${short}-learn"
  cat > "$TARGET_DIR/.claude/skills/${short}-learn/SKILL.md" << LEARNMD
---
name: ${short}-learn
description: |
  Capture a project learning to persistent storage.
  Saves to tools/learnings/ (JSONL) and optionally vault/memory/notes/.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
---

# /${short}-learn — Capture Learning

## Usage
\`/${short}-learn "description of what was learned"\`

## Step 1: Classify
Determine category: bug, gotcha, pattern, or decision

## Step 2: Save to learnings file
Append a JSON line to \`tools/learnings/${short}-learnings.jsonl\`:
\`\`\`json
{"date": "YYYY-MM-DD", "category": "category", "summary": "one-line", "detail": "full explanation", "files": ["relevant/files"]}
\`\`\`

## Step 3: Save to vault (if significant)
If the learning is significant (would affect future architecture decisions):
- Create a note in \`vault/memory/notes/\` with YAML frontmatter
- Or create a decision record in \`vault/memory/decisions/\` using ADR format from \`vault/templates/decision-record.md\`

## Step 4: Confirm
Output: "Learning captured: [summary]"
LEARNMD
  log_ok "Created .claude/skills/${short}-learn/SKILL.md"

  # --- Learnings file ---
  mkdir -p "$TARGET_DIR/tools/learnings"
  touch "$TARGET_DIR/tools/learnings/${short}-learnings.jsonl"
  log_ok "Created tools/learnings/${short}-learnings.jsonl"

  # --- AGENTS.md (cross-tool, open standard) ---
  # Follows the AGENTS.md spec: tool-agnostic, <60 lines, 6 core sections
  # Commands first, concrete over vague, no auto-generated fluff
  local agents_file="$TARGET_DIR/AGENTS.md"
  if [[ ! -f "$agents_file" ]]; then
    local _agents_desc
    _agents_desc=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.identity.description // ""')")
    if [[ "$_agents_desc" == "NOT_FOUND" || "$_agents_desc" == "No description" || -z "$_agents_desc" ]]; then
      _agents_desc="${name} — ${lang} project"
    fi

    {
      echo "# AGENTS.md"
      echo ""
      echo "${_agents_desc}"
      echo ""

      # 1. Commands (most important — put first)
      echo "## Commands"
      echo ""
      echo '```bash'
      [[ "$install" != "NOT_CONFIGURED" ]] && echo "${install}        # install"
      [[ "$lint" != "NOT_CONFIGURED" ]] && echo "${lint}        # lint"
      [[ "$typecheck" != "NOT_CONFIGURED" ]] && echo "${typecheck}        # type check"
      [[ "$test_cmd" != "NOT_CONFIGURED" ]] && echo "${test_cmd}        # test"
      [[ "$build" != "NOT_CONFIGURED" ]] && echo "${build}        # build"
      echo '```'
      echo ""

      # 2. Testing
      local _test_fw
      _test_fw=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.quality.test_framework.tool // empty')")
      if [[ -n "$_test_fw" || "$test_cmd" != "NOT_CONFIGURED" ]]; then
        echo "## Testing"
        echo ""
        [[ -n "$_test_fw" ]] && echo "Framework: ${_test_fw}."
        echo "Run \`${test_cmd}\` before committing. Write tests for new functionality."
        echo ""
      fi

      # 3. Code style
      echo "## Code Style"
      echo ""
      echo "- Follow ${lang} community conventions and idioms"
      [[ "$fw" != "none" && -n "$fw" ]] && echo "- Use ${fw} patterns and APIs"
      [[ "$lint" != "NOT_CONFIGURED" ]] && echo "- Lint: \`${lint}\`"
      local _fmt
      _fmt=$(_sanitize_manifest_val "$(echo "$m" | jq -r '.commands.format // "NOT_CONFIGURED"')")
      [[ "$_fmt" != "NOT_CONFIGURED" ]] && echo "- Format: \`${_fmt}\`"
      echo ""

      # 4. Git workflow
      echo "## Git Workflow"
      echo ""
      echo "- Branch: \`feat/\`, \`fix/\`, \`refactor/\`, \`docs/\`"
      echo "- Commits: conventional (\`feat: ...\`, \`fix: ...\`)"
      echo "- Run lint + test before pushing"
      echo ""

      # 5. Boundaries
      echo "## Boundaries"
      echo ""
      echo "### Always"
      echo "- Validate all user input"
      echo "- Use environment variables for secrets"
      echo "- Handle errors explicitly"
      echo ""
      echo "### Ask First"
      echo "- Database schema changes"
      echo "- New external dependencies"
      echo "- Changes to CI/CD pipeline"
      echo "- Deleting files or removing features"
      echo ""
      echo "### Never"
      echo "- Commit secrets, API keys, or credentials"
      echo "- Skip tests to save time"
      echo "- Use \`--force\` push without explicit request"
    } > "$agents_file"

    log_ok "Created AGENTS.md (open standard, cross-tool)"
  fi

  # Generate .claude/settings.json with safe defaults + PostToolUse hooks
  local settings_file="$TARGET_DIR/.claude/settings.json"
  if [[ ! -f "$settings_file" ]]; then
    local _settings_lang
    _settings_lang=$(echo "$m" | jq -r '.stack.language // "unknown"')
    local typecheck_cmd
    typecheck_cmd=$(echo "$m" | jq -r '.commands.typecheck // empty')

    # Build PostToolUse hook for type checking on file edits
    local hooks_block=""
    case "$_settings_lang" in
      typescript|javascript)
        if [[ -n "$typecheck_cmd" ]]; then
          hooks_block=',
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "npx tsc --noEmit 2>&1 | head -20 || true",
        "timeout": 30000
      }
    ]
  }'
        fi
        ;;
      rust)
        hooks_block=',
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "cargo check 2>&1 | tail -5 || true",
        "timeout": 30000
      }
    ]
  }'
        ;;
      go)
        hooks_block=',
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "go vet ./... 2>&1 | tail -5 || true",
        "timeout": 15000
      }
    ]
  }'
        ;;
      python)
        # #25 — Python PostToolUse hook when mypy/pyright detected
        local py_has_typecheck=false
        if [[ -n "$typecheck_cmd" ]] && echo "$typecheck_cmd" | grep -qE '(mypy|pyright)'; then
          py_has_typecheck=true
        fi
        # Also check key_dependencies
        local py_deps
        py_deps=$(echo "$m" | jq -r '.stack.key_dependencies[]?' 2>/dev/null)
        if echo "$py_deps" | grep -qE '(mypy|pyright)'; then
          py_has_typecheck=true
        fi
        if [[ "$py_has_typecheck" == true ]]; then
          hooks_block=',
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "python3 -m mypy --no-error-summary 2>&1 | tail -5 || true",
        "timeout": 15000
      }
    ]
  }'
        fi
        ;;
    esac

    # #26 — Dual frontend+backend hooks for monorepos
    local is_monorepo
    is_monorepo=$(echo "$m" | jq -r '.stack.is_monorepo // false')
    if [[ "$is_monorepo" == "true" ]]; then
      local mono_apps
      mono_apps=$(echo "$m" | jq -r '.stack.monorepo_apps[]?' 2>/dev/null)
      if [[ -n "$mono_apps" ]]; then
        local mono_hooks=""
        local mono_first=true
        while IFS= read -r app; do
          [[ -z "$app" ]] && continue
          # Sanitize app name — allowlist alphanumeric, dash, underscore, dot only
          app=$(printf '%s' "$app" | tr -dc 'a-zA-Z0-9_.-')
          [[ -z "$app" ]] && continue
          # Check if this app has a tsconfig
          if [[ -f "$TARGET_DIR/apps/${app}/tsconfig.json" || -f "$TARGET_DIR/packages/${app}/tsconfig.json" ]]; then
            [[ "$mono_first" == false ]] && mono_hooks+=","
            mono_hooks+="
      {
        \"matcher\": \"Edit|Write\",
        \"command\": \"cd apps/${app} && npx tsc --noEmit 2>&1 | head -10 || true\",
        \"timeout\": 30000
      }"
            mono_first=false
          fi
        done <<< "$mono_apps"
        if [[ -n "$mono_hooks" ]]; then
          hooks_block=",
  \"hooks\": {
    \"PostToolUse\": [${mono_hooks}
    ]
  }"
        fi
      fi
    fi

    # Add sheal skill permissions when detected
    local sheal_perms=""
    local _sheal_installed
    _sheal_installed=$(echo "$m" | jq -r '.sheal.installed // false' 2>/dev/null)
    if [[ "$_sheal_installed" == "true" ]]; then
      sheal_perms=',
      "Skill(sheal-check)",
      "Skill(sheal-retro)",
      "Skill(sheal-drift)",
      "Skill(sheal-ask)"'
    fi

    # Build SessionStart + Stop hooks for ALL repos (not just sheal)
    # This is the autonomous loop — no manual commands needed
    local _start_cmd _stop_cmd

    # SessionStart: update check + drift check + sheal health (if available)
    # The update check runs first so Claude Code sees upgrade notifications immediately
    local _update_cmd="if command -v aiframework-update-check >/dev/null 2>&1; then aiframework-update-check 2>/dev/null || true; fi"
    if [[ "$_sheal_installed" == "true" ]]; then
      _start_cmd="${_update_cmd}; sheal check --format json --skip tests --project . 2>/dev/null | head -20 || true"
    else
      _start_cmd="${_update_cmd}; if command -v aiframework >/dev/null 2>&1; then aiframework verify --target . 2>/dev/null | tail -5 || true; fi"
    fi

    # Stop: auto-retro + learning bridge + weekly evolve reminder
    if [[ "$_sheal_installed" == "true" ]]; then
      _stop_cmd="if command -v sheal >/dev/null 2>&1 && [ -d .sheal ]; then sheal retro --project . 2>/dev/null | tail -5 || true; fi"
    else
      _stop_cmd="echo '[aiframework] Session complete. Run /aif-learn if you discovered anything non-obvious.' 2>/dev/null || true"
    fi

    # Build the hooks block — always present for all repos
    local session_hooks_block=',
    "SessionStart": [
      {
        "command": "'"$_start_cmd"'",
        "timeout": 15000
      }
    ],
    "Stop": [
      {
        "command": "'"$_stop_cmd"'",
        "timeout": 30000
      }
    ]'

    # Merge with existing hooks_block (PostToolUse etc.)
    if [[ -n "$hooks_block" ]]; then
      hooks_block="${hooks_block%\}}"
      hooks_block+="${session_hooks_block}
  }"
    else
      hooks_block=',
  "hooks": {
    "SessionStart": [
      {
        "command": "'"$_start_cmd"'",
        "timeout": 15000
      }
    ],
    "Stop": [
      {
        "command": "'"$_stop_cmd"'",
        "timeout": 30000
      }
    ]
  }'
    fi

    cat > "$settings_file" << SETTINGS
{
  "permissions": {
    "allow": [
      "Read",
      "Glob",
      "Grep",
      "Bash",
      "Edit",
      "Write",
      "WebSearch",
      "Skill(${short}-review)",
      "Skill(${short}-ship)",
      "Skill(${short}-learn)"${sheal_perms}
    ]
  }${hooks_block}
}
SETTINGS
    log_ok "Created .claude/settings.json"
  else
    # Upgrade path: ensure hooks exist in existing settings.json
    local _needs_hook_update=false

    # Check if SessionStart hook is missing (all repos need this)
    if ! grep -qF 'SessionStart' "$settings_file" 2>/dev/null; then
      _needs_hook_update=true
    fi

    if [[ "$_needs_hook_update" == true ]]; then
      local _sheal_detected
      _sheal_detected=$(echo "$m" | jq -r '.sheal.installed // false' 2>/dev/null)

      local _jq_expr
      if [[ "$_sheal_detected" == "true" ]]; then
        _jq_expr='
          .permissions.allow += ["Skill(sheal-check)", "Skill(sheal-retro)", "Skill(sheal-drift)", "Skill(sheal-ask)"]
          | .permissions.allow |= unique
          | .hooks.SessionStart = [{"command": "if command -v aiframework-update-check >/dev/null 2>&1; then aiframework-update-check 2>/dev/null || true; fi; sheal check --format json --skip tests --project . 2>/dev/null | head -20 || true", "timeout": 15000}]
          | .hooks.Stop = [{"command": "if command -v sheal >/dev/null 2>&1 && [ -d .sheal ]; then sheal retro --project . 2>/dev/null | tail -5 || true; fi", "timeout": 30000}]
        '
      else
        _jq_expr='
          .hooks.SessionStart = [{"command": "if command -v aiframework-update-check >/dev/null 2>&1; then aiframework-update-check 2>/dev/null || true; fi; if command -v aiframework >/dev/null 2>&1; then aiframework verify --target . 2>/dev/null | tail -5 || true; fi", "timeout": 15000}]
          | .hooks.Stop = [{"command": "echo \"[aiframework] Session complete. Run /aif-learn if you discovered anything non-obvious.\" 2>/dev/null || true", "timeout": 5000}]
        '
      fi

      local _updated
      _updated=$(jq "$_jq_expr" "$settings_file" 2>/dev/null)

      if [[ -n "$_updated" ]] && echo "$_updated" | jq empty 2>/dev/null; then
        echo "$_updated" | jq '.' > "$settings_file"
        log_ok "Updated settings.json with SessionStart + Stop hooks"
      else
        log_warn "Could not auto-update settings.json hooks — delete .claude/settings.json and re-run"
      fi
    fi
  fi

  # --- #30-31: Code Reviewer Agent ---
  local agents_dir="$TARGET_DIR/.claude/agents"
  mkdir -p "$agents_dir"
  if [[ ! -f "$agents_dir/code-reviewer.md" ]]; then
    cat > "$agents_dir/code-reviewer.md" << 'AGENTMD'
---
name: code-reviewer
description: Focused code review agent with restricted tools
model: claude-sonnet-4-6
allowed-tools: [Read, Glob, Grep, Bash]
---

# Code Reviewer

Review the provided code changes for:
1. Invariant violations (check CLAUDE.md Invariants section)
2. Missing error handling
3. Security issues (hardcoded secrets, injection risks)
4. Test coverage gaps

Output format:
- PASS: No issues found
- ISSUES: Numbered list with file:line references
AGENTMD
    log_ok "Created .claude/agents/code-reviewer.md"
  fi

  # --- #32-33: Review Command ---
  local commands_dir="$TARGET_DIR/.claude/commands"
  mkdir -p "$commands_dir"
  if [[ ! -f "$commands_dir/review.md" ]]; then
    cat > "$commands_dir/review.md" << 'CMDMD'
---
description: Review code changes against project invariants
allowed-tools: [Read, Glob, Grep, Bash]
argument-hint: "[file or directory to review]"
---

Review $ARGUMENTS for invariant violations, missing tests, and security issues.
Check CLAUDE.md Invariants section for project-specific rules.
CMDMD
    log_ok "Created .claude/commands/review.md"
  fi
}
