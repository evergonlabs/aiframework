use serde_json::{json, Value};
use std::path::Path;

/// Scan for environment variables from .env files, Dockerfiles, and compose files.
pub fn scan(target: &Path, _files: &[String]) -> Value {
    let mut vars: Vec<Value> = Vec::new();
    let mut seen: Vec<String> = Vec::new();

    // Priority 1: .env.example / .env.template / .env.sample
    for env_file in &[".env.example", ".env.template", ".env.sample"] {
        let path = target.join(env_file);
        if let Ok(content) = std::fs::read_to_string(&path) {
            parse_env_file(&content, env_file, &mut vars, &mut seen);
            break;
        }
    }

    // Priority 2: Dockerfile ENV and ARG directives
    parse_dockerfile(target, &mut vars, &mut seen);

    // Priority 3: docker-compose environment
    parse_compose(target, &mut vars, &mut seen);

    json!({
        "variables": vars,
    })
}

fn parse_env_file(content: &str, source: &str, vars: &mut Vec<Value>, seen: &mut Vec<String>) {
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        if let Some(eq_pos) = trimmed.find('=') {
            let name = trimmed[..eq_pos].trim();
            if !is_env_var_name(name) { continue; }
            if seen.contains(&name.to_string()) { continue; }

            let value = trimmed[eq_pos + 1..].trim().trim_matches('"').trim_matches('\'');
            let is_sensitive = is_sensitive_name(name);

            seen.push(name.to_string());
            vars.push(json!({
                "name": name,
                "source": source,
                "is_sensitive": is_sensitive,
                "default": if value.is_empty() { Value::Null } else { json!(value) },
            }));
        }
    }
}

fn parse_dockerfile(target: &Path, vars: &mut Vec<Value>, seen: &mut Vec<String>) {
    let path = target.join("Dockerfile");
    let content = match std::fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => return,
    };

    for line in content.lines() {
        let trimmed = line.trim();
        // Match ENV VAR_NAME=value or ARG VAR_NAME=value
        let directive = if trimmed.starts_with("ENV ") {
            Some(&trimmed[4..])
        } else if trimmed.starts_with("ARG ") {
            Some(&trimmed[4..])
        } else {
            None
        };

        if let Some(rest) = directive {
            let name = rest.split(|c: char| c == '=' || c.is_whitespace()).next().unwrap_or("");
            if !is_env_var_name(name) { continue; }
            if seen.contains(&name.to_string()) { continue; }

            seen.push(name.to_string());
            vars.push(json!({
                "name": name,
                "source": "Dockerfile",
                "is_sensitive": is_sensitive_name(name),
                "default": Value::Null,
            }));
        }
    }
}

fn parse_compose(target: &Path, vars: &mut Vec<Value>, seen: &mut Vec<String>) {
    let compose_files = ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"];
    let content = compose_files.iter()
        .find_map(|f| std::fs::read_to_string(target.join(f)).ok());

    let content = match content {
        Some(c) => c,
        None => return,
    };

    // Extract ${VAR_NAME} references
    let re = regex::Regex::new(r"\$\{([A-Z_][A-Z0-9_]*)").unwrap();
    for cap in re.captures_iter(&content) {
        let name = &cap[1];
        if seen.contains(&name.to_string()) { continue; }

        seen.push(name.to_string());
        vars.push(json!({
            "name": name,
            "source": "docker-compose",
            "is_sensitive": is_sensitive_name(name),
            "default": Value::Null,
        }));
    }
}

fn is_env_var_name(name: &str) -> bool {
    if name.is_empty() { return false; }
    let first = name.as_bytes()[0];
    if !first.is_ascii_uppercase() && first != b'_' { return false; }
    name.bytes().all(|b| b.is_ascii_uppercase() || b.is_ascii_digit() || b == b'_')
}

fn is_sensitive_name(name: &str) -> bool {
    let upper = name.to_uppercase();
    ["SECRET", "KEY", "TOKEN", "PASSWORD", "PRIVATE", "CREDENTIAL"]
        .iter()
        .any(|s| upper.contains(s))
}
