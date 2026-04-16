---
name: aif-analyze
description: Deep code analysis using the code index. Finds missing tests, circular deps, god modules, and architectural issues.
allowed-tools: [Read, Glob, Grep, Bash]
---

# Code Analysis

Analyze the codebase using the pre-computed code index for architectural insights.

## Process

1. Read `.aiframework/code-index.json`
2. Analyze modules for:
   - **Missing tests**: source files with no corresponding test file
   - **Circular dependencies**: modules that import each other
   - **God modules**: high fan_in (>3) AND high total_symbols (>20)
   - **Orphan files**: files with no imports in or out
   - **Hot spots**: files with highest PageRank importance
3. Use Glob/Grep to verify findings against actual code
4. Write structured findings to `.aiframework/enhance-findings.json`

## Output Format

```json
{
  "findings": [
    {"type": "missing-test", "file": "src/utils.py", "suggestion": "Add tests/test_utils.py"},
    {"type": "circular-dep", "modules": ["lib/a", "lib/b"], "severity": "medium"},
    {"type": "god-module", "module": "lib/core", "fan_in": 8, "symbols": 45}
  ]
}
```
