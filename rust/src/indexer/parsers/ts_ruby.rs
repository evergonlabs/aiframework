/// Tree-sitter based Ruby parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

pub fn parse(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_ruby::LANGUAGE;
    if parser.set_language(&language.into()).is_err() {
        return super::ruby::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::ruby::parse(content, filepath),
    };

    let mut symbols = Vec::new();
    let mut imports = Vec::new();
    let mut exports = Vec::new();

    let root = tree.root_node();
    visit_node(content, &root, &mut symbols, &mut imports, &mut exports, None, false);

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
    is_private: bool,
) {
    match node.kind() {
        "class" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let superclass = child_field_text(content, node, "superclass");
            let line = node.start_position().row + 1;

            let sig = match &superclass {
                Some(base) => format!("class {name} < {base}"),
                None => format!("class {name}"),
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());

            // Visit children with class context
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, Some(&name), false);
            }
            return;
        }

        "module" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(), // Ruby modules are class-like
                line,
                signature: format!("module {name}"),
                docstring: String::new(),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());

            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, Some(&name), false);
            }
            return;
        }

        "method" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;

            let kind = if parent_class.is_some() { "method" } else { "function" };
            let visibility = if is_private || name.starts_with('_') {
                "private"
            } else {
                "public"
            };

            let sig = format!("def {name}{params}");

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: visibility.into(),
                parent: parent_class.map(|s| s.to_string()),
            });

            if visibility == "public" && parent_class.is_none() {
                exports.push(name);
            }
            return;
        }

        "singleton_method" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;

            let sig = format!("def self.{name}{params}");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "method".into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: if is_private { "private" } else { "public" }.into(),
                parent: parent_class.map(|s| s.to_string()),
            });
            return;
        }

        "call" => {
            // Handle require/require_relative and private marker
            let method_name = child_field_text(content, node, "method").unwrap_or_default();

            match method_name.as_str() {
                "require" | "require_relative" => {
                    if let Some(args) = node.child_by_field_name("arguments") {
                        let mut cursor = args.walk();
                        for arg in args.named_children(&mut cursor) {
                            if arg.kind() == "string" {
                                let text = node_text(content, &arg);
                                let stripped = text.trim_matches(|c| c == '"' || c == '\'');
                                if !stripped.is_empty() {
                                    imports.push(stripped.to_string());
                                }
                            }
                        }
                    }
                }
                "private" => {
                    // private marker — remaining methods in this scope are private
                    // Check if it's a bare `private` call (no arguments)
                    if node.child_by_field_name("arguments").is_none() {
                        // Mark subsequent siblings as private
                        let mut next = node.next_named_sibling();
                        while let Some(sibling) = next {
                            visit_node(content, &sibling, symbols, imports, exports, parent_class, true);
                            next = sibling.next_named_sibling();
                        }
                        return;
                    }
                }
                _ => {}
            }
        }

        _ => {}
    }

    // Recurse into children
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        visit_node(content, &child, symbols, imports, exports, parent_class, is_private);
    }
}

fn child_field_text(content: &str, node: &tree_sitter::Node, field: &str) -> Option<String> {
    node.child_by_field_name(field)
        .map(|n| node_text(content, &n))
}

fn node_text(content: &str, node: &tree_sitter::Node) -> String {
    content[node.start_byte()..node.end_byte()].to_string()
}
