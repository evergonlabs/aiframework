use std::collections::{HashMap, HashSet};

use serde_json::{json, Map, Value};

/// Build dependency edges from file imports.
/// Returns (edges, modules) matching the Python indexer's output.
pub fn build_graph(files: &Value) -> (Vec<Value>, Value) {
    let files_map = match files.as_object() {
        Some(m) => m,
        None => return (vec![], json!({})),
    };

    // Build a lookup: basename/partial-path → full relative path
    let mut path_lookup: HashMap<String, String> = HashMap::new();
    let mut stem_lookup: HashMap<String, Vec<String>> = HashMap::new();

    for path in files_map.keys() {
        path_lookup.insert(path.clone(), path.clone());

        // Also index by stem (filename without extension)
        if let Some(stem) = std::path::Path::new(path)
            .file_stem()
            .and_then(|s| s.to_str())
        {
            stem_lookup
                .entry(stem.to_string())
                .or_default()
                .push(path.clone());
        }

        // Index by path without extension
        if let Some(no_ext) = path.rsplit_once('.').map(|(p, _)| p.to_string()) {
            path_lookup.insert(no_ext, path.clone());
        }
    }

    let mut edges: Vec<Value> = Vec::new();
    let mut module_data: HashMap<String, ModuleInfo> = HashMap::new();

    // First pass: collect file info and resolved edges
    let mut resolved_edges: Vec<(String, String)> = Vec::new();

    for (source_path, file_data) in files_map {
        let source_dir = std::path::Path::new(source_path)
            .parent()
            .and_then(|p| p.to_str())
            .unwrap_or("")
            .to_string();

        let module = module_data.entry(source_dir.clone()).or_default();
        module.files.insert(source_path.clone());

        if let Some(syms) = file_data.get("symbols").and_then(|v| v.as_array()) {
            module.total_symbols += syms.len();
        }

        let imports = match file_data.get("imports").and_then(|v| v.as_array()) {
            Some(arr) => arr,
            None => continue,
        };

        for imp in imports {
            let import_str = match imp.as_str() {
                Some(s) => s,
                None => continue,
            };

            let target = resolve_import(import_str, source_path, &path_lookup, &stem_lookup);

            if let Some(target_path) = target {
                if target_path != *source_path {
                    resolved_edges.push((source_path.clone(), target_path));
                }
            }
        }
    }

    // Second pass: build edges and update fan_in/fan_out
    for (source_path, target_path) in &resolved_edges {
        edges.push(json!({
            "source": source_path,
            "target": target_path,
            "type": "import",
            "symbols": [],
        }));

        let source_dir = std::path::Path::new(source_path)
            .parent()
            .and_then(|p| p.to_str())
            .unwrap_or("")
            .to_string();
        let target_dir = std::path::Path::new(target_path)
            .parent()
            .and_then(|p| p.to_str())
            .unwrap_or("")
            .to_string();

        module_data.entry(source_dir).or_default().fan_out += 1;
        module_data.entry(target_dir).or_default().fan_in += 1;
    }

    // Detect circular dependencies between modules
    let mut module_edges: HashMap<String, HashSet<String>> = HashMap::new();
    for edge in &edges {
        let src = edge["source"].as_str().unwrap_or("");
        let tgt = edge["target"].as_str().unwrap_or("");
        let src_dir = std::path::Path::new(src)
            .parent()
            .and_then(|p| p.to_str())
            .unwrap_or("")
            .to_string();
        let tgt_dir = std::path::Path::new(tgt)
            .parent()
            .and_then(|p| p.to_str())
            .unwrap_or("")
            .to_string();
        if src_dir != tgt_dir {
            module_edges
                .entry(src_dir)
                .or_default()
                .insert(tgt_dir);
        }
    }

    // Build modules JSON
    let mut modules_map: Map<String, Value> = Map::new();
    for (dir, info) in &module_data {
        let mut files_vec: Vec<&str> = info.files.iter().map(|s| s.as_str()).collect();
        files_vec.sort();

        let role = infer_role(dir);

        let mut entry = json!({
            "files": files_vec,
            "role": role,
            "fan_in": info.fan_in,
            "fan_out": info.fan_out,
            "total_symbols": info.total_symbols,
        });

        // Check for circular deps
        if let Some(targets) = module_edges.get(dir) {
            let circular: Vec<&str> = targets
                .iter()
                .filter(|t| {
                    module_edges
                        .get(t.as_str())
                        .map_or(false, |back| back.contains(dir))
                })
                .map(|s| s.as_str())
                .collect();
            if !circular.is_empty() {
                entry["circular_deps"] = json!(circular);
            }
        }

        modules_map.insert(dir.clone(), entry);
    }

    (edges, Value::Object(modules_map))
}

