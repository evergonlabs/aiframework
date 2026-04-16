# Changelog

All notable changes to aiframework are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [1.1.0] — 2026-04-16
### Added
- **Preserve existing files** — generators now detect and preserve existing CLAUDE.md, CHANGELOG.md, VERSION, STATUS.md, SETUP-DEV.md, CONTRIBUTING.md, docs/README.md, CI workflows, and git hooks. User content is never silently overwritten. Backups saved to `.aiframework/backups/`
- **CLAUDE.md merge** — when an existing CLAUDE.md is found, user-added custom sections are extracted, backed up, and re-appended after regeneration
- **AGENTS.md rewritten** — follows the open standard (Linux Foundation spec): 6 core sections (Commands, Testing, Code Style, Git Workflow, Boundaries), <60 lines, tool-agnostic, read by Claude Code + Cursor + Codex + Copilot
- **Skill suggestion scanner (12th scanner)** — detects 11 patterns (deploy scripts, migrations, Docker, OpenAPI, Storybook, Terraform, monorepo, E2E tests, doc sites, benchmarks, seed data) and suggests custom skills in the report. Suggestions only — never auto-creates without user approval
- **`aiframework report` command** — generates a 13-section human-readable report (`.aiframework/report.md`) so devs can verify detection accuracy and give feedback
- **Report auto-runs after `aiframework run`** — pipeline is now discover → generate → verify → report
- **LLM agent integration reference** — `docs/reference/llm-agent-integration.md` covering manifest schema, CLAUDE.md contract, skill authoring, vault protocol
- **Dependency check** — `check_dependencies()` validates `jq` and `git` at startup with platform-specific install instructions
- **Cleanup trap** — `trap cleanup EXIT` removes temp directories on exit
- **Extended secret detection** — 12 new patterns: Stripe, Slack, SendGrid, private keys, DB connection strings, GCP, Azure
- **`lib/validators/freshness.sh`** — new freshness validator module for drift detection during verify phase
- **4 vault lint functions** — HR-007 (updated date accuracy), HR-009 (flat tag format), HR-013 (CI/template protection), HR-015 (append-only logs)
- **`/aif-feedback` skill** — 5-question structured feedback collection saving to `feedback.jsonl`
- **Learnings seeded** — 8 audit-derived learnings in `aiframework-learnings.jsonl`
- **macOS CI matrix** — lint and integration jobs run on both ubuntu-latest and macos-latest
- **Validator test suite** — `tests/test_validators.sh` with 9 test cases across all 5 validators
- **3 new guides** — Adding a Domain, Creating Custom Skills, Prompting Effectively
- **6 routing table entries** — refactor, docs, performance, CI/tests, recent work, feedback

### Fixed
- **CI action pinned** — `ludeeus/action-shellcheck@master` → `@2.0.0` (supply chain safety)
- **Python version** — docs corrected from 3.9+ to 3.10+ (match/case syntax requires 3.10)
- **Pre-commit escaping** — HR-013 section had escaped `\$ci_changes` preventing variable expansion

### Changed
- **`/aif-evolve` fallback** — gracefully handles missing `~/.claude/usage-data/` directory (learnings-only mode)
- **`generate_claude_md_full()` refactored** — decomposed 1562-line function into 10 `_emit_*` sub-functions

### Removed
- **`AUTOMATION-PLAYBOOK-TEMPLATE.md`** — obsolete 2060-line manual playbook replaced by `aiframework run`

## [1.0.0] — 2026-04-16
### Added
- **Skill-based enhancement** — `/aif-enhance`, `/aif-research`, `/aif-analyze`, `/aif-ingest` replace Agent SDK entirely. Zero API key, zero Python SDK dependency.
- **`.claude/settings.json` generation** — safe default permissions for Claude Code projects
- **Path-scoped rules** — auto-generated `testing.md` and `security.md` in `.claude/rules/` based on detected domains
- **Freshness system** — `aiframework refresh` detects drift in key files and re-generates; pre-push hook warns on staleness
- **Freshness validator** — `aiframework verify` checks manifest age, file drift, code index freshness, CLAUDE.md identity
- **Cross-repo learning** — `~/.aiframework/knowledge/` accumulates repo profiles; `aiframework stats` shows patterns
- **Smart CLAUDE.md** — lean mode (~80 lines) for simple projects, full mode for complex; self-evolution guidance included
- **Repo archetype detection** — library, cli-tool, web-app, api-service, full-stack, monorepo, data-pipeline, ml-project, mobile-app, infrastructure, docs-site
- **Code indexer** — 13 language parsers, PageRank file importance, dependency graph
- **Data-driven registries** — 20 languages, 18 domains, 24 deploy targets, 11 archetypes (extensible via JSON)
- **Test suite** — 21 unit + 14 integration = 35 tests
- **CI pipeline** — GitHub Actions with lint, python, integration, JSON validation jobs
- **Documentation** — Getting Started, Adding a Scanner, Architecture explanation, Code Indexer reference

