use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_MODULE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*defmodule\s+([\w.]+)").unwrap()
});
static RE_DEF: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(def|defp)\s+(\w+[?!]?)\s*(\([^)]*\))?").unwrap()
});
static RE_DEFMACRO: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(defmacro|defmacrop)\s+(\w+[?!]?)\s*(\([^)]*\))?").unwrap()
});
static RE_ALIAS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*alias\s+([\w.]+)").unwrap()
});
static RE_IMPORT: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^\s*(?:import|use|require)\s+([\w.]+)").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let mut current_module: Option<String> = None;

    for (i, line) in content.lines().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        if trimmed.starts_with('#') {
            continue;
        }

        if let Some(caps) = RE_MODULE.captures(trimmed) {
            let name = caps[1].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(), // Elixir modules ≈ classes
                line: lineno,
                signature: format!("defmodule {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());
            current_module = Some(name);
            continue;
        }

        if let Some(caps) = RE_DEF.captures(trimmed) {
            let keyword = &caps[1];
            let name = caps[2].to_string();
            let params = caps.get(3).map_or("", |m| m.as_str());
            let is_private = keyword == "defp";

            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line: lineno,
                signature: format!("{keyword} {name}{params}"),
                docstring: String::new(),
                visibility: if is_private { "private" } else { "public" }.into(),
                parent: current_module.clone(),
            });

            if !is_private {
                exports.push(name);
            }
            continue;
        }

        if let Some(caps) = RE_DEFMACRO.captures(trimmed) {
            let keyword = &caps[1];
            let name = caps[2].to_string();
            let params = caps.get(3).map_or("", |m| m.as_str());
            let is_private = keyword == "defmacrop";

            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line: lineno,
                signature: format!("{keyword} {name}{params}"),
                docstring: String::new(),
                visibility: if is_private { "private" } else { "public" }.into(),
                parent: current_module.clone(),
            });
            continue;
        }

        if let Some(caps) = RE_ALIAS.captures(trimmed) {
            imports.push(caps[1].to_string());
            continue;
        }

        if let Some(caps) = RE_IMPORT.captures(trimmed) {
            imports.push(caps[1].to_string());
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}
