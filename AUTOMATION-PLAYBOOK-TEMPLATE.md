# AUTOMATION-PLAYBOOK-TEMPLATE.md — Universal Automation Bootstrap

> **Version:** 2.0.0 | **Date:** 2026-04-15
> **Purpose:** Drop this file in any repo root. Ask Claude Code to "run the automation playbook".
> Claude will analyze the repo, generate CLAUDE.md, create git hooks, CI, skills, and all 12 layers.

---

## HOW TO USE

1. Copy this single file into the root of any git repository
2. Open Claude Code in that repo
3. Say: **"Run the automation playbook"** or **"Set up the automation from the playbook"**
4. Claude will execute Part 1 (analysis) → Part 2 (generate CLAUDE.md) → Part 3 (create all files)
5. Review and commit the generated files

**This is a self-executing document.** Claude reads it and follows the instructions below.

---

## CRITICAL PRINCIPLES

### 1. Infrastructure-Agnostic
This template assumes NOTHING about what infrastructure, services, or tools a project uses. No project is the same. One project may use PostgreSQL, another Firebase, another no database at all. One may use E2B sandboxes, another may have no code execution. Do NOT copy env var names, service names, or infrastructure details from other projects. **Every value must come from analyzing THIS repo's actual files.**

### 2. Auto-Evolution
The CLAUDE.md is a living document. It starts minimal on day 1 and grows over time:
- **Day 1 (playbook run):** Scaffold with discovered structure, commands, initial invariants
- **Week 1:** Invariants refined as bugs surface, learnings added via `/learn`
- **Month 1:** Key Locations expanded as new services built, Session Learnings populated
- **Month 6+:** Full ComPilot-level depth (100+ learnings, 50+ key locations, 19+ invariants)

**Auto-evolution rules (embedded in the generated CLAUDE.md):**
- After every session with code changes → update CLAUDE.md if new invariants, key locations, or principles discovered
- After every bug fix → add to Session Learnings if the root cause was non-obvious
- After every new feature → add new services/files to Key Locations
- After every new env var → add to Environment Variables table
- After structural change → update Project Structure section
- The CLAUDE.md grows organically — never delete sections, only add and refine

### 3. Greenfield-Ready
If the project is new (no source code, no config, no CI):
- CLAUDE.md starts with just: Project Identity, Key Commands (npm init basics), Workflow Rules, Decision Priority
- All conditional sections (`{{IF ...}}`) are omitted — no empty tables, no placeholder content
- As the project grows, Claude adds sections on first encounter: "I see you added a database — adding Database Safety to invariants and review specialists"
- Empty env var table → omit the section entirely, add it when first .env.example is created
- 0 invariants → add a note: "Invariants will be discovered as the project matures"

---

# PART 1: REPO ANALYSIS PROTOCOL

**Claude: When the user asks you to run this playbook, execute these discovery steps FIRST.**
**Do NOT skip any step. Do NOT guess — read the actual files.**
**If a file doesn't exist, record the value as "NOT FOUND" — never invent content.**

## Step 1.1: Discover Project Identity

```
Read and extract from these files (whichever exist):
- package.json         → name, version, description, scripts
- pyproject.toml       → name, version, description, scripts
- Cargo.toml           → name, version, description
- go.mod               → module name
- Gemfile              → project gems
- README.md            → first paragraph (project description)
- Dockerfile           → base image, ports, entrypoint
- docker-compose.yml   → services, databases, caches
```

**Record:**
- `PROJECT_NAME` — preferred name for the project. Priority: (1) repo directory name, (2) Docker image name from Makefile/CI, (3) package.json `name`. When these conflict, ask the user which name they prefer.
- `PROJECT_DESCRIPTION` — one-line description. Try package.json `description`, then pyproject.toml `description`, then first paragraph of README.md. If none found, ask the user.
- `PROJECT_VERSION` — current version (or "0.1.0" if none)

## Step 1.2: Discover Stack

```
Detect the primary language and framework:

Python:     pyproject.toml, setup.py, requirements.txt, Pipfile
TypeScript: tsconfig.json, tsconfig.base.json
JavaScript: package.json (no tsconfig)
Go:         go.mod
Rust:       Cargo.toml
Ruby:       Gemfile

Detect the framework:
- FastAPI/Flask/Django  → from pyproject.toml dependencies
- Next.js/React/Vue    → from package.json dependencies
- NestJS/Express       → from package.json dependencies
- Gin/Echo             → from go.mod
- Actix/Axum           → from Cargo.toml

Detect monorepo or multi-package:
- workspaces in package.json → JS/TS monorepo
- [workspace] in Cargo.toml with members = [...] → Rust workspace (list all crates)
- go.work file → Go workspace
- apps/ + libs/ directories → monorepo
- multiple pyproject.toml files → Python monorepo
- Nx, Turborepo, Lerna config → monorepo tooling
- Separate subdirectory with its own package.json (e.g., frontend/) → multi-package project
  (NOT a formal monorepo but has multiple build targets — record both)
```

**Record:**
- `LANGUAGE` — Python, TypeScript, JavaScript, Go, Rust, Ruby
- `FRAMEWORK` — FastAPI, Next.js, NestJS, Express, etc.
- `IS_MONOREPO` — true/false
- `MONOREPO_STRUCTURE` — if monorepo, list apps/ and libs/

## Step 1.3: Discover Package Manager & Commands

```
Read scripts/commands from the project config:

npm/yarn/pnpm:   package.json → scripts {}
Python:          pyproject.toml → [project.scripts], Makefile targets
Go:              Makefile targets
Rust:            cargo commands

Check for Makefile, makefile, Makefile.* — extract key targets.
Check for docker-compose.yml — extract services.
```

**Record:**
- `PROJECT_SHORT_NAME` — short slug for skill names (e.g., "defai", "backend", "wallet-talks"). Derive from repo dir name or package name. Must be kebab-case, no spaces.
- `PKG_MANAGER` — pip, npm, yarn, pnpm, cargo, go
- `INSTALL_CMD` — e.g., "npm install", "pip install -e '.[dev]'", "yarn install"
- `DEV_CMD` — e.g., "npm run dev", "python -m app.main", "cargo run"
- `BUILD_CMD` — e.g., "npm run build", "docker build -t app .", "cargo build --release"
- `LINT_CMD` — e.g., "npm run lint", "ruff check .", "cargo clippy". If NOT configured, set to "NOT_CONFIGURED" and note in MISSING_TOOLS.
- `FORMAT_CMD` — e.g., "npm run format", "ruff format .", "cargo fmt"
- `TYPECHECK_CMD` — e.g., "npx tsc --noEmit", "mypy src/", "cargo check". If NOT configured, set to "NOT_CONFIGURED".
- `TEST_CMD` — e.g., "npm run test", "pytest", "cargo test"
- `DEV_PORT` — port for local dev (from .env.example, config file, or dev script). If Dockerfile has a different port, record both: `DEV_PORT` and `PROD_PORT`.
- `LOCK_FILE` — `yarn.lock`, `package-lock.json`, `pnpm-lock.yaml`, `Pipfile.lock`, `Cargo.lock`, `go.sum` (whichever exists). Needed for CI cache and path triggers.
- `GITHUB_URL` — extract from `git remote -v` (origin URL). Strip credentials if present (replace `ghp_xxx@` with empty).
- `LOCAL_PATH` — current working directory (`pwd`)
- `PRODUCTION_URL` — ask the user if not discoverable from code. Note "UNKNOWN" if user doesn't know yet.

## Step 1.4: Discover Directory Structure

```
List the top-level directory structure.
For each key directory (src/, app/, lib/, etc.), list one level deep.
Identify:
- Source code directories
- Test directories and patterns
- Config files
- Documentation directories
- Scripts/tools directories
- CI/CD directories (.github/, .gitlab-ci.yml, etc.)
```

**Record:**
- `SOURCE_DIRS` — where the app code lives
- `TEST_DIRS` — where tests live
- `TEST_PATTERN` — e.g., "*.test.ts", "test_*.py", "*_test.go"
- `DOC_DIRS` — where docs live (or "none")
- `CONFIG_FILES` — list of config files at root

## Step 1.4b: Build Key Locations Map (DEEP SCAN)

