pub mod agents_md;
pub mod ci;
pub mod claude_md;
pub mod cursorrules;
pub mod docs;
pub mod hooks;
pub mod report;
pub mod rules;
pub mod sheal_gen;
pub mod skills;
pub mod tracking;
pub mod vault;
pub mod vault_ingest;
pub mod wiki_graph;

use crate::config::Tier;
use serde_json::Value;
use std::path::Path;

/// Generate all output files from a manifest + code index.
/// Skips files that already exist to avoid overwriting user customizations.
/// Uses default tier (Full) for backward compatibility.
pub fn generate(
    target: &Path,
    manifest: &Value,
    code_index: Option<&Value>,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    generate_with_tier(target, manifest, code_index, Tier::Full)
}

/// Generate output files gated by tier.
///
/// Tier gating:
/// - Lean:       CLAUDE.md, AGENTS.md
/// - Standard+:  + .cursorrules, hooks, CI, skills, rules, docs, tracking
/// - Full+:      + vault, vault_ingest, wiki_graph, sheal
/// - Enterprise: same as Full (extended invariants handled in config)
pub fn generate_with_tier(
    target: &Path,
    manifest: &Value,
    code_index: Option<&Value>,
    tier: Tier,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mut generated = Vec::new();

    // ── Always: CLAUDE.md + AGENTS.md (Lean+) ──────────────────────────

    // CLAUDE.md — always write (it's the primary output)
    let claude_md = claude_md::generate(manifest, code_index);
    let claude_path = target.join("CLAUDE.md");
    write_if_missing_or_generated(&claude_path, &claude_md)?;
    generated.push("CLAUDE.md".into());

    // AGENTS.md — multi-agent config (Cursor, Copilot, Codex, Gemini)
    let agents_path = target.join("AGENTS.md");
    if !agents_path.exists() {
        let agents_md = agents_md::generate(manifest);
        std::fs::write(&agents_path, &agents_md)?;
        generated.push("AGENTS.md".into());
    }

    // ── Standard+: cursorrules, hooks, CI, skills, rules, docs, tracking ─

    if tier >= Tier::Standard {
        // .cursorrules — Cursor IDE configuration
        let cursorrules_path = target.join(".cursorrules");
        if !cursorrules_path.exists() {
            let cursorrules_content = cursorrules::generate(manifest);
            std::fs::write(&cursorrules_path, &cursorrules_content)?;
            generated.push(".cursorrules".into());
        }

        // .githooks/pre-commit + pre-push (skip if hooks already exist)
        let hooks_dir = target.join(".githooks");
        if !hooks_dir.join("pre-commit").exists() {
            let hook_files = hooks::generate(target, manifest)?;
            generated.extend(hook_files);
        }

        // .github/workflows/ci.yml (skip if CI already configured)
        let ci_path = target.join(".github/workflows/ci.yml");
        if !ci_path.exists() {
            let ci_content = ci::generate(manifest);
            let ci_dir = target.join(".github/workflows");
            std::fs::create_dir_all(&ci_dir)?;
            std::fs::write(&ci_path, &ci_content)?;
            generated.push(".github/workflows/ci.yml".into());
        }

        // docs/reference/architecture.md
        let arch_path = target.join("docs/reference/architecture.md");
        if !arch_path.exists() {
            let docs_dir = target.join("docs/reference");
            std::fs::create_dir_all(&docs_dir)?;
            let docs_content = docs::generate(manifest, code_index);
            std::fs::write(&arch_path, &docs_content)?;
            generated.push("docs/reference/architecture.md".into());
        }

        // .claude/skills/{short}-review and {short}-ship
        let skill_files = skills::generate(target, manifest)?;
        generated.extend(skill_files);

        // .claude/rules/workflow.md
        let rule_files = rules::generate(target, manifest)?;
        generated.extend(rule_files);

        // .claude/hooks/session-start.sh (smart session detection)
        let hook_dir = target.join(".claude/hooks");
        let hook_path = hook_dir.join("session-start.sh");
        if !hook_path.exists() {
            std::fs::create_dir_all(&hook_dir)?;
            std::fs::write(&hook_path, include_str!("../../session-start-hook.sh"))?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                std::fs::set_permissions(&hook_path, std::fs::Permissions::from_mode(0o755))?;
            }
            generated.push(".claude/hooks/session-start.sh".into());
        }

        // tools/learnings/{short}-learnings.jsonl
        let tracking_files = tracking::generate(target, manifest)?;
        generated.extend(tracking_files);
    }

    // ── Full+: vault, vault_ingest, wiki_graph, sheal ───────────────────

    if tier >= Tier::Full {
        // vault/ directory structure
        let vault_files = vault::generate(target, manifest, code_index)?;
        generated.extend(vault_files);

        // vault/wiki/entities/ — ingest code index into entity pages
        if code_index.is_some() {
            let ingest_files = vault_ingest::generate(target, manifest, code_index)?;
            generated.extend(ingest_files);

            // vault/wiki/concepts/architecture.md — graph overview
            let concepts_dir = target.join("vault/wiki/concepts");
            let arch_wiki_path = concepts_dir.join("architecture.md");
            if !arch_wiki_path.exists() {
                std::fs::create_dir_all(&concepts_dir)?;
                let graph_content = wiki_graph::generate(manifest, code_index);
                std::fs::write(&arch_wiki_path, &graph_content)?;
                generated.push("vault/wiki/concepts/architecture.md".into());
            }
        }

        // .sheal/ session intelligence config
        let sheal_files = sheal_gen::generate(target, manifest)?;
        generated.extend(sheal_files);
    }

    Ok(generated)
}