### Removed
- **Agent SDK dependency** — `lib/enhancers/` deleted (10 files, 1300 lines). All functionality moved to Claude Code skills.
- **ANTHROPIC_API_KEY requirement** — enhance is now free via `/aif-enhance` skill
- **`--no-enhance` / `--budget` flags** — no longer needed
- **`enhance` CLI command** — replaced by `/aif-enhance` skill in Claude Code

### Fixed
- Bash 3.2 compatibility — works on default macOS bash (warning for 4+ recommendation)
- Vault concept pages have proper tags (HR-002 compliance)
- Vault lib-lint.sh uses bash 3.2-compatible syntax (no associative arrays)
- Awk multiline insertion bug in vault tech-stack update
- Pipefail-safe grep patterns across all scanners
- TypeScript `export default function` now detected by indexer

## [0.4.0] — 2026-04-15
### Added
- **Data-driven registries**: `lib/data/languages.json` (20 languages), `domains.json` (18 domains), `deploy_targets.json` (24 targets), `archetypes.json` (11 archetypes) — extensible without code changes
- **6 new indexer parsers**: Java, C#, PHP, Kotlin, Swift, Elixir — total 13 languages with symbol extraction
- **Repo archetype detection**: classifies repos as library, cli-tool, web-app, api-service, full-stack, monorepo, data-pipeline, ml-project, mobile-app, infrastructure, or documentation-site
- **Maturity detection**: greenfield, active, mature, established — from git history and quality tool presence
- **Complexity scoring**: simple (<20 files), moderate, complex, enterprise (500+)
- **Cross-repo learning system**: `~/.aiframework/knowledge/` accumulates patterns, scanner misses, repo profiles across all analyzed repos
- **`aiframework stats` command**: shows aggregated analysis across all repos you've ever scanned
- **Test suite**: 9 unit tests for indexer (parsers, graph, schema) via Python unittest
- **CI pipeline**: GitHub Actions with 4 jobs — lint, python, integration, JSON validation
- **Makefile**: `make install`, `make test`, `make lint`, `make check` targets
- **8 new domains**: GraphQL, messaging/queues, caching, search, observability, realtime, email, storage
- **Documentation**: Getting Started tutorial, Adding a Scanner guide, Architecture explanation

### Changed
- **Removed Agent SDK dependency** — enhance is now a Claude Code skill (`/aif-enhance`), no API key or Python SDK needed
- Deleted `lib/enhancers/` (10 files) — replaced by `.claude/skills/aif-enhance/`
- Discovery pipeline now 11 steps (was 10) — archetype detection is step 11
- Code indexer supports 13 languages (was 7)
- `bin/aiframework` reads version from VERSION file instead of hardcoded "1.0.0"
- Stack scanner detects ALL languages in polyglot repos (manifest now has `stack.languages` array)
- All 5 scanners are data-driven with JSON registry fallback to hardcoded logic
- Archetype never returns "unknown" — fallback to "minimal" or "application"
- Test suite expanded to 21 tests (was 9) — covers all 13 language parsers + edge cases
- **PageRank file importance** — files ranked by how many other files depend on them (`_meta.top_files`)
- **Repo Map section** in CLAUDE.md — top 15 most architecturally important files
- **Adaptive CLAUDE.md depth** — simple projects get lean output (~150 lines), complex get full (~500 lines)
- **Vault auto-ingest** — key project docs (README, CONTRIBUTING, manifest) auto-deposited into `raw/` with source summaries
- **`/aif-ingest` skill** — manual document ingestion into the vault knowledge base
- **Vault auto-population pipeline fixed** — `populate_vault_from_index()` now correctly finds code-index.json
- **Smart CLAUDE.md generator** — lean mode (80-150 lines) for simple/moderate projects, full mode for complex/enterprise; workflow rules auto-generated to `.claude/rules/workflow.md`
- **Integration tests** — 14 end-to-end assertions across 4 repo types (Next.js, Python, minimal, monorepo)
- **Shellcheck clean** — 0 errors across all scanner files; SC2155/SC2034 warnings fixed
- **Performance** — domain/deploy detection optimized from ~50 jq calls to ~3; pipefail-safe grep patterns
- **Self-evolution** — CLAUDE.md includes "When to Update This File" guidance; content migrates to rules/skills over time

