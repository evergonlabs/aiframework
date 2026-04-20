use serde_json::{json, Value};
use std::path::Path;
use std::process::Command;

/// Scan for project archetype, maturity, and complexity.
pub fn scan(target: &Path, files: &[String]) -> Value {
    let archetype = classify_archetype(target, files);
    let maturity = detect_maturity(target);
    let complexity = detect_complexity(files);

    json!({
        "type": archetype,
        "maturity": maturity,
        "complexity": complexity,
    })
}

fn classify_archetype(target: &Path, files: &[String]) -> String {
    // Monorepo markers
    let mono_markers = ["turbo.json", "lerna.json", "nx.json", "pnpm-workspace.yaml"];
    for marker in &mono_markers {
        if target.join(marker).exists() {
            return "monorepo".into();
        }
    }
    // Also check package.json workspaces
    if let Some(pkg) = read_json(target, "package.json") {
        if pkg.get("workspaces").is_some() {
            return "monorepo".into();
        }
    }

    // Data pipeline
    let data_deps = ["airflow", "dagster", "dbt", "prefect", "luigi"];
    if has_dependency_match(target, files, &data_deps) {
        return "data-pipeline".into();
    }

    // ML project
    let ml_deps = ["torch", "tensorflow", "scikit", "transformers", "keras"];
    if has_dependency_match(target, files, &ml_deps) {
        return "ml-project".into();
    }

    // Mobile app
    let mobile_deps = ["react-native", "flutter", "expo"];
    if has_dependency_match(target, files, &mobile_deps) {
        return "mobile-app".into();
    }

    // Detect domain presence for full-stack/web/api classification
    let has_frontend = files.iter().any(|f| {
        f.contains("components/") || f.contains("pages/") || f.contains("views/")
            || f.contains("layouts/") || f.ends_with(".tsx") || f.ends_with(".vue")
            || f.ends_with(".svelte")
    });
    let has_api_dirs = files.iter().any(|f| {
        f.contains("routes/") || f.contains("controllers/") || f.contains("handlers/")
            || f.contains("endpoints/")
    });

    // Also detect API by framework dependency
    let api_frameworks = ["fastapi", "flask", "django", "express", "gin", "echo", "chi",
                          "fiber", "actix", "axum", "rocket", "sinatra", "rails",
                          "spring", "quarkus", "nestjs", "hono", "starlette",
                          "laravel", "symfony"];
    let has_api_framework = has_dependency_match(target, files, &api_frameworks);
    let has_api = has_api_dirs || has_api_framework;

    if has_frontend && has_api {
        return "full-stack".into();
    }

    // API service (check before web-app so FastAPI/Express projects get correct type)
    if has_api && !has_frontend {
        return "api-service".into();
    }

    // Web framework detection (frontend-focused)
    let web_frameworks = ["next", "nuxt", "svelte", "remix", "gatsby", "angular", "vue"];
    if has_dependency_match(target, files, &web_frameworks) {
        return "web-app".into();
    }

    if has_frontend {
        return "web-app".into();
    }

    // CLI tool: has bin/ directory, no web framework
    let has_bin = files.iter().any(|f| f.starts_with("bin/"));
    if has_bin {
        return "cli-tool".into();
    }

    // Library: few entry points, many files, no framework
    let entry_count = files.iter().filter(|f| {
        f == &"index.ts" || f == &"index.js" || f == &"main.rs" || f == &"lib.rs"
            || f == &"__init__.py" || f == &"main.py" || f == &"main.go"
    }).count();
    if entry_count <= 1 && files.len() > 5 {
        return "library".into();
    }

    // Documentation site
    let doc_deps = ["docusaurus", "vitepress", "mkdocs", "hugo", "eleventy", "astro"];
    if has_dependency_match(target, files, &doc_deps) {
        return "documentation-site".into();
    }
    let md_count = files.iter().filter(|f| f.ends_with(".md") || f.ends_with(".mdx")).count();
    if files.len() > 3 && md_count * 2 > files.len() {
        return "documentation-site".into();
    }

    // Infrastructure
    let infra_markers = ["terraform", "pulumi", "cdk.json", "ansible.cfg"];
    for marker in &infra_markers {
        if target.join(marker).exists() || files.iter().any(|f| f.contains(marker)) {
            return "infrastructure".into();
        }
    }
    if files.iter().any(|f| f.ends_with(".tf")) {
        return "infrastructure".into();
    }

    // Fallback
    if files.len() < 5 { "minimal".into() } else { "application".into() }
}

