# LLM Agent Integration Reference

How aiframework's output is consumed by LLM coding agents (Claude Code, Cursor, Codex, etc.).

## Overview

aiframework generates structured artifacts that LLM agents read automatically. The goal: give an agent complete project context in a single scan, so it can write correct code from the first attempt.

```
aiframework run → manifest.json + code-index.json
                → CLAUDE.md (agent reads this)
                → .claude/rules/ (path-scoped, auto-loaded)
                → .claude/skills/ (slash commands)
                → vault/ (persistent knowledge)
```

## Manifest Schema (`manifest.json`)

The manifest is the intermediate representation. Generators read it to produce all output files. Agents can also read it directly for structured data.

```json
{
  "identity": {
    "name": "my-app",
    "short_name": "myapp",
    "description": "One-line project description",
    "version": "1.0.0"
  },
  "stack": {
    "language": "typescript",
    "framework": "next",
    "is_monorepo": false,
    "key_dependencies": ["prisma", "zod", "tailwindcss"],
    "languages": ["typescript", "css"]
  },
  "commands": {
    "install": "npm install",
    "dev": "npm run dev",
    "build": "npm run build",
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit",
    "test": "npm test",
    "format": "npx prettier --write .",
    "dev_port": "3000",
    "github_url": "https://github.com/org/repo",
    "local_path": "/Users/me/repo"
  },
  "ci": {
    "provider": "github-actions",
    "deploy_target": "vercel",
    "workflows": [{"file": "ci.yml", "purpose": "Lint + test + build"}]
  },
  "env": {
    "variables": [
      {"name": "DATABASE_URL", "required": true, "description": "PostgreSQL connection string"}
    ]
  },
  "domain": {
    "detected_domains": [
      {"name": "database", "display": "Database & Data Layer", "paths": ["prisma/"], "orm": "prisma"},
      {"name": "auth", "display": "Authentication", "paths": ["src/auth/"]}
    ]
  },
  "structure": {
    "directories": ["src", "prisma", "public"],
    "config_files": ["package.json", "tsconfig.json"],
    "entry_points": ["src/app/layout.tsx"],
    "key_files": ["src/lib/db.ts", "src/middleware.ts"]
  },
  "archetype": {
    "type": "web-app",
    "complexity": "complex",
    "maturity": "active"
  },
  "_meta": {
    "generated_at": "2026-04-16T00:00:00Z",
    "aiframework_version": "1.1.0"
  }
}
```

### Key Fields for Agents

| Field | Agent Use |
|-------|-----------|
| `commands.*` | Know how to lint, test, build without asking the user |
| `domain.detected_domains` | Understand which security/quality rules apply |
| `archetype.complexity` | Adjust verbosity — lean answers for simple projects, detailed for complex |
| `structure.key_files` | Prioritize reading these files for context |
| `env.variables` | Know which env vars exist without reading `.env` directly |

## CLAUDE.md Contract

CLAUDE.md is the primary interface between aiframework and the LLM agent. It follows a strict section order that agents can parse predictably.

### Section Order (full mode)

1. **Header** — project name, last updated
2. **When to Read Which Doc** — routing table for documentation
3. **Decision Priority** — conflict resolution hierarchy
4. **Workflow Rules** — 10 numbered rules (plan, verify, git safety, QA, docs, changelog)
5. **Core Principles** — project-specific coding principles
6. **Project Identity** — name, stack, deploy target
7. **Repository** — GitHub URL, local path
8. **Project Structure** — directory tree
9. **Key Commands** — install, dev, build, lint, typecheck, test
10. **CI Workflows** — workflow table
11. **Key Locations** — entry points, configs, scripts, sources, tests
12. **Module Map** — from code-index.json (modules, symbols, dependencies)
13. **Repo Map** — PageRank-ranked most important files
14. **Autonomous Pipeline** — 12-stage workflow with verification gates
15. **Skill Routing Table** — natural language → skill mapping
16. **End-of-Session Checklist** — verification checklist
17. **Invariants** — numbered rules that must never be violated
18. **Environment Variables** — table with required/description
19. **Deploy** — deployment configuration
20. **Custom Skills** — project-specific slash commands
21. **Review Specialists** — domain-specific checklists
22. **Vault** — persistent knowledge base instructions
23. **Session Learnings** — JSONL format and query instructions
24. **Session Start Protocol** — what to read at session start
25. **Execution Matrices** — step-by-step flows for bugs, features, deploys

### Lean vs Full

- **Lean** (~80-150 lines): `archetype.complexity` is `simple` or `moderate`
- **Full** (~400-600 lines): `archetype.complexity` is `complex` or `enterprise`

Lean mode omits: Execution Matrices, Module Map, Repo Map, Session Start Protocol, gstack integration.

### Invariants

Invariants are the highest-priority rules. They are:
- Numbered (`INV-1`, `INV-2`, ...)
- Generated from detected domains (database → "ORM only", auth → "guards on endpoints")
- Enforced by the review skill and pre-push hook
- Never overridden except by explicit user instruction

