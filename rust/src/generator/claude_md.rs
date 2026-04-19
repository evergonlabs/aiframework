use serde_json::Value;

/// Generate a CLAUDE.md from manifest + optional code index.
/// Produces a lean, high-signal file (80-150 lines) that Claude Code reads automatically.
pub fn generate(manifest: &Value, code_index: Option<&Value>) -> String {
    let mut out = String::with_capacity(8192);

    let name = str_or(manifest, &["identity", "name"], "project");
    let desc = str_or(manifest, &["identity", "description"], "");
    let lang = str_or(manifest, &["stack", "language"], "unknown");
    let fw = str_or(manifest, &["stack", "framework"], "none");
    let arch_type = str_or(manifest, &["archetype", "type"], "application");
    let arch_maturity = str_or(manifest, &["archetype", "maturity"], "active");
    let arch_complexity = str_or(manifest, &["archetype", "complexity"], "moderate");

    // Commands
    let lint = str_or(manifest, &["commands", "lint"], "NOT_CONFIGURED");
    let typecheck = str_or(manifest, &["commands", "typecheck"], "NOT_CONFIGURED");
    let test = str_or(manifest, &["commands", "test"], "NOT_CONFIGURED");
    let build = str_or(manifest, &["commands", "build"], "NOT_CONFIGURED");
    let install = str_or(manifest, &["commands", "install"], "NOT_CONFIGURED");

    // Header
    out.push_str(&format!("# CLAUDE.md — {name}\n\n"));
    if !desc.is_empty() {
        out.push_str(&format!("> {desc}\n\n"));
    }

    // Stack line
    let stack_label = if fw != "none" {
        format!("{lang}/{fw}")
    } else {
        lang.clone()
    };
    out.push_str(&format!(
        "| You need to... | Read |\n|----------------|------|\n| Understand this repo | This file |\n\n"
    ));

    // Commands section
    out.push_str("## Commands\n\n```bash\n");
    if lint != "NOT_CONFIGURED" {
        out.push_str(&format!("# Lint\n{lint}\n\n"));
    }
    if typecheck != "NOT_CONFIGURED" {
        out.push_str(&format!("# Type check\n{typecheck}\n\n"));
    }
    if test != "NOT_CONFIGURED" {
        out.push_str(&format!("# Test\n{test}\n\n"));
    }
    if build != "NOT_CONFIGURED" {
        out.push_str(&format!("# Build\n{build}\n\n"));
    }
    if install != "NOT_CONFIGURED" {
        out.push_str(&format!("# Install\n{install}\n\n"));
    }
    out.push_str("```\n\n");

    // Architecture
    out.push_str(&format!(
        "## Architecture\n\n- **Stack**: {stack_label}\n- **Archetype**: {arch_type} ({arch_maturity}, {arch_complexity})\n"
    ));

    // Monorepo
    if manifest["stack"]["is_monorepo"].as_bool().unwrap_or(false) {
        let tool = str_or(manifest, &["stack", "monorepo_tool"], "unknown");
        out.push_str(&format!("- **Monorepo**: yes ({tool})\n"));
    }
    out.push('\n');

    // Key locations from code index
    if let Some(index) = code_index {
        if let Some(top_files) = index["_meta"]["top_files"].as_array() {
            if !top_files.is_empty() {
                out.push_str("## Key Files\n\n");
                out.push_str("**Most important files** (by dependency rank):\n");
                for entry in top_files.iter().take(15) {
                    let file = entry["file"].as_str().unwrap_or("?");
                    let score = entry["importance"].as_u64().unwrap_or(0);
                    if score > 0 {
                        out.push_str(&format!("- `{file}`\n"));
                    }
                }
                out.push('\n');
            }
        }

        // Languages detected
        if let Some(langs) = index["_meta"]["languages"].as_object() {
            if langs.len() > 1 {
                let lang_list: Vec<&str> = langs.keys().map(|k| k.as_str()).collect();
                out.push_str(&format!(
                    "**Languages**: {}\n\n",
                    lang_list.join(", ")
                ));
            }
        }
    }

    // Key locations from structure
    if let Some(source_dirs) = manifest["structure"]["source_dirs"].as_array() {
        if !source_dirs.is_empty() {
            out.push_str("## Key Locations\n\n");
            for dir in source_dirs {
                if let Some(d) = dir.as_str() {
                    out.push_str(&format!("- **Source**: `{d}/`\n"));
                }
            }
            if let Some(test_dirs) = manifest["structure"]["test_dirs"].as_array() {
                for dir in test_dirs {
                    if let Some(d) = dir.as_str() {
                        out.push_str(&format!("- **Tests**: `{d}/`\n"));
                    }
                }
            }
            out.push('\n');
        }
    }

    // Entry points
    if let Some(entries) = manifest["structure"]["entry_points"].as_array() {
        if !entries.is_empty() {
            out.push_str("**Entry points**: ");
            let entry_strs: Vec<&str> = entries
                .iter()
                .filter_map(|e| e.as_str())
                .take(5)
                .collect();
            out.push_str(&format!("`{}`\n\n", entry_strs.join("`, `")));
        }
    }

    // Environment variables
    if let Some(vars) = manifest["env"]["variables"].as_array() {
        if !vars.is_empty() {
            out.push_str("## Environment Variables\n\n");
            out.push_str("| Variable | Required | Description |\n|----------|----------|-------------|\n");
            for var in vars.iter().take(20) {
                let name = var["name"].as_str().unwrap_or("?");
                let sensitive = var["is_sensitive"].as_bool().unwrap_or(false);
                let req = if sensitive { "Yes" } else { "No" };
                out.push_str(&format!("| {name} | {req} | - |\n"));
            }
            out.push('\n');
        }
    }

    // Invariants
    out.push_str("## Invariants\n\n");
    out.push_str("- **INV-1**: LLM trust boundary — validate all AI output\n");

    // Domain-specific invariants
    if let Some(domains) = manifest["domain"]["detected_domains"].as_array() {
        for domain in domains {
            let domain_name = domain["name"].as_str().unwrap_or("");
            match domain_name {
                "auth" => out.push_str("- **INV-AUTH**: Never store credentials in source code\n"),
                "database" => {
                    out.push_str("- **INV-DB**: All schema changes require migrations\n")
                }
                "api" => out.push_str(
                    "- **INV-API**: All endpoints must validate input and return proper error codes\n",
                ),
                "ai" | "ml" => {
                    out.push_str("- **INV-AI**: Validate and sanitize all LLM-generated content\n")
                }
                _ => {}
            }
        }
    }
    out.push('\n');

    // Makefile targets
    if let Some(targets) = manifest["commands"]["makefile_targets"].as_array() {
        if !targets.is_empty() {
            out.push_str("## Makefile\n\n```bash\n");
            for t in targets {
                if let Some(s) = t.as_str() {
                    // Only include clean target names
                    if s.len() < 30
                        && !s.contains(' ')
                        && !s.contains('|')
                        && !s.contains('"')
                    {
                        out.push_str(&format!("make {s}\n"));
                    }
                }
            }
            out.push_str("```\n\n");
        }
    }

    // Common mistakes
    out.push_str("## Common Mistakes\n\n");
    out.push_str("- Not running the full test suite before marking done\n");
    out.push_str("- Editing the wrong config file (staging vs production)\n");
    out.push_str("- Forgetting to update documentation after changes\n\n");

    // Footer
    out.push_str(&format!(
        "---\n\n*Generated by aiframework v2. Stack: {stack_label}.*\n"
    ));

    out
}

/// Navigate nested JSON safely.
fn str_or(value: &Value, path: &[&str], default: &str) -> String {
    let mut current = value;
    for key in path {
        current = &current[*key];
    }
    current
        .as_str()
        .unwrap_or(default)
        .to_string()
}
