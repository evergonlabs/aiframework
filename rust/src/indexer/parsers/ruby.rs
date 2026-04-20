use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_METHOD: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*def\s+(self\.)?(\w+[?!=]?)\s*(\([^)]*\))?").unwrap()
});
static RE_CLASS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*class\s+(\w+)(?:\s*<\s*(\w+))?").unwrap()
});
static RE_MODULE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*module\s+(\w+)").unwrap()
});
static RE_REQUIRE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"^\s*require(?:_relative)?\s+['"]([^'"]+)['"]"#).unwrap()
});
static RE_PRIVATE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*private\s*$").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut is_private = false;
    let mut current_class: Option<String> = None;

    for (i, line) in content.lines().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        // Skip comments
        if trimmed.starts_with('#') {
            continue;
        }

        // Private marker
        if RE_PRIVATE.is_match(trimmed) {
            is_private = true;
            continue;
        }

        // Class
        if let Some(caps) = RE_CLASS.captures(trimmed) {
            let name = caps[1].to_string();
            let base = caps.get(2).map(|m| m.as_str().to_string());
            let sig = match &base {
                Some(b) => format!("class {name} < {b}"),
                None => format!("class {name}"),
            };
            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line: lineno,
                signature: sig,
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());
            current_class = Some(name);
            is_private = false;
            continue;
        }

        // Module
        if let Some(caps) = RE_MODULE.captures(trimmed) {
            let name = caps[1].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(), // Ruby modules are class-like
                line: lineno,
                signature: format!("module {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());
            current_class = Some(name);
            is_private = false;
            continue;
        }

        // Method
        if let Some(caps) = RE_METHOD.captures(trimmed) {
            let is_class_method = caps.get(1).is_some();
            let name = caps[2].to_string();
            let params = caps.get(3).map_or("", |m| m.as_str());

            let kind = if current_class.is_some() { "method" } else { "function" };
            let visibility = if is_private || name.starts_with('_') {
                "private"
            } else {
                "public"
            };

            let prefix = if is_class_method { "def self." } else { "def " };
            let sig = format!("{prefix}{name}{params}");

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line: lineno,
                signature: sig,
                docstring: String::new(),
                visibility: visibility.into(),
                parent: current_class.clone(),
            });

            if visibility == "public" && !is_class_method {
                exports.push(name);
            }
            continue;
        }

        // Require
        if let Some(caps) = RE_REQUIRE.captures(trimmed) {
            imports.push(caps[1].to_string());
        }

        // end keyword resets some state
        if trimmed == "end" {
            // Simplified: could track nesting for accuracy
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}
