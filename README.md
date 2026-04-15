# aiframework

Universal Automation Bootstrap for AI-assisted development. Deterministic repo analysis, CLAUDE.md generation, and knowledge vault creation — in one command.

## The Problem

AI coding agents (Claude Code, Codex, Cursor) scan repos with ~50-80% coverage, guess file paths, and invent environment variables. Every session starts from scratch.

## The Solution

```
discover.sh → manifest.json     (deterministic scan, 100% facts, zero guessing)
generate.sh → CLAUDE.md + files (reads manifest, produces 19+ files)
verify.sh   → validation report (36 checks, catches any drift)
```

Every value in the manifest comes from reading actual files. Nothing is assumed, nothing is invented.

## Quick Start

```bash
# Clone
git clone https://github.com/evergonlabs/aiframework.git
cd aiframework

# Bootstrap any repo
./run.sh /path/to/your-project

# Or step by step
./discover.sh /path/to/your-project    # → .aiframework/manifest.json
./generate.sh /path/to/your-project    # → CLAUDE.md + hooks + CI + skills + vault
./verify.sh /path/to/your-project      # → verification report (36 checks)
```

### CLI Options

```bash
./bin/aiframework <command> [options]

Commands:
  discover    Scan a repo → manifest.json
  generate    Read manifest → generate all files
  verify      Validate generated files against manifest
  run         Full pipeline: discover → generate → verify

Options:
  --target <path>        Target repo (default: current directory)
  --manifest <path>      Custom manifest path
  --output <path>        Output directory for manifest
  --non-interactive      Skip user context questions
  --dry-run              Show what would be generated
  --verbose              Detailed output
```

## What Gets Generated

### Core Files (19+)

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Claude Code source of truth (500+ lines, 25 sections) |
| `.githooks/pre-commit` | Type/lint check on commit |
| `.githooks/pre-push` | Full quality gate + invariant checks |
| `.github/workflows/ci.yml` | CI pipeline (TypeScript/Python/Rust/Go/Ruby/Bash) |
| `.claude/skills/<project>-review/SKILL.md` | Project-specific code review |
| `.claude/skills/<project>-ship/SKILL.md` | Shipping workflow |
| `tools/review-specialists/*.md` | Domain-specific review checklists |
| `tools/learnings/<project>-learnings.jsonl` | Structured learnings |
| `docs/` | Documentation scaffold (Diataxis: tutorials, how-to, reference, explanation, decisions) |
| `CHANGELOG.md` | Release changelog (Keep a Changelog format) |
| `VERSION` | Semantic version |
| `STATUS.md` | Sprint tracker |
| `SETUP-DEV.md` | Developer onboarding (8 steps) |
| `CONTRIBUTING.md` | Contributor guidelines |

### Knowledge Vault (22 files)

