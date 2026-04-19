use serde_json::Value;
use std::path::Path;

/// Generate tools/learnings/{short_name}-learnings.jsonl for learning storage.
/// Returns the list of files created relative to target.
pub fn generate(
    target: &Path,
    manifest: &Value,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mut created = Vec::new();

    let short = str_or(manifest, &["identity", "short_name"], "project");

    let learnings_dir = target.join("tools/learnings");
    let jsonl_path = learnings_dir.join(format!("{short}-learnings.jsonl"));

    if jsonl_path.exists() {
        return Ok(created);
    }

    std::fs::create_dir_all(&learnings_dir)?;

    // Create empty JSONL file with a comment header (empty line = no entries yet)
    std::fs::write(&jsonl_path, "")?;
    created.push(format!("tools/learnings/{short}-learnings.jsonl"));

    Ok(created)
}

/// Navigate nested JSON safely.
fn str_or(value: &Value, path: &[&str], default: &str) -> String {
    let mut current = value;
    for key in path {
        current = &current[*key];
    }
    current.as_str().unwrap_or(default).to_string()
}
