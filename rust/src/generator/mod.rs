pub mod claude_md;

use serde_json::Value;
use std::path::Path;

/// Generate all output files from a manifest + code index.
pub fn generate(
    target: &Path,
    manifest: &Value,
    code_index: Option<&Value>,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mut generated = Vec::new();

    // CLAUDE.md — the most important output
    let claude_md = claude_md::generate(manifest, code_index);
    let claude_path = target.join("CLAUDE.md");
    std::fs::write(&claude_path, &claude_md)?;
    generated.push("CLAUDE.md".into());

    Ok(generated)
}