Built on the [Agentic Memory Vault](https://github.com/galimba/agentic-memory-vault/) pattern — a git-based knowledge graph using markdown + YAML frontmatter + wikilinks.

| Category | Files | What's inside |
|----------|-------|---------------|
| **Rules** | 3 | 15 hard rules (HR-001→HR-015), 15 soft rules (SR-001→SR-015), 200+ tags across 19 prefixes |
| **Schemas** | 3 | Wiki entry frontmatter, skill security policy (3 tiers), content integrity (8 injection patterns) |
| **Scripts** | 3 | vault-tools.sh (11 commands), lib-utils.sh, lib-lint.sh |
| **Hooks** | 1 | Pre-commit enforcing 7 hard rules |
| **Wiki** | 2 | index.md (YAML frontmatter, pre-populated), log.md (append-only ops log) |
| **Memory** | 1 | status.md (operational dashboard) |
| **Docs** | 2 | Three-layer architecture, git workflow conventions |
| **Templates** | 5 | Source summary, concept, entity, comparison, decision record |
| **Config** | 2 | Staleness thresholds, idempotency marker |

```
vault/
├── raw/                    # Immutable source documents (human-owned)
├── wiki/                   # Agent-generated knowledge (sources, concepts, entities)
│   ├── index.md            # Master catalog with YAML frontmatter
│   └── log.md              # Append-only operations log
├── memory/                 # Operational state (decisions, notes, status)
├── .vault/
│   ├── rules/              # 15 hard rules + 15 soft rules + 200+ tags
│   ├── schemas/            # JSON schemas for validation
│   ├── scripts/            # vault-tools.sh (11 commands)
│   └── hooks/              # Pre-commit enforcement
├── docs/                   # Architecture + git workflow
└── templates/              # Page templates for each type
```

**Data flow:** `raw/` → `wiki/` → `memory/` (strictly unidirectional)

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        aiframework                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────┐   │
│  │  SCANNERS   │───▶│  GENERATORS  │───▶│  VALIDATORS   │   │
│  │  (9 modules)│    │  (7 modules) │    │  (4 modules)  │   │
│  └─────────────┘    └──────────────┘    └───────────────┘   │
│        │                   │                    │            │
│        ▼                   ▼                    ▼            │
│  manifest.json      19+ files +          36-check report    │
│  (100% facts)       22 vault files       (PASS/FAIL/WARN)   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Scanners (9 modules — deterministic, zero guessing)

| Scanner | What it discovers |
|---------|-------------------|
| `identity.sh` | Project name, version, description. Reads package.json, Cargo.toml, pyproject.toml, go.mod, Gemfile, Dockerfile, docker-compose |
| `stack.sh` | Language (7), framework (20+), monorepo detection (Nx/Turbo/Lerna/workspaces), multi-package (sub-package.json) |
| `commands.sh` | Package manager, install/dev/build/lint/format/typecheck/test commands, ports, lock file, GitHub URL |
| `structure.sh` | Directory tree, file counts by extension, entry points, test patterns, config files |
| `ci.sh` | CI provider (5), workflow files (triggers, jobs, secrets), deploy target (14+), coverage gaps |
| `env.sh` | Env vars from 6 priority sources: typed config → .env.example → Dockerfile → docker-compose → CI → Makefile secrets |
| `quality.sh` | Linter (6), formatter (6), type checker (5), test framework (5), existing hooks (Husky/githooks/pre-commit) |
| `domain.sh` | 10 domains (auth, DB, API, AI, sandbox, frontend, external APIs, workers, file upload, financial, compliance) + core principles + component counts |
| `user_context.sh` | 5 interactive questions: production URLs, workstream scope, credentials, team conventions, pitfalls |

### Generators (7 modules — reads manifest, writes files)

| Generator | What it produces |
|-----------|-----------------|
| `claude_md.sh` | CLAUDE.md with 25 sections: Decision Priority, Workflow Rules (10), Core Principles, Project Identity, Repository, Project Structure, Key Commands, Key Locations, CI Workflows, Architecture, API Contract Rules, 12-stage Pipeline, Skill Routing, End-of-Session Checklist, Quick Reference Matrix, Invariants, Env Vars, Deploy, GitHub Secrets, Testing, Skills, Review Specialists, Doc-Sync Matrix, Session Learnings, gstack Browser Integration, Session Start Protocol, Execution Matrices |
| `hooks.sh` | Pre-commit (type check or lint) + pre-push (lint + test + build + invariant checks with smart skip patterns) |
| `ci.sh` | GitHub Actions for TypeScript, JavaScript, Python, Rust, Go, Ruby, Bash (ShellCheck) |
| `skills.sh` | Review skill (8 domain invariant checks) + ship skill (6-step workflow) + review specialists (8 types) + learnings file |
| `docs.sh` | Diataxis docs scaffold + SETUP-DEV.md (8 steps) + CONTRIBUTING.md |
| `tracking.sh` | CHANGELOG.md + VERSION + STATUS.md |
| `vault.sh` | Full agentic memory vault: 22 files across rules, schemas, scripts, hooks, wiki, memory, docs, templates |

### Validators (4 modules — 36 checks)

| Validator | What it checks |
|-----------|---------------|
| `files.sh` | All 19+ files exist, hooks activated, CI language matches, vault dirs + files present |
| `consistency.sh` | 15 cross-checks: commands match across CLAUDE.md/hooks/skills/CI, invariant sync, port sync, env var verification, component counts, test file counts |
| `security.sh` | Secret patterns (GitHub PAT, API keys, AWS keys), .env in .gitignore |
| `quality_gate.sh` | Actual command execution (30s timeout), CLAUDE.md content quality (key locations, invariants, env vars) |

## Supported Languages

| Language | Frameworks | CI Template | Hooks |
|----------|-----------|-------------|-------|
| TypeScript | Next.js, NestJS, React, Vue, Svelte, Express, Hono | Node.js (setup-node) | tsc / eslint |
| JavaScript | Same as TypeScript | Node.js | eslint |
| Python | FastAPI, Django, Flask, Starlette | Python (setup-python) | ruff / mypy |
| Rust | Actix, Axum, Rocket, Warp | Rust (rust-toolchain) | cargo check / clippy |
| Go | Gin, Echo, Chi, Fiber | Go (setup-go) | go vet |
| Ruby | (detected via Gemfile) | Ruby (setup-ruby) | rubocop |
| Bash/Shell | (auto-detected) | ShellCheck | N/A |

## Domain Detection (10 types)

| Domain | What triggers it | Invariant generated |
|--------|-----------------|-------------------|
| Auth/AuthZ | auth*, guard*, middleware*, jwt*, oauth* files | Auth middleware on all endpoints |
| Database | migration*, schema*, model*, entity*, prisma, drizzle | No raw SQL, ORM only |
| API | controller*, route*, endpoint*, handler* files | Input validation required |
| AI/LLM | prompt*, llm*, agent*, openai, anthropic deps | LLM trust boundary enforcement |
| Sandbox | sandbox*, executor*, e2b.toml | Sandbox isolation + resource limits |
| Frontend | *.tsx, *.vue, *.svelte files | XSS prevention, accessibility |
| External APIs | provider*, client*, integration* files | API key safety, error handling |
| Workers/Jobs | worker*, job*, queue*, cron* files | Idempotency, retry logic |
| File Upload | upload*, storage*, multer*, s3* files | Upload validation, access control |
| Financial | payroll*, billing*, transaction*, payment* files | Monetary precision, atomicity |

## Playbook Coverage

Based on the [AUTOMATION-PLAYBOOK-TEMPLATE.md](AUTOMATION-PLAYBOOK-TEMPLATE.md) (2,060 lines, 115 checklist items):

| Section | Coverage |
|---------|----------|
| A. Analysis (21 items) | 100% |
| B. CLAUDE.md (34 items) | 100% |
| C. Supporting Files (24 items) | 100% |
| D. Verification (9 items) | 100% |
| E. Consistency (15 items) | 100% |
| F. Infrastructure-Agnostic (12 items) | 100% |
| **Overall** | **100%** |

## Vault — Knowledge Graph for Claude

The vault implements the [Agentic Memory Vault](https://github.com/galimba/agentic-memory-vault/) pattern, adapted for automated bootstrapping.

### Three Core Operations

| Operation | What happens |
|-----------|-------------|
| **INGEST** | Drop a file in `raw/` → agent creates wiki summary, updates index, cross-references concepts |
| **QUERY** | Agent reads index → finds relevant pages → synthesizes answer with `[[wikilink]]` citations |
| **LINT** | Automated health check: frontmatter, tags, orphans, staleness, index completeness |

### Vault Tools (11 commands)

```bash
vault/vault-tools.sh lint          # Full quality scan
vault/vault-tools.sh validate <f>  # Single-file validation
vault/vault-tools.sh orphans       # Find unlinked pages
vault/vault-tools.sh stale [days]  # Find stale content
vault/vault-tools.sh tag-audit     # Validate tags against taxonomy
vault/vault-tools.sh content-audit # Detect injection patterns
vault/vault-tools.sh status        # Operational status
vault/vault-tools.sh stats         # Page counts, tag usage
vault/vault-tools.sh index-rebuild # Regenerate wiki/index.md
vault/vault-tools.sh init-hooks    # Install pre-commit hooks
vault/vault-tools.sh doctor        # Full diagnostic
```

### Security Model

- **Three-tier permissions**: Always (lint, log, cite) / Ask first (promote, bulk changes) / Never (modify raw/, delete files)
- **Content integrity**: 8 injection detection patterns (prompt injection, command injection, data exfiltration)
- **Skill hardening**: SHA-256 manifest verification, three security tiers (strict/moderate/permissive)
- **No-deletion architecture**: Files are archived (`status: archived`), never deleted
- **Append-only logs**: Operations log cannot be rewritten

## gstack Integration

If [gstack](https://github.com/anthropics/claude-code) skills are installed (`~/.claude/skills/gstack/`), the generated CLAUDE.md includes a full browser integration section with `$B` commands for QA testing, deployment verification, and site dogfooding — ~20x faster than Playwright MCP.

## Requirements

- `bash` 4+
- `jq` (JSON processing)
- `git` (repo analysis)
- `shellcheck` (optional, for linting shell scripts)

## Project Structure

```
aiframework/
├── bin/aiframework              # CLI entry point
├── discover.sh                  # Convenience: discover a repo
├── generate.sh                  # Convenience: generate files
├── verify.sh                    # Convenience: verify files
├── run.sh                       # Convenience: full pipeline
├── lib/
│   ├── scanners/                # 9 deterministic repo scanners
│   ├── generators/              # 7 file generators
│   └── validators/              # 4 verification modules
├── templates/                   # Reserved for template overrides
└── AUTOMATION-PLAYBOOK-TEMPLATE.md  # Source playbook (reference)
```

## License

Evergon Labs. All rights reserved.
