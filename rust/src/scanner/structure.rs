use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::Path;

/// Scan for project structure: dirs, file counts, entry points.
pub fn scan(_target: &Path, files: &[String]) -> Value {
    let directories = detect_directories(files);
    let source_dirs = detect_source_dirs(files);
    let test_dirs = detect_test_dirs(files);
    let file_counts = count_by_extension(files);
    let entry_points = detect_entry_points(files);
    let key_files = detect_key_files(files);
    let config_files = detect_config_files(files);

    let ci_dirs = detect_ci_dirs(files);
    let doc_dirs = detect_doc_dirs(files);
    let script_dirs = detect_script_dirs(files);
    let test_file_count = count_test_files(files);
    let test_pattern = detect_test_pattern(files);

    json!({
        "directories": directories,
        "source_dirs": source_dirs,
        "src_dirs": source_dirs,  // bash compat alias
        "test_dirs": test_dirs,
        "file_counts": file_counts,
        "total_files": files.len(),
        "entry_points": entry_points,
        "config_files": config_files,
        "key_files": key_files,
        "ci_dirs": ci_dirs,
        "doc_dirs": doc_dirs,
        "script_dirs": script_dirs,
        "test_file_count": test_file_count,
        "test_pattern": test_pattern,
    })
}

fn detect_directories(files: &[String]) -> Vec<String> {
    let mut dirs = std::collections::HashSet::new();
    for f in files {
        if let Some(parent) = Path::new(f).parent() {
            let dir = parent.to_string_lossy().to_string();
            if !dir.is_empty() && !dir.starts_with(".git") {
                dirs.insert(dir);
            }
        }
    }
    let mut result: Vec<String> = dirs.into_iter().collect();
    result.sort();
    result
}

fn detect_source_dirs(files: &[String]) -> Vec<String> {
    let candidates = ["src", "lib", "app", "pkg", "internal", "cmd", "api"];
    let mut found = Vec::new();
    for candidate in &candidates {
        if files.iter().any(|f| f.starts_with(&format!("{candidate}/"))) {
            found.push(candidate.to_string());
        }
    }
    found
}

fn detect_test_dirs(files: &[String]) -> Vec<String> {
    let candidates = ["tests", "test", "__tests__", "spec", "specs", "test_data"];
    let mut found = Vec::new();
    for candidate in &candidates {
        if files.iter().any(|f| f.starts_with(&format!("{candidate}/"))) {
            found.push(candidate.to_string());
        }
    }
    found
}

fn count_by_extension(files: &[String]) -> HashMap<String, usize> {
    let mut counts: HashMap<String, usize> = HashMap::new();
    for f in files {
        if let Some(ext) = Path::new(f).extension().and_then(|e| e.to_str()) {
            *counts.entry(ext.to_string()).or_insert(0) += 1;
        }
    }
    counts
}

fn detect_entry_points(files: &[String]) -> Vec<String> {
    let patterns = [
        "main.py", "app.py", "manage.py",
        "main.ts", "index.ts", "app.ts",
        "main.js", "index.js", "app.js",
        "main.go", "main.rs",
        "main.java", "App.java",
        "Program.cs",
    ];
    let mut found = Vec::new();
    for f in files {
        let name = Path::new(f).file_name().and_then(|n| n.to_str()).unwrap_or("");
        if patterns.contains(&name) {
            found.push(f.clone());
        }
    }
    found
}

fn detect_key_files(files: &[String]) -> Vec<String> {
    let patterns = [
        "README.md", "CLAUDE.md", "AGENTS.md",
        "package.json", "Cargo.toml", "go.mod",
        "pyproject.toml", "requirements.txt",
        "Makefile", "Dockerfile",
        ".github/workflows/ci.yml",
    ];
    let mut found = Vec::new();
    for f in files {
        if patterns.contains(&f.as_str()) {
            found.push(f.clone());
        }
    }
    found
}

