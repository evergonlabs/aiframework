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
| `name` | Yes | Skill identifier, matches directory name (lowercase, hyphens, max 64 chars) |
| `description` | Yes | One-line summary — Claude uses this to decide when to invoke. Front-load the key use case. |
| `allowed-tools` | Yes | Tools pre-approved without per-use prompts when skill is active |
| `disable-model-invocation` | No | Set `true` to prevent Claude from auto-invoking (manual `/name` only). Use for skills with side effects (deploy, commit, send messages). |
| `context` | No | Set `fork` to run in an isolated subagent conversation. Use for research or verbose output to protect main context. |
| `model` | No | Override model for this skill execution |
| `user-invocable` | No | Set `false` to hide from `/` menu. Claude can still invoke internally. |
| `argument-hint` | No | Hint shown during autocomplete (e.g., `[issue-number]`) |

### Common Tool Sets

- **Read-only**: `[Read, Glob, Grep]` — for analysis and research skills
- **Standard**: `[Read, Write, Edit, Bash, Glob, Grep]` — for most skills
- **Web-enabled**: `[Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch]` — for research skills
- **Isolated research**: Use `context: fork` + `agent: Explore` to run in a subagent

### Important: Description Quality

The `description` field is how Claude decides whether to auto-invoke your skill. Include:
- The primary use case (what it does)
- Trigger phrases (what the user might say)
- When NOT to use it (disambiguation from similar skills)

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

## Testing Skills

Test your skill by running `/<skill-name>` in Claude Code. Check:
1. Does Claude find and invoke the skill from natural language?
2. Does each step execute correctly?
3. Are error cases handled (missing files, failed commands)?
4. Does the output match expectations?

## Skill Chaining

Skills can reference other skills in their instructions:
```
## Step 3: Review
Run `/aif-review` to check the changes before committing.
```
Claude will invoke the referenced skill as a sub-step. Use this for multi-stage workflows (e.g., build → test → review → commit).

## Tips

- Keep skills focused on one workflow — split complex workflows into multiple skills
- Use `allowed-tools` to limit scope (e.g., analysis skills don't need Write)
- Reference specific file paths so Claude Code can find them
- Include fallback behavior for when expected files don't exist
- Test by running `/<skill-name>` in Claude Code
