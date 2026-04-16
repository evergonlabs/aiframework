# Creating Custom Skills

How to create Claude Code skills for your project.

## What is a Skill?

A skill is a markdown file at `.claude/skills/<name>/SKILL.md` that defines a structured workflow Claude Code can execute. Users invoke skills with `/<name>` slash commands.

## SKILL.md Format

```markdown
---
name: my-skill
description: One-line description shown in skill listings
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
---

# Skill Title

Brief description of what this skill does and when to use it.

## When to Use

- Trigger condition 1
- Trigger condition 2

## Step 1: Name

Instructions for this step. Use fenced code blocks for commands:

\```bash
command-to-run
\```

## Step 2: Name

More instructions. Reference project files:
- Read `path/to/file` for context
- Edit `path/to/other-file` with the changes

## Step 3: Output

What the skill produces and where it saves results.
```

## Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier, matches directory name |
| `description` | Yes | One-line summary for Claude Code to decide when to use |
| `allowed-tools` | Yes | Array of tools the skill can use |

### Common Tool Sets

- **Read-only**: `[Read, Glob, Grep]` — for analysis and research skills
- **Standard**: `[Read, Write, Edit, Bash, Glob, Grep]` — for most skills
- **Web-enabled**: `[Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch]` — for research skills

## Step Structure

Each step should:
1. Have a clear action verb in the name
2. Include the exact command or operation
3. Specify what to check before proceeding
4. Define success criteria

## Examples from aiframework

| Skill | Purpose | Key Pattern |
|-------|---------|------------|
| `/aif-review` | Code review with invariant checks | Reads manifest, checks all invariants |
| `/aif-ship` | Shipping workflow | Multi-step pipeline: lint → test → review → commit |
| `/aif-learn` | Capture learnings | Appends to JSONL, optionally writes vault note |
| `/aif-evolve` | Self-improvement | Reads data sources, generates report, applies with approval |
| `/aif-feedback` | Collect feedback | Asks questions, saves to feedback.jsonl |

## Tips

- Keep skills focused on one workflow — split complex workflows into multiple skills
- Use `allowed-tools` to limit scope (e.g., analysis skills don't need Write)
- Reference specific file paths so Claude Code can find them
- Include fallback behavior for when expected files don't exist
- Test by running `/<skill-name>` in Claude Code
