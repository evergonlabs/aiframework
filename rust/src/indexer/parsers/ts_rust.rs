/// Tree-sitter based Rust parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

pub fn parse(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_rust::LANGUAGE;
    if parser.set_language(&language.into()).is_err() {
        return super::rust::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::rust::parse(content, filepath),
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
    parent_impl: Option<&str>,
) {
    match node.kind() {
        // impl block: impl Foo { ... } or impl Trait for Foo { ... }
        "impl_item" => {
            // Extract the type name being implemented
            let type_name = child_field_text(content, node, "type")
                .or_else(|| {
                    // For "impl Trait for Type", the type is the second type identifier
                    child_field_text(content, node, "body")
                        .and_then(|_| None) // fallback below
                })
                .unwrap_or_default();

            // Extract just the type name (strip generics)
            let type_name = type_name
                .split('<')
                .next()
                .unwrap_or(&type_name)
                .trim()
                .to_string();

            // Visit body with impl context
            if let Some(body) = node.child_by_field_name("body") {
                let mut cursor = body.walk();
                for child in body.named_children(&mut cursor) {
                    visit_node(
                        content,
                        &child,
                        symbols,
                        imports,
                        exports,
                        if type_name.is_empty() {
                            None
                        } else {
                            Some(&type_name)
                        },
                    );
                }
            }
            return;
        }

        // Function: fn foo() or pub fn foo() or pub async fn foo()
        "function_item" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;

            let is_pub = has_visibility(node, "public");
            let is_async = node_text_contains_before_fn(content, node, "async");
            let is_method = parent_impl.is_some();
            let kind = if is_method { "method" } else { "function" };

            let prefix = match (is_pub, is_async) {
                (true, true) => "pub async fn",
                (true, false) => "pub fn",
                (false, true) => "async fn",
                (false, false) => "fn",
            };
            let sig = format!("{prefix} {name}{params}");

            symbols.push(Symbol {
                name: name.clone(),
                kind: kind.into(),
                line,
                signature: sig,
                docstring: extract_preceding_doc(content, node),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: parent_impl.map(|s| s.to_string()),
            });
            if is_pub && !is_method {
                exports.push(name);
            }
            return;
        }

        // Struct
        "struct_item" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_pub = has_visibility(node, "public");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "struct".into(),
                line,
                signature: format!("struct {name}"),
                docstring: extract_preceding_doc(content, node),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            return;
        }

        // Enum
        "enum_item" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_pub = has_visibility(node, "public");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "enum".into(),
                line,
                signature: format!("enum {name}"),
                docstring: extract_preceding_doc(content, node),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            return;
        }

        // Trait
        "trait_item" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_pub = has_visibility(node, "public");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "trait".into(),
                line,
                signature: format!("trait {name}"),
                docstring: extract_preceding_doc(content, node),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            return;
        }

        // Type alias: type Foo = Bar;
        "type_item" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_pub = has_visibility(node, "public");

            let full = node_text(content, node);
            symbols.push(Symbol {
                name: name.clone(),
                kind: "type".into(),
                line,
                signature: full.chars().take(80).collect(),
                docstring: extract_preceding_doc(content, node),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            return;
        }

        // Const: const FOO: Type = val;
        "const_item" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_pub = has_visibility(node, "public");

            let full = node_text(content, node);
            symbols.push(Symbol {
                name: name.clone(),
                kind: "const".into(),
                line,
                signature: full.chars().take(80).collect(),
                docstring: extract_preceding_doc(content, node),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            return;
        }

        // Static: static FOO: Type = val;
        "static_item" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_pub = has_visibility(node, "public");

            let full = node_text(content, node);
            symbols.push(Symbol {
                name: name.clone(),
                kind: "const".into(),
                line,
                signature: full.chars().take(80).collect(),
                docstring: extract_preceding_doc(content, node),
                visibility: if is_pub { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_pub {
                exports.push(name);
            }
            return;
        }

        // use statements -> imports
        "use_declaration" => {
            let arg = child_field_text(content, node, "argument").unwrap_or_default();
            // Only track crate-local imports
            if arg.starts_with("crate::") || arg.starts_with("super::") {
                imports.push(arg.replace("::", "/"));
            }
            return;
        }

        // mod declarations -> imports
        "mod_item" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            // Only bare mod declarations (mod foo;), not mod foo { ... }
            if node.child_by_field_name("body").is_none() && !name.is_empty() {
                imports.push(name);
            }
            return;
        }

        _ => {}
    }

    // Recurse into children (unless already handled above)
    let mut cursor = node.walk();
    for child in node.named_children(&mut cursor) {
        visit_node(content, &child, symbols, imports, exports, parent_impl);
    }
}

/// Check if a node has a visibility modifier.
fn has_visibility(node: &tree_sitter::Node, _kind: &str) -> bool {
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        if child.kind() == "visibility_modifier" {
            return true;
        }
    }
    false
}

/// Check if the node text contains "async" before "fn".
fn node_text_contains_before_fn(content: &str, node: &tree_sitter::Node, keyword: &str) -> bool {
    let text = node_text(content, node);
    if let Some(fn_pos) = text.find("fn ") {
        text[..fn_pos].contains(keyword)
    } else {
        false
    }
}

fn child_field_text(content: &str, node: &tree_sitter::Node, field: &str) -> Option<String> {
    node.child_by_field_name(field)
        .map(|n| node_text(content, &n))
}

fn node_text(content: &str, node: &tree_sitter::Node) -> String {
    content[node.start_byte()..node.end_byte()].to_string()
}

/// Extract Rust /// doc comment from the previous sibling (line_comment or attribute_item).
fn extract_preceding_doc(content: &str, node: &tree_sitter::Node) -> String {
    if let Some(prev) = node.prev_named_sibling() {
        if prev.kind() == "line_comment" {
            let text = node_text(content, &prev);
            if text.starts_with("///") {
                let line = text.trim_start_matches("///").trim();
                if !line.is_empty() {
                    return line.to_string();
                }
            }
        }
    }
    String::new()
}
