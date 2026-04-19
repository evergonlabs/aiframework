use serde_json::Value;

/// Generate a .cursorrules file for Cursor IDE configuration.
pub fn generate(manifest: &Value) -> String {
    let mut out = String::with_capacity(4096);

    let name = str_or(manifest, &["identity", "name"], "project");
    let lang = str_or(manifest, &["stack", "language"], "unknown");
    let fw = str_or(manifest, &["stack", "framework"], "none");
    let arch_type = str_or(manifest, &["archetype", "type"], "application");
    let test_cmd = str_or(manifest, &["commands", "test"], "NOT_CONFIGURED");
    let lint_cmd = str_or(manifest, &["commands", "lint"], "NOT_CONFIGURED");

    // Project context
    out.push_str(&format!("# Project: {name}\n\n"));

    // Language and framework
    out.push_str(&format!("## Language & Framework\n\n"));
    out.push_str(&format!("- Primary language: {lang}\n"));
    if fw != "none" {
        out.push_str(&format!("- Framework: {fw}\n"));
    }
    out.push_str(&format!("- Project type: {arch_type}\n\n"));

    // Code style rules
    out.push_str("## Code Style\n\n");
    out.push_str(&style_rules_for(&lang));

    // File structure
    out.push_str("## File Structure\n\n");
    if let Some(source_dirs) = manifest["structure"]["source_dirs"].as_array() {
        for dir in source_dirs {
            if let Some(d) = dir.as_str() {
                out.push_str(&format!("- Source code lives in `{d}/`\n"));
            }
        }
    }
    if let Some(test_dirs) = manifest["structure"]["test_dirs"].as_array() {
        for dir in test_dirs {
            if let Some(d) = dir.as_str() {
                out.push_str(&format!("- Tests live in `{d}/`\n"));
            }
        }
    }
    if let Some(config_files) = manifest["structure"]["config_files"].as_array() {
        if !config_files.is_empty() {
            let names: Vec<&str> = config_files
                .iter()
                .filter_map(|v| v.as_str())
                .take(8)
                .collect();
            out.push_str(&format!("- Config files: {}\n", names.join(", ")));
        }
    }
    out.push('\n');

    // Testing conventions
    out.push_str("## Testing\n\n");
    if test_cmd != "NOT_CONFIGURED" {
        out.push_str(&format!("- Run tests: `{test_cmd}`\n"));
    }
    if lint_cmd != "NOT_CONFIGURED" {
        out.push_str(&format!("- Run linter: `{lint_cmd}`\n"));
    }
    out.push_str(&testing_conventions_for(&lang));
    out.push('\n');

    // General rules
    out.push_str("## General Rules\n\n");
    out.push_str("- Never commit secrets, API keys, or credentials\n");
    out.push_str("- Validate all external input\n");
    out.push_str("- Write clear error messages that help debugging\n");
    out.push_str("- Prefer small, focused functions over large monoliths\n");
    out.push_str("- Update tests when changing behavior\n");

    // Archetype-specific
    match arch_type.as_str() {
        "cli-tool" => {
            out.push_str("- All CLI commands must support --help\n");
            out.push_str("- Use meaningful exit codes (0 = success)\n");
            out.push_str("- Send errors to stderr, output to stdout\n");
        }
        "web-app" | "api" => {
            out.push_str("- Validate all request input before processing\n");
            out.push_str("- Return proper HTTP status codes\n");
        }
        "library" => {
            out.push_str("- Document all public APIs\n");
            out.push_str("- Maintain backward compatibility\n");
        }
        _ => {}
    }

    out
}

/// Return language-specific code style rules.
fn style_rules_for(lang: &str) -> String {
    match lang.to_lowercase().as_str() {
        "rust" => concat!(
            "- Use `rustfmt` formatting (default settings)\n",
            "- Prefer `Result<T, E>` over panics for error handling\n",
            "- Use `clippy` lints — no warnings allowed\n",
            "- Derive traits where possible (`Debug`, `Clone`, `PartialEq`)\n",
            "- Prefer iterators over manual loops\n\n",
        ).to_string(),
        "python" => concat!(
            "- Follow PEP 8 with 88-char line limit (Black formatter)\n",
            "- Use type hints for function signatures\n",
            "- Use dataclasses or Pydantic for structured data\n",
            "- Prefer pathlib over os.path\n\n",
        ).to_string(),
        "javascript" | "typescript" => concat!(
            "- Use Prettier for formatting\n",
            "- Prefer `const` over `let`; never use `var`\n",
            "- Use async/await over raw Promises\n",
            "- Destructure objects and arrays where readable\n\n",
        ).to_string(),
        "go" => concat!(
            "- Use `gofmt` formatting\n",
            "- Always check returned errors\n",
            "- Keep interfaces small (1-3 methods)\n",
            "- Use table-driven tests\n\n",
        ).to_string(),
        "ruby" => concat!(
            "- Follow Rubocop defaults\n",
            "- Use symbols for hash keys\n",
            "- Prefer blocks over procs for callbacks\n\n",
        ).to_string(),
        "java" | "kotlin" => concat!(
            "- Follow Google Java Style Guide\n",
            "- Use meaningful variable and method names\n",
            "- Prefer composition over inheritance\n\n",
        ).to_string(),
        _ => "- Follow established project conventions\n\n".to_string(),
    }
}

/// Return language-specific testing conventions.
fn testing_conventions_for(lang: &str) -> String {
    match lang.to_lowercase().as_str() {
        "rust" => "- Use `#[test]` for unit tests, `tests/` for integration tests\n- Use `assert_eq!` and `assert!` macros\n".to_string(),
        "python" => "- Use pytest for testing\n- Name test files `test_*.py`\n".to_string(),
        "javascript" | "typescript" => "- Use describe/it blocks for test structure\n- Mock external dependencies\n".to_string(),
        "go" => "- Use `*_test.go` files alongside source\n- Use table-driven test patterns\n".to_string(),
        _ => "- Write tests for all new functionality\n".to_string(),
    }
}

/// Navigate nested JSON safely.
fn str_or(value: &Value, path: &[&str], default: &str) -> String {
    let mut current = value;
    for key in path {
        current = &current[*key];
    }
    current.as_str().unwrap_or(default).to_string()
}