const USER_SECTIONS_MARKER: &str = "<!-- USER SECTIONS -->";

/// Write file if it doesn't exist or was generated by aiframework (has our footer).
/// When overwriting a generated file:
/// 1. Creates a .bak backup before writing
/// 2. Preserves user-added sections (content after `<!-- USER SECTIONS -->` marker)
fn write_if_missing_or_generated(
    path: &Path,
    content: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    if path.exists() {
        let existing = std::fs::read_to_string(path)?;
        if existing.contains("Generated by aiframework") {
            // Create .bak backup before overwriting
            let bak_path = path.with_extension("md.bak");
            std::fs::write(&bak_path, &existing)?;

            // Preserve user sections from the existing file
            let user_sections = extract_user_sections(&existing);
            let final_content = if user_sections.is_empty() {
                content.to_string()
            } else {
                // Ensure generated content has the marker, then append user content
                let base = if content.contains(USER_SECTIONS_MARKER) {
                    // Replace everything after the marker with preserved user content
                    if let Some(idx) = content.find(USER_SECTIONS_MARKER) {
                        format!(
                            "{}{}\n{}",
                            &content[..idx],
                            USER_SECTIONS_MARKER,
                            user_sections
                        )
                    } else {
                        content.to_string()
                    }
                } else {
                    format!("{}\n\n{}\n{}", content.trim_end(), USER_SECTIONS_MARKER, user_sections)
                };
                base
            };

            std::fs::write(path, final_content)?;
        }
        // Otherwise skip — user owns this file
    } else {
        std::fs::write(path, content)?;
    }
    Ok(())
}

/// Extract user-added sections: content after `<!-- USER SECTIONS -->` marker.
/// Also detects ## sections not present in our standard template.
fn extract_user_sections(existing: &str) -> String {
    // Primary: look for explicit USER SECTIONS marker
    if let Some(idx) = existing.find(USER_SECTIONS_MARKER) {
        let after = &existing[idx + USER_SECTIONS_MARKER.len()..];
        let trimmed = after.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }

    // Secondary: find ## sections that aren't part of the standard template
    let standard_sections = [
        "## Commands",
        "## Invariants",
        "## Architecture",
        "## Key Locations",
        "## Environment Variables",
        "## Gotchas",
        "## Common Mistakes",
        "## Key State",
        "## Makefile",
        "## Automated Enforcement",
        "## Skills",
        "## Self-Healing Workflow",
        "## Vault",
        "## Doc Sync",
        "## Getting Started",
        "## Self-Evolution",
        "## Session Learnings",
    ];

    let mut user_parts = Vec::new();
    let mut current_section = String::new();
    let mut is_user_section = false;

    for line in existing.lines() {
        if line.starts_with("## ") {
            // Flush previous user section
            if is_user_section && !current_section.trim().is_empty() {
                user_parts.push(current_section.clone());
            }
            current_section.clear();
            is_user_section = !standard_sections.iter().any(|s| line.starts_with(s));
        }
        if is_user_section {
            current_section.push_str(line);
            current_section.push('\n');
        }
    }
    // Flush last section
    if is_user_section && !current_section.trim().is_empty() {
        user_parts.push(current_section);
    }

    user_parts.join("\n").trim().to_string()
}
