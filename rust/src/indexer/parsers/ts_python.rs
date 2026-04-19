/// Tree-sitter based Python parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

pub fn parse(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_python::LANGUAGE;
    if parser.set_language(&language.into()).is_err() {
        return super::python::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::python::parse(content, filepath),
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
        "class_definition" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let bases = child_field_text(content, node, "superclasses").unwrap_or_default();
            let line = node.start_position().row + 1;

            let sig = if bases.is_empty() {
                format!("class {name}")
            } else {
                format!("class {name}{bases}")
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line,
                signature: sig,
                docstring: extract_docstring(content, node),
                visibility: "public".into(),
                parent: None,
            });
            exports.push(name.clone());

            // Visit children with class context
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, Some(&name));
            }
            return; // Don't recurse again below
        }

        "function_definition" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let ret = child_field_text(content, node, "return_type");
            let line = node.start_position().row + 1;

            let is_method = parent_class.is_some();
            let kind = if is_method { "method" } else { "function" };

            let visibility = if name.starts_with('_') && !name.starts_with("__") {
                "private"
            } else {
                "public"
            };

            let sig = match &ret {
                Some(r) => format!("def {name}{params} -> {r}"),
                None => format!("def {name}{params}"),
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line,
                signature: sig,
                docstring: extract_docstring(content, node),
                visibility: visibility.into(),
                parent: parent_class.map(|s| s.to_string()),
            });

            if visibility == "public" && !is_method {
                exports.push(name);
            }
            return; // Don't recurse into function bodies for top-level symbols
        }

        "import_statement" => {
            // import foo, bar
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                if child.kind() == "dotted_name" {
                    let module = node_text(content, &child);
                    let normalized = normalize_import(&module);
                    if !normalized.is_empty() {
                        imports.push(normalized);
                    }
                }
            }
        }

        "import_from_statement" => {
            // from foo import bar
            if let Some(module_node) = node.child_by_field_name("module_name") {
                let module = node_text(content, &module_node);
                let normalized = normalize_import(&module);
                if !normalized.is_empty() {
                    imports.push(normalized);
                }
            }
        }

        "expression_statement" if parent_class.is_none() => {
            // Module-level assignments — check for UPPER_CASE constants
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                if child.kind() == "assignment" {
                    if let Some(left) = child.child_by_field_name("left") {
                        if left.kind() == "identifier" {
                            let name = node_text(content, &left);
                            if name
                                .chars()
                                .all(|c| c.is_uppercase() || c == '_' || c.is_ascii_digit())
                                && name.len() > 1
                            {
                                let line = left.start_position().row + 1;
                                let full_text = node_text(content, &node);
                                symbols.push(Symbol {
                                    name: name.clone(),
                                    kind: "const".into(),
                                    line,
                                    signature: full_text.chars().take(80).collect(),
                                    docstring: String::new(),
                                    visibility: "public".into(),
                                    parent: None,
                                });
                                exports.push(name);
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
        visit_node(content, &child, symbols, imports, exports, parent_class);
    }
}

fn child_field_text(content: &str, node: &tree_sitter::Node, field: &str) -> Option<String> {
    node.child_by_field_name(field)
        .map(|n| node_text(content, &n))
}

fn node_text(content: &str, node: &tree_sitter::Node) -> String {
    content[node.start_byte()..node.end_byte()].to_string()
}

fn normalize_import(module: &str) -> String {
    module.trim_start_matches('.').replace('.', "/")
}

fn extract_docstring(content: &str, node: &tree_sitter::Node) -> String {
    if let Some(body) = node.child_by_field_name("body") {
        if let Some(first) = body.named_child(0) {
            if first.kind() == "expression_statement" {
                if let Some(expr) = first.named_child(0) {
                    if expr.kind() == "string" || expr.kind() == "concatenated_string" {
                        let text = node_text(content, &expr);
                        let stripped = text
                            .trim_start_matches("\"\"\"")
                            .trim_start_matches("'''")
                            .trim_end_matches("\"\"\"")
                            .trim_end_matches("'''")
                            .trim();
                        return stripped.lines().next().unwrap_or("").to_string();
                    }
                }
            }
        }
    }
    String::new()
}
