/// Tier system and configuration loading.
/// Matches lib/config.sh from the bash version.
///
/// Tiers control which generators run:
/// - Lean: CLAUDE.md + AGENTS.md only (simple projects)
/// - Standard: + cursorrules, hooks, CI, skills, rules, docs, tracking (moderate)
/// - Full: + vault, vault ingest, wiki graph, sheal (complex)
/// - Enterprise: + extended invariants, full vault ingestion

use serde_json::Value;
use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Tier {
    Lean = 0,
    Standard = 1,
    Full = 2,
    Enterprise = 3,
}

impl Tier {
    pub fn from_str_opt(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "lean" | "lite" => Some(Tier::Lean),
            "standard" => Some(Tier::Standard),
            "full" => Some(Tier::Full),
            "enterprise" => Some(Tier::Enterprise),
            _ => None,
        }
    }

    /// Auto-detect tier from archetype complexity in the manifest.
    pub fn from_complexity(complexity: &str) -> Self {
        match complexity {
            "simple" => Tier::Lean,
            "moderate" => Tier::Standard,
            "complex" => Tier::Full,
            "enterprise" => Tier::Enterprise,
            _ => Tier::Full, // backward-compat default
        }
    }
}

impl std::fmt::Display for Tier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Tier::Lean => write!(f, "lean"),
            Tier::Standard => write!(f, "standard"),
            Tier::Full => write!(f, "full"),
            Tier::Enterprise => write!(f, "enterprise"),
        }
    }
}

/// Resolved configuration for a run.
pub struct Config {
    pub tier: Tier,
    pub formats: Vec<String>,
    pub vault: bool,
    pub custom_invariants: Vec<String>,
    pub exclude_dirs: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            tier: Tier::Full,
            formats: vec!["claude".into(), "agents".into(), "cursor".into()],
            vault: true,
            custom_invariants: Vec::new(),
            exclude_dirs: Vec::new(),
        }
    }
}

/// Load config from `.aiframework/config.json` (if present), then resolve
/// the tier from: CLI flag > config file > auto-detect from manifest > default (full).
pub fn load_config(target: &Path, manifest: &Value, cli_tier: Option<&str>) -> Config {
    let mut cfg = Config::default();

    // --- Read .aiframework/config.json ---
    let config_path = target.join(".aiframework/config.json");
    if config_path.is_file() {
        if let Ok(content) = std::fs::read_to_string(&config_path) {
            if let Ok(json) = serde_json::from_str::<Value>(&content) {
                // formats
                if let Some(arr) = json.get("formats").and_then(|v| v.as_array()) {
                    let fmts: Vec<String> = arr
                        .iter()
                        .filter_map(|v| v.as_str().map(String::from))
                        .collect();
                    if !fmts.is_empty() {
                        cfg.formats = fmts;
                    }
                }

                // tier from config file
                if let Some(t) = json.get("tier").and_then(|v| v.as_str()) {
                    if let Some(parsed) = Tier::from_str_opt(t) {
                        cfg.tier = parsed;
                    }
                }

                // vault
                if let Some(false) = json.get("vault").and_then(|v| v.as_bool()) {
                    cfg.vault = false;
                }

                // custom_invariants
                if let Some(arr) = json.get("custom_invariants").and_then(|v| v.as_array()) {
                    cfg.custom_invariants = arr
                        .iter()
                        .filter_map(|v| v.as_str().map(String::from))
                        .collect();
                }

                // exclude_dirs
                if let Some(arr) = json.get("exclude_dirs").and_then(|v| v.as_array()) {
                    cfg.exclude_dirs = arr
                        .iter()
                        .filter_map(|v| v.as_str().map(String::from))
                        .collect();
                }
            }
        }
    }

    // --- Resolve tier: CLI flag > config file > auto-detect ---
    if let Some(flag) = cli_tier {
        if let Some(parsed) = Tier::from_str_opt(flag) {
            cfg.tier = parsed;
        }
    } else if cfg.tier == Tier::Full {
        // Config didn't set a non-default tier — try auto-detect from manifest
        let complexity = manifest
            .get("archetype")
            .and_then(|a| a.get("complexity"))
            .and_then(|c| c.as_str())
            .unwrap_or("");
        if !complexity.is_empty() {
            cfg.tier = Tier::from_complexity(complexity);
        }
        // else keep default (Full) for backward compat
    }

    cfg
}

/// Shorthand: resolve tier only (backward-compat helper).
pub fn resolve_tier(cli_tier: Option<&str>, target: &Path, manifest: &Value) -> Tier {
    load_config(target, manifest, cli_tier).tier
}

/// Check whether a format is enabled in this config.
pub fn format_enabled(cfg: &Config, fmt: &str) -> bool {
    cfg.formats.iter().any(|f| f == fmt)
}

/// Check whether the current tier includes a given feature.
pub fn tier_includes(tier: Tier, feature: &str) -> bool {
    match feature {
        // Always included (Lean+) — Claude Code essentials
        "claude" | "agents" | "hooks" | "rules" | "settings" => true,

        // Standard+
        "cursor" | "ci" | "skills" | "docs" | "tracking" => {
            tier >= Tier::Standard
        }

        // Full+
        "vault" | "vault-full" | "vault-ingest" | "wiki-graph" | "sheal" | "specialists" => {
            tier >= Tier::Full
        }

        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tier_ordering() {
        assert!(Tier::Lean < Tier::Standard);
        assert!(Tier::Standard < Tier::Full);
        assert!(Tier::Full < Tier::Enterprise);
    }

    #[test]
    fn tier_includes_lean() {
        assert!(tier_includes(Tier::Lean, "claude"));
        assert!(tier_includes(Tier::Lean, "agents"));
        assert!(!tier_includes(Tier::Lean, "cursor"));
        assert!(!tier_includes(Tier::Lean, "vault"));
    }

    #[test]
    fn tier_includes_standard() {
        assert!(tier_includes(Tier::Standard, "claude"));
        assert!(tier_includes(Tier::Standard, "hooks"));
        assert!(tier_includes(Tier::Standard, "docs"));
        assert!(!tier_includes(Tier::Standard, "vault"));
    }

    #[test]
    fn tier_includes_full() {
        assert!(tier_includes(Tier::Full, "claude"));
        assert!(tier_includes(Tier::Full, "hooks"));
        assert!(tier_includes(Tier::Full, "vault"));
        assert!(tier_includes(Tier::Full, "sheal"));
    }

    #[test]
    fn parse_tier_strings() {
        assert_eq!(Tier::from_str_opt("lean"), Some(Tier::Lean));
        assert_eq!(Tier::from_str_opt("FULL"), Some(Tier::Full));
        assert_eq!(Tier::from_str_opt("Enterprise"), Some(Tier::Enterprise));
        assert_eq!(Tier::from_str_opt("bogus"), None);
    }

    #[test]
    fn auto_detect_from_manifest() {
        assert_eq!(Tier::from_complexity("simple"), Tier::Lean);
        assert_eq!(Tier::from_complexity("moderate"), Tier::Standard);
        assert_eq!(Tier::from_complexity("complex"), Tier::Full);
        assert_eq!(Tier::from_complexity("enterprise"), Tier::Enterprise);
    }
}
