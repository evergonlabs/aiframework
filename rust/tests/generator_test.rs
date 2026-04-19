use serde_json::json;

use aiframework::generator::claude_md;

#[test]
fn test_claude_md_basic() {
    let manifest = json!({
        "identity": {"name": "test-app", "description": "A test app", "version": "1.0.0", "short_name": "test-app"},
        "stack": {"language": "typescript", "framework": "nextjs", "is_monorepo": false},
        "commands": {
            "lint": "npm run lint",
            "test": "npm test",
            "build": "npm run build",
            "typecheck": "npx tsc --noEmit",
            "install": "npm install",
            "package_manager": "npm",
            "makefile_targets": []
        },
        "structure": {
            "source_dirs": ["src"],
            "test_dirs": ["__tests__"],
            "entry_points": ["src/index.ts"],
            "key_files": ["package.json", "tsconfig.json"]
        },
        "archetype": {"type": "web-app", "maturity": "active", "complexity": "moderate"},
        "domain": {"detected_domains": []},
        "env": {"variables": []},
        "quality": {},
        "ci": {}
    });

    let result = claude_md::generate(&manifest, None);

    // Check required sections
    assert!(result.contains("# CLAUDE.md — test-app"), "Missing title");
    assert!(result.contains("> A test app"), "Missing description");
    assert!(result.contains("## Commands"), "Missing Commands section");
    assert!(result.contains("npm run lint"), "Missing lint command");
    assert!(result.contains("npm test"), "Missing test command");
    assert!(result.contains("npm run build"), "Missing build command");
    assert!(result.contains("npx tsc --noEmit"), "Missing typecheck command");
    assert!(result.contains("## Architecture"), "Missing Architecture section");
    assert!(result.contains("typescript/nextjs"), "Missing stack label");
    assert!(result.contains("web-app"), "Missing archetype");
    assert!(result.contains("## Key Locations"), "Missing Key Locations");
    assert!(result.contains("`src/`"), "Missing source dir");
    assert!(result.contains("`__tests__/`"), "Missing test dir");
    assert!(result.contains("## Invariants"), "Missing Invariants");
    assert!(result.contains("INV-1"), "Missing INV-1");
    assert!(result.contains("## Gotchas"), "Missing Gotchas");
    assert!(result.contains("tsconfig.json"), "Missing TS-specific gotcha");
}

#[test]
fn test_claude_md_with_code_index() {
    let manifest = json!({
        "identity": {"name": "my-lib"},
        "stack": {"language": "rust", "framework": "none"},
        "commands": {"lint": "cargo clippy", "test": "cargo test", "makefile_targets": []},
        "structure": {"source_dirs": ["src"], "test_dirs": ["tests"]},
        "archetype": {"type": "library"},
        "domain": {"detected_domains": []},
        "env": {"variables": []},
        "quality": {},
        "ci": {}
    });

    let index = json!({
        "_meta": {
            "total_files": 42,
            "total_symbols": 200,
            "total_edges": 30,
            "languages": {"rust": 40, "toml": 2},
            "top_files": [
                {"file": "src/lib.rs", "importance": 1000},
                {"file": "src/parser.rs", "importance": 800},
            ]
        }
    });

    let result = claude_md::generate(&manifest, Some(&index));

    assert!(result.contains("## Key Files"), "Missing Key Files");
    assert!(result.contains("`src/lib.rs`"), "Missing top file");
    assert!(result.contains("`src/parser.rs`"), "Missing second top file");
    assert!(result.contains("rust, toml"), "Missing languages");
    assert!(result.contains("cargo clippy"), "Missing Rust gotcha");
}

