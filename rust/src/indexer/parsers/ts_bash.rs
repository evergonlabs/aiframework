/// Tree-sitter based Bash parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

pub fn parse(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_bash::LANGUAGE;
    if parser.set_language(&language.into()).is_err() {
        return super::bash::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::bash::parse(content, filepath),
    };

    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let root = tree.root_node();
    visit_node(content, &root, &mut symbols, &mut imports, &mut exports);

    imports.sort();
    imports.dedup();
    (symbols, imports, exports)
}

fn visit_node(
    content: &str,
    node: &tree_sitter::Node,
    symbols: &mut Vec<Symbol>,
    imports: &mut Vec<String>,
    exports: &mut Vec<String>,
) {
    match node.kind() {
        // Function definition: both `function name { ... }` and `name() { ... }`
        "function_definition" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            if name.is_empty() {
                return;
            }
            let line = node.start_position().row + 1;

            // Skip common keywords that look like functions
            if matches!(
                name.as_str(),
                "if" | "for" | "while" | "until" | "case" | "select"
            ) {
                return;
            }

            let sig = format!("function {name}()");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name);
            return;
        }

        // Command: source/. statements for imports
        "command" => {
            let mut cursor = node.walk();
            let children: Vec<_> = node.named_children(&mut cursor).collect();

            if let Some(cmd_name_node) = children.first() {
                if cmd_name_node.kind() == "command_name" {
                    let cmd_name = node_text(content, cmd_name_node);
                    if cmd_name == "source" || cmd_name == "." {
                        // Get the argument (the file being sourced)
                        if let Some(arg_node) = children.get(1) {
                            let path = node_text(content, arg_node);
                            let path = path.trim_matches(|c| c == '"' || c == '\'');
                            let cleaned = clean_bash_path(path);
                            if !cleaned.is_empty() && is_safe_path(&cleaned) {
                                imports.push(cleaned);
                            }
                        }
                    }
                }
            }
        }

        _ => {}
    }

    // Recurse into children (unless already handled above)
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        visit_node(content, &child, symbols, imports, exports);
    }
}

fn child_field_text(content: &str, node: &tree_sitter::Node, field: &str) -> Option<String> {
    node.child_by_field_name(field)
        .map(|n| node_text(content, &n))
}

fn node_text(content: &str, node: &tree_sitter::Node) -> String {
    content[node.start_byte()..node.end_byte()].to_string()
}

/// Check if a path contains only safe characters (no shell metacharacters).
fn is_safe_path(path: &str) -> bool {
    path.chars()
        .all(|c| c.is_alphanumeric() || matches!(c, '.' | '/' | '_' | '-'))
}

/// Strip shell variable expansions from a path.
/// Reuses the same logic as the regex-based bash parser.
fn clean_bash_path(path: &str) -> String {
    let mut result = path.to_string();

    // Remove all ${VAR} expansions
    while result.contains("${") {
        if let Some(start) = result.find("${") {
            if let Some(end) = result[start..].find('}') {
                let after = start + end + 1;
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

    // Remove $VAR/ prefixes
    while result.starts_with('$') {
        if let Some(slash) = result.find('/') {
            result = result[slash + 1..].to_string();
        } else {
            return String::new();
        }
    }

    // Remove $(command) substitutions
    while result.contains("$(") {
        if let Some(start) = result.find("$(") {
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
