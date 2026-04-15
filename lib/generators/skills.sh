#!/usr/bin/env bash
# Generator: Custom Skills
# Creates project-specific review and ship skills

generate_skills() {
  local m="$MANIFEST"
  local short=$(echo "$m" | jq -r '.identity.short_name')
  local name=$(echo "$m" | jq -r '.identity.name')
  local lint=$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')
  local typecheck=$(echo "$m" | jq -r '.commands.typecheck // "NOT_CONFIGURED"')
  local test_cmd=$(echo "$m" | jq -r '.commands.test // "NOT_CONFIGURED"')
  local build=$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')

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
  echo "$m" | jq -r '.domain.detected_domains[] | .name' 2>/dev/null | while IFS= read -r domain; do
    case "$domain" in
      auth)
        echo "### 1.${inv_num} INV-${inv_num}: Authentication Guards"
        echo "Verify all new/modified endpoints have auth middleware applied."
        echo "Look for: unprotected routes, missing guards, public endpoints that should be private."
        echo ""
        ;;
      database)
        echo "### 1.${inv_num} INV-${inv_num}: Database Safety"
        echo "Verify no raw SQL, all queries through ORM, migrations are reversible."
        echo "Look for: raw SQL strings, missing migrations, schema changes without migration."
        echo ""
        ;;
      api)
        echo "### 1.${inv_num} INV-${inv_num}: Input Validation"
        echo "Verify all API endpoints validate input before processing."
        echo "Look for: missing validation, untyped request bodies, direct user input in queries."
        echo ""
        ;;
      ai)
        echo "### 1.${inv_num} INV-${inv_num}: LLM Trust Boundary"
        echo "Verify LLM output is never trusted as safe."
        echo "Look for: unsanitized AI output in HTML, eval of AI-generated code, AI output in SQL."
        echo ""
        ;;
      sandbox)
        echo "### 1.${inv_num} INV-${inv_num}: Sandbox Isolation"
        echo "Verify code execution is sandboxed with resource limits."
        echo "Look for: unsandboxed exec, missing timeouts, file system access."
        echo ""
        ;;
      frontend)
        echo "### 1.${inv_num} INV-${inv_num}: Frontend Security & Quality"
        echo "Verify no XSS vulnerabilities (dangerouslySetInnerHTML, v-html, innerHTML assignments)."
        echo "Check accessibility: proper labels, alt text, ARIA attributes, keyboard navigation."
        echo "Verify loading states exist for all async operations."
        echo ""
        ;;
      external-apis)
        echo "### 1.${inv_num} INV-${inv_num}: External API Safety"
        echo "Verify no API keys or secrets are hardcoded or exposed to client bundles."
        echo "Check that all external API calls have proper error handling and timeout configuration."
        echo "Look for: missing try/catch, no timeout set, leaked credentials."
        echo ""
        ;;
      workers)
        echo "### 1.${inv_num} INV-${inv_num}: Worker/Job Safety"
        echo "Verify job handlers are idempotent — safe to retry without side effects."
        echo "Check retry logic and backoff configuration."
        echo "Look for: missing dead letter queue, no idempotency key, unbounded retries."
        echo ""
        ;;
    esac
    ((inv_num++)) || true
  done >> "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md"

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
    local display trigger_desc
    display=$(echo "$m" | jq -r ".domain.detected_domains[] | select(.name == \"$domain\") | .display")

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

  # --- Learnings file ---
  mkdir -p "$TARGET_DIR/tools/learnings"
  touch "$TARGET_DIR/tools/learnings/${short}-learnings.jsonl"
  log_ok "Created tools/learnings/${short}-learnings.jsonl"
}
