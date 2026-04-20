# Contributing to aiframework

## Setup

```bash
git clone https://github.com/evergonlabs/aiframework
cd aiframework/rust
cargo build
cargo test
```

Requires [Rust 1.75+](https://rustup.rs).

## Branch Naming

- `feat/description` — new feature
- `fix/description` — bug fix
- `refactor/description` — code restructuring

## Commit Messages (Conventional Commits)

```
feat: add kotlin tree-sitter parser
fix: resolve timeout on large repos
refactor: extract scanner into separate module
```

## Pull Request Process

1. Branch from `main`
2. Run `cargo test` and `cargo clippy` locally
3. Create PR with description: What, Why, How, Testing
4. CI must pass (build + test + smoke tests on Ubuntu + macOS)

## Code Style

- `cargo clippy` for linting
- `cargo fmt` for formatting
- Follow existing patterns in `rust/src/`

## Testing

```bash
cd rust
cargo test              # 42 unit + integration tests
cargo run -- index --target .. --summary   # smoke test
```

Tests live in `rust/tests/` (integration) and inline `#[cfg(test)]` modules (unit).

## Project Structure

```
rust/src/
├── cli.rs          CLI commands (clap)
├── config.rs       Tier system + config loading
├── telemetry.rs    PostHog analytics
├── ui.rs           Terminal output (colors, tables)
├── scanner/        13 repo scanners
├── indexer/        Code indexer + 13 language parsers
├── generator/      14 file generators
├── validator/      5 validation checks
└── mcp/            MCP JSON-RPC server
```
