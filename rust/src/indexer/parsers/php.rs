use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_CLASS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:abstract\s+)?class\s+(\w+)").unwrap()
});
static RE_INTERFACE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*interface\s+(\w+)").unwrap()
});
static RE_FUNCTION: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:public|protected|private)?\s*(?:static\s+)?function\s+(\w+)\s*\(([^)]*)\)").unwrap()
});
static RE_USE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^use\s+([\w\\]+);").unwrap()
});
static RE_REQUIRE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?:require|include)(?:_once)?\s*\(?['"]([^'"]+)['"]"#).unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut current_class: Option<String> = None;

    for (i, line) in content.lines().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        if trimmed.starts_with("//") || trimmed.starts_with("/*") || trimmed.starts_with('*') || trimmed.starts_with('#') {
            continue;
        }

        if let Some(caps) = RE_USE.captures(trimmed) {
            imports.push(caps[1].replace('\\', "/"));
            continue;
        }

        if let Some(caps) = RE_REQUIRE.captures(trimmed) {
            imports.push(caps[1].to_string());
            continue;
        }

        if let Some(caps) = RE_CLASS.captures(trimmed) {
            let name = caps[1].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line: lineno,
                signature: format!("class {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());
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

        if let Some(caps) = RE_FUNCTION.captures(trimmed) {
            let name = caps[1].to_string();
            let params = caps[2].to_string();

            let kind = if current_class.is_some() { "method" } else { "function" };
            let visibility = if trimmed.starts_with("private") || trimmed.contains(" private ") {
                "private"
            } else {
                "public"
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line: lineno,
                signature: format!("function {name}({params})"),
                docstring: String::new(),
                visibility: visibility.into(),
                parent: current_class.clone(),
            });

            if visibility == "public" && current_class.is_none() {
                exports.push(name);
            }
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}