fn detect_ci_dirs(files: &[String]) -> Vec<String> {
    let candidates = [".github", ".circleci", ".gitlab"];
    let mut found = Vec::new();
    for candidate in &candidates {
        if files.iter().any(|f| f.starts_with(&format!("{candidate}/"))) {
            found.push(candidate.to_string());
        }
    }
    found
}

fn detect_doc_dirs(files: &[String]) -> Vec<String> {
    let candidates = ["docs", "doc", "documentation"];
    let mut found = Vec::new();
    for candidate in &candidates {
        if files.iter().any(|f| f.starts_with(&format!("{candidate}/"))) {
            found.push(candidate.to_string());
        }
    }
    found
}

fn detect_script_dirs(files: &[String]) -> Vec<String> {
    let candidates = ["scripts", "bin", "tools"];
    let mut found = Vec::new();
    for candidate in &candidates {
        if files.iter().any(|f| f.starts_with(&format!("{candidate}/"))) {
            found.push(candidate.to_string());
        }
    }
    found
}

fn count_test_files(files: &[String]) -> usize {
    files.iter().filter(|f| {
        let lower = f.to_lowercase();
        lower.contains(".test.") || lower.contains(".spec.")
            || lower.contains("test_") || lower.contains("_test.")
            || lower.starts_with("tests/") || lower.starts_with("test/")
            || lower.starts_with("__tests__/")
    }).count()
}

fn detect_test_pattern(files: &[String]) -> Value {
    let mut patterns: Vec<&str> = Vec::new();

    let has_jest_style = files.iter().any(|f| f.contains(".test.ts") || f.contains(".test.tsx") || f.contains(".test.js"));
    let has_spec_style = files.iter().any(|f| f.contains(".spec.ts") || f.contains(".spec.tsx") || f.contains(".spec.js"));
    let has_pytest_prefix = files.iter().any(|f| {
        Path::new(f).file_name().and_then(|n| n.to_str()).map_or(false, |n| n.starts_with("test_") && n.ends_with(".py"))
    });
    let has_pytest_suffix = files.iter().any(|f| f.ends_with("_test.py"));
    let has_go_test = files.iter().any(|f| f.ends_with("_test.go"));
    let has_rust_test = files.iter().any(|f| f.contains("/tests/") && f.ends_with(".rs"));

    if has_jest_style { patterns.push("*.test.ts"); }
    if has_spec_style { patterns.push("*.spec.ts"); }
    if has_pytest_prefix { patterns.push("test_*.py"); }
    if has_pytest_suffix { patterns.push("*_test.py"); }
    if has_go_test { patterns.push("*_test.go"); }
    if has_rust_test { patterns.push("tests/*.rs"); }

    if patterns.is_empty() {
        Value::Null
    } else {
        serde_json::json!(patterns.join(" / "))
    }
}

fn detect_config_files(files: &[String]) -> Vec<String> {
    let config_patterns = [
        ".eslintrc", ".eslintrc.js", ".eslintrc.json", ".eslintrc.yml",
        ".prettierrc", ".prettierrc.js", ".prettierrc.json",
        "tsconfig.json", "jsconfig.json",
        ".env", ".env.example", ".env.local",
        "Dockerfile", "docker-compose.yml", "docker-compose.yaml",
        "Makefile", ".editorconfig", ".gitignore",
        "jest.config.js", "jest.config.ts", "vitest.config.ts",
        "webpack.config.js", "vite.config.ts", "next.config.js",
        "pyproject.toml", "setup.py", "setup.cfg", "tox.ini",
        "ruff.toml", ".ruff.toml", "mypy.ini",
        ".rubocop.yml", "Rakefile",
        ".github/workflows/ci.yml", ".gitlab-ci.yml",
        "fly.toml", "vercel.json", "netlify.toml",
        "terraform.tf", "pulumi.yaml",
    ];
    let mut found = Vec::new();
    for f in files {
        let name = std::path::Path::new(f)
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("");
        if config_patterns.contains(&name) || config_patterns.contains(&f.as_str()) {
            found.push(f.clone());
        }
    }
    found.sort();
    found.dedup();
    found
}
