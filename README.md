# aiframework

One command. Any repo. Fully configured for AI-assisted development with Claude Code.

## What It Does

aiframework scans your repo, indexes every symbol, and generates a complete Claude Code configuration:
- **CLAUDE.md** -- project instructions Claude reads every session (~80-150 lines, lean and high-signal)
- **`.claude/rules/`** -- path-scoped rules loaded automatically when Claude reads matching files
- **`.claude/settings.json`** -- permissions and tool configuration
- **`.claude/skills/`** -- slash commands for review, ship, learn workflows
- **`AGENTS.md`** -- cross-tool agent configuration
- **`vault/`** -- persistent knowledge base (wiki, memory, learnings)
- **`.githooks/`** -- pre-commit and pre-push quality gates
- **`.github/workflows/`** -- CI pipeline for your language

## Quick Start

```bash
# Install
git clone https://github.com/evergonlabs/aiframework.git
cd aiframework && make install

# Run on your project
aiframework run --target /path/to/your-project

# Open in Claude Code
cd /path/to/your-project && claude
```

That's it. Claude Code now reads your generated CLAUDE.md and has full project context.

## Requirements

- `bash` 3.2+ (4+ recommended)
- `jq` -- `brew install jq` / `apt install jq`
- `git`
- `python3` 3.10+ (for code indexer; bash fallback if unavailable)

## After Generation: Your Workflow

### Day 1 (one-time setup, 5 minutes)

| Step | Command | What happens |
|------|---------|-------------|
| 1 | `aiframework run --target .` | Scans repo, generates all config files |
| 2 | Open in Claude Code | Claude reads CLAUDE.md automatically |
| 3 | `/aif-enhance` | (Optional) Research gaps, add framework conventions |
| 4 | Edit CLAUDE.md | Add project-specific env vars, gotchas |

### Daily Development

| What you're doing | Skill to run |
|-------------------|-------------|
| Ready to merge | `/aif-review` -- code review with invariant checks |
| Ready to ship | `/aif-ship` -- lint -> review -> docs -> changelog -> commit |
| Found a gotcha | `/aif-learn "description"` -- captures to persistent storage |
| Need framework docs | `/aif-research` -- searches official documentation |
| Want code analysis | `/aif-analyze` -- finds missing tests, circular deps |
| Adding reference docs | `/aif-ingest` -- deposits into vault knowledge base |

### Weekly Maintenance

| What | Skill | What happens |
|------|-------|-------------|
| Evolve your rules | `/aif-evolve` | Reads native Claude Code session data + learnings, proposes CLAUDE.md improvements |
| Check for new features | `/aif-pulse` | Researches latest Claude Code capabilities, suggests project improvements |
| Refresh after changes | `aiframework refresh` | Detects drift in package.json/deps, re-generates if needed |

## What Gets Generated

### Files (23+)

| File | Purpose | Auto-loaded by Claude? |
|------|---------|----------------------|
| `CLAUDE.md` | Project instructions (commands, invariants, architecture) | Yes -- every session |
| `AGENTS.md` | Cross-tool agent config | Yes -- if present |
| `.claude/rules/workflow.md` | Development process rules | Yes -- always |
| `.claude/rules/testing.md` | Testing conventions | Yes -- when editing test files |
| `.claude/rules/security.md` | Security rules | Yes -- when editing auth/api files |
| `.claude/settings.json` | Permissions (safe defaults) | Yes -- enforced |
| `.claude/skills/<name>-review/` | Code review with invariant checks | On `/name-review` |
| `.claude/skills/<name>-ship/` | Shipping workflow | On `/name-ship` |
| `.claude/skills/<name>-learn/` | Capture learnings | On `/name-learn` |
| `.githooks/pre-commit` | Lint on commit | Auto -- git hook |
| `.githooks/pre-push` | Full quality gate on push | Auto -- git hook |
| `.github/workflows/ci.yml` | CI pipeline | Auto -- on push/PR |
| `vault/` | Knowledge base (31 files) | Referenced in CLAUDE.md |
| `tools/learnings/` | JSONL learnings file | Read by `/aif-evolve` |
| `docs/` | Documentation scaffold | Reference |
| `CHANGELOG.md` | Release notes | Reference |
| `VERSION` | Semantic version | Reference |

### The Generated `.claude/` Directory

```
.claude/
├── rules/
│   ├── workflow.md    # Always loaded — dev process, git safety, verification
│   ├── testing.md     # Loaded for **/*.test.*, **/tests/** — test conventions
│   └── security.md    # Loaded for **/auth/**, **/api/** — security rules
├── settings.json      # Pre-approves: Read, Glob, Grep, WebSearch
└── skills/
    ├── <name>-review/ # /name-review → invariant checks
    ├── <name>-ship/   # /name-ship → lint → review → commit
    └── <name>-learn/  # /name-learn → persist learnings
```

## Skills Reference (10 total)

