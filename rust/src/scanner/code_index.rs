use serde_json::{json, Value};
use std::path::Path;

/// Record code index metadata in the manifest.
/// The actual indexing is done by the indexer module — this scanner
/// just records what method was used and the result path.
pub fn scan(target: &Path, _files: &[String]) -> Value {
    let index_path = target.join(".aiframework/code-index.json");

    if index_path.exists() {
        // Read existing index metadata
        if let Ok(content) = std::fs::read_to_string(&index_path) {
            if let Ok(index) = serde_json::from_str::<Value>(&content) {
                let file_count = index["_meta"]["total_files"].as_u64().unwrap_or(0);
                return json!({
                    "file_count": file_count,
                    "index_path": ".aiframework/code-index.json",
                    "method": "indexed",
                });
            }
        }
    }

    json!({
        "file_count": 0,
        "index_path": ".aiframework/code-index.json",
        "method": "pending",
    })
}
