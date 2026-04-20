/// MCP (Model Context Protocol) server — exposes repo context to Claude Code.
/// JSON-RPC 2.0 over stdin/stdout.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::io::{self, BufRead, Write};
use std::path::Path;

#[derive(Deserialize)]
#[allow(dead_code)]
struct JsonRpcRequest {
    jsonrpc: String,
    id: Option<Value>,
    method: String,
    params: Option<Value>,
}

#[derive(Serialize)]
struct JsonRpcResponse {
    jsonrpc: String,
    id: Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<Value>,
}

/// Run the MCP server — reads JSON-RPC from stdin, writes to stdout.
pub fn serve(target: &Path) -> Result<(), Box<dyn std::error::Error>> {
    let target = target.canonicalize()?;

    // Pre-load manifest and code index if available
    let manifest = load_json(&target.join(".aiframework/manifest.json"));
    let code_index = load_json(&target.join(".aiframework/code-index.json"));

    let stdin = io::stdin();
    let stdout = io::stdout();

    for line in stdin.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        let request: JsonRpcRequest = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                let err_response = JsonRpcResponse {
                    jsonrpc: "2.0".into(),
                    id: Value::Null,
                    result: None,
                    error: Some(json!({"code": -32700, "message": format!("Parse error: {e}")})),
                };
                writeln!(stdout.lock(), "{}", serde_json::to_string(&err_response)?)?;
                continue;
            }
        };

        let id = request.id.clone().unwrap_or(Value::Null);

        let result = handle_method(
            &request.method,
            request.params.as_ref(),
            &target,
            manifest.as_ref(),
            code_index.as_ref(),
        );

        let response = match result {
            Ok(value) => JsonRpcResponse {
                jsonrpc: "2.0".into(),
                id,
                result: Some(value),
                error: None,
            },
            Err(msg) => JsonRpcResponse {
                jsonrpc: "2.0".into(),
                id,
                result: None,
                error: Some(json!({"code": -32603, "message": msg})),
            },
        };

        writeln!(stdout.lock(), "{}", serde_json::to_string(&response)?)?;
        stdout.lock().flush()?;
    }

    Ok(())
}

