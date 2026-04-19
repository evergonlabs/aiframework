use serde_json::{json, Value};
use std::path::Path;

fn count_jsonl_lines(dir: &Path) -> usize {
    if !dir.is_dir() {
        return 0;
    }
    let mut count = 0;
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|e| e.to_str()) == Some("jsonl") {
                if let Ok(content) = std::fs::read_to_string(&path) {
                    count += content.lines().filter(|l| !l.trim().is_empty()).count();
                }
            }
        }
    }
    count
}

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

    // New fields
    let initialized = target.join(".sheal/config.json").exists();
    let project_learnings_count = count_jsonl_lines(&target.join("tools/learnings"));
    let global_learnings_count = dirs::home_dir()
        .map(|h| count_jsonl_lines(&h.join(".sheal/learnings")))
        .unwrap_or(0);
    let has_rules_block = target.join(".claude/rules").is_dir()
        && std::fs::read_dir(target.join(".claude/rules"))
            .map(|mut d| d.next().is_some())
            .unwrap_or(false);
    let has_retro_skill = target.join(".claude/skills").is_dir()
        && std::fs::read_dir(target.join(".claude/skills"))
            .map(|entries| {
                entries
                    .flatten()
                    .any(|e| {
                        e.file_name()
                            .to_str()
                            .map(|n| n.to_lowercase().contains("retro"))
                            .unwrap_or(false)
                    })
            })
            .unwrap_or(false);

    json!({
        "installed": installed,
        "version": version,
        "vault_exists": vault_exists,
        "config_exists": config_exists,
        "has_learnings": has_learnings,
        "initialized": initialized,
        "project_learnings_count": project_learnings_count,
        "global_learnings_count": global_learnings_count,
        "has_rules_block": has_rules_block,
        "has_retro_skill": has_retro_skill,
    })
}
