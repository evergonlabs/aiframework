/// Tree-sitter based Swift parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

pub fn parse(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_swift::LANGUAGE;
    if parser.set_language(&language.into()).is_err() {
        return super::swift::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::swift::parse(content, filepath),
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
    parent_type: Option<&str>,
) {
    match node.kind() {
        "class_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_pub = has_access_modifier(content, node, "public")
                || has_access_modifier(content, node, "open");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line,
                signature: format!("class {name}"),
                docstring: String::new(),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name.clone());
            }

            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, Some(&name));
            }
            return;
        }

        "struct_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_pub = has_access_modifier(content, node, "public");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "struct".into(),
                line,
                signature: format!("struct {name}"),
                docstring: String::new(),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name.clone());
            }

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

        "protocol_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;

            symbols.push(Symbol {
                name: name.clone(),
                kind: "interface".into(),
                line,
                signature: format!("protocol {name}"),
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

        "function_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;

            let kind = if parent_type.is_some() { "method" } else { "function" };
            let is_priv = has_access_modifier(content, node, "private")
                || has_access_modifier(content, node, "fileprivate");

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line,
                signature: format!("func {name}{params}"),
                docstring: String::new(),
                visibility: if is_priv { "private" } else { "public" }.into(),
                parent: parent_type.map(|s| s.to_string()),
            });

            if !is_priv && parent_type.is_none() {
                exports.push(name);
            }
            return;
        }

        "import_declaration" => {
            // import Foundation
            let text = node_text(content, node);
            let module = text.trim_start_matches("import ").trim();
            if !module.is_empty() {
                imports.push(module.to_string());
            }
        }

        _ => {}
    }

    // Recurse into children
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        visit_node(content, &child, symbols, imports, exports, parent_type);
    }
}

fn has_access_modifier(content: &str, node: &tree_sitter::Node, modifier: &str) -> bool {
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        let kind = child.kind();
        if kind == "modifiers" || kind == "modifier" {
            let text = node_text(content, &child);
            if text.contains(modifier) {
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
