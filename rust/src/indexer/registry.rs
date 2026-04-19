use super::parse::Symbol;
use super::parsers;

/// Parser function signature: (content, filepath) -> (symbols, imports, exports)
pub type ParserFn = fn(&str, &str) -> (Vec<Symbol>, Vec<String>, Vec<String>);

/// Get parser for a file extension. Returns None if unsupported.
pub fn get_parser(ext: &str) -> Option<ParserFn> {
    match ext {
        // Python (tree-sitter based — more accurate than regex)
        "py" => Some(parsers::ts_python::parse),

        // TypeScript (tree-sitter based)
        "ts" | "tsx" => Some(parsers::ts_typescript::parse_ts),

        // JavaScript (tree-sitter based)
        "js" | "jsx" | "mjs" | "cjs" => Some(parsers::ts_typescript::parse_js),

        // Go (tree-sitter based)
        "go" => Some(parsers::ts_go::parse),

        // Rust (tree-sitter based)
        "rs" => Some(parsers::ts_rust::parse),

        // Ruby (tree-sitter based)
        "rb" => Some(parsers::ts_ruby::parse),

        // Bash / Shell (tree-sitter based)
        "sh" | "bash" | "zsh" => Some(parsers::ts_bash::parse),

        // Java (tree-sitter based)
        "java" => Some(parsers::ts_java::parse),

        // C# (regex — keeps binary small)
        "cs" => Some(parsers::csharp::parse),

        // PHP (regex)
        "php" => Some(parsers::php::parse),

        // Kotlin (regex)
        "kt" | "kts" => Some(parsers::kotlin::parse),

        // Swift (regex)
        "swift" => Some(parsers::swift::parse),

        // Elixir (regex)
        "ex" | "exs" => Some(parsers::elixir::parse),

        _ => None,
    }
}

/// Map file extension to canonical language name (matches Python indexer).
pub fn ext_to_language(ext: &str) -> &'static str {
    match ext {
        "py" => "python",
        "ts" | "tsx" => "typescript",
        "js" | "jsx" | "mjs" | "cjs" => "javascript",
        "go" => "go",
        "rs" => "rust",
        "rb" => "ruby",
        "sh" | "bash" | "zsh" => "bash",
        "java" => "java",
        "cs" => "csharp",
        "php" => "php",
        "kt" | "kts" => "kotlin",
        "swift" => "swift",
        "ex" | "exs" => "elixir",
        _ => "unknown",
    }
}
