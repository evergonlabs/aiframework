# aiframework — Documentation

## Structure (Diataxis)

| Category | Directory | Purpose |
|----------|-----------|---------|
| Tutorials | `onboarding/` | Learning-oriented, step-by-step |
| How-to Guides | `guides/` | Task-oriented instructions |
| Reference | `reference/` | Precise technical descriptions |
| Explanation | `explanation/` | Conceptual discussions |
| Decisions | `decisions/` | Architecture Decision Records |

## Onboarding (Tutorials)

| Document | Description |
|----------|-------------|
| [`onboarding/getting-started.md`](onboarding/getting-started.md) | Step-by-step first-time setup: prerequisites, installation, first run, understanding output |

## How-to Guides

| Document | Description |
|----------|-------------|
| [`guides/adding-a-scanner.md`](guides/adding-a-scanner.md) | Extend aiframework with a new scanner module: architecture, function signature, registration, testing |
| [`guides/adding-a-domain.md`](guides/adding-a-domain.md) | Add a new domain detection: edit domains.json, create review specialist, test |
| [`guides/creating-custom-skills.md`](guides/creating-custom-skills.md) | Create Claude Code skills: SKILL.md format, frontmatter, step structure, allowed-tools |
| [`guides/prompting-effectively.md`](guides/prompting-effectively.md) | AI dev philosophy: skill routing, good vs bad prompts, vault usage, skill chaining |

## Explanation

| Document | Description |
|----------|-------------|
| [`explanation/architecture.md`](explanation/architecture.md) | Conceptual overview: 4-stage pipeline, manifest-driven design, knowledge vault, code indexer, security model |

## Reference Docs

| Document | Description |
|----------|-------------|
| [`reference/code-indexer.md`](reference/code-indexer.md) | Code indexer: output schema, language support, dependency graph, downstream consumers |
| [`reference/llm-agent-integration.md`](reference/llm-agent-integration.md) | LLM agent integration: manifest schema, CLAUDE.md contract, skill authoring, vault protocol |
