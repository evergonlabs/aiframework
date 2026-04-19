use serde_json::Value;

/// Generate a human-readable ASCII report to stdout.
/// Beautiful retro-style output with Unicode box drawing characters.
pub fn generate(manifest: &Value, code_index: Option<&Value>) -> String {
    let mut out = String::with_capacity(4096);

    let name = manifest["identity"]["name"].as_str().unwrap_or("Project");
    let version = manifest["identity"]["version"].as_str().unwrap_or("–");
    let language = manifest["stack"]["language"].as_str().unwrap_or("unknown");
    let framework = manifest["stack"]["framework"].as_str().unwrap_or("none");
    let archetype = manifest["archetype"]["type"].as_str().unwrap_or("unknown");

    let stack_label = if framework != "none" {
        format!("{language} / {framework}")
    } else {
        language.to_string()
    };

    // Header box
    let title = format!(" {name} ");
    let w = 60;
    out.push_str(&top_line(w));
    out.push_str(&padded_line("", w));
    out.push_str(&center_line(&title, w));
    out.push_str(&padded_line("", w));
    out.push_str(&bottom_line(w));
    out.push('\n');

    // Identity section
    out.push_str(&section_header("IDENTITY", w));
    out.push_str(&kv_line("Name", name, w));
    out.push_str(&kv_line("Version", version, w));
    out.push_str(&kv_line("Stack", &stack_label, w));
    out.push_str(&kv_line("Archetype", archetype, w));
    out.push_str(&separator(w));

    // Domains
    if let Some(domains) = manifest["domain"]["detected_domains"].as_array() {
        if !domains.is_empty() {
            out.push_str(&section_header("DOMAINS", w));
            for d in domains {
                let display = d["display"].as_str().unwrap_or("?");
                out.push_str(&item_line(display, w));
            }
            out.push_str(&separator(w));
        }
    }

    // Commands
    out.push_str(&section_header("COMMANDS", w));
    for key in &["test", "lint", "build", "dev", "start"] {
        if let Some(cmd) = manifest["commands"][key].as_str() {
            if !cmd.is_empty() {
                out.push_str(&kv_line(key, cmd, w));
            }
        }
    }
    out.push_str(&separator(w));

    // Quality tools
    if let Some(quality) = manifest["quality"].as_object() {
        if !quality.is_empty() {
            out.push_str(&section_header("QUALITY", w));
            if let Some(linter) = quality.get("linter").and_then(|v| v.as_str()) {
                out.push_str(&kv_line("Linter", linter, w));
            }
            if let Some(formatter) = quality.get("formatter").and_then(|v| v.as_str()) {
                out.push_str(&kv_line("Formatter", formatter, w));
            }
            if let Some(tc) = quality.get("type_checker").and_then(|v| v.as_str()) {
                out.push_str(&kv_line("Type check", tc, w));
            }
            out.push_str(&separator(w));
        }
    }

    // CI coverage
    if let Some(ci) = manifest["ci"].as_object() {
        if !ci.is_empty() {
            out.push_str(&section_header("CI", w));
            if let Some(provider) = ci.get("provider").and_then(|v| v.as_str()) {
                out.push_str(&kv_line("Provider", provider, w));
            }
            out.push_str(&separator(w));
        }
    }

    // Code index stats
    if let Some(ci) = code_index {
        let meta = &ci["_meta"];
        out.push_str(&section_header("CODE INDEX", w));
        if let Some(n) = meta["total_files"].as_u64() {
            out.push_str(&kv_line("Files", &n.to_string(), w));
        }
        if let Some(n) = meta["total_symbols"].as_u64() {
            out.push_str(&kv_line("Symbols", &n.to_string(), w));
        }
        if let Some(n) = meta["total_edges"].as_u64() {
            out.push_str(&kv_line("Edges", &n.to_string(), w));
        }

        // Languages
        if let Some(langs) = meta["languages"].as_object() {
            let parts: Vec<String> = langs
                .iter()
                .map(|(k, v)| format!("{k}:{}", v.as_u64().unwrap_or(0)))
                .collect();
            out.push_str(&kv_line("Languages", &parts.join(", "), w));
        }
        out.push_str(&separator(w));

        // Top files
        if let Some(top) = meta["top_files"].as_array() {
            out.push_str(&section_header("TOP FILES (PageRank)", w));
            for f in top.iter().take(10) {
                let path = f["file"].as_str().unwrap_or("?");
                let score = f["importance"].as_u64().unwrap_or(0);
                let label = format!("{score:>4}  {path}");
                out.push_str(&item_line(&label, w));
            }
            out.push_str(&separator(w));
        }
    }

    // Skills / suggestions
    if let Some(skills) = manifest["skills"]["suggested"].as_array() {
        if !skills.is_empty() {
            out.push_str(&section_header("SKILL SUGGESTIONS", w));
            for s in skills {
                if let Some(name) = s.as_str() {
                    out.push_str(&item_line(name, w));
                }
            }
            out.push_str(&separator(w));
        }
    }

    // Footer
    out.push_str(&bottom_line(w));

    out
}

// ── Box drawing helpers ─────────────────────────────────────

fn top_line(w: usize) -> String {
    format!("┌{}┐\n", "─".repeat(w))
}

fn bottom_line(w: usize) -> String {
    format!("└{}┘\n", "─".repeat(w))
}

fn separator(w: usize) -> String {
    format!("├{}┤\n", "─".repeat(w))
}

fn padded_line(text: &str, w: usize) -> String {
    let text_len = text.chars().count();
    let pad = if w > text_len { w - text_len } else { 0 };
    format!("│{text}{}│\n", " ".repeat(pad))
}

fn center_line(text: &str, w: usize) -> String {
    let text_len = text.chars().count();
    if text_len >= w {
        return padded_line(text, w);
    }
    let left = (w - text_len) / 2;
    let right = w - text_len - left;
    format!("│{}{}{}│\n", " ".repeat(left), text, " ".repeat(right))
}

fn section_header(label: &str, w: usize) -> String {
    let label_part = format!("┤ {label} ├");
    let label_len = label.len() + 4; // " label " + the ┤├
    let remaining = if w > label_len { w - label_len } else { 0 };
    format!("├─{label_part}{}┤\n", "─".repeat(remaining))
}

fn kv_line(key: &str, value: &str, w: usize) -> String {
    let content = format!("  {key}: {value}");
    padded_line(&content, w)
}

fn item_line(text: &str, w: usize) -> String {
    let content = format!("  · {text}");
    padded_line(&content, w)
}