fn detect_maturity(target: &Path) -> String {
    let commit_count = Command::new("git")
        .args(["rev-list", "--count", "HEAD"])
        .current_dir(target)
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .and_then(|s| s.trim().parse::<u64>().ok())
        .unwrap_or(0);

    let has_ci = target.join(".github/workflows").is_dir()
        || target.join(".gitlab-ci.yml").exists()
        || target.join(".circleci").is_dir()
        || target.join("Jenkinsfile").exists();

    if commit_count < 20 {
        "greenfield".into()
    } else if has_ci && commit_count > 200 {
        "mature".into()
    } else if has_ci {
        "active".into()
    } else if commit_count > 100 {
        "legacy".into()
    } else {
        "established".into()
    }
}

fn detect_complexity(files: &[String]) -> String {
    let count = files.len();

    // Complexity signals beyond just file count
    let has_docker = files.iter().any(|f| f == "Dockerfile" || f == "docker-compose.yml");
    let has_ci = files.iter().any(|f| f.contains(".github/workflows/") || f.contains(".gitlab-ci"));
    let has_multiple_languages = {
        let mut exts = std::collections::HashSet::new();
        for f in files {
            if let Some(ext) = std::path::Path::new(f).extension().and_then(|e| e.to_str()) {
                if matches!(ext, "ts" | "js" | "py" | "rs" | "go" | "rb" | "java" | "cs" | "php") {
                    exts.insert(ext);
                }
            }
        }
        exts.len() >= 2
    };
    let has_monorepo = files.iter().any(|f| f == "turbo.json" || f == "lerna.json" || f == "nx.json");
    let pkg_json_count = files.iter().filter(|f| f.ends_with("package.json")).count();

    // Score-based complexity
    let mut score = 0;
    score += count.min(500) / 10; // file count contribution (max 50)
    if has_docker { score += 10; }
    if has_ci { score += 10; }
    if has_multiple_languages { score += 15; }
    if has_monorepo { score += 20; }
    if pkg_json_count >= 3 { score += 15; } // multiple packages

    if score < 10 {
        "simple".into()
    } else if score < 30 {
        "moderate".into()
    } else if score < 60 {
        "complex".into()
    } else {
        "enterprise".into()
    }
}

/// Check if any known dependency file contains a substring match.
fn has_dependency_match(target: &Path, _files: &[String], patterns: &[&str]) -> bool {
    // Check package.json dependencies
    if let Some(pkg) = read_json(target, "package.json") {
        for section in ["dependencies", "devDependencies"] {
            if let Some(deps) = pkg.get(section).and_then(|d| d.as_object()) {
                for key in deps.keys() {
                    if patterns.iter().any(|p| key.contains(p)) {
                        return true;
                    }
                }
            }
        }
    }
    // Check pyproject.toml / requirements.txt
    for req_file in &["requirements.txt", "requirements-dev.txt", "Pipfile"] {
        if let Ok(content) = std::fs::read_to_string(target.join(req_file)) {
            let lower = content.to_lowercase();
            if patterns.iter().any(|p| lower.contains(p)) {
                return true;
            }
        }
    }
    // Check Cargo.toml
    if let Ok(content) = std::fs::read_to_string(target.join("Cargo.toml")) {
        let lower = content.to_lowercase();
        if patterns.iter().any(|p| lower.contains(p)) {
            return true;
        }
    }
    false
}

fn read_json(target: &Path, filename: &str) -> Option<Value> {
    std::fs::read_to_string(target.join(filename))
        .ok()
        .and_then(|c| serde_json::from_str(&c).ok())
}
