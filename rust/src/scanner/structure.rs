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
