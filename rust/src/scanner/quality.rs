use serde_json::{json, Value};
use std::path::Path;

/// Scan for quality tooling: linter, formatter, type checker, test framework, hooks.
pub fn scan(target: &Path, _files: &[String]) -> Value {
    let linter = detect_linter(target);
    let formatter = detect_formatter(target);
    let type_checker = detect_type_checker(target);
    let test_framework = detect_test_framework(target);
    let hooks = detect_hooks(target);

    json!({
        "linter": linter,
        "formatter": formatter,
        "type_checker": type_checker,
        "test_framework": test_framework,
        "hooks": hooks,
    })
}

fn detect_linter(target: &Path) -> Value {
    // ESLint
    let eslint_configs = [
        ".eslintrc.js", ".eslintrc.json", ".eslintrc.yml", ".eslintrc.yaml",
        ".eslintrc", "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs",
        "eslint.config.ts",
    ];
    for cfg in &eslint_configs {
        if target.join(cfg).exists() {
            return tool_json("eslint", cfg, true);
        }
    }

    // Ruff
    for cfg in &[".ruff.toml", "ruff.toml"] {
        if target.join(cfg).exists() {
            return tool_json("ruff", cfg, true);
        }
    }
    if has_toml_section(target, "[tool.ruff]") {
        return tool_json("ruff", "pyproject.toml", true);
    }

    // Clippy (Rust)
    if target.join("Cargo.toml").exists() {
        return tool_json("clippy", "Cargo.toml", true);
    }

    // Pylint
    if target.join(".pylintrc").exists() {
        return tool_json("pylint", ".pylintrc", true);
    }

    // golangci-lint
    for cfg in &[".golangci.yml", ".golangci.yaml", ".golangci.json", ".golangci.toml"] {
        if target.join(cfg).exists() {
            return tool_json("golangci-lint", cfg, true);
        }
    }

    // Rubocop
    if target.join(".rubocop.yml").exists() {
        return tool_json("rubocop", ".rubocop.yml", true);
    }

    // ShellCheck (detect by scripts presence)
    if target.join(".shellcheckrc").exists() {
        return tool_json("shellcheck", ".shellcheckrc", true);
    }

    tool_json_none()
}

fn detect_formatter(target: &Path) -> Value {
    // Prettier
    let prettier_configs = [
        ".prettierrc", ".prettierrc.json", ".prettierrc.js", ".prettierrc.yaml",
        ".prettierrc.yml", ".prettierrc.toml", "prettier.config.js",
        "prettier.config.mjs", "prettier.config.cjs",
    ];
    for cfg in &prettier_configs {
        if target.join(cfg).exists() {
            return tool_json("prettier", cfg, true);
        }
    }

    // Black
    if has_toml_section(target, "[tool.black]") {
        return tool_json("black", "pyproject.toml", true);
    }

    // Ruff format (if ruff is present)
    if has_toml_section(target, "[tool.ruff]") {
        return tool_json("ruff-format", "pyproject.toml", true);
    }

    // rustfmt
    if target.join("Cargo.toml").exists() {
        let cfg = if target.join("rustfmt.toml").exists() {
            "rustfmt.toml"
        } else if target.join(".rustfmt.toml").exists() {
            ".rustfmt.toml"
        } else {
            "built-in"
        };
        return tool_json("rustfmt", cfg, true);
    }

    // gofmt
    if target.join("go.mod").exists() {
        return tool_json("gofmt", "built-in", true);
    }

    tool_json_none()
}

fn detect_type_checker(target: &Path) -> Value {
    // TypeScript
    if target.join("tsconfig.json").exists() {
        let strict = std::fs::read_to_string(target.join("tsconfig.json"))
            .ok()
            .and_then(|c| serde_json::from_str::<Value>(&c).ok())
            .and_then(|v| v["compilerOptions"]["strict"].as_bool())
            .unwrap_or(false);
        let cfg = if strict { "tsconfig.json (strict)" } else { "tsconfig.json" };
        return tool_json("tsc", cfg, true);
    }

    // mypy
    if target.join("mypy.ini").exists() || target.join(".mypy.ini").exists() {
        return tool_json("mypy", "mypy.ini", true);
    }
    if has_toml_section(target, "[tool.mypy]") {
        return tool_json("mypy", "pyproject.toml", true);
    }

    // pyright
    if target.join("pyrightconfig.json").exists() {
        return tool_json("pyright", "pyrightconfig.json", true);
    }
    if has_toml_section(target, "[tool.pyright]") {
        return tool_json("pyright", "pyproject.toml", true);
    }

    // Rust compiler as type checker
    if target.join("Cargo.toml").exists() {
        return tool_json("cargo-check", "built-in", true);
    }

    // Go vet
    if target.join("go.mod").exists() {
        return tool_json("go-vet", "built-in", true);
    }

    tool_json_none()
}

fn detect_test_framework(target: &Path) -> Value {
    // Jest
    let jest_configs = [
        "jest.config.ts", "jest.config.js", "jest.config.json",
        "jest.config.mjs", "jest.config.cjs",
    ];
    for cfg in &jest_configs {
        if target.join(cfg).exists() {
            return tool_json("jest", cfg, true);
        }
    }

    // Vitest
    let vitest_configs = [
        "vitest.config.ts", "vitest.config.js",
        "vitest.config.mts", "vitest.config.mjs",
    ];
    for cfg in &vitest_configs {
        if target.join(cfg).exists() {
            return tool_json("vitest", cfg, true);
        }
    }

    // Pytest
    if target.join("pytest.ini").exists() {
        return tool_json("pytest", "pytest.ini", true);
    }
    if target.join("conftest.py").exists() {
        return tool_json("pytest", "conftest.py", true);
    }
    if has_toml_section(target, "[tool.pytest") {
        return tool_json("pytest", "pyproject.toml", true);
    }

    // RSpec
    if target.join(".rspec").exists() {
        return tool_json("rspec", ".rspec", true);
    }

    // Cargo test
    if target.join("Cargo.toml").exists() {
        return tool_json("cargo-test", "built-in", true);
    }

    // Go test
    if target.join("go.mod").exists() {
        return tool_json("go-test", "built-in", true);
    }

    tool_json_none()
}

fn detect_hooks(target: &Path) -> Value {
    let (system, dir) = if target.join(".husky").is_dir() {
        ("husky", ".husky")
    } else if target.join(".githooks").is_dir() {
        ("githooks", ".githooks")
    } else if target.join(".pre-commit-config.yaml").exists() {
        ("pre-commit", ".pre-commit-config.yaml")
    } else {
        return json!({
            "system": Value::Null,
            "pre_commit": false,
            "pre_push": false,
        });
    };

    let hook_path = target.join(dir);
    let pre_commit = hook_path.join("pre-commit").exists();
    let pre_push = hook_path.join("pre-push").exists();

    json!({
        "system": system,
        "pre_commit": pre_commit,
        "pre_push": pre_push,
    })
}

// --- helpers ---

fn tool_json(tool: &str, config_file: &str, configured: bool) -> Value {
    json!({
        "tool": tool,
        "config_file": config_file,
        "configured": configured,
    })
}

fn tool_json_none() -> Value {
    json!({
        "tool": Value::Null,
        "config_file": Value::Null,
        "configured": false,
    })
}

fn has_toml_section(target: &Path, section: &str) -> bool {
    std::fs::read_to_string(target.join("pyproject.toml"))
        .map(|c| c.contains(section))
        .unwrap_or(false)
}
