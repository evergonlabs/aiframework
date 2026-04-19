/// Tree-sitter based Elixir parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

pub fn parse(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_elixir::LANGUAGE;
    if parser.set_language(&language.into()).is_err() {
        return super::elixir::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::elixir::parse(content, filepath),
    };

    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let root = tree.root_node();
    visit_node(content, &root, &mut symbols, &mut imports, &mut exports, None);

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
    current_module: Option<&str>,
) {
    match node.kind() {
        "call" => {
            // Elixir uses call nodes for defmodule, def, defp, etc.
            let target = first_named_child_text(content, node);

            match target.as_str() {
                "defmodule" => {
                    let name = call_first_arg_text(content, node);
                    if !name.is_empty() {
                        let line = node.start_position().row + 1;
                        symbols.push(Symbol {
                            name: name.clone(),
                            kind: "class".into(), // Elixir modules ~ classes
                            line,
                            signature: format!("defmodule {name}"),
                            docstring: String::new(),
                            visibility: "public".into(),
                            parent: None,
                        });
                        exports.push(name.clone());

                        // Visit children with module context
                        let mut cursor = node.walk();
                        for child in node.named_children(&mut cursor) {
                            visit_node(content, &child, symbols, imports, exports, Some(&name));
                        }
                        return;
                    }
                }

                "def" | "defp" => {
                    let is_private = target == "defp";
                    let (name, params) = extract_def_name_params(content, node);
                    if !name.is_empty() {
                        let line = node.start_position().row + 1;
                        let sig = if params.is_empty() {
                            format!("{target} {name}")
                        } else {
                            format!("{target} {name}{params}")
                        };

                        symbols.push(Symbol {
                            name: name.clone(),
                            kind: "function".into(),
                            line,
                            signature: sig,
                            docstring: String::new(),
                            visibility: if is_private { "private" } else { "public" }.into(),
                            parent: current_module.map(|s| s.to_string()),
                        });

                        if !is_private {
                            exports.push(name);
                        }
                    }
                    return;
                }

                "defmacro" | "defmacrop" => {
                    let is_private = target == "defmacrop";
                    let (name, params) = extract_def_name_params(content, node);
                    if !name.is_empty() {
                        let line = node.start_position().row + 1;
                        let sig = if params.is_empty() {
                            format!("{target} {name}")
                        } else {
                            format!("{target} {name}{params}")
                        };

                        symbols.push(Symbol {
                            name: name.clone(),
                            kind: "function".into(),
                            line,
                            signature: sig,
                            docstring: String::new(),
                            visibility: if is_private { "private" } else { "public" }.into(),
                            parent: current_module.map(|s| s.to_string()),
                        });
                    }
                    return;
                }

                "alias" => {
                    let arg = call_first_arg_text(content, node);
                    if !arg.is_empty() {
                        imports.push(arg);
                    }
                    return;
                }

                "import" | "use" | "require" => {
                    let arg = call_first_arg_text(content, node);
                    if !arg.is_empty() {
                        imports.push(arg);
                    }
                    return;
                }

                _ => {}
            }
        }

        _ => {}
    }

    // Recurse into children
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        visit_node(content, &child, symbols, imports, exports, current_module);
    }
}

/// Get text of first named child (the call target, e.g. "defmodule", "def")
fn first_named_child_text(content: &str, node: &tree_sitter::Node) -> String {
    if let Some(child) = node.named_child(0) {
        return node_text(content, &child);
    }
    String::new()
}

/// Extract the first argument of a call (e.g., module name in `defmodule Foo do`)
fn call_first_arg_text(content: &str, node: &tree_sitter::Node) -> String {
    // The arguments are typically the second named child
    if let Some(args) = node.child_by_field_name("arguments") {
        if let Some(first) = args.named_child(0) {
            return node_text(content, &first);
        }
    }
    // Fallback: try second named child directly
    if let Some(child) = node.named_child(1) {
        let text = node_text(content, &child);
        // Strip "do...end" block if present
        if let Some(name) = text.split_whitespace().next() {
            return name.to_string();
        }
    }
    String::new()
}

/// Extract function name and params from a def/defp call node
fn extract_def_name_params(content: &str, node: &tree_sitter::Node) -> (String, String) {
    // In Elixir tree-sitter, `def foo(a, b)` has the function call as second child
    if let Some(child) = node.named_child(1) {
        let text = node_text(content, &child);
        // Could be "foo(a, b)" or just "foo"
        if let Some(paren_pos) = text.find('(') {
            let name = text[..paren_pos].trim().to_string();
            // Find matching close paren
            if let Some(close) = text.rfind(')') {
                let params = text[paren_pos..=close].to_string();
                return (name, params);
            }
        } else {
            // No parens — just the function name
            let name = text.split_whitespace().next().unwrap_or("").to_string();
            return (name, String::new());
        }
    }
    (String::new(), String::new())
}

fn node_text(content: &str, node: &tree_sitter::Node) -> String {
    content[node.start_byte()..node.end_byte()].to_string()
}
