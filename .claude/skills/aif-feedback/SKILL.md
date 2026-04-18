---
name: aif-feedback
description: Collect structured user feedback on aiframework-generated output. Saves to tools/learnings/feedback.jsonl for integration with /aif-evolve.
allowed-tools: [Read, Bash]
---

# Collect Feedback

Gather structured feedback from the user about their experience with aiframework-generated output. This data feeds into `/aif-evolve` for continuous improvement.

## When to Use

- After a user has run aiframework on a project
- When a user reports dissatisfaction with generated output
- Periodically to collect improvement signals

## Step 0: Telemetry (silent, non-blocking)

```bash
aiframework-telemetry skill_invoked skill=aif-feedback 2>/dev/null || true
```

## Step 1: Ask 5 Questions

Present these questions one at a time, waiting for each answer:

1. **CLAUDE.md Quality** (1-5): "How useful is the generated CLAUDE.md for your daily work?"
2. **Accuracy** (1-5): "How accurate were the detected stack, domains, and commands?"
3. **Missing Context** (free text): "What important context about your project is missing from the output?"
4. **Noise** (free text): "What generated content is unhelpful or distracting that you'd remove?"
5. **Top Wish** (free text): "If you could improve one thing about aiframework, what would it be?"

## Step 2: Save Feedback

Append a JSON line to `tools/learnings/feedback.jsonl`:

```bash
jq -n --arg d "$(date +%Y-%m-%d)" --arg q SCORE --arg a SCORE --arg mc "ANSWER" --arg n "ANSWER" --arg tw "ANSWER" --arg p "$(basename "$(pwd)")" \
  '{date:$d, claude_md_quality:($q|tonumber), accuracy:($a|tonumber), missing_context:$mc, noise:$n, top_wish:$tw, project:$p}' >> tools/learnings/feedback.jsonl
```

## Step 3: Acknowledge

Thank the user and explain:
- Feedback is stored locally in `tools/learnings/feedback.jsonl`
- Running `/aif-evolve` will incorporate this feedback into improvement recommendations
- Patterns across feedback entries drive CLAUDE.md and rule evolution

## Integration with /aif-evolve

The evolve skill reads `feedback.jsonl` alongside `*-learnings.jsonl` to:
- Identify recurring complaints (noise, missing context)
- Prioritize improvements by frequency and severity
- Track quality scores over time
