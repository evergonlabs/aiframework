use regex::Regex;
use std::sync::LazyLock;

use crate::indexer::parse::Symbol;

static RE_FUNC_KEYWORD: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^function\s+(\w+)").unwrap()
});
static RE_FUNC_PARENS: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^(\w+)\s*\(\)\s*\{").unwrap()
});
static RE_SOURCE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"^\s*(?:source|\.) ["']?([^"'\n]+?)["']?\s*(?:#.*)?$"#).unwrap()
});
static RE_SAFE_PATH: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"^[\w./_-]+$").unwrap()
});

pub fn parse(content: &str, _filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    for (i, line) in content.lines().enumerate() {
        let lineno = i + 1;
        let trimmed = line.trim();

        // Skip comments
        if trimmed.starts_with('#') {
            continue;
        }

        // function keyword style
        if let Some(caps) = RE_FUNC_KEYWORD.captures(trimmed) {
            let name = caps[1].to_string();
            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line: lineno,
                signature: format!("function {name}()"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name);
            continue;
        }

        // name() { style
        if let Some(caps) = RE_FUNC_PARENS.captures(trimmed) {
            let name = caps[1].to_string();
            // Skip common keywords that look like functions
            if matches!(name.as_str(), "if" | "for" | "while" | "until" | "case" | "select") {
                continue;
            }
            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line: lineno,
                signature: format!("{name}()"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name);
            continue;
        }

        // source / . imports
        if let Some(caps) = RE_SOURCE.captures(trimmed) {
            let path = &caps[1];
            // Strip variable expansions and validate
            let cleaned = clean_bash_path(path);
            if !cleaned.is_empty() && RE_SAFE_PATH.is_match(&cleaned) {
                imports.push(cleaned);
            }
        }
    }

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}

/// Strip shell variable expansions from a path.
/// Handles: "$LIB_DIR/scanners/foo.sh" → "scanners/foo.sh"
///          "${ROOT}/lib/bar.sh" → "lib/bar.sh"
///          "$HOME/.config" → ".config"
fn clean_bash_path(path: &str) -> String {
    let mut result = path.to_string();

    // Remove all ${VAR} expansions (may appear anywhere in path)
    while result.contains("${") {
        if let Some(start) = result.find("${") {
            if let Some(end) = result[start..].find('}') {
                let after = start + end + 1;
                // Skip trailing / if present
                let skip = if result.as_bytes().get(after) == Some(&b'/') {
                    1
                } else {
                    0
                };
                result = format!("{}{}", &result[..start], &result[after + skip..]);
            } else {
                break;
            }
        }
    }

    // Remove $VAR/ prefixes (simple variable like $LIB_DIR/)
    while result.starts_with('$') {
        if let Some(slash) = result.find('/') {
            result = result[slash + 1..].to_string();
        } else {
            // Bare $VAR with no path — can't resolve
            return String::new();
        }
    }

    // Remove $(command) substitutions
    while result.contains("$(") {
        if let Some(start) = result.find("$(") {
            // Find matching )
            let mut depth = 0;
            let mut end = start;
            for (i, ch) in result[start..].char_indices() {
                match ch {
                    '(' => depth += 1,
                    ')' => {
                        depth -= 1;
                        if depth == 0 {
                            end = start + i;
                            break;
                        }
                    }
                    _ => {}
                }
            }
            if end > start {
                let after = end + 1;
                let skip = if result.as_bytes().get(after) == Some(&b'/') {
                    1
                } else {
                    0
                };
                result = format!("{}{}", &result[..start], &result[after + skip..]);
            } else {
                break;
            }
        }
    }

    result
}