## Skill Authoring for Agents

Skills are markdown files that define structured workflows. An agent reads the skill and executes each step.

### File Location

```
.claude/skills/<name>/SKILL.md
```

### Frontmatter

```yaml
---
name: skill-name
description: One-line description (agent uses this to decide when to invoke)
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier, matches directory name |
| `description` | Yes | One-line summary — agent uses this to decide when to invoke |
| `allowed-tools` | Yes | Tools pre-approved without per-use prompts |
| `disable-model-invocation` | No | Prevent auto-invocation (use for side-effect skills) |
| `context` | No | Set to `fork` for isolated subagent execution |
| `model` | No | Override model for this skill |

### Step Structure

Each `## Step N: Title` section should contain:
1. What to read or check
2. What action to take
3. What output to produce
4. How to verify success

### Tool Restrictions

`allowed-tools` limits which tools the agent can use during skill execution:
- **Read-only skills** (analysis, research): `[Read, Glob, Grep, WebSearch, WebFetch]`
- **Standard skills** (code changes): `[Read, Write, Edit, Bash, Glob, Grep]`
- **Restricted skills** (sensitive operations): `[Read, Bash]`

## Vault Protocol

The vault is a three-layer knowledge base that persists across agent sessions.

### Layers

| Layer | Path | Owner | Mutability |
|-------|------|-------|------------|
| Raw | `vault/raw/` | Human | Immutable (HR-001) |
| Wiki | `vault/wiki/` | Agent | Append-mostly (HR-014) |
| Memory | `vault/memory/` | Agent | Read-write |

### Data Flow

```
raw/ → wiki/ → memory/   (strictly unidirectional, never reverse)
```

### Agent Session Protocol

1. **Session start**: Read `vault/memory/status.md` for ongoing work context
2. **During work**: Save insights to `vault/memory/notes/`
3. **Significant decisions**: Log to `vault/memory/decisions/` (ADR format)
4. **Session end**: Update `vault/memory/status.md` with progress
5. **New knowledge**: Create wiki pages in `vault/wiki/concepts/` or `vault/wiki/entities/`

### Integrity Rules

| Rule | Enforcement | Description |
|------|-------------|-------------|
| HR-001 | pre-commit | `raw/` is immutable — no staged changes allowed |
| HR-002 | pre-commit | All wiki/memory `.md` files must have YAML frontmatter |
| HR-003 | pre-commit | Tags must be from approved taxonomy |
| HR-007 | vault-lint | Frontmatter `updated` date must be within 30 days of git date |
| HR-008 | pre-commit | New wiki files must be registered in index |
| HR-009 | vault-lint | Tags must use `prefix/value` format |
| HR-011 | pre-commit | `.vault/` infrastructure is protected |
| HR-012 | pre-commit | Agent config changes require human review |
| HR-013 | vault-lint | CI/template changes require review |
| HR-014 | pre-commit | No file deletions — use `status: archived` instead |
| HR-015 | vault-lint | `log.md` is append-only — line count must not decrease |

### Frontmatter Schema

Every wiki/memory page must start with:

```yaml
---
title: Page Title
type: concept | entity | comparison | decision | note | status
created: 2026-04-16
updated: 2026-04-16
status: active | draft | archived
tags:
  - domain/ai
  - type/concept
---
```

## Learnings System

Learnings are append-only JSONL files that accumulate project knowledge.

### Format

```jsonl
{"date":"2026-04-16","category":"bug","summary":"One-line","detail":"Full explanation","files":["path/to/file"]}
```

### Categories

- `bug` — a bug that was fixed (capture the root cause)
- `gotcha` — a non-obvious behavior or pitfall
- `pattern` — a useful pattern discovered
- `decision` — an architectural decision made

### Integration

- `/aif-learn` appends to `tools/learnings/<project>-learnings.jsonl`
- `/aif-feedback` appends to `tools/learnings/feedback.jsonl`
- `/aif-evolve` reads both files to propose CLAUDE.md improvements
- Learnings are read at session start (Session Start Protocol, step 3)

## Code Index (`code-index.json`)

See [`code-indexer.md`](code-indexer.md) for the full schema. Key fields for agents:

| Field | Agent Use |
|-------|-----------|
| `modules` | Understand codebase organization |
| `symbols` | Find function/class definitions without grep |
| `edges` | Understand import graph and dependencies |
| `_meta.top_files` | Know which files are architecturally important |
| `_meta.circular_deps` | Avoid introducing more circular dependencies |

## Cross-Tool Compatibility

aiframework's output works with any agent that reads markdown files:

| Agent | Reads | Auto-loaded |
|-------|-------|-------------|
| Claude Code | CLAUDE.md, .claude/rules/, .claude/skills/ | Yes |
| Cursor | CLAUDE.md (as project instructions) | Manual |
| Codex | CLAUDE.md (via system prompt) | Manual |
| Custom agents | manifest.json, code-index.json | Via API |

For non-Claude-Code agents, the manifest and code index are the most useful artifacts — they provide structured data without needing markdown parsing.
