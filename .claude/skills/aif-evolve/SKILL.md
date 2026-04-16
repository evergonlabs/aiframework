---
name: aif-evolve
description: Analyze Claude Code native insights + project learnings to evolve CLAUDE.md, rules, and skills. Reads session data (friction, goals, tool usage, satisfaction) and learnings JSONL to propose targeted improvements. Run periodically.
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# Project Evolution

Analyze real usage data to continuously improve your Claude Code configuration.
Reads TWO data sources: Claude Code native insights + project learnings.

## When to Use

Run periodically (weekly or after major milestones) to:
- Learn from actual session friction and outcomes
- Promote repeated corrections into permanent rules
- Identify tool usage patterns and optimize workflows
- Keep CLAUDE.md lean and high-signal

## Step 1: Load Native Claude Code Insights

Read session data from Claude Code's usage analytics:

```bash
# Session metadata — duration, tools, tokens, friction, satisfaction
ls ~/.claude/usage-data/session-meta/*.json | wc -l
# Facets — goals, outcomes, friction patterns, satisfaction
ls ~/.claude/usage-data/facets/*.json | wc -l
```

For each session JSON in `~/.claude/usage-data/session-meta/`, extract:
- `project_path` — filter to current project only
- `duration_minutes` — how long sessions take
- `tool_counts` — which tools are used most (Read, Edit, Bash, Agent, Grep, Glob)
- `tool_errors` — what's failing
- `git_commits` — productivity per session
- `lines_added`, `lines_removed` — code velocity
- `languages` — what files are being touched
- `uses_web_search`, `uses_mcp` — feature adoption

For each facet JSON in `~/.claude/usage-data/facets/`, extract:
- `goal_categories` — what developers are doing (feature, debug, refactor, docs)
- `outcome` — fully_achieved vs partially vs failed
- `friction_counts` — what goes wrong (buggy_code, unclear_instructions, wrong_approach)
- `friction_detail` — specific friction descriptions
- `claude_helpfulness` — essential vs helpful vs limited
- `user_satisfaction_counts` — satisfied vs frustrated

### Aggregation

```bash
# Get all sessions for this project
python3 -c "
import json, os, sys
from pathlib import Path
from collections import Counter

project = os.getcwd()
meta_dir = Path.home() / '.claude/usage-data/session-meta'
facets_dir = Path.home() / '.claude/usage-data/facets'

sessions = []
for f in meta_dir.glob('*.json'):
    try:
        d = json.loads(f.read_text())
        if project in d.get('project_path', ''):
            sessions.append(d)
    except: pass

if not sessions:
    print('No sessions found for this project.')
    sys.exit(0)

print(f'Sessions: {len(sessions)}')
print(f'Total time: {sum(s.get(\"duration_minutes\", 0) for s in sessions)} min')
print(f'Total commits: {sum(s.get(\"git_commits\", 0) for s in sessions)}')

# Tool usage
tools = Counter()
for s in sessions:
    for t, c in s.get('tool_counts', {}).items():
        tools[t] += c
print(f'Top tools: {tools.most_common(5)}')

# Errors
total_errors = sum(s.get('tool_errors', 0) for s in sessions)
print(f'Total tool errors: {total_errors}')

# Friction from facets
frictions = Counter()
for f in facets_dir.glob('*.json'):
    try:
        d = json.loads(f.read_text())
        if d.get('session_id') in [s['session_id'] for s in sessions]:
            for k, v in d.get('friction_counts', {}).items():
                frictions[k] += v
    except: pass
if frictions:
    print(f'Top friction: {frictions.most_common(5)}')
"
```

## Step 2: Load Project Learnings

```bash
cat tools/learnings/*-learnings.jsonl 2>/dev/null | wc -l
```

Read each learning and categorize by type: bug, gotcha, pattern, decision.

Also read:
- `CLAUDE.md` — current rules and invariants
- `.claude/rules/` — existing path-scoped rules
- `vault/memory/status.md` — operational context
- `git log --oneline -20` — recent work

## Step 3: Pattern Analysis

Cross-reference insights with learnings to find:

### From Native Insights:
- **High-friction sessions**: Where `friction_counts` is high → what was the cause? Can a rule prevent it?
- **Underused tools**: If WebSearch usage is 0 but project has unknown infra → suggest `/aif-research`
- **Long sessions**: Duration > 60 min with few commits → workflow friction → check rules
- **Repeated goals**: If `goal_categories.testing_and_debugging` dominates → project needs better test setup
- **Tool errors**: If Bash errors are high → hooks or permissions may need adjustment

### From Project Learnings:
- **Repeated corrections**: Same mistake in learnings 2+ times → promote to CLAUDE.md invariant
- **Domain clusters**: Learnings about specific files/dirs → create path-scoped `.claude/rules/`
- **Stale rules**: CLAUDE.md rules about removed dependencies/features → propose removal
- **Missing coverage**: Code areas with zero learnings → blind spots

### Cross-Reference:
- **Friction + Learning overlap**: If insights show friction on auth code AND learnings mention auth gotchas → strengthen `.claude/rules/security.md`
- **Satisfaction + Rules**: If satisfaction is high when certain rules are followed → reinforce those rules
- **Tool adoption gaps**: If insights show no MCP/WebSearch usage but project would benefit → recommend in pulse

## Step 4: Generate Recommendations

Present findings as:

```markdown
## Evolution Report — {date}

### Data Sources
- Native insights: N sessions, N minutes, N commits
- Project learnings: N entries
- Current CLAUDE.md: N lines
- Current rules: N files

### Findings

#### Promote to CLAUDE.md Invariants
1. "{learning}" appeared N times → Add: INV-N: {rule}

#### New Path-Scoped Rules
1. Friction in `src/api/` → Create `.claude/rules/api-patterns.md`

#### CLAUDE.md Cleanup
1. Rule about {old dependency} is stale → Remove
2. CLAUDE.md is {N} lines → {above/below} 200-line target

#### Workflow Optimizations
1. Average session: {N} min with {N} commits → {assessment}
2. Top friction: {type} → Suggest: {fix}
3. Underused feature: {feature} → Suggest: {action}

### Quick Wins (apply now)
1. ...

### Strategic (requires planning)
1. ...
```

## Step 5: Apply with Approval

Ask the user: "Found N improvements. Apply quick wins now?"

For each approved change, use Edit tool to update:
- CLAUDE.md (add invariants, remove stale rules)
- `.claude/rules/*.md` (create or update path-scoped rules)
- `.claude/settings.json` (add hooks, adjust permissions)
- `vault/wiki/log.md` (log the evolution session)

## Step 6: Track Evolution

Record what changed:

```bash
echo '{"date":"'$(date +%Y-%m-%d)'","category":"pattern","summary":"Evolution session","detail":"Analyzed N sessions + N learnings. Applied N changes to CLAUDE.md and N new rules.","files":["CLAUDE.md",".claude/rules/"]}' >> tools/learnings/*-learnings.jsonl
```

Append to vault log:
```
| {date} | evolve | Analyzed {N} sessions: {N} invariants added, {N} rules created, {N} stale rules removed |
```
