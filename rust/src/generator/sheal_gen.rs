use serde_json::Value;
use std::path::Path;

/// Generate .sheal/ configuration for runtime session intelligence.
/// Creates config.json and templates/ directory.
pub fn generate(
    target: &Path,
    manifest: &Value,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mut created = Vec::new();

    let sheal_dir = target.join(".sheal");

    // Skip if .sheal/ already exists
    if sheal_dir.exists() {
        return Ok(created);
    }

    std::fs::create_dir_all(&sheal_dir)?;

    let name = manifest["identity"]["name"]
        .as_str()
        .unwrap_or("project");
    let language = manifest["stack"]["language"]
        .as_str()
        .unwrap_or("unknown");

    // Extract test command
    let test_cmd = manifest["commands"]["test"]
        .as_str()
        .or_else(|| manifest["commands"]["test"]["run"].as_str())
        .unwrap_or("");

    // Extract lint command
    let lint_cmd = manifest["commands"]["lint"]
        .as_str()
        .or_else(|| manifest["commands"]["lint"]["run"].as_str())
        .unwrap_or("");

    // Extract build command
    let build_cmd = manifest["commands"]["build"]
        .as_str()
        .or_else(|| manifest["commands"]["build"]["run"].as_str())
        .unwrap_or("");

    // Build config JSON
    let config = serde_json::json!({
        "project": name,
        "language": language,
        "commands": {
            "test": test_cmd,
            "lint": lint_cmd,
            "build": build_cmd
        },
        "session": {
            "auto_check": true,
            "auto_retro": false
        },
        "learnings": {
            "dir": ".sheal/learnings",
            "max_active": 50
        }
    });

    let config_path = sheal_dir.join("config.json");
    let config_json = serde_json::to_string_pretty(&config)?;
    std::fs::write(&config_path, &config_json)?;
    created.push(".sheal/config.json".into());

    // Create templates directory
    let templates_dir = sheal_dir.join("templates");
    std::fs::create_dir_all(&templates_dir)?;
    created.push(".sheal/templates/".into());

    // Create learnings directory
    let learnings_dir = sheal_dir.join("learnings");
    std::fs::create_dir_all(&learnings_dir)?;
    created.push(".sheal/learnings/".into());

    Ok(created)
}
