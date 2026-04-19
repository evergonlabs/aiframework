use serde_json::{json, Value};
use std::path::Path;

/// Scan for project identity: name, version, description.
pub fn scan(target: &Path, _files: &[String]) -> Value {
    let name = detect_name(target);
    let version = detect_version(target);
    let description = detect_description(target);
    let short_name = to_short_name(&name);

    json!({
        "name": name,
        "short_name": short_name,
        "version": version,
        "description": description,
    })
}

fn detect_name(target: &Path) -> String {
    // Try package.json
    let pkg_json = target.join("package.json");
    if pkg_json.exists() {
        if let Ok(content) = std::fs::read_to_string(&pkg_json) {
            if let Ok(pkg) = serde_json::from_str::<Value>(&content) {
                if let Some(name) = pkg["name"].as_str() {
                    return name.to_string();
                }
            }
        }
    }

    // Try Cargo.toml
    let cargo_toml = target.join("Cargo.toml");
    if cargo_toml.exists() {
        if let Ok(content) = std::fs::read_to_string(&cargo_toml) {
            if let Some(name) = extract_toml_value(&content, "name") {
                return name;
            }
        }
    }

    // Try pyproject.toml
    let pyproject = target.join("pyproject.toml");
    if pyproject.exists() {
        if let Ok(content) = std::fs::read_to_string(&pyproject) {
            if let Some(name) = extract_toml_value(&content, "name") {
                return name;
            }
        }
    }

    // Fallback: directory name
    target
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string()
}

fn detect_version(target: &Path) -> String {
    // VERSION file
    let version_file = target.join("VERSION");
    if version_file.exists() {
        if let Ok(v) = std::fs::read_to_string(&version_file) {
            let v = v.trim();
            if !v.is_empty() {
                return v.to_string();
            }
        }
    }

    // package.json
    let pkg_json = target.join("package.json");
    if pkg_json.exists() {
        if let Ok(content) = std::fs::read_to_string(&pkg_json) {
            if let Ok(pkg) = serde_json::from_str::<Value>(&content) {
                if let Some(v) = pkg["version"].as_str() {
                    return v.to_string();
                }
            }
        }
    }

    // Cargo.toml
    let cargo_toml = target.join("Cargo.toml");
    if cargo_toml.exists() {
        if let Ok(content) = std::fs::read_to_string(&cargo_toml) {
            if let Some(v) = extract_toml_value(&content, "version") {
                return v;
            }
        }
    }

    // pyproject.toml
    let pyproject = target.join("pyproject.toml");
    if pyproject.exists() {
        if let Ok(content) = std::fs::read_to_string(&pyproject) {
            if let Some(v) = extract_toml_value(&content, "version") {
                return v;
            }
        }
    }

    "0.0.0".to_string()
}

/// Extract a value from a TOML file (simple key = "value" parsing).
fn extract_toml_value(content: &str, key: &str) -> Option<String> {
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with(key) {
            if let Some(val) = trimmed.split('=').nth(1) {
                let v = val.trim().trim_matches('"').trim_matches('\'');
                if !v.is_empty() {
                    return Some(v.to_string());
                }
            }
        }
    }
    None
}

fn detect_description(target: &Path) -> String {
    // package.json
    let pkg_json = target.join("package.json");
    if pkg_json.exists() {
        if let Ok(content) = std::fs::read_to_string(&pkg_json) {
            if let Ok(pkg) = serde_json::from_str::<Value>(&content) {
                if let Some(d) = pkg["description"].as_str() {
                    return d.to_string();
                }
            }
        }
    }

    // First line of README.md
    let readme = target.join("README.md");
    if readme.exists() {
        if let Ok(content) = std::fs::read_to_string(&readme) {
            for line in content.lines().skip(1) {
                let trimmed = line.trim();
                if !trimmed.is_empty() && !trimmed.starts_with('#') && !trimmed.starts_with("![") && !trimmed.starts_with('<') && !trimmed.starts_with('[') && !trimmed.starts_with("---") {
                    return trimmed.chars().take(200).collect();
                }
            }
        }
    }

    String::new()
}

fn to_short_name(name: &str) -> String {
    name.to_lowercase()
        .replace(' ', "-")
        .replace('_', "-")
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == '-')
        .collect()
}
