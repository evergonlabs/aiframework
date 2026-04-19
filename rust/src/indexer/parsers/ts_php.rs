/// Tree-sitter based PHP parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

pub fn parse(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_php::LANGUAGE_PHP;
    if parser.set_language(&language.into()).is_err() {
        return super::php::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::php::parse(content, filepath),
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
    parent_class: Option<&str>,
) {
    match node.kind() {
        "class_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line,
                signature: format!("class {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());

            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, Some(&name));
            }
            return;
        }

        "interface_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;

            symbols.push(Symbol {
                name: name.clone(),
                kind: "interface".into(),
                line,
                signature: format!("interface {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());

            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, Some(&name));
            }
            return;
        }

        "trait_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(), // traits are class-like
                line,
                signature: format!("trait {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());

            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, Some(&name));
            }
            return;
        }

        "enum_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;

            symbols.push(Symbol {
                name: name.clone(),
                kind: "enum".into(),
                line,
                signature: format!("enum {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());

            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, Some(&name));
            }
            return;
        }

        "function_definition" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;

            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line,
                signature: format!("function {name}{params}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());
            return;
        }

        "method_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;

            let visibility = if has_modifier(content, node, "private") {
                "private"
            } else if has_modifier(content, node, "protected") {
                "protected"
            } else {
                "public"
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: "method".into(),
                line,
                signature: format!("function {name}{params}"),
                docstring: String::new(),
                visibility: visibility.into(),
                parent: parent_class.map(|s| s.to_string()),
            });
            return;
        }

        "namespace_use_declaration" => {
            // use Foo\Bar\Baz;
            let text = node_text(content, node);
            let ns = text
                .trim_start_matches("use ")
                .trim_end_matches(';')
                .trim();
            if !ns.is_empty() {
                imports.push(ns.replace('\\', "/"));
            }
        }

        "expression_statement" => {
            // Check for require/include statements
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                match child.kind() {
                    "require_expression" | "require_once_expression"
                    | "include_expression" | "include_once_expression" => {
                        // Extract the path from the require/include
                        let mut inner_cursor = child.walk();
                        for arg in child.named_children(&mut inner_cursor) {
                            if arg.kind() == "string" {
                                let text = node_text(content, &arg);
                                let stripped = text.trim_matches(|c| c == '"' || c == '\'');
                                if !stripped.is_empty() {
                                    imports.push(stripped.to_string());
                                }
                            }
                        }
                    }
                    _ => {}
                }
            }
        }

        _ => {}
    }

    // Recurse into children
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        visit_node(content, &child, symbols, imports, exports, parent_class);
    }
}

fn has_modifier(content: &str, node: &tree_sitter::Node, modifier: &str) -> bool {
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        if child.kind() == "visibility_modifier" {
            let text = node_text(content, &child);
            if text == modifier {
                return true;
            }
        }
    }
    false
}

fn child_field_text(content: &str, node: &tree_sitter::Node, field: &str) -> Option<String> {
    node.child_by_field_name(field)
        .map(|n| node_text(content, &n))
}

fn node_text(content: &str, node: &tree_sitter::Node) -> String {
    content[node.start_byte()..node.end_byte()].to_string()
}
