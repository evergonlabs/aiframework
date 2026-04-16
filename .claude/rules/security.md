---
paths:
  - "**/auth/**"
  - "**/api/**"
  - "**/middleware/**"
---

# Security Rules

- Never log sensitive data (tokens, passwords, PII)
- Validate all input at system boundaries
- Use parameterized queries — never string concatenation for SQL
- API keys must come from environment variables
