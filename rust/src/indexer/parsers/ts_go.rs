/// Tree-sitter based Go parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

pub fn parse(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_go::LANGUAGE;
    if parser.set_language(&language.into()).is_err() {
        return super::go::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::go::parse(content, filepath),
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
        // Function declaration: func Name(...) or method: func (r *Type) Name(...)
        "function_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_exported = name.starts_with(|c: char| c.is_uppercase());

            let sig = format!("func {name}{params}");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: if is_exported { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_exported {
                exports.push(name);
            }
            return;
        }

        // Method declaration: func (r *Type) Name(...)
        "method_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let receiver = child_field_text(content, node, "receiver");
            let line = node.start_position().row + 1;
            let is_exported = name.starts_with(|c: char| c.is_uppercase());

            let sig = match &receiver {
                Some(r) => format!("func {r} {name}{params}"),
                None => format!("func {name}{params}"),
            };

            // Extract receiver type as parent
            let parent = receiver.as_ref().and_then(|r| {
                let r = r.trim_start_matches('(').trim_end_matches(')');
                r.split_whitespace().last().map(|s| s.trim_start_matches('*').to_string())
            });

            symbols.push(Symbol {
                name: name.clone(),
                kind: "method".into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: if is_exported { "public" } else { "private" }.into(),
                parent,
            });
            if is_exported {
                exports.push(name);
            }
            return;
        }

        // Type declaration: type Foo struct/interface/alias
        "type_declaration" => {
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                if child.kind() == "type_spec" {
                    let name = child_field_text(content, &child, "name").unwrap_or_default();
                    let line = child.start_position().row + 1;
                    let is_exported = name.starts_with(|c: char| c.is_uppercase());

                    // Determine kind from the type value
                    let type_node = child.child_by_field_name("type");
                    let (kind, kind_str) = match type_node.as_ref().map(|n| n.kind()) {
                        Some("struct_type") => ("struct", "struct"),
                        Some("interface_type") => ("interface", "interface"),
                        _ => ("type", "type"),
                    };

                    let sig = if kind == "type" {
                        let full = node_text(content, &child);
                        full.chars().take(80).collect()
                    } else {
                        format!("type {name} {kind_str}")
                    };

                    symbols.push(Symbol {
                        name: name.clone(),
                        kind: kind.into(),
                        line,
                        signature: sig,
                        docstring: String::new(),
                        visibility: if is_exported { "public" } else { "private" }.into(),
                        parent: None,
                    });
                    if is_exported {
                        exports.push(name);
                    }
                }
            }
            return;
        }

        // Const/var declarations
        "const_declaration" | "var_declaration" => {
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                if child.kind() == "const_spec" || child.kind() == "var_spec" {
                    let name = child_field_text(content, &child, "name").unwrap_or_default();
                    if name.is_empty() {
                        continue;
                    }
                    let line = child.start_position().row + 1;
                    let is_exported = name.starts_with(|c: char| c.is_uppercase());

                    let full = node_text(content, &child);
                    symbols.push(Symbol {
                        name: name.clone(),
                        kind: "const".into(),
                        line,
                        signature: full.chars().take(80).collect(),
                        docstring: String::new(),
                        visibility: if is_exported { "public" } else { "private" }.into(),
                        parent: None,
                    });
                    if is_exported {
                        exports.push(name);
                    }
                }
            }
            return;
        }

        // Import declarations
        "import_declaration" => {
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                if child.kind() == "import_spec_list" {
                    let mut inner_cursor = child.walk();
                    for spec in child.named_children(&mut inner_cursor) {
                        if spec.kind() == "import_spec" {
                            if let Some(path_node) = spec.child_by_field_name("path") {
                                let path = node_text(content, &path_node);
                                let path = path.trim_matches('"');
                                if let Some(last) = path.rsplit('/').next() {
                                    imports.push(last.to_string());
                                }
                            }
                        }
                    }
                } else if child.kind() == "import_spec" {
                    if let Some(path_node) = child.child_by_field_name("path") {
                        let path = node_text(content, &path_node);
                        let path = path.trim_matches('"');
                        if let Some(last) = path.rsplit('/').next() {
                            imports.push(last.to_string());
                        }
                    }
                } else if child.kind() == "interpreted_string_literal" {
                    // Single import without spec: import "fmt"
                    let path = node_text(content, &child);
                    let path = path.trim_matches('"');
                    if let Some(last) = path.rsplit('/').next() {
                        imports.push(last.to_string());
                    }
                }
            }
            return;
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
