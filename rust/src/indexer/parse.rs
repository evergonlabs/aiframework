/// Parsed file data collected from a single source file.
pub struct FileData {
    pub path: String,
    pub language: String,
    pub size_bytes: u64,
    pub lines: usize,
    pub symbols: Vec<Symbol>,
    pub imports: Vec<String>,
    pub exports: Vec<String>,
}

/// A code symbol: function, class, method, type, interface, etc.
#[derive(Clone, Debug)]
pub struct Symbol {
    pub name: String,
    pub kind: String, // "function", "class", "method", "interface", "type", "struct", "enum", "trait", "const"
    pub line: usize,
    pub signature: String,
    pub docstring: String,
    pub visibility: String, // "public" or "private"
    pub parent: Option<String>,
}
