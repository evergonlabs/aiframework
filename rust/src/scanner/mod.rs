pub mod identity;
pub mod stack;
pub mod commands;
pub mod structure;

use serde_json::{json, Value};
use std::path::Path;

/// Run all scanners and produce a manifest.
pub fn discover(target: &Path) -> Result<Value, Box<dyn std::error::Error>> {
    let target = target.canonicalize()?;

    // Collect file list for detection
    let files = collect_files(&target)?;
    let file_names: Vec<String> = files.iter().map(|f| f.to_string()).collect();

    // Run scanners
    let identity = identity::scan(&target, &file_names);
    let stack = stack::scan(&target, &file_names);
    let commands = commands::scan(&target, &file_names, &stack);
    let structure = structure::scan(&target, &file_names);

    let manifest = json!({
        "identity": identity,
        "stack": stack,
        "commands": commands,
        "structure": structure,
    });

    Ok(manifest)
}

/// Collect all relative file paths in the repo.
fn collect_files(target: &Path) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mut files = Vec::new();
    let walker = ignore::WalkBuilder::new(target)
        .hidden(false)
        .git_ignore(true)
        .build();

    for entry in walker {
        let entry = entry?;
        if !entry.file_type().map_or(false, |ft| ft.is_file()) {
            continue;
        }
        let path = entry.path();
        if let Ok(rel) = path.strip_prefix(target) {
            let rel_str = rel.to_string_lossy().to_string();
            if rel_str.starts_with(".git/") {
                continue;
            }
            files.push(rel_str);
        }
    }
    Ok(files)
}