```
This is the most referenced section in a CLAUDE.md. Scan for these categories
BUT ONLY INCLUDE THOSE THAT ACTUALLY EXIST in this project:

1. Entry point(s) — main.ts, main.py, index.ts, etc.
2. Config file — where env vars are loaded
3. Database schema — if project has a database
4. API routes — if project has HTTP endpoints
5. Auth/guards — if project has authentication
6. Key services — business logic
7. Workers/jobs — if project has async processing
8. External providers — if project integrates external APIs
9. Frontend pages — if project has a frontend
10. Frontend hooks — if project has client-side data fetching
11. Shared utilities — helpers, constants, types
12. Scripts — deploy, build, migration scripts
13. AI/LLM — if project uses AI/language models
14. Code execution/sandbox — if project executes user code

Skip any category that doesn't exist. Don't create empty entries.

For EACH entry, note:
- The exact file path
- Purpose in 5-10 words
- Non-obvious details (e.g., "schema is at db/schema.prisma NOT prisma/schema.prisma")
- Related files that must stay in sync

Additional instructions:
- Follow abstraction chains: if main.ts delegates to AppBuilder.create(), record BOTH
- Flag registration/wiring files (module.ts, app.module.ts, routes/index.ts) as HIGH-IMPORTANCE — these are where new features get connected
- Record approximate counts: "19+ controllers", "37 services", "22 DTOs"

Output format for Key Locations section in CLAUDE.md:
- **Label**: `path/to/file` — description. Non-obvious detail if any.
```

**Record:**
- `KEY_LOCATIONS` — list of 15-50 entries in the bullet format above
- `COMPONENT_COUNTS` — e.g., "17 controllers, 37 services, 22 DTOs, 37 tool managers"

## Step 1.5: Discover Existing CI/CD & Deploy

```
Check:
- .github/workflows/*.yml    → GitHub Actions
- .gitlab-ci.yml             → GitLab CI
- Jenkinsfile                → Jenkins
- .circleci/config.yml       → CircleCI
- Dockerfile, Dockerfile.*   → containerized deploy (note: some repos have multiple Dockerfiles)
- docker-compose.yml         → local infra
- vercel.json                → Vercel
- netlify.toml               → Netlify
- fly.toml                   → Fly.io
- render.yaml                → Render
- appspec.yml                → AWS CodeDeploy
- buildspec.yml              → AWS CodeBuild
- Makefile docker targets    → Docker build/push
- e2b.toml                   → E2B/sandbox
- Helm charts, k8s/          → Kubernetes
- terraform/, *.tf           → Infrastructure as code
- supabase/                   → Supabase (edge functions, migrations, config)
- firebase.json               → Firebase
- serverless.yml              → Serverless Framework
- wrangler.toml               → Cloudflare Workers

Read each CI workflow file fully to understand:
- What triggers it (push, PR, manual)
- What jobs it runs
- Where it deploys to
- What secrets it uses
```

**Record:**
- `CI_PROVIDER` — GitHub Actions, GitLab CI, etc.
- `CI_WORKFLOWS` — list of ALL workflow files with purpose. Include in CLAUDE.md if 2+ workflows exist:
  ```
  | Workflow | Purpose | Trigger |
  |----------|---------|---------|
  | ci.yml | Lint + test + build | PR, push to main |
  | deploy.yml | Deploy to production | push to main |
  ```
- `CI_COVERAGE` — which quality gates are covered (lint? test? build? security audit? doc staleness?)
- `CI_GAPS` — which gates are missing from CI
- `DEPLOY_TARGET` — Docker/VPS, GCP, AWS, Vercel, etc.
- `DEPLOY_TRIGGER` — push to main, tag, manual, etc.
- `DEPLOY_REGISTRY` — Docker registry URL if applicable
- `GITHUB_SECRETS` — list of secrets used in workflows

## Step 1.6: Discover Environment Variables

```
Check for env vars in priority order (higher = more authoritative):

1. TYPED CONFIG FILES (best source — has defaults, types, validation):
   - src/config.ts with Zod schema
   - config.py with Pydantic Settings
   - src/env.ts, src/settings.py, etc.
   If found, this is the PRIMARY source for env var names and defaults.

2. .env.example, .env.template, .env.sample
   Secondary source — may have fewer vars than typed config.

3. Environment references in Dockerfile (ENV, ARG, --secret)
4. Environment references in docker-compose.yml
5. CI workflow env/secrets references
6. Makefile secrets (--secret flags in docker build commands)

IMPORTANT: Use var names EXACTLY as they appear in the source file.
If config.ts says DATABASE_URL but .env.example says POSTGRES_HOST — note BOTH.
Build-time secrets (Docker --secret) are different from runtime env vars.
```

