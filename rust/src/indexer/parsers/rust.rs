use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_FUNC: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(pub(?:\([^)]*\))?\s+)?(async\s+)?fn\s+(\w+)\s*\(([^)]*)\)").unwrap()
});
static RE_STRUCT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(pub(?:\([^)]*\))?\s+)?struct\s+(\w+)").unwrap()
});
static RE_ENUM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(pub(?:\([^)]*\))?\s+)?enum\s+(\w+)").unwrap()
});
static RE_TRAIT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(pub(?:\([^)]*\))?\s+)?trait\s+(\w+)").unwrap()
});
static RE_TYPE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(pub(?:\([^)]*\))?\s+)?type\s+(\w+)\s*=").unwrap()
});
static RE_CONST: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(pub(?:\([^)]*\))?\s+)?(?:const|static)\s+(\w+)\s*:").unwrap()
});
static RE_IMPL: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^impl(?:<[^>]*>)?\s+(?:(\w+)\s+for\s+)?(\w+)").unwrap()
});
static RE_USE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^use\s+([\w:]+)").unwrap()
});
static RE_MOD: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(?:pub\s+)?mod\s+(\w+)\s*;").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut current_impl: Option<String> = None;
    let mut impl_depth = 0i32;
    let mut brace_depth = 0i32;
    let mut pending_doc = String::new();

    for (i, line) in content.lines().enumerate() {
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

        // Exit impl block
        if current_impl.is_some() && brace_depth < impl_depth {
            current_impl = None;
        }

        // Capture /// doc comments for docstrings
        if trimmed.starts_with("///") {
            if pending_doc.is_empty() {
                let comment = trimmed.trim_start_matches("///").trim();
                if !comment.is_empty() {
                    pending_doc = comment.to_string();
                }
            }
            continue;
        }
        if trimmed.starts_with("//") || trimmed.starts_with("/*") || trimmed.starts_with('*') {
            continue;
        }
        // Blank line resets pending doc
        if trimmed.is_empty() {
            pending_doc.clear();
            continue;
        }

        // impl block
        if let Some(caps) = RE_IMPL.captures(trimmed) {
            let type_name = caps[2].to_string();
            current_impl = Some(type_name);
            impl_depth = brace_depth;
            continue;
        }

        // Function / method
        if let Some(caps) = RE_FUNC.captures(trimmed) {
            let is_pub = caps.get(1).is_some();
            let is_async = caps.get(2).is_some();
            let name = caps[3].to_string();
            let params = caps[4].to_string();

            let is_method = current_impl.is_some();
            let kind = if is_method { "method" } else { "function" };

            let prefix = match (is_pub, is_async) {
                (true, true) => "pub async fn",
                (true, false) => "pub fn",
                (false, true) => "async fn",
                (false, false) => "fn",
            };
            let sig = format!("{prefix} {name}({params})");

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line: lineno,
                signature: sig,
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: current_impl.clone(),
            });
            if is_pub && !is_method {
                exports.push(name);
            }
            continue;
        }

        // Struct
        if let Some(caps) = RE_STRUCT.captures(trimmed) {
            let is_pub = caps.get(1).is_some();
            let name = caps[2].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "struct".into(),
                line: lineno,
                signature: format!("struct {name}"),
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            continue;
        }

        // Enum
        if let Some(caps) = RE_ENUM.captures(trimmed) {
            let is_pub = caps.get(1).is_some();
            let name = caps[2].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "enum".into(),
                line: lineno,
                signature: format!("enum {name}"),
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            continue;
        }

        // Trait
        if let Some(caps) = RE_TRAIT.captures(trimmed) {
            let is_pub = caps.get(1).is_some();
            let name = caps[2].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "trait".into(),
                line: lineno,
                signature: format!("trait {name}"),
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            continue;
        }

        // Type alias
        if let Some(caps) = RE_TYPE.captures(trimmed) {
            let is_pub = caps.get(1).is_some();
            let name = caps[2].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "type".into(),
                line: lineno,
                signature: trimmed.chars().take(80).collect(),
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            continue;
        }

        // Const / static
        if let Some(caps) = RE_CONST.captures(trimmed) {
            let is_pub = caps.get(1).is_some();
            let name = caps[2].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "const".into(),
                line: lineno,
                signature: trimmed.chars().take(80).collect(),
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            continue;
        }

        // use statements → imports
        if let Some(caps) = RE_USE.captures(trimmed) {
            let path = caps[1].to_string();
            // Only track crate-local imports (not std/external)
            if path.starts_with("crate::") || path.starts_with("super::") {
                imports.push(path.replace("::", "/"));
            }
        }

        // mod declarations → imports
        if let Some(caps) = RE_MOD.captures(trimmed) {
            imports.push(caps[1].to_string());
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}
