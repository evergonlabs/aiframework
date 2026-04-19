pub mod data;
pub mod graph;
pub mod metrics;
pub mod parse;
pub mod parsers;
pub mod registry;

use std::collections::HashMap;
use std::path::Path;
use std::time::Instant;

use rayon::prelude::*;
use serde_json::{json, Map, Value};

use self::graph::{build_graph, compute_pagerank};
use self::registry::get_parser;

const MAX_FILE_SIZE: u64 = 512 * 1024; // 512 KB
const VERSION: &str = "2.0.0";

/// Index a repository: walk files, parse symbols/imports, build edges, compute PageRank.
/// Returns a JSON Value matching the Python indexer's code-index.json schema.
pub fn index_repo(target: &Path) -> Result<Value, Box<dyn std::error::Error>> {
    let start = Instant::now();
    let target = target.canonicalize()?;

    // Walk files respecting .gitignore but including dotdirs like .githooks/
    let walker = ignore::WalkBuilder::new(&target)
        .hidden(false) // include dotfiles — we filter .git/ manually
        .git_ignore(true)
        .git_global(true)
        .git_exclude(true)
        .build();

    let entries: Vec<_> = walker
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().map_or(false, |ft| ft.is_file()))
        .filter(|e| {
            e.metadata()
                .map_or(false, |m| m.len() <= MAX_FILE_SIZE)
        })
        .collect();

    // Parse files in parallel
    let parsed: Vec<_> = entries
        .par_iter()
        .filter_map(|entry| {
            let path = entry.path();
            let rel = path.strip_prefix(&target).ok()?;
            let rel_str = rel.to_str()?;

            // Skip .git/ and common non-source dirs
            if rel_str.starts_with(".git/")
                || rel_str.starts_with("node_modules/")
                || rel_str.starts_with("vendor/")
                || rel_str.starts_with("__pycache__/")
                || rel_str.contains("/target/")
                || rel_str.starts_with("target/")
                || rel_str.starts_with("dist/")
            {
                return None;
            }

            // Get extension, or detect from shebang for extensionless files
            let ext_string = match path.extension().and_then(|e| e.to_str()) {
                Some(e) => e.to_string(),
                None => {
                    // Try to detect language from shebang
                    let first_bytes = std::fs::read(path).ok()?;
                    let first_line = std::str::from_utf8(&first_bytes)
                        .ok()
                        .and_then(|s| s.lines().next());
                    match first_line {
                        Some(l) if l.contains("/bash") || l.contains("/sh") || l.contains("env bash") || l.contains("env sh") => "sh".to_string(),
                        Some(l) if l.contains("python") => "py".to_string(),
                        Some(l) if l.contains("ruby") => "rb".to_string(),
                        Some(l) if l.contains("node") => "js".to_string(),
                        _ => return None,
                    }
                }
            };
            let parser = get_parser(&ext_string)?;

            let content = std::fs::read_to_string(path).ok()?;

            // Skip binary files (contain null bytes)
            if content.contains('\0') {
                return None;
            }

            let lines = count_lines(&content);
            let size = content.len() as u64;
            let (symbols, imports, exports) = parser(&content, rel_str);
            let file_metrics = metrics::compute_file_metrics(&content);

            Some(parse::FileData {
                path: rel_str.to_string(),
                language: registry::ext_to_language(&ext_string).to_string(),
                size_bytes: size,
                lines,
                symbols,
                imports,
                exports,
                complexity: file_metrics.complexity,
                logical_loc: file_metrics.logical_loc,
                patterns: file_metrics.patterns.iter().map(|s| s.to_string()).collect(),
            })
        })
        .collect();

    // Build files map
    let mut files_map: Map<String, Value> = Map::new();
    let mut all_symbols: Vec<Value> = Vec::new();
    let mut lang_counts: HashMap<String, usize> = HashMap::new();

    for file in &parsed {
        *lang_counts.entry(file.language.clone()).or_insert(0) += 1;

        let sym_values: Vec<Value> = file
            .symbols
            .iter()
            .map(|s| {
                let mut m = json!({
                    "name": s.name,
                    "kind": s.kind,
                    "file": file.path,
                    "line": s.line,
                    "signature": s.signature,
                    "visibility": s.visibility,
                });
                if !s.docstring.is_empty() {
                    m["docstring"] = json!(s.docstring);
                }
                if let Some(ref parent) = s.parent {
                    m["parent"] = json!(parent);
                }
                m
            })
            .collect();

        all_symbols.extend(sym_values.clone());

        let import_values: Vec<Value> = file.imports.iter().map(|i| json!(i)).collect();
        let export_values: Vec<Value> = file.exports.iter().map(|e| json!(e)).collect();

        let mut file_json = json!({
            "language": file.language,
            "size_bytes": file.size_bytes,
            "lines": file.lines,
            "symbols": sym_values,
            "imports": import_values,
            "exports": export_values,
            "complexity": file.complexity,
            "logical_loc": file.logical_loc,
        });

        if !file.patterns.is_empty() {
            file_json["patterns"] = json!(file.patterns);
        }

        files_map.insert(file.path.clone(), file_json);
    }

    // Build dependency graph edges and modules
    let files_value = Value::Object(files_map.clone());
    let (edges, modules) = build_graph(&files_value);

    // Compute PageRank importance scores
    let importance = compute_pagerank(&edges, &files_value);

    // Inject importance into files
    for file in &parsed {
        if let Some(entry) = files_map.get_mut(&file.path) {
            let score = importance.get(&file.path).copied().unwrap_or(0);
            entry["importance"] = json!(score);
        }
    }

    // Top files by importance
    let mut top_files: Vec<_> = importance.iter().collect();
    top_files.sort_by(|a, b| b.1.cmp(a.1));
    let top_files_json: Vec<Value> = top_files
        .iter()
        .take(20)
        .map(|(path, score)| json!({"file": path, "importance": score}))
        .collect();

    let elapsed = start.elapsed().as_millis() as u64;

    let result = json!({
        "_meta": {
            "generated_at": chrono_now(),
            "indexer_version": VERSION,
            "target_dir": target.to_str().unwrap_or(""),
            "total_files": parsed.len(),
            "total_symbols": all_symbols.len(),
            "total_edges": edges.len(),
            "languages": lang_counts,
            "elapsed_ms": elapsed,
            "top_files": top_files_json,
        },
        "files": files_map,
        "symbols": all_symbols,
        "edges": edges,
        "modules": modules,
    });

    Ok(result)
}

