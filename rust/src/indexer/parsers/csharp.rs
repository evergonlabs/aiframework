use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_CLASS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?:public|internal|private)?\s*(?:abstract\s+)?(?:sealed\s+)?(?:partial\s+)?class\s+(\w+)").unwrap()
});
static RE_INTERFACE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?:public|internal)?\s*interface\s+(I\w+)").unwrap()
});
static RE_ENUM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?:public|internal)?\s*enum\s+(\w+)").unwrap()
});
static RE_METHOD: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s+(?:public|protected|private|internal)?\s*(?:static\s+)?(?:async\s+)?(?:virtual\s+)?(?:override\s+)?(\w+(?:<[^>]*>)?)\s+(\w+)\s*\(([^)]*)\)").unwrap()
});
static RE_USING: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^using\s+([\w.]+);").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut current_class: Option<String> = None;

    for (i, line) in content.lines().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        if trimmed.starts_with("//") || trimmed.starts_with("/*") || trimmed.starts_with('*') {
            continue;
        }

        if let Some(caps) = RE_USING.captures(trimmed) {
            imports.push(caps[1].to_string());
            continue;
        }

        if let Some(caps) = RE_CLASS.captures(trimmed) {
            let name = caps[1].to_string();
            let is_pub = trimmed.contains("public");
            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line: lineno,
                signature: format!("class {name}"),
                docstring: String::new(),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub { exports.push(name.clone()); }
            current_class = Some(name);
            continue;
        }

        if let Some(caps) = RE_INTERFACE.captures(trimmed) {
            let name = caps[1].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "interface".into(),
                line: lineno,
                signature: format!("interface {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name);
            continue;
        }

        if let Some(caps) = RE_ENUM.captures(trimmed) {
            let name = caps[1].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "enum".into(),
                line: lineno,
                signature: format!("enum {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name);
            continue;
        }

        if let Some(caps) = RE_METHOD.captures(line) {
            let return_type = caps[1].to_string();
            let name = caps[2].to_string();
            let params = caps[3].to_string();

            if name == current_class.as_deref().unwrap_or("") || matches!(name.as_str(), "if" | "for" | "while" | "switch" | "catch" | "return" | "new") {
                continue;
            }

            let visibility = if trimmed.starts_with("public") { "public" } else { "private" };

            symbols.push(Symbol {
                name: name.clone(),
                kind: "method".into(),
                line: lineno,
                signature: format!("{return_type} {name}({params})"),
                docstring: String::new(),
                visibility: visibility.into(),
                parent: current_class.clone(),
            });
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}
