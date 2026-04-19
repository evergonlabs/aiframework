use serde_json::{json, Value};
use std::path::Path;

/// Scan for user context: repo ownership, contact, maintenance status.
pub fn scan(target: &Path, _files: &[String]) -> Value {
    let git_config = target.join(".git/config");
    let mut contact = String::new();
    let mut owner_email = String::new();

    if git_config.exists() {
        if let Ok(content) = std::fs::read_to_string(&git_config) {
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.starts_with("email = ") {
                    owner_email = trimmed.trim_start_matches("email = ").to_string();
                }
            }
        }
    }

    // Try to get git user name
    if let Ok(output) = std::process::Command::new("git")
        .args(["config", "user.name"])
        .current_dir(target)
        .output()
    {
        if output.status.success() {
            contact = String::from_utf8_lossy(&output.stdout).trim().to_string();
        }
    }

    // Maintenance status heuristic: check last commit date
    let maintained = if let Ok(output) = std::process::Command::new("git")
        .args(["log", "-1", "--format=%ct"])
        .current_dir(target)
        .output()
    {
        if output.status.success() {
            let timestamp_str = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if let Ok(ts) = timestamp_str.parse::<u64>() {
                let now = std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs();
                // Consider maintained if last commit was within 90 days
                now - ts < 90 * 24 * 3600
            } else {
                true
            }
        } else {
            true
        }
    } else {
        true
    };

    json!({
        "contact": contact,
        "owner_email": owner_email,
        "maintained": maintained,
    })
}