#[test]
fn test_claude_md_with_domains() {
    let manifest = json!({
        "identity": {"name": "api-service"},
        "stack": {"language": "python", "framework": "fastapi"},
        "commands": {"lint": "ruff check .", "test": "pytest", "makefile_targets": []},
        "structure": {"source_dirs": ["app"]},
        "archetype": {"type": "api-service"},
        "domain": {
            "detected_domains": [
                {"name": "auth", "display": "Authentication", "paths": ["app/auth/"]},
                {"name": "database", "display": "Database", "paths": ["app/models/"]},
                {"name": "api", "display": "API", "paths": ["app/routes/"]}
            ]
        },
        "env": {
            "variables": [
                {"name": "DATABASE_URL", "source": ".env.example", "is_sensitive": true},
                {"name": "PORT", "source": ".env.example", "is_sensitive": false}
            ]
        },
        "quality": {
            "linter": {"tool": "ruff", "config_file": "ruff.toml", "configured": true},
            "test_framework": {"tool": "pytest", "configured": true}
        },
        "ci": {
            "provider": "github-actions",
            "coverage": ["lint", "test"],
            "gaps": ["typecheck", "security"]
        }
    });

    let result = claude_md::generate(&manifest, None);

    // Domain invariants
    assert!(result.contains("INV-AUTH"), "Missing auth invariant");
    assert!(result.contains("INV-DB"), "Missing database invariant");
    assert!(result.contains("INV-API"), "Missing API invariant");

    // Environment variables
    assert!(result.contains("## Environment Variables"), "Missing env section");
    assert!(result.contains("DATABASE_URL"), "Missing DATABASE_URL");
    assert!(result.contains("PORT"), "Missing PORT");

    // Quality tools
    assert!(result.contains("## Quality Tools"), "Missing quality section");
    assert!(result.contains("ruff"), "Missing linter");
    assert!(result.contains("ruff.toml"), "Missing linter config");
    assert!(result.contains("pytest"), "Missing test framework");

    // CI
    assert!(result.contains("## CI"), "Missing CI section");
    assert!(result.contains("github-actions"), "Missing CI provider");
    assert!(result.contains("lint, test"), "Missing CI coverage");
    assert!(result.contains("typecheck, security"), "Missing CI gaps");

    // Python-specific gotchas
    assert!(result.contains("Virtual environment"), "Missing Python gotcha");
}

#[test]
fn test_claude_md_monorepo() {
    let manifest = json!({
        "identity": {"name": "platform"},
        "stack": {"language": "typescript", "framework": "none", "is_monorepo": true, "monorepo_tool": "turborepo"},
        "commands": {"lint": "turbo lint", "test": "turbo test", "makefile_targets": []},
        "structure": {},
        "archetype": {"type": "monorepo"},
        "domain": {"detected_domains": []},
        "env": {"variables": []},
        "quality": {},
        "ci": {}
    });

    let result = claude_md::generate(&manifest, None);
    assert!(result.contains("**Monorepo**: yes (turborepo)"), "Missing monorepo info");
}

#[test]
fn test_claude_md_makefile() {
    let manifest = json!({
        "identity": {"name": "cli-tool"},
        "stack": {"language": "bash", "framework": "none"},
        "commands": {
            "lint": "make lint",
            "test": "make test",
            "makefile_targets": ["install", "lint", "test", "dist", "clean"]
        },
        "structure": {},
        "archetype": {"type": "cli-tool"},
        "domain": {"detected_domains": []},
        "env": {"variables": []},
        "quality": {},
        "ci": {}
    });

    let result = claude_md::generate(&manifest, None);
    assert!(result.contains("## Makefile"), "Missing Makefile section");
    assert!(result.contains("make install"), "Missing make install");
    assert!(result.contains("make lint"), "Missing make lint");
    assert!(result.contains("make test"), "Missing make test");
    assert!(result.contains("shellcheck"), "Missing bash-specific gotcha");
}

#[test]
fn test_claude_md_minimal() {
    // Minimal manifest — should not crash, should produce valid output
    let manifest = json!({
        "identity": {"name": "empty"},
        "stack": {"language": "unknown"},
        "commands": {"makefile_targets": []},
        "structure": {},
        "archetype": {},
        "domain": {},
        "env": {},
        "quality": {},
        "ci": {}
    });

    let result = claude_md::generate(&manifest, None);
    assert!(result.contains("# CLAUDE.md — empty"), "Missing title");
    assert!(result.contains("## Commands"), "Missing commands");
    assert!(result.contains("## Invariants"), "Missing invariants");
    assert!(!result.is_empty());
}
