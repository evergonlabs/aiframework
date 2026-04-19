use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_FUNC: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^([ \t]*)def\s+(\w+)\s*\(([^)]*)\)(?:\s*->\s*([^:]+))?").unwrap()
});
static RE_CLASS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^class\s+(\w+)(\([^)]*\))?:").unwrap()
});
static RE_IMPORT_FROM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^from\s+([\w.]+)\s+import").unwrap()
});
static RE_IMPORT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^import\s+([\w.]+)").unwrap()
});
static RE_ASSIGN: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^([A-Z][A-Z_0-9]+)\s*[=:]").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut current_class: Option<String> = None;
    let mut class_indent = 0usize;
    let mut prev_docstring = String::new();

    for (i, line) in content.lines().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        // Track docstrings (single-line only for performance)
        if trimmed.starts_with("\"\"\"") || trimmed.starts_with("'''") {
            let q = &trimmed[..3];
            if trimmed.len() > 6 && trimmed.ends_with(q) {
                prev_docstring = trimmed[3..trimmed.len() - 3].to_string();
            }
            continue;
        }

        // Class detection
        if let Some(caps) = RE_CLASS.captures(line) {
            let name = caps[1].to_string();
            class_indent = line.len() - line.trim_start().len();
            current_class = Some(name.clone());

            let bases = caps.get(2).map_or("", |m| m.as_str());
            let sig = if bases.is_empty() {
                format!("class {name}")
            } else {
                format!("class {name}{bases}")
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line: lineno,
                signature: sig,
                docstring: std::mem::take(&mut prev_docstring),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name);
            continue;
        }

        // Function/method detection
        if let Some(caps) = RE_FUNC.captures(line) {
            let indent_str = &caps[1];
            let indent = indent_str.len();
            let name = caps[2].to_string();
            let params = caps[3].to_string();
            let ret = caps.get(4).map(|m| m.as_str().trim().to_string());

            // Determine if this is a method (indented inside a class)
            let is_method = current_class.is_some() && indent > class_indent;
            let kind = if is_method { "method" } else { "function" };

            let visibility = if name.starts_with('_') && !name.starts_with("__") {
                "private"
            } else {
                "public"
            };

            let sig = match &ret {
                Some(r) => format!("def {name}({params}) -> {r}"),
                None => format!("def {name}({params})"),
            };

            let parent = if is_method {
                current_class.clone()
            } else {
                // Exited class scope
                if indent <= class_indent {
                    current_class = None;
                }
                None
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line: lineno,
                signature: sig,
                docstring: std::mem::take(&mut prev_docstring),
                visibility: visibility.into(),
                parent,
            });

            if visibility == "public" && !is_method {
                exports.push(name);
            }
            continue;
        }

        // Imports
        if let Some(caps) = RE_IMPORT_FROM.captures(trimmed) {
            let module = normalize_python_import(&caps[1]);
            if !module.is_empty() {
                imports.push(module);
            }
        } else if let Some(caps) = RE_IMPORT.captures(trimmed) {
            let module = normalize_python_import(&caps[1]);
            if !module.is_empty() {
                imports.push(module);
            }
        }

        // Module-level constants
        if current_class.is_none() {
            if let Some(caps) = RE_ASSIGN.captures(trimmed) {
                let name = caps[1].to_string();
                symbols.push(Symbol {
                    name: name.clone(),
                    kind: "const".into(),
                    line: lineno,
                    signature: trimmed.to_string(),
                    docstring: String::new(),
                    visibility: "public".into(),
                    parent: None,
                });
                exports.push(name);
            }
        }

        // Reset docstring if line is not blank and not a docstring
        if !trimmed.is_empty() {
            prev_docstring.clear();
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}

fn normalize_python_import(module: &str) -> String {
    // Strip leading dots (relative imports)
    module.trim_start_matches('.').replace('.', "/")
}
