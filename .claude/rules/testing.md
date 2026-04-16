---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/test_*"
  - "**/tests/**"
---

# Testing Rules

- Tests must be deterministic — no flaky tests
- Mock external services, not internal modules
- Each test file tests one module
- Test names describe the expected behavior