### Fixed
- Agent SDK: removed non-existent `max_budget_usd` parameter
- Agent SDK: hook event `"PreToolUse"` (was lowercase `"pre_tool_use"`)
- Agent SDK: system prompt via `ClaudeAgentOptions.system_prompt` (was concatenated into user prompt)
- Agent SDK: hook returns `systemMessage` (was `reason`)
- Agent SDK: added `disallowed_tools=["Bash"]` for explicit blocking
- Agent SDK: `asyncio.run()` fallback for nested event loops

## [0.3.0] — 2026-04-15
### Added
- **Code Indexer**: deterministic repo structure analysis — files, symbols, imports, edges, modules
  - 7 language parsers: Bash, Python, TypeScript, JavaScript, Go, Rust, Ruby
  - Dependency graph with fan-in/fan-out, circular dependency detection, module grouping
  - `aiframework index` standalone command and `--no-index` flag
  - Parallel parsing via ThreadPoolExecutor (indexes medium repos in <50ms)
- **Vault auto-population from code index**: module entity pages, architecture concept page, API reference pages, enhanced tech-stack
- **CLAUDE.md Module Map**: structured module table with roles, key symbols, and dependencies
- **Architecture Hot Spots**: highest fan-in and most complex modules surfaced in CLAUDE.md

### Fixed
- **Critical SDK API bug**: `enhance.py` now uses correct `query()` + `ClaudeAgentOptions` API instead of non-existent `sdk.run()`
- **SDK hook signature**: uses `HookMatcher` with proper async hook callbacks
- **Per-model budget tracking**: `BudgetTracker` now tracks costs per model using `MODEL_PRICING`
- **Security fail-closed**: invalid regex patterns in injection scanner now block content instead of silently skipping
- **JSON extraction**: `_extract_json` handles arrays and catches `IndexError`

### Changed
- Discovery pipeline now 10 steps (was 9) — code index is step 10
- `claude-agent-sdk` requirement bumped to `>=0.1.59`
- Code analyzer agent reads code-index.json as primary data source
- New gap types: `gap-no-tests`, `gap-circular-deps`, `gap-orphan-files`, `gap-god-modules`

## [0.2.0] — 2026-04-15
### Added
- `enhance` command: Agent SDK-powered manifest enrichment (optional, BYOK)
- Gap analysis: identifies missing invariants, unknown infra, low component counts
- Research agent: investigates unknown deploy targets via domain-whitelisted web search
- Framework agent: fetches best practices from official framework docs
- Code analysis agent: semantic route/model/service detection beyond heuristics
- Vault enrichment agent: persists findings as wiki concept pages
- Security layer: domain whitelist (40+ sites), injection scanning, tool restrictions
- Budget tracking with configurable cap (default 50c, `--budget` flag)
- `--no-enhance` flag to skip enhance and keep pipeline fully free/deterministic
- Enhanced invariants injected into CLAUDE.md from `_enhance` manifest key
- Enhancement summary section in generated CLAUDE.md

## [0.1.0] — 2026-04-15
### Added
- Initial project setup
- Automation pipeline (12 stages) via aiframework
- CLAUDE.md for Claude Code integration (25 sections)
- Git hooks (pre-commit + pre-push quality gates with invariant checks)
- Custom Claude Code skills (/aif-review, /aif-ship)
- Documentation scaffold (Diataxis structure)
- CI workflow for quality gates
- Agentic memory vault (22 files)
