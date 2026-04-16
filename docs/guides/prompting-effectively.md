# Prompting Effectively with aiframework

How to get the most out of Claude Code in an aiframework-bootstrapped project.

## The Skill Routing Model

aiframework generates a Skill Routing Table in CLAUDE.md that maps natural language to skill invocations. You don't need to remember exact commands — Claude Code reads the routing table and picks the right skill.

### Good Prompts

| What you say | What happens |
|-------------|-------------|
| "there's a bug in the auth flow" | Claude runs `/investigate` before touching code |
| "add a caching layer" | Claude runs `/plan-eng-review` then builds |
| "fix the typo in README" | Claude fixes directly, then verifies |
| "ship it" | Full pipeline: verify → review → security → QA → ship |
| "what do we know about the deploy process?" | Claude checks the vault for decisions and context |

### Less Effective Prompts

| What you say | Why it's less effective |
|-------------|----------------------|
| "change line 42" | No context — Claude can't verify the change is correct |
| "rewrite everything" | Too broad — scope the change to a specific module |
| "make it faster" | Vague — specify which operation or endpoint |

## Using the Vault

The vault (`vault/`) stores persistent knowledge across sessions:

- **Ask about past decisions**: "What did we decide about the database migration?"
- **Check context**: "What's the current status of the auth rewrite?"
- **Add knowledge**: "Remember that we chose Redis over Memcached for caching"

Claude Code reads `vault/memory/status.md` at session start for context continuity.

## Skill Chaining

Complex tasks naturally chain through multiple skills:

1. "Build a new user profile API endpoint"
   - Claude runs `/plan-eng-review` → builds → verifies → `/aif-review` → updates docs

2. "Deploy the latest changes"
   - Claude verifies → `/aif-review` → `/cso` (if security-relevant) → `/aif-ship`

## Tips

- **Be specific about scope**: "Add rate limiting to the /api/users endpoint" > "add rate limiting"
- **State the why**: "Add caching to reduce DB load during peak traffic" helps Claude make better design decisions
- **Trust the pipeline**: After saying "ship it", let the pipeline run — it handles verification, review, and docs automatically
- **Use the vault**: Drop design docs in `vault/raw/` and ask Claude to process them into wiki pages
- **Capture learnings**: After fixing a tricky bug, run `/aif-learn` to save the insight for future sessions