/// Compute PageRank scores for files. Returns map of path → score (0-1000).
pub fn compute_pagerank(
    edges: &[Value],
    files: &Value,
) -> HashMap<String, u64> {
    let files_map = match files.as_object() {
        Some(m) => m,
        None => return HashMap::new(),
    };

    let n = files_map.len();
    if n == 0 {
        return HashMap::new();
    }

    let damping = 0.85_f64;
    let iterations = 20;

    // Build adjacency: target → [sources that import it]
    let mut incoming: HashMap<&str, Vec<&str>> = HashMap::new();
    let mut outgoing_count: HashMap<&str, usize> = HashMap::new();

    for edge in edges {
        let src = edge["source"].as_str().unwrap_or("");
        let tgt = edge["target"].as_str().unwrap_or("");
        if !src.is_empty() && !tgt.is_empty() {
            incoming.entry(tgt).or_default().push(src);
            *outgoing_count.entry(src).or_insert(0) += 1;
        }
    }

    // Initialize scores
    let init_score = 1.0 / n as f64;
    let mut scores: HashMap<&str, f64> = files_map
        .keys()
        .map(|k| (k.as_str(), init_score))
        .collect();

    // Iterate
    for _ in 0..iterations {
        let mut new_scores: HashMap<&str, f64> = HashMap::new();
        for path in files_map.keys() {
            let path_str = path.as_str();
            let mut rank = (1.0 - damping) / n as f64;

            if let Some(sources) = incoming.get(path_str) {
                for &src in sources {
                    let src_score = scores.get(src).copied().unwrap_or(0.0);
                    let src_out = *outgoing_count.get(src).unwrap_or(&1) as f64;
                    rank += damping * (src_score / src_out);
                }
            }

            new_scores.insert(path_str, rank);
        }
        scores = new_scores;
    }

    // Normalize to 0-1000 scale
    let max_score = scores
        .values()
        .copied()
        .fold(0.0_f64, f64::max);

    if max_score == 0.0 {
        return files_map
            .keys()
            .map(|k| (k.clone(), 0u64))
            .collect();
    }

    files_map
        .keys()
        .map(|k| {
            let score = scores.get(k.as_str()).copied().unwrap_or(0.0);
            let normalized = ((score / max_score) * 1000.0).round() as u64;
            (k.clone(), normalized)
        })
        .collect()
}

/// Resolve an import string to a known file path.
fn resolve_import(
    import: &str,
    source: &str,
    path_lookup: &HashMap<String, String>,
    stem_lookup: &HashMap<String, Vec<String>>,
) -> Option<String> {
    // Direct match (exact path)
    if let Some(path) = path_lookup.get(import) {
        return Some(path.clone());
    }

    // Try relative resolution from source directory
    let source_dir = std::path::Path::new(source)
        .parent()
        .and_then(|p| p.to_str())
        .unwrap_or("");

    if !source_dir.is_empty() {
        let relative = format!("{}/{}", source_dir, import);
        if let Some(path) = path_lookup.get(&relative) {
            return Some(path.clone());
        }
    }

    // Suffix match: "scanners/identity.sh" matches "lib/scanners/identity.sh"
    // This handles bash source patterns where $LIB_DIR is stripped
    if import.contains('/') {
        let suffix = format!("/{}", import);
        for known_path in path_lookup.values() {
            if known_path.ends_with(&suffix) {
                return Some(known_path.clone());
            }
        }
        // Also try without leading path component
        // e.g., "freshness/track.sh" matches "lib/freshness/track.sh"
        for known_path in path_lookup.values() {
            if known_path.ends_with(import) {
                return Some(known_path.clone());
            }
        }
    }

    // Try stem match (e.g., "utils" matches "lib/utils.py")
    if let Some(candidates) = stem_lookup.get(import) {
        if candidates.len() == 1 {
            return Some(candidates[0].clone());
        }
        // Prefer candidate closest to source
        let best = candidates
            .iter()
            .min_by_key(|c| {
                let common = common_prefix_len(source, c);
                usize::MAX - common
            });
        return best.cloned();
    }

    // Python module resolution: "lib.indexers.parse" → "lib/indexers/parse"
    if import.contains('.') {
        let as_path = import.replace('.', "/");
        if let Some(path) = path_lookup.get(&as_path) {
            return Some(path.clone());
        }
        // Also try suffix match on dotted paths
        let suffix = format!("/{}", as_path);
        for known_path in path_lookup.values() {
            if known_path.ends_with(&suffix) || known_path.ends_with(&as_path) {
                return Some(known_path.clone());
            }
        }
    }

    None
}

fn common_prefix_len(a: &str, b: &str) -> usize {
    a.chars().zip(b.chars()).take_while(|(x, y)| x == y).count()
}

#[derive(Default)]
struct ModuleInfo {
    files: HashSet<String>,
    fan_in: usize,
    fan_out: usize,
    total_symbols: usize,
}

/// Infer module role from directory name (matches Python indexer heuristics).
fn infer_role(dir: &str) -> &'static str {
    let last = dir.rsplit('/').next().unwrap_or(dir);
    match last {
        "scanners" | "scan" | "scanner" => "discovery",
        "generators" | "gen" | "generator" => "generation",
        "validators" | "validator" | "validation" => "validation",
        "indexers" | "indexer" | "index" => "indexing",
        "parsers" | "parser" => "parsing",
        "mcp" => "mcp",
        "tests" | "test" | "__tests__" | "spec" => "testing",
        "utils" | "util" | "helpers" | "helper" | "lib" | "common" => "utility",
        "api" | "routes" | "controllers" | "handlers" => "api",
        "models" | "entities" | "schemas" => "data",
        "services" | "service" => "service",
        "middleware" | "middlewares" => "middleware",
        "config" | "configs" | "settings" => "config",
        "migrations" | "migrate" => "migration",
        "bin" | "cmd" | "cli" => "cli",
        "data" => "data",
        "bridge" => "bridge",
        "freshness" => "tracking",
        _ => "module",
    }
}
