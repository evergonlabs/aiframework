use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_CLASS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:public\s+|open\s+|internal\s+|private\s+|fileprivate\s+)?(?:final\s+)?class\s+(\w+)").unwrap()
});
static RE_STRUCT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:public\s+|internal\s+|private\s+)?struct\s+(\w+)").unwrap()
});
static RE_ENUM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:public\s+|internal\s+|private\s+)?enum\s+(\w+)").unwrap()
});
static RE_PROTOCOL: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:public\s+)?protocol\s+(\w+)").unwrap()
});
static RE_FUNC: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:public\s+|open\s+|internal\s+|private\s+|fileprivate\s+)?(?:static\s+|class\s+)?(?:override\s+)?func\s+(\w+)\s*\(([^)]*)\)").unwrap()
});
static RE_IMPORT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^import\s+(\w+)").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut current_type: Option<String> = None;

    for (i, line) in content.lines().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        if trimmed.starts_with("//") || trimmed.starts_with("/*") || trimmed.starts_with('*') {
            continue;
        }

        if let Some(caps) = RE_IMPORT.captures(trimmed) {
            imports.push(caps[1].to_string());
            continue;
        }

        if let Some(caps) = RE_CLASS.captures(trimmed) {
            let name = caps[1].to_string();
            let is_pub = trimmed.starts_with("public") || trimmed.starts_with("open");
            symbols.push(Symbol {
                name: name.clone(), kind: "class".into(), line: lineno,
                signature: format!("class {name}"), docstring: String::new(),
                visibility: if is_pub { "public" } else { "private" }.into(), parent: None,
            });
            if is_pub { exports.push(name.clone()); }
            current_type = Some(name);
            continue;
        }

        if let Some(caps) = RE_STRUCT.captures(trimmed) {
            let name = caps[1].to_string();
            let is_pub = trimmed.starts_with("public");
            symbols.push(Symbol {
                name: name.clone(), kind: "struct".into(), line: lineno,
                signature: format!("struct {name}"), docstring: String::new(),
                visibility: if is_pub { "public" } else { "private" }.into(), parent: None,
            });
            if is_pub { exports.push(name.clone()); }
            current_type = Some(name);
            continue;
        }

        if let Some(caps) = RE_ENUM.captures(trimmed) {
            let name = caps[1].to_string();
            symbols.push(Symbol {
                name: name.clone(), kind: "enum".into(), line: lineno,
                signature: format!("enum {name}"), docstring: String::new(),
                visibility: "public".into(), parent: None,
            });
            exports.push(name.clone());
            current_type = Some(name);
            continue;
        }

        if let Some(caps) = RE_PROTOCOL.captures(trimmed) {
            let name = caps[1].to_string();
            symbols.push(Symbol {
                name: name.clone(), kind: "interface".into(), line: lineno,
                signature: format!("protocol {name}"), docstring: String::new(),
                visibility: "public".into(), parent: None,
            });
            exports.push(name);
            continue;
        }

        if let Some(caps) = RE_FUNC.captures(trimmed) {
            let name = caps[1].to_string();
            let params = caps[2].to_string();
            let kind = if current_type.is_some() { "method" } else { "function" };
            let is_priv = trimmed.starts_with("private") || trimmed.starts_with("fileprivate");

            symbols.push(Symbol {
                name: name.clone(), kind: kind.into(), line: lineno,
                signature: format!("func {name}({params})"), docstring: String::new(),
                visibility: if is_priv { "private" } else { "public" }.into(),
                parent: current_type.clone(),
            });

            if !is_priv && current_type.is_none() {
                exports.push(name);
            }
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}