| Skill | When to use | What it does |
|-------|------------|-------------|
| `/aif-enhance` | After first scan | Research gaps, find framework conventions, analyze code, enrich vault |
| `/aif-research` | Unknown framework patterns | Search official docs for conventions and invariants |
| `/aif-analyze` | Code quality check | Read code-index.json for missing tests, circular deps, god modules |
| `/aif-evolve` | Weekly | Analyze native Claude Code session data + learnings, propose CLAUDE.md updates |
| `/aif-pulse` | Weekly | Research latest Claude Code features, suggest project improvements |
| `/aif-feedback` | After runs | Collect structured user feedback (5 questions) for `/aif-evolve` |
| `/aif-review` | Before merging | Code review against project invariants |
| `/aif-ship` | Ready to push | Full pipeline: lint -> review -> docs -> changelog -> commit |
| `/aif-learn` | After discoveries | Capture gotcha/pattern to persistent JSONL storage |
| `/aif-ingest` | New reference docs | Deposit document into vault knowledge base |

## How It Works

```
aiframework run --target /path/to/repo
  │
  ├── DISCOVER (11 scanners)
  │   ├── identity, stack, commands, structure
  │   ├── ci, env, quality, domain, user_context
  │   ├── code_index (13 languages, symbols, imports, edges)
  │   └── archetype (library/web-app/api/monorepo/...)
  │   → manifest.json + code-index.json
  │
  ├── GENERATE (8 generators)
  │   ├── CLAUDE.md (lean ~80-150 lines)
  │   ├── .claude/rules/ (path-scoped)
  │   ├── .claude/settings.json + skills/
  │   ├── AGENTS.md, hooks, CI, docs, tracking
  │   └── vault/ (31 files, auto-ingest)
  │   → 23+ files
  │
  └── VERIFY (5 validators, 36+ checks)
      ├── files, consistency, security, quality_gate
      ├── freshness (manifest age, file drift, index staleness)
      └── → PASS / FAIL / WARN report
```

## Supported Languages

| Language | Indexer | Frameworks Detected |
|----------|---------|-------------------|
| TypeScript/JavaScript | Functions, classes, types, imports | Next.js, NestJS, React, Vue, Express, Hono, Svelte |
| Python | Functions, classes, methods, imports | FastAPI, Django, Flask, Starlette |
| Go | Functions, types, imports | Gin, Echo, Chi, Fiber |
| Rust | Functions, structs, enums, imports | Actix, Axum, Rocket, Warp |
| Ruby | Methods, classes, modules | Rails, Sinatra |
| Java | Classes, methods, interfaces | Spring Boot, Quarkus |
| C#, PHP, Kotlin, Swift, Elixir | Full symbol extraction | Major frameworks |
| + 20 languages in registry | Detection via marker files | Extensible via JSON |

## Domain Detection (18 types)

Auth, Database, API, AI/LLM, Frontend, Workers, File Upload, Financial, GraphQL, Messaging, Caching, Search, Observability, Realtime, Email, Storage, Sandbox, External APIs

Each detected domain adds invariants and security rules to CLAUDE.md.

## Archetype Detection (11 types)

library, cli-tool, web-app, api-service, full-stack, monorepo, data-pipeline, ml-project, mobile-app, infrastructure, documentation-site

Archetype controls CLAUDE.md depth (lean for simple projects, full for complex).

## Self-Evolution

aiframework-generated projects improve over time:

1. **Drift detection**: `aiframework refresh` checks if package.json/deps changed and re-generates
2. **Learning capture**: `/aif-learn` persists gotchas to JSONL
3. **Feedback loop**: `/aif-feedback` collects structured user feedback (quality, accuracy, missing context)
4. **Rule evolution**: `/aif-evolve` reads native Claude Code insights + learnings + feedback, proposes CLAUDE.md updates
5. **Ecosystem pulse**: `/aif-pulse` researches latest Claude Code features and suggests adoption
6. **Pre-push warning**: Git hook warns if manifest is stale

## CLI Reference

```
aiframework <command> [options]

Commands:
  run         Full pipeline: discover → generate → verify → report
  discover    Scan repo → manifest.json + code-index.json
  generate    Read manifest → generate all files
  verify      Validate generated files (36 checks + freshness)
  report      Generate human-readable report of everything detected/generated
  refresh     Lightweight: re-discover + generate only if drift detected
  index       Build code index only
  stats       Show cross-repo learning patterns

Options:
  --target <path>      Target repo (default: current directory)
  --non-interactive    Skip user context questions
  --no-index           Skip code indexing
  --dry-run            Preview without writing
  --verbose            Detailed output
```

## Data-Driven and Extensible

All detection logic reads from JSON registries. Add a language, domain, or archetype by editing a file:

| Registry | Entries | Location |
|----------|---------|----------|
| Languages | 20 | `lib/data/languages.json` |
| Domains | 18 | `lib/data/domains.json` |
| Deploy targets | 24 | `lib/data/deploy_targets.json` |
| Archetypes | 11 | `lib/data/archetypes.json` |

## Project Structure

```
aiframework/
├── bin/aiframework           # CLI entry point
├── lib/
│   ├── scanners/             # 11 deterministic scanners
│   ├── indexers/             # Code indexer (Python, 13 languages)
│   ├── generators/           # 8 file generators
│   ├── validators/           # 5 verification modules + freshness
│   ├── freshness/            # Drift detection
│   ├── knowledge/            # Cross-repo learning store
│   └── data/                 # JSON registries (languages, domains, etc.)
├── .claude/skills/           # 10 aif-* skills
├── tests/                    # Unit + integration tests
├── docs/                     # Onboarding, guides, reference, architecture
├── vault/                    # Knowledge vault (rules, wiki, memory)
└── Makefile                  # install, uninstall, lint, test, check
```

## License

Evergon Labs. All rights reserved.
