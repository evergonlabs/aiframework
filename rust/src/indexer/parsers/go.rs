use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_FUNC: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^func\s+(\([^)]*\)\s+)?(\w+)\s*\(([^)]*)\)").unwrap()
});
static RE_TYPE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^type\s+(\w+)\s+(struct|interface)").unwrap()
});
static RE_TYPE_ALIAS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^type\s+(\w+)\s+\w+").unwrap()
});
static RE_CONST: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(?:const|var)\s+(\w+)\s+").unwrap()
});
static RE_IMPORT_SINGLE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"^import\s+"([^"]+)""#).unwrap()
});
static RE_IMPORT_LINE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"^\s+"([^"]+)""#).unwrap()
});
static RE_PACKAGE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^package\s+(\w+)").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut in_import_block = false;
    let mut pending_doc = String::new();

    for (i, line) in content.lines().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        // Capture Go doc comments (// before declarations)
        if trimmed.starts_with("//") {
            if pending_doc.is_empty() {
                let comment = trimmed.trim_start_matches("//").trim();
                if !comment.is_empty() {
                    pending_doc = comment.to_string();
                }
            }
            continue;
        }
        // Blank line resets pending doc
        if trimmed.is_empty() {
            pending_doc.clear();
            continue;
        }

        // Import block tracking
        if trimmed == "import (" {
            in_import_block = true;
            continue;
        }
        if in_import_block {
            if trimmed == ")" {
                in_import_block = false;
                continue;
            }
            if let Some(caps) = RE_IMPORT_LINE.captures(line) {
                let path = &caps[1];
                // Extract last segment as the import name
                if let Some(last) = path.rsplit('/').next() {
                    imports.push(last.to_string());
                }
            }
            continue;
        }

        // Single-line import
        if let Some(caps) = RE_IMPORT_SINGLE.captures(trimmed) {
            let path = &caps[1];
            if let Some(last) = path.rsplit('/').next() {
                imports.push(last.to_string());
            }
            continue;
        }

        // Function (including methods with receiver)
        if let Some(caps) = RE_FUNC.captures(trimmed) {
            let receiver = caps.get(1).map(|m| m.as_str().trim().to_string());
            let name = caps[2].to_string();
            let params = caps[3].to_string();

            let is_exported = name.starts_with(|c: char| c.is_uppercase());
            let kind = if receiver.is_some() { "method" } else { "function" };

            let sig = match &receiver {
                Some(r) => format!("func {r} {name}({params})"),
                None => format!("func {name}({params})"),
            };

            // Extract receiver type as parent
            let parent = receiver.as_ref().and_then(|r| {
                let r = r.trim_start_matches('(').trim_end_matches(')');
                r.split_whitespace().last().map(|s| s.trim_start_matches('*').to_string())
            });

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line: lineno,
                signature: sig,
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_exported { "public" } else { "private" }.into(),
                parent,
            });
            if is_exported {
                exports.push(name);
            }
            continue;
        }

        // Type declaration (struct/interface)
        if let Some(caps) = RE_TYPE.captures(trimmed) {
            let name = caps[1].to_string();
            let kind_str = &caps[2];
            let is_exported = name.starts_with(|c: char| c.is_uppercase());
            let kind = if kind_str == "interface" {
                "interface"
            } else {
                "struct"
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line: lineno,
                signature: format!("type {name} {kind_str}"),
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_exported { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_exported {
                exports.push(name);
            }
            continue;
        }

        // Type alias
        if let Some(caps) = RE_TYPE_ALIAS.captures(trimmed) {
            let name = caps[1].to_string();
            let is_exported = name.starts_with(|c: char| c.is_uppercase());
            symbols.push(Symbol {
                name: name.clone(),
                kind: "type".into(),
                line: lineno,
                signature: trimmed.to_string(),
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_exported { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_exported {
                exports.push(name);
            }
            continue;
        }

        // Constants/variables
        if let Some(caps) = RE_CONST.captures(trimmed) {
            let name = caps[1].to_string();
            let is_exported = name.starts_with(|c: char| c.is_uppercase());
            symbols.push(Symbol {
                name: name.clone(),
                kind: "const".into(),
                line: lineno,
                signature: trimmed.chars().take(80).collect(),
                docstring: std::mem::take(&mut pending_doc),
                visibility: if is_exported { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_exported {
                exports.push(name);
            }
        }

        // Package declaration (used for module grouping)
        if let Some(caps) = RE_PACKAGE.captures(trimmed) {
            let _pkg = &caps[1]; // Available if needed
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}
