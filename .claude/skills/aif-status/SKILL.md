---
description: "Project health check and next-steps guide. Run this first after aiframework setup, or anytime to check what needs attention."
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Agent"]
---

# /aif-status — Project Setup Status & Next Steps

You are checking the health of an aiframework-configured project and guiding the user on what to do next.

## Steps

### Step 1: Check Generated Files

Read and verify these files exist. For each, note if it's present, its line count, and whether it looks correct:

```
CLAUDE.md                           — Project brain (should be 80-150 lines)
AGENTS.md                           — Universal agent config (should be 30-80 lines)
.cursorrules                        — Cursor IDE config
.claude/rules/workflow.md           — Workflow rules
.claude/rules/pipeline.md           — 12-stage pipeline (moderate+ only)
.claude/rules/session-protocol.md   — Session checklists (moderate+ only)
.claude/rules/invariants.md         — Domain invariants (moderate+ only)
.claude/settings.json               — Claude Code permissions
.claude/skills/                     — Custom skills
.githooks/pre-push                  — Quality gate hook
.github/workflows/ci.yml            — CI pipeline
docs/reference/architecture.md      — Architecture reference (moderate+ only)
vault/memory/status.md              — Session memory
tools/learnings/                    — Learning capture
CHANGELOG.md                        — Release history
VERSION                             — Version tracking
```

Use Glob to check: `**/{CLAUDE.md,AGENTS.md,.cursorrules}` and `.claude/rules/*.md` and `.claude/skills/*/SKILL.md`

### Step 2: Check Manifest Quality

Read `.aiframework/manifest.json` and evaluate:

1. **Language**: Is it correct? Does it match the actual primary language?
2. **Framework**: Detected or "none"?
3. **Archetype**: Does it make sense for this project?
4. **Commands**: Are build/test/lint configured or NOT_CONFIGURED?
5. **Domains**: Any detected? Are they accurate (not false positives)?
6. **Description**: Is it a real description or HTML/empty?
7. **Complexity**: simple/moderate/complex/enterprise — affects tier

### Step 3: Check Code Index

Read `.aiframework/code-index.json` metadata:
```bash
jq '._meta' .aiframework/code-index.json
```

Report: files indexed, symbols extracted, modules found. If 0 files: code index wasn't run (use `aiframework index`).

### Step 4: Check Vault Health

```bash
vault/.vault/scripts/vault-tools.sh doctor 2>/dev/null || echo "Vault not initialized"
```

### Step 5: Check for Enhancement Opportunities

Identify gaps that `/aif-enhance` can fill:

- [ ] Framework detected but no framework-specific invariants? → `/aif-enhance`
- [ ] Commands NOT_CONFIGURED for build/test/lint? → User needs to add to package.json/Makefile
- [ ] No domains detected? → Project may need `/aif-enhance` to research conventions
- [ ] Code index has 0 modules? → Run `aiframework index --target .`
- [ ] No learnings captured? → Start using `/aif-learn` after discoveries
- [ ] CLAUDE.md over 200 lines? → Run `aiframework refresh` to slim it down

### Step 6: Generate Status Report

Output a clean table:

```
═══════════════════════════════════════════════════
  aiframework Status — {project_name}
═══════════════════════════════════════════════════

  Stack:      {language} / {framework}
  Archetype:  {archetype} ({maturity}, {complexity})
  Tier:       {tier}

  ┌─────────────────────────┬──────────┐
  │ Component               │ Status   │
  ├─────────────────────────┼──────────┤
  │ CLAUDE.md               │ ✓ (N lines) │
  │ AGENTS.md               │ ✓ (N lines) │
  │ .cursorrules            │ ✓ / ✗    │
  │ Extended rules          │ ✓ N files │
  │ Custom skills           │ ✓ N skills │
  │ Git hooks               │ ✓ / ✗    │
  │ CI workflow             │ ✓ / ✗    │
  │ Code index              │ N files, N symbols │
  │ Vault                   │ ✓ / ✗    │
  │ Learnings               │ N entries │
  └─────────────────────────┴──────────┘

  What to do next:
  ─────────────────

  1. /aif-enhance    ← Research your framework's conventions (run once)
  2. /aif-analyze    ← Find missing tests, circular deps (run once)
  3. Start coding!   ← aiframework is ready

  Recurring:
  4. /aif-learn "..."  ← After discovering gotchas
  5. /aif-evolve       ← Weekly: improve rules from learnings
  6. /aif-pulse        ← Weekly: discover new Claude Code features
```

### Step 7: Offer Quick Actions

If gaps were found, offer to fix them:

- "I see your build command is NOT_CONFIGURED. Want me to detect it from your Makefile/package.json?"
- "No framework invariants found. Want me to run `/aif-enhance` to research your framework's best practices?"
- "CLAUDE.md is 300 lines — want me to run `aiframework refresh` to slim it down?"
- "No learnings captured yet. After your next bug fix, run `/aif-learn` to record what you learned."

## Output Rules

- Be concise — status table + numbered next steps
- Don't dump raw file contents — summarize
- If everything is green, say so: "All systems go. Start coding."
- If there are gaps, prioritize: what gives the most value for least effort?