fn count_lines(text: &str) -> usize {
    if text.is_empty() {
        return 0;
    }
    text.chars().filter(|&c| c == '\n').count() + if text.ends_with('\n') { 0 } else { 1 }
}

/// ISO 8601 timestamp without pulling in chrono crate
fn chrono_now() -> String {
    use std::time::SystemTime;
    let dur = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default();
    let secs = dur.as_secs();
    // Basic UTC timestamp
    let days = secs / 86400;
    let time_secs = secs % 86400;
    let hours = time_secs / 3600;
    let mins = (time_secs % 3600) / 60;
    let s = time_secs % 60;

    // Days since epoch to Y-M-D (simplified)
    let mut y = 1970i64;
    let mut remaining = days as i64;
    loop {
        let days_in_year = if is_leap(y) { 366 } else { 365 };
        if remaining < days_in_year {
            break;
        }
        remaining -= days_in_year;
        y += 1;
    }
    let month_days: [i64; 12] = if is_leap(y) {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    };
    let mut m = 0usize;
    for (i, &d) in month_days.iter().enumerate() {
        if remaining < d {
            m = i;
            break;
        }
        remaining -= d;
    }
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
        y,
        m + 1,
        remaining + 1,
        hours,
        mins,
        s
    )
}

fn is_leap(y: i64) -> bool {
    (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
}