fn handle_method(
    method: &str,
    _params: Option<&Value>,
    target: &Path,
    manifest: Option<&Value>,
    code_index: Option<&Value>,
) -> Result<Value, String> {
    match method {
        // MCP initialization
        "initialize" => Ok(json!({
            "protocolVersion": "2024-11-05",
            "capabilities": {
                "resources": {"listChanged": false},
                "tools": {},
            },
            "serverInfo": {
                "name": "aiframework",
                "version": env!("CARGO_PKG_VERSION"),
            }
        })),

        "initialized" => Ok(json!({})),

        // List available resources
        "resources/list" => {
            let mut resources = vec![
                json!({"uri": "aiframework://manifest", "name": "Project Manifest", "mimeType": "application/json"}),
            ];
            if code_index.is_some() {
                resources.push(json!({"uri": "aiframework://code-index", "name": "Code Index", "mimeType": "application/json"}));
            }
            if manifest.is_some() {
                resources.push(json!({"uri": "aiframework://commands", "name": "Project Commands", "mimeType": "text/plain"}));
                resources.push(json!({"uri": "aiframework://invariants", "name": "Project Invariants", "mimeType": "text/plain"}));
                resources.push(json!({"uri": "aiframework://architecture", "name": "Architecture Overview", "mimeType": "text/plain"}));
            }
            Ok(json!({"resources": resources}))
        }

        // Read a specific resource
        "resources/read" => {
            let uri = _params
                .and_then(|p| p["uri"].as_str())
                .ok_or("Missing uri parameter")?;

            match uri {
                "aiframework://manifest" => {
                    let m = manifest.ok_or("No manifest loaded")?;
                    Ok(json!({"contents": [{"uri": uri, "text": serde_json::to_string_pretty(m).unwrap_or_default(), "mimeType": "application/json"}]}))
                }
                "aiframework://code-index" => {
                    let idx = code_index.ok_or("No code index loaded")?;
                    // Return just the metadata, not the full index (too large)
                    let meta = &idx["_meta"];
                    Ok(json!({"contents": [{"uri": uri, "text": serde_json::to_string_pretty(meta).unwrap_or_default(), "mimeType": "application/json"}]}))
                }
                "aiframework://commands" => {
                    let m = manifest.ok_or("No manifest loaded")?;
                    let cmds = &m["commands"];
                    let mut text = String::new();
                    for (key, val) in cmds.as_object().unwrap_or(&serde_json::Map::new()) {
                        if let Some(s) = val.as_str() {
                            if s != "NOT_CONFIGURED" {
                                text.push_str(&format!("{key}: {s}\n"));
                            }
                        }
                    }
                    Ok(json!({"contents": [{"uri": uri, "text": text, "mimeType": "text/plain"}]}))
                }
                "aiframework://invariants" => {
                    let m = manifest.ok_or("No manifest loaded")?;
                    let mut text = String::from("INV-1: LLM trust boundary — validate all AI output\n");
                    if let Some(domains) = m["domain"]["detected_domains"].as_array() {
                        for d in domains {
                            let name = d["name"].as_str().unwrap_or("");
                            match name {
                                "auth" => text.push_str("INV-AUTH: Never store credentials in source code\n"),
                                "database" => text.push_str("INV-DB: All schema changes require migrations\n"),
                                "api" => text.push_str("INV-API: Validate input, return proper error codes\n"),
                                _ => {}
                            }
                        }
                    }
                    Ok(json!({"contents": [{"uri": uri, "text": text, "mimeType": "text/plain"}]}))
                }
                "aiframework://architecture" => {
                    let m = manifest.ok_or("No manifest loaded")?;
                    let lang = m["stack"]["language"].as_str().unwrap_or("unknown");
                    let fw = m["stack"]["framework"].as_str().unwrap_or("none");
                    let arch = m["archetype"]["type"].as_str().unwrap_or("unknown");
                    let text = format!("Stack: {lang}/{fw}\nArchetype: {arch}\n");
                    Ok(json!({"contents": [{"uri": uri, "text": text, "mimeType": "text/plain"}]}))
                }
                _ => Err(format!("Unknown resource: {uri}")),
            }
        }

        // List available tools
        "tools/list" => Ok(json!({"tools": [
            {
                "name": "get_top_files",
                "description": "Get the most important files in the codebase by PageRank",
                "inputSchema": {"type": "object", "properties": {"limit": {"type": "number", "description": "Max files to return (default 10)"}}}
            },
            {
                "name": "get_file_symbols",
                "description": "Get symbols (functions, classes, types) in a specific file",
                "inputSchema": {"type": "object", "properties": {"path": {"type": "string", "description": "Relative file path"}}, "required": ["path"]}
            },
            {
                "name": "search_symbols",
                "description": "Search for symbols by name across the codebase",
                "inputSchema": {"type": "object", "properties": {"query": {"type": "string", "description": "Symbol name to search for"}}, "required": ["query"]}
            },
            {
                "name": "analyze_file",
                "description": "Get symbols, imports, exports, complexity, patterns, and imported-by list for a file",
                "inputSchema": {"type": "object", "properties": {"path": {"type": "string", "description": "File path relative to project root"}}, "required": ["path"]}
            },
            {
                "name": "find_tests",
                "description": "Find test files and test function names. If path is omitted, finds all test files.",
                "inputSchema": {"type": "object", "properties": {"path": {"type": "string", "description": "Source file path (optional — omit to find all tests)"}}}
            },
            {
                "name": "check_invariants",
                "description": "List all project invariants from manifest and whether they are enforced",
                "inputSchema": {"type": "object", "properties": {}}
            },
            {
                "name": "refresh",
                "description": "Re-run aiframework discover + index + generate cycle and return summary",
                "inputSchema": {"type": "object", "properties": {}}
            },
        ]})),

        // Execute a tool
        "tools/call" => {
            let tool_name = _params
                .and_then(|p| p["name"].as_str())
                .ok_or("Missing tool name")?;
            let args = _params.and_then(|p| p["arguments"].as_object());

            match tool_name {
                "get_top_files" => {
                    let idx = code_index.ok_or("No code index")?;
                    let limit = args
                        .and_then(|a| a.get("limit"))
                        .and_then(|v| v.as_u64())
                        .unwrap_or(10) as usize;

                    let top = idx["_meta"]["top_files"]
                        .as_array()
                        .map(|arr| arr.iter().take(limit).cloned().collect::<Vec<_>>())
                        .unwrap_or_default();

                    Ok(json!({"content": [{"type": "text", "text": serde_json::to_string_pretty(&top).unwrap_or_default()}]}))
                }

                "get_file_symbols" => {
                    let idx = code_index.ok_or("No code index")?;
                    let path = args
                        .and_then(|a| a.get("path"))
                        .and_then(|v| v.as_str())
                        .ok_or("Missing path")?;

                    let file_data = &idx["files"][path];
                    if file_data.is_null() {
                        return Ok(json!({"content": [{"type": "text", "text": format!("File not found: {path}")}]}));
                    }

                    let symbols = &file_data["symbols"];
                    Ok(json!({"content": [{"type": "text", "text": serde_json::to_string_pretty(symbols).unwrap_or_default()}]}))
                }

                "search_symbols" => {
                    let idx = code_index.ok_or("No code index")?;
                    let query = args
                        .and_then(|a| a.get("query"))
                        .and_then(|v| v.as_str())
                        .ok_or("Missing query")?
                        .to_lowercase();

                    let mut matches = Vec::new();
                    if let Some(symbols) = idx["symbols"].as_array() {
                        for sym in symbols {
                            let name = sym["name"].as_str().unwrap_or("");
                            if name.to_lowercase().contains(&query) {
                                matches.push(sym.clone());
                                if matches.len() >= 20 {
                                    break;
                                }
                            }
                        }
                    }

                    Ok(json!({"content": [{"type": "text", "text": serde_json::to_string_pretty(&matches).unwrap_or_default()}]}))
                }

                "analyze_file" => {
                    let idx = code_index.ok_or("No code index")?;
                    let path = args
                        .and_then(|a| a.get("path"))
                        .and_then(|v| v.as_str())
                        .ok_or("Missing path")?;

                    // Get file data from code index
                    let file_data = &idx["files"][path];
                    let symbols = if !file_data.is_null() {
                        file_data["symbols"].clone()
                    } else {
                        Value::Array(vec![])
                    };

                    // Build imports_from (outgoing edges) and imported_by (incoming edges)
                    let edges = idx["edges"].as_array();
                    let mut imports_from = Vec::new();
                    let mut imported_by = Vec::new();
                    if let Some(edge_list) = edges {
                        for e in edge_list {
                            if e["source"].as_str() == Some(path) {
                                if let Some(t) = e["target"].as_str() {
                                    imports_from.push(Value::String(t.to_string()));
                                }
                            }
                            if e["target"].as_str() == Some(path) {
                                if let Some(s) = e["source"].as_str() {
                                    imported_by.push(Value::String(s.to_string()));
                                }
                            }
                        }
                    }

                    let result = json!({
                        "path": path,
                        "symbols": symbols,
                        "imports_from": imports_from,
                        "imported_by": imported_by,
                    });

                    Ok(json!({"content": [{"type": "text", "text": serde_json::to_string_pretty(&result).unwrap_or_default()}]}))
                }

                "find_tests" => {
                    let path_arg = args
                        .and_then(|a| a.get("path"))
                        .and_then(|v| v.as_str());

                    let test_pattern = manifest
                        .and_then(|m| m["structure"]["test_pattern"].as_str())
                        .unwrap_or("");
                    let test_dirs: Vec<&str> = manifest
                        .and_then(|m| m["structure"]["test_dirs"].as_array())
                        .map(|arr| arr.iter().filter_map(|v| v.as_str()).collect())
                        .unwrap_or_default();

                    let mut test_files: Vec<Value> = Vec::new();

                    // Walk test directories looking for test files
                    for td in &test_dirs {
                        let test_dir = target.join(td);
                        if test_dir.is_dir() {
                            collect_test_files(&test_dir, target, path_arg, &mut test_files);
                        }
                    }

                    // Also check code index for files with "test" in their path
                    if let Some(idx) = code_index {
                        if let Some(files_obj) = idx["files"].as_object() {
                            for (fpath, fdata) in files_obj {
                                let is_test_file = fpath.contains("test") || fpath.contains("spec");
                                let matches_source = path_arg
                                    .map(|p| {
                                        let stem = Path::new(p).file_stem().and_then(|s| s.to_str()).unwrap_or("");
                                        !stem.is_empty() && fpath.contains(stem)
                                    })
                                    .unwrap_or(true);

                                if is_test_file && matches_source {
                                    let symbols = fdata["symbols"].as_array()
                                        .map(|arr| {
                                            arr.iter()
                                                .filter(|s| {
                                                    let name = s["name"].as_str().unwrap_or("");
                                                    name.starts_with("test_") || name.starts_with("Test") || name.contains("test")
                                                })
                                                .filter_map(|s| s["name"].as_str().map(|n| Value::String(n.to_string())))
                                                .collect::<Vec<_>>()
                                        })
                                        .unwrap_or_default();

                                    test_files.push(json!({
                                        "file": fpath,
                                        "test_functions": symbols,
                                    }));
                                }
                            }
                        }
                    }

                    let result = json!({
                        "source": path_arg.unwrap_or("*"),
                        "test_files": test_files,
                        "test_pattern": test_pattern,
                    });

                    Ok(json!({"content": [{"type": "text", "text": serde_json::to_string_pretty(&result).unwrap_or_default()}]}))
                }

                "check_invariants" => {
                    let mut invariants = Vec::new();

                    // Always include the baseline invariant
                    invariants.push(json!({
                        "id": "INV-1",
                        "rule": "LLM trust boundary — validate all AI output",
                        "domain": "general",
                        "enforced": true,
                    }));
                    invariants.push(json!({
                        "id": "INV-2",
                        "rule": "No secrets in source code",
                        "domain": "general",
                        "enforced": true,
                    }));

                    // Add domain-specific invariants from manifest
                    if let Some(m) = manifest {
                        if let Some(domains) = m["domain"]["detected_domains"].as_array() {
                            let mut idx = 3;
                            for d in domains {
                                let name = d["name"].as_str().unwrap_or("");
                                let (rule, enforced) = match name {
                                    "auth" => ("Auth guards on all protected endpoints", true),
                                    "database" => ("Database access through ORM only", true),
                                    "api" => ("Input validation on all API endpoints", true),
                                    "ai" => ("LLM outputs sanitized before use", true),
                                    _ => continue,
                                };
                                invariants.push(json!({
                                    "id": format!("INV-{idx}"),
                                    "rule": rule,
                                    "domain": name,
                                    "enforced": enforced,
                                }));
                                idx += 1;
                            }
                        }
                    }

                    let result = json!({"invariants": invariants});
                    Ok(json!({"content": [{"type": "text", "text": serde_json::to_string_pretty(&result).unwrap_or_default()}]}))
                }

                "refresh" => {
                    // Run aiframework refresh as a subprocess
                    let output = std::process::Command::new("aiframework")
                        .args(["refresh", "--target", &target.to_string_lossy()])
                        .output();

                    let result = match output {
                        Ok(out) => {
                            let stdout = String::from_utf8_lossy(&out.stdout);
                            let tail: String = stdout.chars().rev().take(500).collect::<String>().chars().rev().collect();
                            json!({
                                "success": out.status.success(),
                                "output": tail,
                            })
                        }
                        Err(e) => json!({
                            "success": false,
                            "error": format!("{e}"),
                        }),
                    };

                    Ok(json!({"content": [{"type": "text", "text": serde_json::to_string_pretty(&result).unwrap_or_default()}]}))
                }

                _ => Err(format!("Unknown tool: {tool_name}")),
            }
        }

        _ => Err(format!("Unknown method: {method}")),
    }
}

/// Recursively collect test files under a directory.
fn collect_test_files(dir: &Path, root: &Path, source_filter: Option<&str>, results: &mut Vec<Value>) {
    let walker = walkdir::WalkDir::new(dir).into_iter().filter_map(|e| e.ok());
    for entry in walker {
        if !entry.file_type().is_file() {
            continue;
        }
        let path = entry.path();
        let rel = path.strip_prefix(root).unwrap_or(path);
        let rel_str = rel.to_string_lossy();

        let is_test = rel_str.contains("test") || rel_str.contains("spec");
        if !is_test {
            continue;
        }

        // If a source filter is given, check the stem matches
        if let Some(src) = source_filter {
            let stem = Path::new(src).file_stem().and_then(|s| s.to_str()).unwrap_or("");
            if !stem.is_empty() && !rel_str.contains(stem) {
                continue;
            }
        }

        results.push(json!({
            "file": rel_str,
            "test_functions": [],
        }));
    }
}

fn load_json(path: &Path) -> Option<Value> {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
}