**Record:**
- `ENV_VARS` — table of variable name, required/optional, description. Built ONLY from actual file content:
  - Use EXACT variable names from .env.example (e.g., `POSTGRES_HOST` not `DATABASE_URL` if that's what the file says)
  - If .env.example doesn't exist but Dockerfile has ENV lines → use those
  - If neither exists → `ENV_VARS` = empty, omit the Environment Variables section from CLAUDE.md
  - NEVER invent or rename env var names. NEVER copy env var names from other projects.
  - Each project has unique infrastructure — don't assume PostgreSQL, Redis, E2B, or any specific service

## Step 1.7: Discover Existing Quality Tools

```
Check which tools are already configured:
- Linter config: .eslintrc*, eslint.config.*, .ruff.toml, ruff section in pyproject.toml, .pylintrc
- Formatter: .prettierrc*, prettier in package.json, black/ruff format
- Type checker: tsconfig.json (strict mode?), mypy.ini, pyright
- Test config: jest.config.*, vitest.config.*, pytest.ini, conftest.py
- Pre-existing hooks: .husky/, .githooks/, pre-commit-config.yaml

Note what is MISSING (not yet configured) — this is important for recommendations.
```

**Record:**
- `LINTER` — tool name + config file (or "NOT CONFIGURED")
- `FORMATTER` — tool name + config file (or "NOT CONFIGURED")
- `TYPE_CHECKER` — tool name + config file (or "NOT CONFIGURED")
- `TEST_FRAMEWORK` — tool name + config file
- `TEST_FILES_EXIST` — run `find . -name "*.test.*" -o -name "*.spec.*" | grep -v node_modules | wc -l`. If 0, note: "Test framework configured but NO test files exist. Note this in CLAUDE.md Testing section."
- `EXISTING_HOOKS` — what hooks exist already
- `MISSING_TOOLS` — what needs to be set up

**When tools are missing — decision protocol:**
- If LINT_CMD is NOT_CONFIGURED:
  - Python → recommend `ruff` (add to pyproject.toml `[project.optional-dependencies] dev`)
  - TypeScript → should already have eslint via framework; flag if missing
  - Pre-commit hook: SKIP lint gate, add TODO comment in hook
  - Pre-push hook: SKIP lint gate, add TODO comment in hook
  - CI workflow: SKIP lint job, add commented-out template
  - CLAUDE.md: note as "> **Note:** Linter not configured — recommended first step"
- If TYPECHECK_CMD is NOT_CONFIGURED:
  - Pre-commit hook: SKIP entirely (no value without type checker)
  - Note in CLAUDE.md
- If both lint AND typecheck are missing: create pre-commit hook with just a format check (if formatter exists) or skip pre-commit entirely. Pre-push still runs test + build.

## Step 1.8: Discover Domain-Specific Concerns

```
Look at the codebase to identify domain-specific patterns that need invariants.
ONLY check patterns that actually exist in this project — not all projects have:
- databases, auth, AI, sandboxes, or external APIs

Scan for WHATEVER this specific project has:
- Auth/authz patterns (if auth code exists)
- Database access patterns (if DB code exists)
- External API integrations (if API clients exist)
- User input handling (if user-facing endpoints exist)
- File upload/storage (if file handling code exists)
- Sandbox/code execution (if code execution exists)
- Financial calculations (if financial logic exists)
- Compliance requirements (if compliance code exists)
- Monorepo boundary rules (if monorepo)
- AI/LLM integration patterns (if AI code exists)
- Any OTHER domain-specific pattern unique to this project

The goal is to discover what THIS project's rules are — not apply a generic checklist.
```

**Record:**
- `INVARIANTS` — list of project-specific rules that must never be violated. For each invariant, note:
  - Is it ENFORCED by existing tooling (linter rule, type check, test)? Or is it ASPIRATIONAL (not yet enforced)?
  - Example: if linter has `@typescript-eslint/no-explicit-any: 'off'`, then "No `as any`" is aspirational, not enforced. Document this honestly: "INV-2: No `as any` (ASPIRATIONAL — eslint rule is currently off)"
- `REVIEW_DOMAINS` — list of specialist review domains needed
- `SECURITY_CONCERNS` — areas that need `/cso` attention
- `CORE_PRINCIPLES` — design philosophy inferred from code (e.g., "No raw SQL — uses ORM everywhere", "All config via Settings class", "No provider names in UI")

## Step 1.8b: Collect User-Provided Context

**Claude: Ask the user these questions. Some info cannot be discovered from code.**

```
1. Production URL(s) — "What are the production/staging URLs for this app?"
   (Needed for /qa and /canary commands)

2. Active workstream — "Is there a current task with scope restrictions?
   (files you're allowed to edit, modules that are off-limits)"

3. Credentials location — "Where are credentials stored?
   (e.g., 1Password, ~/.zshrc.local, Vault)"

4. Team conventions — "Any team rules I should know about?
   (e.g., 'never push without asking', 'French UI', 'no provider names in UI')"

5. Known pitfalls — "Any gotchas or past incidents I should be aware of?"
```

**If the user says "skip" or "none" for any question, omit that section from CLAUDE.md.**
**Never invent answers — only include what the user provides or what code analysis proves.**

---

## Step 1.9: Compile Analysis Report

**Present the full analysis to the user in a summary table before proceeding.**
Ask: "Does this look right? Anything to add or correct before I generate the files?"

---

# PART 2: CLAUDE.md TEMPLATE

**Claude: After the user confirms the analysis, generate `CLAUDE.md` using this template.**
**Replace every `{{VARIABLE}}` with the discovered value from Part 1.**
**Remove sections that don't apply (e.g., Docker Compose section if no docker-compose.yml).**
**Add project-specific sections based on the domain analysis.**

---

```markdown
# CLAUDE.md — {{PROJECT_NAME}}

**Source of truth for Claude Code in this repository.**
**Update this file after significant decisions, bug fixes, or architectural changes.**

**Last updated: {{TODAY_DATE}}**

---

## When to Read Which Doc

| You need to... | Read |
|----------------|------|
| Understand how to work in this repo | This file (CLAUDE.md) |
{{FOR EACH DOC_FILE discovered in docs/:}}
| {{DOC_PURPOSE}} | [{{DOC_PATH}}]({{DOC_PATH}}) |
{{END FOR}}
| Debug a recurring issue | `docs/LESSONS_LEARNED.md` (if exists) |
| Follow the development workflow | `tools/workflow/WORKFLOW.md` (if exists) |

---

## Decision Priority

When instructions conflict, follow this order:
1. **User's explicit instruction** in the current conversation
2. **Invariants** (below) — these are never overridden
3. **Workflow Rules** (below) — process guardrails
4. **Core Principles** (below) — design philosophy
5. **Reference docs** (`docs/`) — context, but code is always the source of truth

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
{{PROJECT_SPECIFIC_VERIFICATION_RULES — e.g., "After frontend changes, verify sidebar nav entries"}}

### 4. Git Safety
- After fixes: `git add` + `git commit` — but do NOT push until user says so
- NEVER push to main without explicit user confirmation
- NEVER commit after every small change — batch related changes into logical commits
- Prefer fewer, larger commits over many small ones

### 5. Subagent Strategy
- Use subagents for research, exploration, and parallel analysis
- Limit to 6-8 agents per wave maximum
- After each wave: summarize results, commit, then start next wave
- Use `/compact` after each major milestone to maintain headroom

### 6. QA Auto-Fix
When QA discovers issues, ALL must be automatically fixed:
1. Run tests — collect all failures
2. Fix each failure: identify root cause → fix implementation (never skip a test)
3. Run type check → must pass
4. Run tests again — all must pass
5. Commit

Auto-fix rules (adapt to your language):
- Type/compile error → fix the code properly:
  - TypeScript: never use `as any` or `@ts-ignore`
  - Rust: never use `unsafe` or `#[allow(dead_code)]` to hide problems
  - Python: never use `type: ignore` without justification
  - Go: never use `//nolint` without justification
- Test expects X but got Y → fix the implementation, not the test assertion
- Never skip a test to make CI pass:
  - TypeScript: never `.skip()`
  - Rust: never `#[ignore]` on production-relevant tests
  - Python: never `@pytest.mark.skip` without documented reason
  - Go: never `t.Skip()` without documented reason

### 7. Documentation Auto-Sync
After ANY feature implementation, refactor, or significant change — before marking complete:

**Code-adjacent updates (always):**
1. CLAUDE.md — if change adds invariants, new key locations, new commands
2. docs/ — update relevant doc files
{{PROJECT_SPECIFIC_DOC_SYNC_RULES}}

**Verification (always last):**
- No doc references stale counts, removed features, or outdated file paths
- All verification commands pass

**Triggers:** New API routes, new pages/modules, new services, new database models, architectural changes.
**Skip when:** Pure bug fixes with no API/UI surface change, test-only changes, dependency updates.

{{IF HAS_NEW_FEATURE_CHECKLIST}}
### 8. New Feature Checklist
Before marking any new feature complete, verify ALL applicable items:

{{NEW_FEATURE_CHECKLIST — backend items, frontend items, verification items, doc items}}
{{ENDIF}}

{{IF HAS_DOMAIN_SPECIFIC_CHECKLISTS — e.g., new provider, new integration, new module}}
### 9. {{DOMAIN_CHECKLIST_NAME}} Checklist
{{DOMAIN_CHECKLIST_ITEMS}}
{{ENDIF}}

### 10. Changelog Update
After marking any feature complete and before pushing:
1. Update CHANGELOG.md with user-facing description of changes
2. Bump VERSION file (PATCH for fixes, MINOR for features, MAJOR for breaking changes)
3. CHANGELOG entry must describe what users can DO — no internal jargon

### 11. CLAUDE.md Auto-Evolution
This file is a living document that grows with the project. After ANY session with code changes:
- **New service/module added** → add to Key Locations
- **New env var added** → add to Environment Variables table
- **Non-obvious bug fixed** → add to Session Learnings via `/learn`
- **New invariant discovered** → add to Invariants section
- **New API pattern established** → add to API Contract Rules (if section exists)
- **Structural change** → update Project Structure
- **New deploy config** → update Deploy section
- Update the "Last updated" footer with session summary
- NEVER delete content — only add, refine, or mark as deprecated

---

## Core Principles

{{IF CORE_PRINCIPLES discovered from code analysis or user input:}}
{{CORE_PRINCIPLES — design philosophy specific to THIS project.
Infer from: coding patterns, linter rules, team conventions shared by user.
Do NOT copy principles from other projects.
If no clear principles are discovered, omit this section — it will grow over time.}}
{{ELSE}}
*Core principles will emerge as the project matures. Add principles here when patterns are established.*
{{ENDIF}}

---

## Project Identity

**{{PROJECT_NAME}}** — {{PROJECT_DESCRIPTION}}

**Stack:** {{LANGUAGE}} / {{FRAMEWORK}} / {{KEY_DEPENDENCIES}}
{{IF DEPLOY_TARGET}}**Deploy:** {{DEPLOY_TARGET}} ({{DEPLOY_REGISTRY}}){{ENDIF}}
{{IF DEV_PORT}}**Port:** {{DEV_PORT}}{{ENDIF}}
{{IF PROJECT_STATUS}}**Status:** {{PROJECT_STATUS — e.g., "Pre-launch. 72 tasks in docs/TASKS.md"}}{{ENDIF}}

---

## Repository

**GitHub:** `{{GITHUB_URL}}`
**Local path:** `{{LOCAL_PATH}}`
{{IF READ_ONLY_REPOS}}
Do NOT modify: {{READ_ONLY_REPOS — list of paths that should not be edited}}
{{ENDIF}}

---

{{IF DEPLOYMENT_URLS}}
## Deployment

| Service | URL |
|---------|-----|
{{FOR EACH SERVICE:}}
| {{SERVICE_NAME}} | {{SERVICE_URL}} |
{{END FOR}}

{{IF CREDENTIALS_LOCATION}}
**Credentials:** {{CREDENTIALS_LOCATION — e.g., "~/.zshrc.local" or "1Password vault"}}
{{ENDIF}}

Full deployment details: [docs/INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md)

---
{{ENDIF}}

{{IF ACTIVE_WORKSTREAM — current task with scope restrictions}}
## Active Workstream

### {{WORKSTREAM_NAME}}

**Module:** {{AFFECTED_MODULES}}

**Allowed files (edit):**
{{ALLOWED_FILES_LIST}}

**Read-only files (reference only):**
{{READONLY_FILES_LIST}}

**Forbidden actions:**
{{FORBIDDEN_ACTIONS_LIST}}

---
{{ENDIF}}

## Project Structure

{{DIRECTORY_TREE — show source dirs 1-2 levels deep, annotated with purpose}}

{{IF IS_MONOREPO}}
### Monorepo Layout

{{MONOREPO_STRUCTURE — list apps/ and libs/ with descriptions}}

{{IF SHARED_LIBRARIES — e.g. libs/shared/ with multiple sub-packages}}
### Shared Libraries ({{COUNT}} in `libs/shared/`)

{{LIBRARY_LIST — comma-separated with brief purpose annotations}}
{{ENDIF}}

### Path Aliases

{{PATH_ALIASES — if tsconfig paths or similar exist}}
{{ENDIF}}

---

## Key Commands

```bash
# Install
{{INSTALL_CMD}}

# Dev
{{DEV_CMD}}

# Build
{{BUILD_CMD}}

# Lint
{{LINT_CMD}}

# Type check
{{TYPECHECK_CMD}}

# Test
{{TEST_CMD}}

{{IF FORMAT_CMD}}
# Format
{{FORMAT_CMD}}
{{ENDIF}}

{{IF DOCKER_BUILD_CMD}}
# Docker build
{{DOCKER_BUILD_CMD}}
{{ENDIF}}
```

{{IF MISSING_TOOLS}}
> **Note:** The following tools are not yet configured: {{MISSING_TOOLS}}.
> Setting these up is recommended as a first step.
{{ENDIF}}

---

## Key Locations

{{IF KEY_LOCATIONS has entries from Step 1.4b:}}
{{KEY_LOCATIONS — file-by-file map of where to find critical code.
ONLY include files/dirs that actually exist. Never assume a project has:
- a database (it might not)
- workers/jobs (it might not)
- a frontend (it might be backend-only)
- AI/LLM code (it might be a simple CRUD app)

Format:
- **Label**: `actual/path/to/file` — purpose. Non-obvious detail if any.

Include ONLY what exists. This section grows over time as the project evolves.
}}
{{ELSE}}
*Key locations will be added as the project develops. Update this section when new important files are created.*
{{ENDIF}}

{{IF ARCHITECTURE_DIAGRAM}}
---

## Architecture

{{ARCHITECTURE_DIAGRAM — data flow, system interaction, or request lifecycle.
Use ASCII art or describe the pipeline based on what was actually discovered.
Only include components that exist in this project.
}}
{{ENDIF}}

{{IF API_CONTRACT_RULES}}
---

## API Contract Rules

{{API_CONTRACT_RULES — behavioral rules for API consistency discovered from code patterns.
Only include rules that match THIS project's actual validation/schema approach.
Examples of what to look for:
- What validation library is used? (Zod, Joi, class-validator, none)
- What ORM is used? (Prisma, TypeORM, Drizzle, Mongoose, none)
- How are API responses shaped? (standardized wrapper, raw, pagination pattern)
- Are there existing naming conventions in route handlers?
}}
{{ENDIF}}

{{IF MODULAR_MAKEFILE}}
---

## Makefile System

The project uses a modular Makefile system:
{{FOR EACH MAKEFILE:}}
- `{{MAKEFILE_PATH}}` — {{PURPOSE}}
{{END FOR}}
{{ENDIF}}

---

## Autonomous Pipeline (12 Stages)

### Stage 1: INVESTIGATE (before writing any code)

**When:** User reports a bug or asks to fix something.

```
/investigate "description of the issue"
```

Do NOT start coding before understanding the root cause.

### Stage 2: PLAN (before major features)

**When:** User asks for a significant feature or architectural change.

```
/plan-eng-review "description of the feature"
```

Skip for small, clear-scope fixes.

### Stage 3: BUILD (write the code)

**When:** After investigation/planning is complete, or for small clear-scope changes.

Rules while building:
- No secrets in code — use environment variables
{{PROJECT_SPECIFIC_BUILD_RULES — discovered from domain analysis}}
- Max 3 parallel agents per wave, `/compact` between waves
- Each agent writes output to file, returns 2-line summary

### Stage 4: VERIFY (after every code change — ALWAYS)

**When:** After completing ANY code changes. This is not optional.

```bash
{{LINT_CMD}}              # Must pass with 0 errors
{{TYPECHECK_CMD}}         # Must pass
{{TEST_CMD}}              # Must pass
{{BUILD_CMD}}             # Must compile/build
```

Fix any failures before proceeding.

### Stage 5: REVIEW (before every commit)

```
/review
```

### Stage 6: SECURITY (before commits touching auth/security/API)

**When:** Changes touch auth, permissions, API endpoints, user input, database.

```
/cso
```

### Stage 6.5: CHANGELOG Update

1. Update `CHANGELOG.md` with user-facing description
2. Bump `VERSION` file (PATCH=fixes, MINOR=features, MAJOR=breaking)

### Stage 7: DOCS (after every structural change — AUTONOMOUS)

| What changed | Update these docs |
|--------------|-------------------|
{{DOC_SYNC_MATRIX — generated from project structure analysis}}

### Stage 8: QA (before every deploy)

```
/qa {{APP_URL — e.g., http://localhost:3000}}
```

### Stage 9: SHIP (when ready to push)

```
/ship
```

### Stage 10: POST-DEPLOY (after merge to main)

```
/canary {{PRODUCTION_URL}}
```

### Stage 11: LEARN (after every significant fix or discovery)

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
| "what happened this week", "progress" | Run `/retro` |

**When in doubt:** Run more skills, not fewer.

---

## End-of-Session Checklist

Before ending ANY session where code was changed, Claude MUST complete:

- [ ] **Verify**: Did I run lint + test + build? All pass?
- [ ] **Review**: Did I run `/review` on the changes?
- [ ] **Security**: If I touched auth/API/permissions → did I run `/cso`?
- [ ] **Docs**: Did any structural change happen? → Update docs
- [ ] **Learn**: Did I discover something non-obvious? → `/learn`
- [ ] **CHANGELOG**: Did I update CHANGELOG.md + VERSION?
- [ ] **STATUS.md**: Did I update the sprint tracker?
- [ ] **Commit**: Are all changes committed with a descriptive message?
- [ ] **Push**: If user asked to push → run full pipeline

If ANY box is unchecked, complete it before responding to the user.

---

## Quick Reference Matrix

| Trigger | Skills to run (in order) |
|---------|------------------------|
| Bug reported | `/investigate` → fix → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| New feature | `/plan-eng-review` → build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` → `/canary` → `/learn` |
| Small fix | build → verify → `/review` → docs → `/ship` |
| Refactor | build → verify → `/review` → `/cso` → docs → `/qa` → `/ship` |
| Docs only | update docs → commit |
| Weekly | `/retro` |

---

## Invariants

{{IF INVARIANTS discovered in Step 1.8 — at least 1:}}
{{FOR EACH INVARIANT:}}

### INV-{{N}}: {{INVARIANT_NAME}} {{IF ASPIRATIONAL}}(ASPIRATIONAL — not yet enforced by tooling){{ENDIF}}
{{INVARIANT_DESCRIPTION — what the rule is, why it matters, what a violation looks like.
MUST be specific to THIS project. Do NOT copy generic invariants from other projects.
Each invariant must reference actual code patterns, files, or tools discovered in this repo.}}

{{END FOR}}
{{ELSE}}
*No invariants discovered yet. As the project matures, invariants will be added here when patterns emerge. Use `/learn` to capture rules as they are discovered.*
{{ENDIF}}

---

## Environment Variables

{{IF FRONTEND_WITH_PUBLIC_ENV — e.g. Next.js with NEXT_PUBLIC_ vars}}
| Variable | Scope | Description |
|----------|-------|-------------|
{{ENV_VARS table with Scope column: Client / Server / Both}}
{{ELSE}}
| Variable | Required | Description |
|----------|----------|-------------|
{{ENV_VARS table from Step 1.6}}
{{ENDIF}}

---

{{IF DEPLOY_TARGET is not "none" and not "NOT FOUND":}}
## Deploy

{{DEPLOY_DETAILS — trigger, process, target, auth, health check.
Describe ONLY what was discovered in Step 1.5. Do NOT assume any specific platform.}}

{{IF e2b.toml exists}}
### Sandbox Template

- Config: `e2b.toml`
- Dockerfile: `e2b.Dockerfile` (if exists)
- Assets: `e2b-assets/` (if exists)
- Built separately from the main app
{{ENDIF}}

{{IF docker-compose.yml exists}}
### Local Development Infrastructure

`docker-compose.yml` provides:
{{LIST_SERVICES — read from docker-compose.yml services: section. List exactly what's there.}}

```bash
docker compose up -d    # Start infra
{{DEV_CMD}}             # Start app
```
{{ENDIF}}
{{ELSE}}
## Deploy

*No deployment pipeline discovered. Add deploy configuration when ready.*
{{ENDIF}}

---

{{IF GITHUB_SECRETS has entries from Step 1.5:}}
## GitHub Secrets

| Secret | Purpose | Used By |
|--------|---------|---------|
{{GITHUB_SECRETS table — ONLY secrets actually referenced in CI workflow files.
Extract from: env:, secrets., vars. references in .github/workflows/*.yml
Do NOT invent secrets. Do NOT copy from other projects.}}
{{ELSE}}
## GitHub Secrets

*No CI secrets discovered. Add secrets here when CI workflows are configured.*
{{ENDIF}}

---

{{IF TEST_FRAMEWORK is not "NOT CONFIGURED":}}
## Testing

- **Framework:** {{TEST_FRAMEWORK}}
- **Config:** {{TEST_CONFIG_FILE}}
- **Run:** `{{TEST_CMD}}`
{{IF TEST_COVERAGE_CMD}}- **Coverage:** `{{TEST_COVERAGE_CMD}}`{{ENDIF}}
- **Pattern:** {{TEST_PATTERN — where test files live}}
{{IF TEST_FILES_EXIST == 0}}
> **Note:** Test framework is configured but **no test files exist yet**. Writing tests is a recommended first step.
{{ENDIF}}
{{ELSE}}
## Testing

*No test framework configured. Add testing setup as a priority.*
{{ENDIF}}

---

## Custom Skills

### `/{{PROJECT_SHORT_NAME}}-review`

Checks:
{{FOR EACH INVARIANT:}}
{{N}}. **{{INVARIANT_NAME}}** — {{SHORT_CHECK_DESCRIPTION}}
{{END FOR}}

### `/{{PROJECT_SHORT_NAME}}-ship`

1. `{{LINT_CMD}}` + `{{TYPECHECK_CMD}}` + `{{TEST_CMD}}` + `{{BUILD_CMD}}`
2. Invariant scan (INV-1 through INV-{{N}})
3. Doc sync
4. CHANGELOG + VERSION bump
5. Commit (never push without asking)

---

## Review Specialists

{{FOR EACH REVIEW_DOMAIN from Step 1.8:}}

### {{DOMAIN_NAME}} (`tools/review-specialists/{{DOMAIN_SLUG}}.md`)
{{CHECKLIST_ITEMS — 5-10 specific checks for this domain}}

{{END FOR}}

---

## Doc-Sync Matrix

| What changed | Update these docs |
|--------------|-------------------|
{{DOC_SYNC_MATRIX — generated from project structure}}
| New env variable | This file (Environment Variables table) |
| Architecture decision | `docs/decisions/adr-NNN.md` |

---

## Session Learnings

Stored in `tools/learnings/{{PROJECT_SHORT_NAME}}-learnings.jsonl`. Use `/learn` to add new entries.
Format: `{"ts", "skill", "type", "key", "insight", "confidence", "source", "files"}`.
Top learnings are surfaced at session start. Add new learnings when discovering project-specific pitfalls.

{{IF KNOWN_LEARNINGS — from memory, existing docs, README warnings, or domain analysis:}}
### Operational Patterns

{{FOR EACH PATTERN discovered:}}
- **{{PATTERN_SUMMARY}}**: {{DESCRIPTION}}
{{END FOR}}
{{ENDIF}}

*Learnings accumulate over time. After fixing a non-obvious bug or discovering a gotcha, run `/learn` to add it here. Over weeks and months, this section becomes the most valuable part of the CLAUDE.md.*

---

## gstack Browser Integration

If gstack is installed (`~/.claude/skills/gstack/`), use `$B` commands for browser interactions:
- `$B` is ~20x faster than Playwright MCP (~100ms vs ~2-5s)
- Uses ref-based element selection (`@e1`, `@e2`) instead of CSS selectors
- Persistent Chromium daemon — cookies/tabs/login persist between commands

Commands: `goto`, `snapshot -i`, `click @ref`, `fill @ref`, `screenshot`, `console`, `network`, `text`, `html`, `responsive`, `diff`, `chain`.

---

## Session Start Protocol

At the start of each session:
1. Read `tools/learnings/{{PROJECT_SHORT_NAME}}-learnings.jsonl` — surface top 5 relevant learnings
2. Check `git log --oneline -10` — understand recent work
3. Check `git status` — understand current state
4. If a STATUS.md file exists — read it for multi-phase task progress
5. Decision Priority: User > Invariants > Workflow Rules > Core Principles > Docs

{{SESSION_START_EXTRAS — project-specific steps, e.g.:
- "If compliance-related → read Compliance Verification Protocol"
- "Check IMPORTANT/ folder for compliance feedback"
}}

---

*Last updated: {{TODAY_DATE}}. Session: {{SESSION_SUMMARY — what was done, key changes, test counts, commit range}}. Previous session: {{PREVIOUS_SESSION_SUMMARY — brief, from STATUS.md or git log}}.*

<!-- Update this footer after every session where code was changed. Include: what was done, test count delta, key fixes, commit range. This provides context for the next session. -->
```

---

# PART 3: FILE GENERATION

**Claude: After generating CLAUDE.md, create all supporting files.**

## 3.1: Git Hooks

### `.githooks/pre-commit`

**For TypeScript projects:**
```bash
#!/bin/bash
echo "Pre-commit: Type checking..."
{{TYPECHECK_CMD}} 2>&1
if [ $? -ne 0 ]; then
  echo "Type check failed. Fix errors before committing."
  exit 1
fi
echo "Type check passed."
```

**For Python projects:**
```bash
#!/bin/bash
echo "Pre-commit: Lint checking..."
{{LINT_CMD}} 2>&1
if [ $? -ne 0 ]; then
  echo "Lint check failed. Fix errors before committing."
  exit 1
fi
echo "Lint check passed."
```

**For Rust projects:**
```bash
#!/bin/bash
echo "Pre-commit: Compile checking..."
cargo check --workspace 2>&1
if [ $? -ne 0 ]; then
  echo "Compile check failed. Fix errors before committing."
  exit 1
fi
echo "Compile check passed."
```

**For Go projects:**
```bash
#!/bin/bash
echo "Pre-commit: Vet checking..."
go vet ./... 2>&1
if [ $? -ne 0 ]; then
  echo "Go vet failed. Fix errors before committing."
  exit 1
fi
echo "Vet check passed."
```

**For any other language:** Use the fastest available check command (compile/lint/vet).

**Skip pre-commit if no type checker or linter is configured. Note this as a gap.**

**IMPORTANT — Existing hooks check:**
Before creating hooks, check if the project already has hooks:
- `.husky/` directory with pre-commit/pre-push → project uses Husky. Do NOT create `.githooks/`. Instead, review existing hooks and suggest improvements if gaps found.
- `.githooks/` directory → project already has custom hooks. Review and improve, don't overwrite.
- `pre-commit-config.yaml` → project uses pre-commit framework. Don't create competing hooks.
- If NO hook system exists → create `.githooks/` as described below.

### `.githooks/pre-push`

```bash
#!/bin/bash

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  {{PROJECT_NAME}} Pre-Push Quality Gate"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null)

# Smart skip: only non-app files changed
# Include ALL dirs/files that do NOT affect the app build:
# docs, scripts, tools, config-only files, CI configs, git hooks,
# markdown files at root, test files, env files, lock files
SKIP_PATTERNS="{{SKIP_PATTERNS — build from project structure. Example for a typical repo:
^docs/|^scripts/|^tools/|^\.github/|^\.githooks/|^e2b-assets/|^CLAUDE\.md$|^CONTRIBUTING\.md$|^SETUP-DEV\.md$|^STATUS\.md$|^CHANGELOG\.md$|^VERSION$|^AUTOMATION-PLAYBOOK.*$|^LICENSE$|^README\.md$|^\.env|^\.gitignore$|\.test\.(ts|tsx|py)$|\.spec\.(ts|tsx)$
Adapt by adding project-specific non-app dirs and removing dirs that DO affect the build.}}"

NEEDS_CHECK=false
for file in $CHANGED_FILES; do
  if ! echo "$file" | grep -qE "$SKIP_PATTERNS"; then
    NEEDS_CHECK=true
    break
  fi
done

if [ "$NEEDS_CHECK" = false ]; then
  echo "  Only non-app files changed — skipping quality checks"
  exit 0
fi

# Gate 1: Lint
echo "  [1/3] Linting..."
{{LINT_CMD}} 2>&1
if [ $? -ne 0 ]; then
  echo "  BLOCKED: Lint errors. Fix before pushing."
  exit 1
fi
echo "  [1/3] Lint passed"

# Gate 2: Test
echo "  [2/3] Testing..."
{{TEST_CMD}} 2>&1 | tail -5
if [ $? -ne 0 ]; then
  echo "  BLOCKED: Test failures. Fix before pushing."
  exit 1
fi
echo "  [2/3] Tests passed"

# Gate 3: Build
echo "  [3/3] Building..."
{{BUILD_CMD}} 2>&1 | tail -3
if [ $? -ne 0 ]; then
  echo "  BLOCKED: Build failed. Fix before pushing."
  exit 1
fi
echo "  [3/3] Build passed"

{{INVARIANT_CHECKS — generated from discovered invariants, checking changed files only}}

echo ""
echo "  All gates passed — push allowed"
echo "  TIP: Run /review and /cso before creating a PR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
```

### Activate hooks

```bash
mkdir -p .githooks
chmod +x .githooks/pre-commit .githooks/pre-push
git config core.hooksPath .githooks
```

---

## 3.2: GitHub Actions CI

### `.github/workflows/ci.yml`

**Generate based on detected language/framework.**

**TypeScript/Node template (npm/yarn/pnpm):**
```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
    paths:
      - '{{SOURCE_DIRS}}/**'
      - 'package.json'
      - '{{LOCK_FILE — e.g., yarn.lock, package-lock.json, pnpm-lock.yaml}}'
      - '.github/workflows/ci.yml'

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: {{NODE_VERSION}}
          cache: {{PKG_MANAGER}}
      - run: {{INSTALL_CMD}}
      - run: {{BUILD_CMD}}

  lint:
    name: Lint
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: {{NODE_VERSION}}
          cache: {{PKG_MANAGER}}
      - run: {{INSTALL_CMD}}
      - run: {{LINT_CMD}}

  test:
    name: Test
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: {{NODE_VERSION}}
          cache: {{PKG_MANAGER}}
      - run: {{INSTALL_CMD}}
      - run: {{TEST_CMD}}
```

**Python template:**
```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
    paths:
      - '{{SOURCE_DIRS}}/**'
      - 'pyproject.toml'
      - '.github/workflows/ci.yml'

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    name: Lint + Type Check + Test
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '{{PYTHON_VERSION}}'
      - run: pip install -e ".[dev]"
      - name: Lint
        run: {{LINT_CMD}}
      - name: Type check
        run: {{TYPECHECK_CMD}}
      - name: Test
        run: {{TEST_CMD}}

  build:
    name: Docker Build
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t {{PROJECT_NAME}} .
```

**Rust template:**
```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    name: Check + Clippy + Test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - uses: Swatinem/rust-cache@v2
      - name: Format check
        run: cargo fmt --all -- --check
      - name: Clippy
        run: cargo clippy --workspace -- -D warnings
      - name: Test
        run: cargo test --workspace
      - name: Build
        run: cargo build --workspace
```

**Go template:**
```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    name: Vet + Lint + Test
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - name: Vet
        run: go vet ./...
      - name: Test
        run: go test ./...
      - name: Build
        run: go build ./...
```

**Important — CI creation decision tree:**
1. If repo has NO CI workflows → create `ci.yml` from the template above
2. If repo has CI that covers lint+test+build → do NOT create a new one. Document the existing CI in CLAUDE.md.
3. If repo has CI but it ONLY covers deploy (no lint/test/build gates) → create `ci.yml` as an ADDITIONAL workflow alongside the existing deploy workflow. Name it `ci.yml` to avoid conflicts.
4. If repo has CI with PARTIAL coverage (e.g., build but no lint) → suggest adding the missing jobs to the existing workflow, or create a separate `ci.yml` for the gaps. Ask the user which approach they prefer.

---

## 3.3: Custom Skills

**Skills are created inside the repo** at `.claude/skills/` (repo-local).
Claude Code automatically discovers skills in the current repo's `.claude/skills/` directory.
This keeps skills version-controlled with the project code.

### `.claude/skills/{{PROJECT_SHORT_NAME}}-review/SKILL.md`

```yaml
---
name: {{PROJECT_SHORT_NAME}}-review
description: |
  {{PROJECT_NAME}} pre-landing code review with project-specific checks.
  Checks: {{LIST_INVARIANT_NAMES}}
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

# /{{PROJECT_SHORT_NAME}}-review — Code Review

## Step 1: CRITICAL Pass

For each changed file, check:

{{FOR EACH INVARIANT:}}
### 1.{{N}} {{INVARIANT_NAME}} (INV-{{N}})
{{INVARIANT_CHECK_INSTRUCTIONS — what to grep/look for, what violations look like}}

{{END FOR}}

## Step 2: Specialist Army (if applicable)

Launch parallel specialists based on what files changed:
{{FOR EACH REVIEW_DOMAIN:}}
- **{{DOMAIN_NAME}}**: when changes touch {{TRIGGER_PATHS}}
{{END FOR}}

## Step 3: Report

Output a table:
| Check | Status | Details |
|-------|--------|---------|
| ... | PASS/FAIL/WARN | ... |
```

### `.claude/skills/{{PROJECT_SHORT_NAME}}-ship/SKILL.md`

```yaml
---
name: {{PROJECT_SHORT_NAME}}-ship
description: |
  {{PROJECT_NAME}} shipping workflow. Runs lint + test + build, reviews code,
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

# /{{PROJECT_SHORT_NAME}}-ship — Shipping Workflow

## Step 1: Verify
```
{{LINT_CMD}}
{{TYPECHECK_CMD}}
{{TEST_CMD}}
{{BUILD_CMD}}
```

## Step 2: Invariant Scan
Check changed files against all {{N}} invariants.

## Step 3: Doc Sync
{{DOC_SYNC_MATRIX}}

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
```

---

## 3.4: Review Specialists

### `tools/review-specialists/`

**Create one .md file per domain discovered in Step 1.8.**

Template for each specialist:

```markdown
# {{DOMAIN_NAME}} Specialist

Check all changes in {{TRIGGER_PATHS}} for:
1. {{CHECK_1}}
2. {{CHECK_2}}
3. {{CHECK_3}}
...
```

**Common specialists to consider (create only those that apply):**

| Specialist | When to create | Trigger paths |
|-----------|---------------|---------------|
| API Security | Any project with HTTP endpoints | controllers/, routes/, api/, endpoints/ |
| Database Safety | Any project with DB access | migrations/, models/, entities/, repositories/ |
| AI/LLM Safety | Any project using LLM APIs | prompts/, agent/, llm/, ai/ |
| Frontend Quality | Any frontend project | components/, pages/, app/ |
| Sandbox Safety | Any project with code execution | sandbox/, e2b/, executor/ |
| Auth/AuthZ | Any project with authentication | auth/, guards/, middleware/ |
| Financial Calculations | Any fintech project | payroll/, billing/, transactions/ |
| Web3 Security | Any blockchain project | wallet/, contracts/, signing/ |
| Monorepo Boundaries | Any monorepo | apps/*/imports, libs/*/exports |

---

## 3.5: Structured Learnings

### `tools/learnings/{{PROJECT_SHORT_NAME}}-learnings.jsonl`

Create an empty file. Initial learnings will be added via `/learn` during development.

```bash
mkdir -p tools/learnings
touch tools/learnings/{{PROJECT_SHORT_NAME}}-learnings.jsonl
```

---

## 3.6: Documentation Scaffold

### `docs/` (Diataxis structure)

```bash
mkdir -p docs/{onboarding,guides,reference,explanation,decisions}
```

**Create `docs/README.md`:**
```markdown
# {{PROJECT_NAME}} — Documentation

## Structure (Diataxis)

| Category | Directory | Purpose |
|----------|-----------|---------|
| Tutorials | `onboarding/` | Learning-oriented, step-by-step |
| How-to Guides | `guides/` | Task-oriented instructions |
| Reference | `reference/` | Precise technical descriptions |
| Explanation | `explanation/` | Conceptual discussions |
| Decisions | `decisions/` | Architecture Decision Records |
```

---

## 3.7: Release & Sprint Tracking

### `CHANGELOG.md`

```markdown
# Changelog

All notable changes to {{PROJECT_NAME}} are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Automation pipeline (12 layers) via AUTOMATION-PLAYBOOK-TEMPLATE.md
- CLAUDE.md for Claude Code integration
- Git hooks (pre-commit + pre-push quality gates)
- Custom Claude Code skills (/{{PROJECT_SHORT_NAME}}-review, /{{PROJECT_SHORT_NAME}}-ship)

## [{{PROJECT_VERSION}}] — {{TODAY_DATE}}
### Added
- Initial project setup
```

### `VERSION`

```
{{PROJECT_VERSION}}
```

### `STATUS.md`

```markdown
# Current Sprint — Status Tracker

## Current Phase: Automation setup

## Progress
| Phase | Description | Status | Date |
|-------|-------------|--------|------|
| 1 | Automation playbook setup | Done | {{TODAY_DATE}} |
| 2 | CLAUDE.md generated | Done | {{TODAY_DATE}} |
| 3 | Git hooks (pre-commit + pre-push) | Done | {{TODAY_DATE}} |
| 4 | Custom skills created | Done | {{TODAY_DATE}} |
| 5 | Review specialists created | Done | {{TODAY_DATE}} |

## Audit Findings Log
| # | Date | Finding | Root Cause | Fix Applied |
|---|------|---------|-----------|-------------|

*Last updated: {{TODAY_DATE}}*
```

---

## 3.8: Developer Onboarding

### `SETUP-DEV.md`

```markdown
# Developer Setup — {{PROJECT_NAME}}

## Prerequisites

{{PREREQUISITES — language runtime version, tools needed, with check + install commands}}

## 8-Step Setup

### Step 1: Clone
```bash
git clone {{REPO_URL}}
cd {{PROJECT_NAME}}
```

### Step 2: Install dependencies
```bash
{{INSTALL_CMD}}
```

### Step 3: Activate git hooks
```bash
git config core.hooksPath .githooks
```

### Step 4: Environment variables
```bash
cp .env.example .env
# Edit .env with your values — ask team lead for credentials
```

### Step 5: Verify everything works
```bash
{{LINT_CMD}}
{{TEST_CMD}}
{{BUILD_CMD}}
```

### Step 6: Install Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

### Step 7: Install gstack
```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup --no-prefix
~/.claude/skills/gstack/bin/gstack-config set proactive false
~/.claude/skills/gstack/bin/gstack-config set telemetry off
```

### Step 8: Read key docs
| Order | File | Time |
|:-----:|------|:----:|
| 1 | `CLAUDE.md` | 10 min |
| 2 | `docs/onboarding/architecture-overview.md` | 5 min |
```

### `CONTRIBUTING.md`

```markdown
# Contributing to {{PROJECT_NAME}}

## Branch Naming
- `feat/description` — new feature
- `fix/description` — bug fix
- `refactor/description` — code restructuring
- `chore/description` — maintenance
- `docs/description` — documentation only

## Commit Messages (Conventional Commits)
- `feat: add user authentication`
- `fix: resolve timeout on large backtests`
- `refactor: extract metrics calculation to separate module`

## Pull Request Process
1. Branch from `main`
2. Run lint + test + build locally (pre-push hook enforces this)
3. Create PR with description: What, Why, How, Testing
4. Wait for CI to pass
5. Request review

## Code Style
{{CODE_STYLE_RULES — discovered from linter/formatter config}}

## Testing
{{TESTING_REQUIREMENTS — when to write tests, framework, patterns}}
```

---

# PART 4: EXECUTION MATRICES

## Automated Enforcement (runs without Claude)

| Trigger | What runs | Where |
|---------|-----------|-------|
| `git commit` | {{PRECOMMIT_CHECK}} | Pre-commit hook (local) |
| `git push` | Lint + Test + Build + Invariants | Pre-push hook (local) |
| PR to `main` | Lint + Test + Build | GitHub Actions CI |
| Push to `main` | {{DEPLOY_ACTION}} | {{DEPLOY_TARGET}} |

## Bug Fix Flow

```
User reports bug
    → /investigate (root cause — NEVER skip)
    → BUILD (minimal fix for root cause)
    → VERIFY ({{LINT_CMD}} + {{TEST_CMD}} + {{BUILD_CMD}})
    → /review
    → /cso (if security-related)
    → DOCS (if structural change)
    → /qa
    → /ship
    → /canary
    → /learn
    → CHANGELOG (PATCH) + STATUS.md
```

## Feature Flow

```
User requests feature
    → /plan-eng-review (if major scope)
    → BUILD
    → VERIFY ({{LINT_CMD}} + {{TEST_CMD}} + {{BUILD_CMD}})
    → /review
    → /cso (if auth/API/security)
    → DOCS
    → /qa
    → /ship
    → /canary
    → /learn
    → CHANGELOG (MINOR) + STATUS.md
```

## Deploy Flow

```
"Ship it" / "Create PR"
    → VERIFY (full quality gate)
    → /review
    → /cso
    → /qa
    → /ship (create PR)
    → [PR approved]
    → /land-and-deploy
    → /canary
```

## Weekly Cadence

```
Monday:   /retro + review STATUS.md + plan the week
Daily:    /review + /cso on all PRs, update STATUS.md
Friday:   /qa full regression, update CHANGELOG.md
Monthly:  /cso full-repo security audit, review docs
```

## Failure Recovery

| Layer | Symptom | Fix |
|-------|---------|-----|
| Pre-commit | "Type/lint check failed" | Fix errors shown, retry `git commit` |
| Pre-push | "Lint errors" | Run lint auto-fix if available, fix remaining manually |
| Pre-push | "Test failures" | Run tests in verbose mode, fix failing tests |
| Pre-push | "Build failed" | Read build output, fix compilation errors |
| CI | Red X on PR | Same as pre-push — fix locally, push again |
| Deploy | Build/push fails | Check deploy logs, fix and redeploy |
| Skill | "Skill not found" | Re-run: `cd ~/.claude/skills/gstack && ./setup --no-prefix` |

---

# PART 5: COMPLETE FILE MANIFEST

After running this playbook, the following files will exist:

| File | Purpose | Generated by |
|------|---------|-------------|
| `CLAUDE.md` | Claude Code source of truth | Part 2 |
| `.githooks/pre-commit` | Type/lint check on commit | Part 3.1 |
| `.githooks/pre-push` | Full quality gate on push | Part 3.1 |
| `.github/workflows/ci.yml` | CI pipeline (if not already present) | Part 3.2 |
| `.claude/skills/{{SHORT}}-review/SKILL.md` | Custom code review | Part 3.3 |
| `.claude/skills/{{SHORT}}-ship/SKILL.md` | Custom shipping workflow | Part 3.3 |
| `tools/review-specialists/*.md` | Domain-specific review checklists | Part 3.4 |
| `tools/learnings/{{SHORT}}-learnings.jsonl` | Structured learnings (empty) | Part 3.5 |
| `docs/README.md` | Documentation index | Part 3.6 |
| `docs/onboarding/` | Tutorial docs (scaffold) | Part 3.6 |
| `docs/guides/` | How-to docs (scaffold) | Part 3.6 |
| `docs/reference/` | Reference docs (scaffold) | Part 3.6 |
| `docs/explanation/` | Explanation docs (scaffold) | Part 3.6 |
| `docs/decisions/` | ADR directory (scaffold) | Part 3.6 |
| `CHANGELOG.md` | Release changelog | Part 3.7 |
| `VERSION` | Semantic version | Part 3.7 |
| `STATUS.md` | Sprint tracker | Part 3.7 |
| `SETUP-DEV.md` | Developer onboarding | Part 3.8 |
| `CONTRIBUTING.md` | Contributor guidelines | Part 3.8 |

**Total: 19+ files across 12 automation layers.**

---

# PART 6: POST-SETUP VERIFICATION

**Claude: After generating all files, run these verification steps.**
**Do NOT skip any step. Report ALL results in a summary table.**

## 6.1: File Existence Check

```bash
# Run and verify all these files exist:
ls CLAUDE.md
ls .githooks/pre-commit .githooks/pre-push
ls .claude/skills/{{SHORT}}-review/SKILL.md
ls .claude/skills/{{SHORT}}-ship/SKILL.md
ls tools/review-specialists/  # at least 1 file
ls tools/learnings/{{SHORT}}-learnings.jsonl
ls docs/README.md
ls CHANGELOG.md VERSION STATUS.md
ls SETUP-DEV.md CONTRIBUTING.md
```

## 6.2: Hook Activation Check

```bash
git config core.hooksPath  # Should output ".githooks"
```

If not set, run: `git config core.hooksPath .githooks`

## 6.3: Quality Gate Dry Run

```bash
# Run each command — report pass/fail. Do NOT commit anything.
{{LINT_CMD}}        # If NOT_CONFIGURED, skip and note
{{TYPECHECK_CMD}}   # If NOT_CONFIGURED, skip and note
{{TEST_CMD}}        # Must pass
{{BUILD_CMD}}       # Must pass
```

## 6.4: CLAUDE.md Content Quality Check

**Verify CLAUDE.md has no empty placeholders:**
```bash
grep -n '{{' CLAUDE.md    # Should return 0 matches
grep -n 'ADAPT' CLAUDE.md # Should return 0 matches
grep -n 'TODO' CLAUDE.md  # Note any TODOs as follow-up items
```

**Verify every section has content (not just headers):**
- [ ] Project Identity — has name, description, stack
- [ ] Key Commands — has actual commands (not placeholders)
- [ ] Key Locations — has at least 10 entries
- [ ] Invariants — has at least 2 invariants
- [ ] Environment Variables — has at least 3 entries
- [ ] Custom Skills — skill files reference actual invariants
- [ ] Review Specialists — at least 1 specialist created

## 6.5: Security Check

```bash
# Grep for potential secrets in all generated files
grep -rn "sk-\|ghp_\|password\|secret.*=.*['\"]" CLAUDE.md .githooks/ .claude/ tools/ SETUP-DEV.md CONTRIBUTING.md 2>/dev/null
```

Should return 0 matches. If any found, remove immediately.

## 6.6: Report

**Present results to user as:**

| Check | Status | Details |
|-------|--------|---------|
| Files created | X/19 | list any missing |
| Hooks active | YES/NO | — |
| Lint | PASS/SKIP/FAIL | — |
| Type check | PASS/SKIP/FAIL | — |
| Tests | PASS/FAIL | X passed |
| Build | PASS/FAIL | — |
| CLAUDE.md quality | CLEAN/HAS_TODOS | N TODOs |
| Security | CLEAN/FOUND_ISSUES | — |
| **Overall** | **READY / NEEDS FIXES** | — |

---

# PART 7: MASTER CHECKLIST

**This is the definitive checklist. Nothing is complete until every applicable box is checked.**

## A. Analysis (Part 1) — Did we discover everything?

- [ ] A1. Project name, description, version extracted
- [ ] A2. Language, framework, monorepo status detected
- [ ] A3. Package manager identified
- [ ] A4. All commands discovered: install, dev, build, lint, typecheck, test, format
- [ ] A4b. `LOCK_FILE` identified (yarn.lock / package-lock.json / pnpm-lock.yaml / etc.)
- [ ] A5. `PROJECT_SHORT_NAME` defined (kebab-case slug for skills)
- [ ] A6. `GITHUB_URL` extracted from `git remote -v`
- [ ] A7. `LOCAL_PATH` recorded
- [ ] A8. `DEV_PORT` identified (from Dockerfile, config, or dev script)
- [ ] A9. Directory structure listed (source, test, docs, config, scripts)
- [ ] A10. Key Locations deep scan done (15+ entries minimum)
- [ ] A11. CI/CD workflows read and understood (triggers, jobs, secrets)
- [ ] A12. Deploy target identified (Docker/Vercel/GCP/AWS/VPS/none)
- [ ] A13. Environment variables table built (from .env.example + config + Dockerfile + CI)
- [ ] A14. Existing quality tools inventoried (linter, formatter, type checker, test framework, hooks)
- [ ] A15. Missing tools identified and documented
- [ ] A16. Domain-specific invariants discovered (auth, DB, API, sandbox, etc.)
- [ ] A16b. Each invariant cross-checked: ENFORCED (by linter/test) vs ASPIRATIONAL (not yet enforced)
- [ ] A17. Review specialist domains identified
- [ ] A18. Core principles inferred from code patterns
- [ ] A19. User asked for: production URLs, active workstream, credentials location, team conventions, known pitfalls
- [ ] A20. Analysis report presented to user and confirmed

## B. CLAUDE.md (Part 2) — Is every section filled?

- [ ] B1. "When to Read Which Doc" table populated (or minimal if no docs/ yet)
- [ ] B2. Decision Priority section present (verbatim from template)
- [ ] B3. Workflow Rules present with all 10 rules
- [ ] B4. Core Principles filled (at least 3 project-specific principles)
- [ ] B5. Project Identity: name, description, stack, deploy, port
- [ ] B6. Repository: GitHub URL, local path
- [ ] B7. Deployment URLs (if user provided them)
- [ ] B8. Active Workstream (if user has one — or omitted)
- [ ] B9. Project Structure: directory tree with annotations
- [ ] B10. Key Commands: every command is an actual runnable command (not a placeholder)
- [ ] B11. Key Locations: 15+ entries with file paths and descriptions
- [ ] B12. Architecture diagram (if system has non-trivial data flow)
- [ ] B13. API Contract Rules (if project has API endpoints)
- [ ] B14. Makefile System (if project uses Makefiles)
- [ ] B15. Autonomous Pipeline: all 12 stages present
- [ ] B16. Stage 4 VERIFY: lists the actual lint/typecheck/test/build commands
- [ ] B17. Skill Routing Table present
- [ ] B18. End-of-Session Checklist present
- [ ] B19. Quick Reference Matrix present
- [ ] B20. Invariants: at least 2, each with name and description
- [ ] B21. Environment Variables table: at least 3 entries
- [ ] B22. Deploy section: trigger, process, registry/target
- [ ] B23. GitHub Secrets table (from CI workflow analysis)
- [ ] B24. Testing section: framework, config file, run command, pattern. If 0 test files exist, state that honestly.
- [ ] B25. Custom Skills: both /<project>-review and /<project>-ship defined
- [ ] B26. Review Specialists: at least 1 specialist domain
- [ ] B27. Doc-Sync Matrix: what changes trigger which doc updates
- [ ] B28. Session Learnings: format defined, file path set
- [ ] B29. gstack Browser Integration section present
- [ ] B30. Session Start Protocol present
- [ ] B31. Last Updated footer with session summary guidance
- [ ] B32. **ZERO `{{}}` placeholders remaining** in the generated CLAUDE.md
- [ ] B33. **ZERO `[ADAPT:]` markers remaining**
- [ ] B34. **No invented/guessed information** — everything from code analysis or user input

## C. Supporting Files (Part 3) — Are all files created?

- [ ] C1. `.githooks/pre-commit` — created with correct command (or skipped with documented reason)
- [ ] C2. `.githooks/pre-push` — created with correct lint/test/build commands
- [ ] C3. `.githooks/pre-push` — SKIP_PATTERNS match project structure
- [ ] C4. `.githooks/pre-push` — invariant checks match CLAUDE.md invariants
- [ ] C5. `git config core.hooksPath .githooks` — executed
- [ ] C6. `.github/workflows/ci.yml` — created OR existing CI verified as sufficient
- [ ] C7. CI workflow uses correct language setup (Node/Python/Go/Rust)
- [ ] C8. CI workflow uses correct package manager cache
- [ ] C9. CI workflow uses correct install/lint/test/build commands
- [ ] C10. `.claude/skills/<project>-review/SKILL.md` — created
- [ ] C11. Review skill references all invariants from CLAUDE.md
- [ ] C12. Review skill triggers specialist army correctly
- [ ] C13. `.claude/skills/<project>-ship/SKILL.md` — created
- [ ] C14. Ship skill uses correct verify commands matching CLAUDE.md Stage 4
- [ ] C15. `tools/review-specialists/` — at least 1 specialist file created
- [ ] C16. Each specialist has 5+ specific check items
- [ ] C17. `tools/learnings/<project>-learnings.jsonl` — file created (can be empty)
- [ ] C18. `docs/README.md` — created with Diataxis structure
- [ ] C19. `docs/` subdirectories created (onboarding, guides, reference, explanation, decisions)
- [ ] C20. `CHANGELOG.md` — created with initial entry
- [ ] C21. `VERSION` — created with correct version from project config
- [ ] C22. `STATUS.md` — created with automation setup phases marked Done
- [ ] C23. `SETUP-DEV.md` — created with correct prerequisites and commands
- [ ] C24. `CONTRIBUTING.md` — created with branch naming and commit conventions

## D. Verification (Part 6) — Does everything work?

- [ ] D1. All files from Part 5 manifest exist
- [ ] D2. `git config core.hooksPath` returns `.githooks`
- [ ] D3. Lint passes (or documented as NOT_CONFIGURED)
- [ ] D4. Type check passes (or documented as NOT_CONFIGURED)
- [ ] D5. Tests pass
- [ ] D6. Build passes
- [ ] D7. `grep '{{' CLAUDE.md` returns 0 matches
- [ ] D8. No secrets in any generated file
- [ ] D9. Verification report table presented to user

## E. Consistency Cross-Checks — Do all files agree?

- [ ] E1. Verify commands in CLAUDE.md Stage 4 match commands in pre-push hook
- [ ] E2. Verify commands in CLAUDE.md Stage 4 match commands in ship skill Step 1
- [ ] E3. Verify commands in CLAUDE.md Stage 4 match commands in CI workflow
- [ ] E4. Verify invariants in CLAUDE.md match invariant checks in review skill
- [ ] E5. Verify invariants in CLAUDE.md match invariant checks in pre-push hook
- [ ] E6. Verify `PROJECT_SHORT_NAME` is consistent across: CLAUDE.md, skill filenames, learnings filename
- [ ] E7. Verify SETUP-DEV.md commands match CLAUDE.md Key Commands
- [ ] E8. Verify doc-sync matrix in CLAUDE.md matches doc-sync in ship skill
- [ ] E9. Verify CI workflow has no unresolved `{{}}` placeholders (`grep '{{' .github/workflows/ci.yml`)
- [ ] E10. Verify pre-push hook has no unresolved `{{}}` placeholders
- [ ] E11. Verify `GITHUB_URL` in CLAUDE.md/SETUP-DEV.md has NO credentials (no `ghp_` tokens)
- [ ] E12. Verify DEV_PORT in CLAUDE.md matches .env.example (note if Dockerfile port differs)
- [ ] E13. Verify EVERY env var name in CLAUDE.md actually exists in .env.example or config file (no invented names)
- [ ] E14. Verify component counts in CLAUDE.md match actual `ls | wc -l` (controllers, services, DTOs, etc.)
- [ ] E15. Verify test file count claim matches `find . -name "*.spec.*" -o -name "*.test.*" | wc -l`

## F. Infrastructure-Agnostic Checks — No assumptions leaked?

- [ ] F1. EVERY env var name in CLAUDE.md exists verbatim in .env.example or config file (no renamed/invented vars)
- [ ] F2. No service names assumed that don't exist (e.g., don't mention PostgreSQL if project uses MongoDB)
- [ ] F3. No framework-specific terms assumed (e.g., don't mention "guards" if project isn't NestJS)
- [ ] F4. Deploy section describes only what was discovered (no assumed registries or platforms)
- [ ] F5. Invariants reference actual code patterns in THIS repo (not copied from other projects)
- [ ] F6. Review specialists match domains that actually exist in this codebase
- [ ] F7. All empty/non-applicable sections use the greenfield fallback text (not empty tables)
- [ ] F8. Shared lib list matches actual `ls libs/shared/` output (no invented libs)
- [ ] F9. If project has existing hooks (.husky/), NO competing .githooks/ was created
- [ ] F10. If project has typed config (config.ts with Zod, config.py with Pydantic), env vars come from THAT file
- [ ] F11. If project has multiple package.json files (e.g., frontend/), both are documented
- [ ] F12. All CI workflows documented (not just the one that does lint/test)

**If ANY box cannot be checked, fix the issue before declaring the playbook complete.**
