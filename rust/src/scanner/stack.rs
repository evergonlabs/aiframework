use serde_json::{json, Value};
use std::path::Path;

use crate::indexer::data;

/// Scan for stack: language, framework, monorepo, key deps.
pub fn scan(target: &Path, files: &[String]) -> Value {
    // Detect primary language using data registry
    let (language, lang_entry) = data::detect_language(files)
        .map(|(l, e)| (l, Some(e)))
        .unwrap_or_else(|| ("unknown".to_string(), None));

    // Detect all languages present
    let languages = detect_all_languages(files);

    // Detect framework
    let framework = lang_entry
        .and_then(|entry| {
            // Read a few key files for content-based detection
            let mut contents = std::collections::HashMap::new();
            for f in ["package.json", "Cargo.toml", "requirements.txt", "go.mod", "Gemfile", "composer.json"] {
                let path = target.join(f);
                if let Ok(content) = std::fs::read_to_string(&path) {
                    contents.insert(f.to_string(), content);
                }
            }
            data::detect_framework(entry, files, &contents)
        })
        .unwrap_or_else(|| "none".to_string());

    // Monorepo detection
    let is_monorepo = detect_monorepo(files);
    let monorepo_tool = if is_monorepo {
        detect_monorepo_tool(target)
    } else {
        "none".to_string()
    };

    // Key dependencies
    let key_deps = detect_key_deps(target);

    json!({
        "language": language,
        "languages": languages,
        "framework": framework,
        "is_monorepo": is_monorepo,
        "monorepo_tool": monorepo_tool,
        "key_dependencies": key_deps,
    })
}

fn detect_all_languages(files: &[String]) -> Vec<String> {
    let mut langs = std::collections::HashSet::new();

    for file in files {
        if let Some(ext) = Path::new(file).extension().and_then(|e| e.to_str()) {
            let lang = match ext {
                "py" => "python",
                "ts" | "tsx" => "typescript",
                "js" | "jsx" | "mjs" | "cjs" => "javascript",
                "go" => "go",
                "rs" => "rust",
                "rb" => "ruby",
                "java" => "java",
                "cs" => "csharp",
                "php" => "php",
                "kt" | "kts" => "kotlin",
                "swift" => "swift",
                "ex" | "exs" => "elixir",
                "sh" | "bash" => "bash",
                _ => continue,
            };
            langs.insert(lang.to_string());
        }
    }

    let mut result: Vec<String> = langs.into_iter().collect();
    result.sort();
    result
}

fn detect_monorepo(files: &[String]) -> bool {
    for f in files {
        let name = Path::new(f)
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("");
        if matches!(name, "turbo.json" | "lerna.json" | "nx.json" | "pnpm-workspace.yaml") {
            return true;
        }
    }
    // Check for packages/ or apps/ directories with multiple package.json
    let pkg_count = files
        .iter()
        .filter(|f| {
            f.ends_with("package.json") && f.contains('/')
                && !f.starts_with("node_modules/")
        })
        .count();
    pkg_count >= 3
}

fn detect_monorepo_tool(target: &Path) -> String {
    if target.join("turbo.json").exists() { return "turborepo".into(); }
    if target.join("lerna.json").exists() { return "lerna".into(); }
    if target.join("nx.json").exists() { return "nx".into(); }
    if target.join("pnpm-workspace.yaml").exists() { return "pnpm-workspaces".into(); }
    "unknown".into()
}

fn detect_key_deps(target: &Path) -> Vec<String> {
    let mut deps = Vec::new();

    // package.json dependencies
    let pkg_json = target.join("package.json");
    if pkg_json.exists() {
        if let Ok(content) = std::fs::read_to_string(&pkg_json) {
            if let Ok(pkg) = serde_json::from_str::<Value>(&content) {
                if let Some(d) = pkg["dependencies"].as_object() {
                    deps.extend(d.keys().take(20).map(|k| k.clone()));
                }
            }
        }
    }

    // requirements.txt
    let req_txt = target.join("requirements.txt");
    if req_txt.exists() {
        if let Ok(content) = std::fs::read_to_string(&req_txt) {
            for line in content.lines().take(20) {
                let dep = line.split(&['=', '>', '<', '[', ';'][..]).next().unwrap_or("").trim();
                if !dep.is_empty() && !dep.starts_with('#') && !dep.starts_with('-') {
                    deps.push(dep.to_string());
                }
            }
        }
    }

    deps
}
