---
description: "Project invariants, archetype rules, review specialist checklists"
globs: "**/*"
---

# Invariants & Project Profile

## INV-1: LLM trust boundary enforcement
Never trust LLM output as safe — validate, sanitize, and scope all AI-generated content.


## INV-2: No secrets in source code
Never commit API keys, passwords, tokens, or credentials.

---

## Project Profile

- **Archetype**: cli-tool
- **Maturity**: active
- **Complexity**: complex

### Archetype Invariants

- [CLI-1]: All commands must have --help output with usage examples
- [CLI-2]: Exit codes must be meaningful — 0 for success, non-zero for specific error categories
- [CLI-3]: All user-facing output must go to stdout, errors/warnings to stderr

---

## Review Specialists

### AI/LLM Integration
Trigger paths: rust/src/ (any module handling LLM interaction)

- [ ] LLM outputs are sanitized before use
- [ ] Prompt injection defenses in place
- [ ] Token limits enforced per request
- [ ] API keys stored in env vars, not code
- [ ] Fallback behavior when LLM is unavailable
- [ ] Cost monitoring/alerting configured
- [ ] Output validation before displaying to users
