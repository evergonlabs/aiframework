use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_FUNC: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(export\s+)?(default\s+)?(async\s+)?function\s+(\w+)\s*\(([^)]*)\)").unwrap()
});
static RE_ARROW: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(export\s+)?(const|let|var)\s+(\w+)\s*=\s*(async\s+)?\([^)]*\)\s*(?::\s*\w+\s*)?=>").unwrap()
});
static RE_CLASS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(export\s+)?(default\s+)?class\s+(\w+)(?:\s+extends\s+(\w+))?(?:\s+implements\s+(\w+))?").unwrap()
});
static RE_INTERFACE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(export\s+)?interface\s+(\w+)").unwrap()
});
static RE_TYPE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(export\s+)?type\s+(\w+)\s*=").unwrap()
});
static RE_ENUM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(export\s+)?(const\s+)?enum\s+(\w+)").unwrap()
});
static RE_METHOD: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s+(async\s+)?(\w+)\s*\(([^)]*)\)").unwrap()
});
static RE_IMPORT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?:import|require)\s*\(?['"]([^'"]+)['"]"#).unwrap()
});
static RE_IMPORT_FROM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"from\s+['"]([^'"]+)['"]"#).unwrap()
});
static RE_CONST_EXPORT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^export\s+(?:const|let|var)\s+(\w+)\s*[=:]").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut in_class = false;
    let mut current_class: Option<String> = None;
    let mut brace_depth = 0i32;
    let mut class_brace_depth = 0i32;
    let mut pending_jsdoc = String::new();

    let lines: Vec<&str> = content.lines().collect();
    for (i, line) in lines.iter().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        // Track brace depth
        for ch in trimmed.chars() {
            match ch {
                '{' => brace_depth += 1,
                '}' => brace_depth -= 1,
                _ => {}
            }
        }

        // Exit class scope
        if in_class && brace_depth < class_brace_depth {
            in_class = false;
            current_class = None;
        }

        // Capture JSDoc comments (/** ... */) for docstrings
        if trimmed.starts_with("/**") {
            pending_jsdoc = extract_jsdoc(&lines, i);
            continue;
        }
        if trimmed.starts_with("//") || trimmed.starts_with("/*") || trimmed.starts_with('*') {
            continue;
        }

        // Class
        if let Some(caps) = RE_CLASS.captures(trimmed) {
            let is_export = caps.get(1).is_some();
            let name = caps[3].to_string();
            let extends = caps.get(4).map(|m| m.as_str().to_string());

            let sig = match &extends {
                Some(base) => format!("class {name} extends {base}"),
                None => format!("class {name}"),
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line: lineno,
                signature: sig,
                docstring: std::mem::take(&mut pending_jsdoc),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });

            if is_export {
                exports.push(name.clone());
            }

            in_class = true;
            current_class = Some(name);
            class_brace_depth = brace_depth;
            continue;
        }

        // Interface
        if let Some(caps) = RE_INTERFACE.captures(trimmed) {
            let is_export = caps.get(1).is_some();
            let name = caps[2].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "interface".into(),
                line: lineno,
                signature: format!("interface {name}"),
                docstring: std::mem::take(&mut pending_jsdoc),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            continue;
        }

        // Type alias
        if let Some(caps) = RE_TYPE.captures(trimmed) {
            let is_export = caps.get(1).is_some();
            let name = caps[2].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "type".into(),
                line: lineno,
                signature: format!("type {name}"),
                docstring: std::mem::take(&mut pending_jsdoc),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            continue;
        }

        // Enum
        if let Some(caps) = RE_ENUM.captures(trimmed) {
            let is_export = caps.get(1).is_some();
            let name = caps[3].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "enum".into(),
                line: lineno,
                signature: format!("enum {name}"),
                docstring: std::mem::take(&mut pending_jsdoc),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            continue;
        }

        // Function declaration
        if let Some(caps) = RE_FUNC.captures(trimmed) {
            let is_export = caps.get(1).is_some();
            let is_async = caps.get(3).is_some();
            let name = caps[4].to_string();
            let params = caps[5].to_string();

            let prefix = if is_async { "async function" } else { "function" };
            let sig = format!("{prefix} {name}({params})");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line: lineno,
                signature: sig,
                docstring: std::mem::take(&mut pending_jsdoc),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            continue;
        }

        // Arrow function
        if let Some(caps) = RE_ARROW.captures(trimmed) {
            let is_export = caps.get(1).is_some();
            let name = caps[3].to_string();

            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line: lineno,
                signature: format!("const {name} = () =>"),
                docstring: std::mem::take(&mut pending_jsdoc),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            continue;
        }

        // Exported const/let/var (not arrow)
        if let Some(caps) = RE_CONST_EXPORT.captures(trimmed) {
            let name = caps[1].to_string();
            // Skip if already captured as arrow function
            if !symbols.iter().any(|s| s.name == name && s.line == lineno) {
                symbols.push(Symbol {
                    name: name.clone(),
                    kind: "const".into(),
                    line: lineno,
                    signature: trimmed.chars().take(80).collect(),
                    docstring: std::mem::take(&mut pending_jsdoc),
                    visibility: "public".into(),
                    parent: None,
                });
                exports.push(name);
            }
            continue;
        }

        // Class methods
        if in_class {
            if let Some(caps) = RE_METHOD.captures(line) {
                let is_async = caps.get(1).is_some();
                let name = caps[2].to_string();
                let params = caps[3].to_string();

                // Skip keywords that look like methods
                if matches!(
                    name.as_str(),
                    "if" | "for" | "while" | "switch" | "catch" | "return" | "new" | "throw"
                ) {
                    continue;
                }

                let prefix = if is_async { "async " } else { "" };
                let sig = format!("{prefix}{name}({params})");

                symbols.push(Symbol {
                    name: name.clone(),
                    kind: "method".into(),
                    line: lineno,
                    signature: sig,
                    docstring: std::mem::take(&mut pending_jsdoc),
                    visibility: if name.starts_with('_') {
                        "private"
                    } else {
                        "public"
                    }
                    .into(),
                    parent: current_class.clone(),
                });
            }
        }

        // Imports
        if let Some(caps) = RE_IMPORT_FROM.captures(trimmed) {
            let module = normalize_ts_import(&caps[1]);
            if !module.is_empty() {
                imports.push(module);
            }
        } else if let Some(caps) = RE_IMPORT.captures(trimmed) {
            let module = normalize_ts_import(&caps[1]);
            if !module.is_empty() {
                imports.push(module);
            }
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}

/// Extract the first meaningful line from a JSDoc comment block starting at line index `start`.
fn extract_jsdoc(lines: &[&str], start: usize) -> String {
    for j in start..lines.len() {
        let t = lines[j].trim();
        if t.starts_with("/**") {
            // Single-line JSDoc: /** description */
            let inner = t.trim_start_matches("/**").trim_end_matches("*/").trim();
            if !inner.is_empty() {
                return inner.to_string();
            }
            continue;
        }
        if t.starts_with("*/") {
            break;
        }
        if t.starts_with('*') {
            let inner = t.trim_start_matches('*').trim();
            if !inner.is_empty() && !inner.starts_with('@') {
                return inner.to_string();
            }
        }
    }
    String::new()
}

fn normalize_ts_import(module: &str) -> String {
    // Skip node_modules / npm packages (no ./ or ../ prefix and no /)
    if !module.starts_with('.') && !module.contains('/') {
        return String::new();
    }
    // Strip leading ./ or ../
    let cleaned = module
        .trim_start_matches("./")
        .trim_start_matches("../");
    cleaned.to_string()
}
