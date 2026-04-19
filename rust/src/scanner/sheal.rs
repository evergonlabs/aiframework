use serde_json::{json, Value};
use std::path::Path;

/// Detect sheal (runtime session intelligence) installation and state.
pub fn scan(target: &Path, files: &[String]) -> Value {
    // Check if sheal is installed globally
    let installed = std::process::Command::new("sheal")
        .arg("--version")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);

    let version = if installed {
        std::process::Command::new("sheal")
            .arg("--version")
            .output()
            .ok()
            .and_then(|o| {
                String::from_utf8(o.stdout)
                    .ok()
                    .map(|s| s.trim().to_string())
            })
            .unwrap_or_default()
    } else {
        String::new()
    };

    // Check for vault directory
    let vault_exists = target.join("vault").exists();

    // Check for .sheal config
    let config_exists = files.iter().any(|f| f.starts_with(".sheal/") || f == ".sheal.json");

    // Check for learnings file
    let has_learnings = files.iter().any(|f| f.contains("learnings") && f.ends_with(".jsonl"));

    json!({
        "installed": installed,
        "version": version,
        "vault_exists": vault_exists,
        "config_exists": config_exists,
        "has_learnings": has_learnings,
    })
}
