use serde_json::{json, Value};
use std::path::Path;

/// Scan for project identity: name, version, description.
pub fn scan(target: &Path, _files: &[String]) -> Value {
    let name = detect_name(target);
    let version = detect_version(target);
    let description = detect_description(target);
    let short_name = to_short_name(&name);

    let compose_services = detect_compose_services(target);
    let dockerfile = detect_dockerfile(target);

    json!({
        "name": name,
        "short_name": short_name,
        "short": short_name,  // bash compat alias
        "version": version,
        "description": description,
        "compose_services": compose_services,
        "dockerfile": dockerfile,
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

fn detect_compose_services(target: &Path) -> Vec<String> {
    for name in &["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"] {
        let path = target.join(name);
        if path.exists() {
            if let Ok(content) = std::fs::read_to_string(&path) {
                let mut services = Vec::new();
                let mut in_services = false;
                for line in content.lines() {
                    let trimmed = line.trim();
                    // Top-level "services:" key (no leading whitespace)
                    if !line.starts_with(' ') && !line.starts_with('\t') && trimmed.starts_with("services:") {
                        in_services = true;
                        continue;
                    }
                    // Another top-level key ends the services block
                    if in_services && !line.starts_with(' ') && !line.starts_with('\t') && !trimmed.is_empty() {
                        break;
                    }
                    // Service names are indented exactly one level and end with ':'
                    if in_services && trimmed.ends_with(':') && !trimmed.starts_with('#') {
                        // Check it's a direct child (2-space or 4-space indent, not deeper nested key)
                        let indent = line.len() - line.trim_start().len();
                        if indent > 0 && indent <= 4 {
                            let svc = trimmed.trim_end_matches(':').trim();
                            if !svc.is_empty() {
                                services.push(svc.to_string());
                            }
                        }
                    }
                }
                return services;
            }
        }
    }
    vec![]
}

fn detect_dockerfile(target: &Path) -> Value {
    let dockerfile = target.join("Dockerfile");
    if !dockerfile.exists() {
        return Value::Null;
    }

    let content = match std::fs::read_to_string(&dockerfile) {
        Ok(c) => c,
        Err(_) => return Value::Null,
    };

    let mut base_image = String::new();
    let mut exposed_port = String::new();

    for line in content.lines() {
        let trimmed = line.trim();
        if base_image.is_empty() && trimmed.to_uppercase().starts_with("FROM ") {
            base_image = trimmed[5..].split_whitespace().next().unwrap_or("").to_string();
        }
        if trimmed.to_uppercase().starts_with("EXPOSE ") {
            exposed_port = trimmed[7..].split_whitespace().next().unwrap_or("").to_string();
        }
    }

    json!({
        "base_image": base_image,
        "exposed_port": exposed_port,
    })
}

fn to_short_name(name: &str) -> String {
    name.to_lowercase()
        .replace(' ', "-")
        .replace('_', "-")
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == '-')
        .collect()
}
