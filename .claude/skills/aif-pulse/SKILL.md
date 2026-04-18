---
name: aif-pulse
description: Check for latest Claude Code features, best practices, and ecosystem updates. Researches official docs, discovers new capabilities, and suggests project improvements. Run periodically to keep your AI development setup cutting-edge.
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, WebSearch, WebFetch, Agent, AskUserQuestion]
---

# AI Development Pulse

**Telemetry (run first, silent):**

```bash
aiframework-telemetry skill_invoked skill=aif-pulse 2>/dev/null || true
```

Stay current with Claude Code features, best practices, and the AI-assisted development ecosystem. Discovers what's new and applies relevant improvements to your project.

## When to Use

- Weekly or after major Claude Code releases
- When you suspect there are new features you're not using
- When you want to optimize your AI development workflow
- After reading about a new Claude Code capability

## Process

### Step 1: Research Latest Updates

Search for the latest Claude Code documentation and features:

```
WebSearch: "Claude Code new features 2026"
WebSearch: "Claude Code changelog latest release"
WebSearch: "Claude Code best practices update"
WebSearch: "claude code skills hooks agents new"
```

Also check official sources:
- `WebFetch: https://code.claude.com/docs/en/changelog` (if available)
- `WebFetch: https://docs.anthropic.com/en/docs/claude-code/overview`

### Step 2: Audit Current Project Setup

Read the project's current configuration:

1. `CLAUDE.md` — how many lines? Is it lean or bloated?
2. `.claude/rules/` — what rules exist? Are they path-scoped?
3. `.claude/skills/` — what skills exist? Are they well-structured?
4. `.claude/settings.json` — what permissions/hooks are configured?
5. `.claude/agents/` — any custom subagents?
6. `AGENTS.md` — cross-tool compatibility?
7. `.mcp.json` — any MCP servers configured?
8. Check git hooks: `.githooks/` or `.husky/`

### Step 3: Gap Analysis

Compare current setup against latest best practices:

**CLAUDE.md Health Check:**
- Is it under 200 lines? (Official recommendation)
- Does it contain ONLY what Claude can't figure out from code?
- Are there rules that belong in `.claude/rules/` instead?
- Are there workflows that belong in `.claude/skills/` instead?
- Is there a Self-Evolution section?

**Rules Check:**
- Are rules using `paths:` frontmatter for file-scoped loading?
- Are rules specific enough? (not just generic "write clean code")
- Are there domains detected in the manifest that don't have rules?

**Skills Check:**
- Is there a review skill? Ship skill? Learn skill?
- Are skills using `allowed-tools` to scope permissions?
- Are skills using `disable-model-invocation` for side-effect workflows?
- Could any repeated prompts become skills?

**Settings Check:**
- Are safe tools pre-approved? (Read, Glob, Grep, WebSearch)
- Are there hooks for auto-formatting after edits?
- Are dangerous commands blocked? (rm -rf, DROP TABLE)

**Advanced Features Check:**
- Custom subagents in `.claude/agents/`?
- MCP servers for external tool integration?
- `CLAUDE.local.md` for personal overrides?
- Prompt caching optimization?

### Step 4: Discover New Capabilities

Search for features the project might benefit from:

```
WebSearch: "Claude Code hooks PostToolUse auto format"
WebSearch: "Claude Code custom subagents .claude/agents"
WebSearch: "Claude Code MCP servers useful"
WebSearch: "Claude Code skills examples advanced"
WebSearch: "Claude Code context window optimization"
```

Look specifically for:
- **New tool types** — has Claude Code added new built-in tools?
- **New hook events** — FileChanged, CwdChanged, PreCompact, PostCompact?
- **New skill features** — context: fork, agent: Explore, model overrides?
- **New settings** — auto-memory, env injection, model selection?
- **Community patterns** — what are top projects doing with .claude/?

### Step 5: Generate Recommendations

For each finding, create a recommendation:

```
## Recommendations

### 1. [Feature Name]
- **What**: Brief description of the feature/practice
- **Why**: How it helps this specific project
- **How**: Exact steps or code to implement
- **Impact**: High/Medium/Low

### 2. ...
```

Categories:
- **Quick Wins** — can be applied in <5 minutes
- **Medium Effort** — needs 15-30 minutes of setup
- **Strategic** — requires planning, significant benefit

### Step 6: Apply Quick Wins

For recommendations marked as Quick Wins, ask the user:

"I found N improvements. M are quick wins I can apply now. Should I apply them?"

If approved, apply each one:
- Update `.claude/settings.json` with new hooks/permissions
- Add missing `.claude/rules/` files
- Update CLAUDE.md if it's bloated
- Create new skills for repeated workflows
- Add `.claude/agents/` for specialized tasks

### Step 7: Log and Track

1. Record findings to the learnings file:
```bash
echo '{"date":"'$(date +%Y-%m-%d)'","category":"pattern","summary":"AI Pulse findings","detail":"Found N improvements, applied M quick wins","files":["CLAUDE.md",".claude/"]}' >> tools/learnings/*-learnings.jsonl
```

2. Update vault status:
```
| {date} | pulse | AI Pulse: found N improvements, applied M |
```
Append to `vault/wiki/log.md`

3. Update `vault/memory/status.md` with pulse date

## What to Look For (Reference)

### Claude Code Features Checklist

| Feature | Check | Since |
|---------|-------|-------|
| CLAUDE.md | ✓ Must exist | v1.0 |
| .claude/rules/ (path-scoped) | Check for paths: frontmatter | 2025 |
| .claude/skills/ | Check for SKILL.md files | 2025 |
| .claude/settings.json | Check permissions + hooks | 2025 |
| .claude/agents/ | Check for custom subagents | 2026 |
| AGENTS.md | Check for cross-tool config | 2025 |
| .mcp.json | Check for MCP servers | 2025 |
| CLAUDE.local.md | Check for personal overrides | 2025 |
| Auto memory (MEMORY.md) | Check ~/.claude/projects/ | 2025 |
| Hooks (PostToolUse) | Check settings.json hooks | 2025 |
| Prompt caching | Automatic, check usage | 2025 |
| Worktree isolation | Check skill context: fork | 2026 |
| Model routing per skill | Check skill model: field | 2026 |

### AI Development Patterns

| Pattern | Description |
|---------|-------------|
| **Lean CLAUDE.md** | Under 200 lines, high-signal only |
| **Progressive Disclosure** | Rules load by path, skills load on demand |
| **Deterministic over Advisory** | Hooks > CLAUDE.md for enforcement |
| **Skills as Playbooks** | Capture repeated prompts as skills |
| **Subagents for Isolation** | Heavy research in separate context |
| **MCP for External** | Database, API, browser via MCP servers |
| **Auto-format Hooks** | PostToolUse hook runs prettier/ruff after edits |
| **Memory Separation** | CLAUDE.md = team rules, MEMORY.md = personal patterns |
