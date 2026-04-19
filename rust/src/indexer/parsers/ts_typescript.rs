/// Tree-sitter based TypeScript/JavaScript parser — more accurate than regex.
/// Uses AST traversal for reliable symbol extraction.
/// Handles both TypeScript (.ts/.tsx) and JavaScript (.js/.jsx/.mjs/.cjs).

use tree_sitter::Parser;

use crate::indexer::parse::Symbol;

/// Parse TypeScript (.ts / .tsx) files.
pub fn parse_ts(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_typescript::LANGUAGE_TYPESCRIPT;
    if parser.set_language(&language.into()).is_err() {
        return super::typescript::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::typescript::parse(content, filepath),
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

/// Parse JavaScript (.js / .jsx / .mjs / .cjs) files.
pub fn parse_js(content: &str, filepath: &str) -> (Vec<Symbol>, Vec<String>, Vec<String>) {
    let mut parser = Parser::new();
    let language = tree_sitter_javascript::LANGUAGE;
    if parser.set_language(&language.into()).is_err() {
        return super::typescript::parse(content, filepath);
    }

    let tree = match parser.parse(content, None) {
        Some(t) => t,
        None => return super::typescript::parse(content, filepath),
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
        // Class declaration: class Foo { ... } or export class Foo { ... }
        "class_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_export = is_exported(node);

            let superclass = child_field_text(content, node, "superclass");
            let sig = match &superclass {
                Some(base) => format!("class {name} extends {base}"),
                None => format!("class {name}"),
            };

            symbols.push(Symbol {
                name: name.clone(),
                kind: "class".into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name.clone());
            }

            // Visit children with class context
            if let Some(body) = node.child_by_field_name("body") {
                let mut cursor = body.walk();
                for child in body.named_children(&mut cursor) {
                    visit_node(content, &child, symbols, imports, exports, Some(&name));
                }
            }
            return;
        }

        // Interface declaration (TypeScript only)
        "interface_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_export = is_exported(node);

            symbols.push(Symbol {
                name: name.clone(),
                kind: "interface".into(),
                line,
                signature: format!("interface {name}"),
                docstring: String::new(),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            return;
        }

        // Type alias (TypeScript only)
        "type_alias_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_export = is_exported(node);

            symbols.push(Symbol {
                name: name.clone(),
                kind: "type".into(),
                line,
                signature: format!("type {name}"),
                docstring: String::new(),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            return;
        }

        // Enum declaration (TypeScript only)
        "enum_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_export = is_exported(node);

            symbols.push(Symbol {
                name: name.clone(),
                kind: "enum".into(),
                line,
                signature: format!("enum {name}"),
                docstring: String::new(),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            return;
        }

        // Function declaration: function foo() {} or export function foo() {}
        "function_declaration" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;
            let is_export = is_exported(node);
            let is_async = has_async_keyword(content, node);

            let prefix = if is_async { "async function" } else { "function" };
            let sig = format!("{prefix} {name}{params}");

            symbols.push(Symbol {
                name: name.clone(),
                kind: "function".into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: if is_export { "public" } else { "private" }.into(),
                parent: None,
            });
            if is_export {
                exports.push(name);
            }
            return;
        }

        // Method definition inside a class body
        "method_definition" => {
            let name = child_field_text(content, node, "name").unwrap_or_default();
            let params = child_field_text(content, node, "parameters").unwrap_or_default();
            let line = node.start_position().row + 1;

            // Skip constructor-like keywords
            if matches!(
                name.as_str(),
                "if" | "for" | "while" | "switch" | "catch" | "return" | "new" | "throw"
            ) {
                return;
            }

            let is_async = has_async_keyword(content, node);
            let prefix = if is_async { "async " } else { "" };
            let sig = format!("{prefix}{name}{params}");

            symbols.push(Symbol {
                name,
                kind: "method".into(),
                line,
                signature: sig,
                docstring: String::new(),
                visibility: "public".into(),
                parent: parent_class.map(|s| s.to_string()),
            });
            return;
        }

        // Variable declarations: const foo = ..., export const foo = ...
        // Catches arrow functions and exported constants
        "lexical_declaration" | "variable_declaration" => {
            let is_export = is_exported(node);
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                if child.kind() == "variable_declarator" {
                    let name = child_field_text(content, &child, "name").unwrap_or_default();
                    if name.is_empty() {
                        continue;
                    }
                    let line = child.start_position().row + 1;

                    // Check if value is an arrow function
                    let is_arrow = child
                        .child_by_field_name("value")
                        .map(|v| v.kind() == "arrow_function")
                        .unwrap_or(false);

                    let kind = if is_arrow { "function" } else { "const" };
                    let sig = if is_arrow {
                        format!("const {name} = () =>")
                    } else {
                        let full = node_text(content, node);
                        full.chars().take(80).collect()
                    };

                    if is_export {
                        symbols.push(Symbol {
                            name: name.clone(),
                            kind: kind.into(),
                            line,
                            signature: sig,
                            docstring: String::new(),
                            visibility: "public".into(),
                            parent: None,
                        });
                        exports.push(name);
                    } else if is_arrow {
                        symbols.push(Symbol {
                            name,
                            kind: kind.into(),
                            line,
                            signature: sig,
                            docstring: String::new(),
                            visibility: "private".into(),
                            parent: None,
                        });
                    }
                }
            }
            return;
        }

        // Export statement wrapping other declarations
        "export_statement" => {
            let mut cursor = node.walk();
            for child in node.named_children(&mut cursor) {
                visit_node(content, &child, symbols, imports, exports, parent_class);
            }
            return;
        }

        // Import statements
        "import_statement" => {
            if let Some(source) = node.child_by_field_name("source") {
                let module = node_text(content, &source);
                let module = module.trim_matches(|c| c == '\'' || c == '"');
                let normalized = normalize_ts_import(module);
                if !normalized.is_empty() {
                    imports.push(normalized);
                }
            }
            return;
        }

        // require() calls — handled in call_expression
        "call_expression" => {
            if let Some(func) = node.child_by_field_name("function") {
                if node_text(content, &func) == "require" {
                    if let Some(args) = node.child_by_field_name("arguments") {
                        if let Some(first_arg) = args.named_child(0) {
                            let module = node_text(content, &first_arg);
                            let module = module.trim_matches(|c| c == '\'' || c == '"');
                            let normalized = normalize_ts_import(module);
                            if !normalized.is_empty() {
                                imports.push(normalized);
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

/// Check if a node is wrapped in an export_statement parent.
fn is_exported(node: &tree_sitter::Node) -> bool {
    if let Some(parent) = node.parent() {
        return parent.kind() == "export_statement";
    }
    false
}

/// Check if a function/method has the async keyword.
fn has_async_keyword(content: &str, node: &tree_sitter::Node) -> bool {
    // Check the text before the function keyword for "async"
    let text = node_text(content, node);
    text.starts_with("async ")
}

fn child_field_text(content: &str, node: &tree_sitter::Node, field: &str) -> Option<String> {
    node.child_by_field_name(field)
        .map(|n| node_text(content, &n))
}

fn node_text(content: &str, node: &tree_sitter::Node) -> String {
    content[node.start_byte()..node.end_byte()].to_string()
}

/// Normalize a TS/JS import path — skip npm packages (no ./ or ../ prefix).
fn normalize_ts_import(module: &str) -> String {
    if !module.starts_with('.') && !module.contains('/') {
        return String::new();
    }
    let cleaned = module
        .trim_start_matches("./")
        .trim_start_matches("../");
    cleaned.to_string()
}
