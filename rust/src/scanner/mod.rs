pub mod archetype;
pub mod ci;
pub mod code_index;
pub mod commands;
pub mod domain;
pub mod env;
pub mod identity;
pub mod quality;
pub mod sheal;
pub mod skill_suggest;
pub mod stack;
pub mod structure;
pub mod user_context;

use serde_json::{json, Value};
use std::path::Path;

/// Run all 13 scanners and produce a complete manifest.
pub fn discover(target: &Path) -> Result<Value, Box<dyn std::error::Error>> {
    let target = target.canonicalize()?;

    // Collect file list for detection
    let files = collect_files(&target)?;
    let file_names: Vec<String> = files.iter().map(|f| f.to_string()).collect();

    // Run all scanners
    let identity = identity::scan(&target, &file_names);
    let stack = stack::scan(&target, &file_names);
    let commands = commands::scan(&target, &file_names, &stack);
    let structure = structure::scan(&target, &file_names);
    let archetype = archetype::scan(&target, &file_names);
    let ci_data = ci::scan(&target, &file_names);
    let domain = domain::scan(&target, &file_names);
    let env_data = env::scan(&target, &file_names);
    let quality = quality::scan(&target, &file_names);
    let user_context = user_context::scan(&target, &file_names);
    let skill_suggestions = skill_suggest::scan(&target, &file_names);
    let code_index_meta = code_index::scan(&target, &file_names);
    let sheal_data = sheal::scan(&target, &file_names);

    let manifest = json!({
        "identity": identity,
        "stack": stack,
        "commands": commands,
        "structure": structure,
        "archetype": archetype,
        "ci": ci_data,
        "domain": domain,
        "env": env_data,
        "quality": quality,
        "user_context": user_context,
        "skill_suggestions": skill_suggestions,
        "code_index": code_index_meta,
        "sheal": sheal_data,
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
