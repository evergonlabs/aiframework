/// MCP (Model Context Protocol) server — exposes repo context to Claude Code.
/// JSON-RPC 2.0 over stdin/stdout.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::io::{self, BufRead, Write};
use std::path::Path;

#[derive(Deserialize)]
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

                _ => Err(format!("Unknown tool: {tool_name}")),
            }
        }

        _ => Err(format!("Unknown method: {method}")),
    }
}

fn load_json(path: &Path) -> Option<Value> {
    std::fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
}
