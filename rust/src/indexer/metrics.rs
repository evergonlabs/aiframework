/// Code complexity and quality metrics computed during indexing.
/// These go beyond what the Python indexer provides.


/// Compute cyclomatic complexity estimate from source code.
/// Counts decision points: if, else, for, while, case, catch, &&, ||, ?
pub fn cyclomatic_complexity(content: &str) -> usize {
    let mut complexity = 1; // base path

    for line in content.lines() {
        let trimmed = line.trim();
        // Skip comments
        if trimmed.starts_with("//")
            || trimmed.starts_with('#')
            || trimmed.starts_with("/*")
            || trimmed.starts_with('*')
        {
            continue;
        }

        // Count decision keywords
        for word in trimmed.split(|c: char| !c.is_alphanumeric() && c != '_') {
            match word {
                "if" | "elif" | "elsif" | "else" | "for" | "while" | "case" | "when"
                | "catch" | "except" | "rescue" => complexity += 1,
                _ => {}
            }
        }

        // Count boolean operators
        complexity += trimmed.matches("&&").count();
        complexity += trimmed.matches("||").count();
        // Ternary
        if trimmed.contains('?') && trimmed.contains(':') && !trimmed.starts_with("//") {
            complexity += 1;
        }
    }

    complexity
}

/// Count logical lines of code (excluding blanks and comments).
pub fn logical_loc(content: &str) -> usize {
    let mut count = 0;
    let mut in_block_comment = false;

    for line in content.lines() {
        let trimmed = line.trim();

        if in_block_comment {
            if trimmed.contains("*/") {
                in_block_comment = false;
            }
            continue;
        }

        if trimmed.starts_with("/*") {
            in_block_comment = !trimmed.contains("*/");
            continue;
        }

        if trimmed.is_empty()
            || trimmed.starts_with("//")
            || trimmed.starts_with('#')
            || trimmed.starts_with("'''")
            || trimmed.starts_with("\"\"\"")
        {
            continue;
        }

        count += 1;
    }

    count
}

/// Detect code patterns that indicate quality or design issues.
pub fn detect_patterns(content: &str) -> Vec<&'static str> {
    let mut patterns = Vec::new();

    let lines: Vec<&str> = content.lines().collect();
    let total_lines = lines.len();

    // God file: too many functions or too many lines
    if total_lines > 500 {
        patterns.push("large_file");
    }

    // Count functions
    let func_count = lines
        .iter()
        .filter(|l| {
            let t = l.trim();
            t.starts_with("def ")
                || t.starts_with("fn ")
                || t.starts_with("func ")
                || t.starts_with("function ")
                || t.contains("function ")
                || (t.contains("=>") && t.contains("const "))
        })
        .count();

    if func_count > 20 {
        patterns.push("many_functions");
    }

    // TODO/FIXME/HACK markers
    let todo_count: usize = lines
        .iter()
        .filter(|l| {
            let upper = l.to_uppercase();
            upper.contains("TODO") || upper.contains("FIXME") || upper.contains("HACK")
        })
        .count();

    if todo_count > 5 {
        patterns.push("many_todos");
    }

    // Deep nesting (rough heuristic: lines with 5+ tabs/20+ spaces of indent)
    let deep_lines = lines
        .iter()
        .filter(|l| {
            let indent = l.len() - l.trim_start().len();
            indent >= 20 || l.chars().take_while(|&c| c == '\t').count() >= 5
        })
        .count();

    if deep_lines > 10 {
        patterns.push("deep_nesting");
    }

    patterns
}

/// Compute file-level metrics.
#[allow(dead_code)]
pub struct FileMetrics {
    pub total_lines: usize,
    pub logical_loc: usize,
    pub complexity: usize,
    pub patterns: Vec<&'static str>,
}

pub fn compute_file_metrics(content: &str) -> FileMetrics {
    FileMetrics {
        total_lines: content.lines().count(),
        logical_loc: logical_loc(content),
        complexity: cyclomatic_complexity(content),
        patterns: detect_patterns(content),
    }
}
