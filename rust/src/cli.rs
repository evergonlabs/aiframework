use clap::{Parser, Subcommand};
use serde_json::json;
use std::path::PathBuf;

use crate::config;
use crate::generator;
use crate::indexer;
use crate::scanner;
use crate::telemetry;
use crate::ui;
use crate::validator;

#[derive(Parser)]
#[command(name = "aiframework", version, about = "Make Claude Code understand your project instantly")]
pub struct Args {
    #[command(subcommand)]
    pub command: Command,
}

#[derive(Subcommand)]
pub enum Command {
    /// Build code index: symbols, imports, edges, PageRank
    Index {
        /// Target directory to index
        #[arg(long, default_value = ".")]
        target: PathBuf,

        /// Output path for code-index.json
        #[arg(long)]
        output: Option<PathBuf>,

        /// Print summary to stdout instead of writing JSON
        #[arg(long)]
        summary: bool,
    },

    /// Full pipeline: discover + generate + verify
    Run {
        /// Target directory
        #[arg(long, default_value = ".")]
        target: PathBuf,

        /// Skip code indexing
        #[arg(long)]
        no_index: bool,

        /// Skip interactive prompts
        #[arg(long)]
        non_interactive: bool,

        /// Preview without writing
        #[arg(long)]
        dry_run: bool,

        /// Detailed output
        #[arg(long)]
        verbose: bool,

        /// Override tier: lean, standard, full, enterprise
        #[arg(long)]
        tier: Option<String>,
    },

    /// Scan repo into manifest.json + code-index.json
    Discover {
        /// Target directory
        #[arg(long, default_value = ".")]
        target: PathBuf,

        /// Output directory for manifest
        #[arg(long)]
        output: Option<PathBuf>,

        /// Skip code indexing
        #[arg(long)]
        no_index: bool,

        /// Detailed output
        #[arg(long)]
        verbose: bool,

        /// Override tier: lean, standard, full, enterprise
        #[arg(long)]
        tier: Option<String>,
    },

    /// Read manifest, generate all files
    Generate {
        /// Path to manifest.json
        #[arg(long)]
        manifest: Option<PathBuf>,

        /// Target directory
        #[arg(long, default_value = ".")]
        target: PathBuf,

        /// Override tier: lean, standard, full, enterprise
        #[arg(long)]
        tier: Option<String>,
    },

    /// Validate generated files
    Verify {
        /// Target directory
        #[arg(long, default_value = ".")]
        target: PathBuf,

        /// Path to manifest.json
        #[arg(long)]
        manifest: Option<PathBuf>,
    },

    /// Re-discover + generate only if drift detected
    Refresh {
        /// Target directory
        #[arg(long, default_value = ".")]
        target: PathBuf,
    },

    /// Human-readable report of everything detected
    Report {
        #[arg(long, default_value = ".")]
        target: PathBuf,
    },

    /// MCP server — expose repo context to Claude Code via JSON-RPC
    Mcp {
        /// Target directory
        #[arg(long, default_value = ".")]
        target: PathBuf,
    },

    /// Cross-repo knowledge store statistics
    Stats {
        /// Target directory (for current repo stats fallback)
        #[arg(long, default_value = ".")]
        target: PathBuf,
    },

    /// Self-update + refresh all bootstrapped repos
    #[command(alias = "upgrade", alias = "self-update")]
    Update,
}

pub fn parse() -> Args {
    Args::parse()
}

pub fn run(args: Args) -> Result<(), Box<dyn std::error::Error>> {
    match args.command {
        Command::Index {
            target,
            output,
            summary,
        } => {
            let result = indexer::index_repo(&target)?;

            if summary {
                let meta = &result["_meta"];
                ui::banner();
                ui::phase("INDEX");
                ui::phase_kv("files", &meta["total_files"].to_string());
                ui::phase_kv("symbols", &meta["total_symbols"].to_string());
                ui::phase_kv("edges", &meta["total_edges"].to_string());
                ui::phase_kv("time", &format!("{}ms", meta["elapsed_ms"]));
                if let Some(langs) = meta["languages"].as_object() {
                    let lang_list: Vec<&str> = langs.keys().map(|k| k.as_str()).collect();
                    ui::phase_kv("languages", &lang_list.join(", "));
                }
                if let Some(top) = meta["top_files"].as_array() {
                    println!();
                    ui::dim("  Top files by PageRank:");
                    for f in top.iter().take(10) {
                        let score = f["importance"].as_u64().unwrap_or(0);
                        let path = f["file"].as_str().unwrap_or("?");
                        ui::phase_detail(&format!("{score:>4}  {path}"));
                    }
                }
                println!();
            } else {
                let out_path = output.unwrap_or_else(|| target.join(".aiframework/code-index.json"));
                if let Some(parent) = out_path.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                let json = serde_json::to_string_pretty(&result)?;
                std::fs::write(&out_path, &json)?;
                ui::ok(&format!("Wrote {}", out_path.display()));
            }
            Ok(())
        }

        Command::Run {
            target,
            no_index,
            non_interactive,
            dry_run,
            verbose,
            tier: cli_tier,
        } => {
            let start = std::time::Instant::now();
            ui::banner();

            // Phase 1: DISCOVER
            ui::phase("DISCOVER");
            let manifest = scanner::discover(&target)?;

            let aif_dir = target.join(".aiframework");
            std::fs::create_dir_all(&aif_dir)?;

            let manifest_path = aif_dir.join("manifest.json");
            let manifest_json = serde_json::to_string_pretty(&manifest)?;
            std::fs::write(&manifest_path, &manifest_json)?;

            let lang = manifest["stack"]["language"].as_str().unwrap_or("unknown");
            let fw = manifest["stack"]["framework"].as_str().unwrap_or("none");
            let arch = manifest["archetype"]["type"].as_str().unwrap_or("unknown");

            let stack_label = if fw != "none" {
                format!("{lang} / {fw}")
            } else {
                lang.to_string()
            };
            ui::phase_detail(&format!("{stack_label} / {arch}"));

            // Show detected domains
            if let Some(domains) = manifest["domain"]["detected_domains"].as_array() {
                if !domains.is_empty() {
                    let names: Vec<&str> = domains
                        .iter()
                        .filter_map(|d| d["display"].as_str())
                        .collect();
                    ui::phase_kv("domains", &names.join(", "));
                }
            }

            // Phase 2: INDEX
            let mut total_files = 0u64;
            let mut total_symbols = 0u64;
            let mut total_edges = 0u64;

            let code_index = if !no_index {
                ui::phase("INDEX");
                let index = indexer::index_repo(&target)?;
                let meta = &index["_meta"];
                total_files = meta["total_files"].as_u64().unwrap_or(0);
                total_symbols = meta["total_symbols"].as_u64().unwrap_or(0);
                total_edges = meta["total_edges"].as_u64().unwrap_or(0);

                ui::phase_detail(&format!(
                    "{total_files} files, {total_symbols} symbols, {total_edges} edges"
                ));

                if let Some(langs) = meta["languages"].as_object() {
                    let lang_list: Vec<&str> = langs.keys().map(|k| k.as_str()).collect();
                    ui::phase_kv("languages", &lang_list.join(", "));
                }

                let index_path = aif_dir.join("code-index.json");
                let index_json = serde_json::to_string_pretty(&index)?;
                std::fs::write(&index_path, &index_json)?;
                Some(index)
            } else {
                None
            };

            // Resolve tier
            let cfg = crate::config::load_config(&target, &manifest, cli_tier.as_deref());
            ui::phase_kv("tier", &cfg.tier.to_string());

            // Interactive confirmation (unless --non-interactive or piped)
            if !non_interactive && ui::is_tty() {
                println!();
                ui::info("Proceed with generation? [Y/n] ");
                let mut input = String::new();
                if std::io::stdin().read_line(&mut input).is_ok() {
                    let t = input.trim().to_lowercase();
                    if t == "n" || t == "no" {
                        ui::dim("Cancelled.");
                        return Ok(());
                    }
                }
            }

            // Phase 3: GENERATE
            let files_generated;
            if !dry_run {
                ui::phase("GENERATE");
                let generated = generator::generate_with_tier(
                    &target, &manifest, code_index.as_ref(), cfg.tier,
                )?;
                files_generated = generated.len();
                for f in &generated {
                    ui::ok(f);
                }
            } else {
                ui::phase("GENERATE (dry-run)");
                ui::dim("No files written.");
                files_generated = 0;
            }

            // Phase 4: VERIFY
            ui::phase("VERIFY");
            let results = validator::verify(&target)?;
            let pass_count = results
                .iter()
                .filter(|r| r.status == validator::CheckStatus::Pass)
                .count();
            let fail_count = results
                .iter()
                .filter(|r| r.status == validator::CheckStatus::Fail)
                .count();

            if fail_count == 0 {
                ui::ok(&format!("{pass_count}/{} checks passed", results.len()));
            } else {
                ui::warn(&format!(
                    "{pass_count}/{} passed, {fail_count} failures",
                    results.len()
                ));
                if verbose {
                    for r in &results {
                        if r.status == validator::CheckStatus::Fail {
                            ui::fail(&format!("{}: {}", r.name, r.detail));
                        }
                    }
                }
            }

            let elapsed = start.elapsed();
            ui::done(
                elapsed.as_secs_f64(),
                files_generated,
                total_symbols,
                total_edges,
            );

            // Telemetry: fire-and-forget
            telemetry::send_event("run", &json!({
                "language": lang,
                "framework": fw,
                "archetype": arch,
                "tier": cfg.tier.to_string(),
                "file_count": total_files,
                "symbol_count": total_symbols,
                "edge_count": total_edges,
                "files_generated": files_generated,
                "duration_ms": elapsed.as_millis() as u64,
            }));

            Ok(())
        }

        Command::Discover {
            target,
            output,
            no_index,
            verbose,
            ..
        } => {
            ui::banner();
            ui::phase("DISCOVER");

            let manifest = scanner::discover(&target)?;

            let out_dir = output.unwrap_or_else(|| target.join(".aiframework"));
            std::fs::create_dir_all(&out_dir)?;

            let manifest_path = out_dir.join("manifest.json");
            let json_str = serde_json::to_string_pretty(&manifest)?;
            std::fs::write(&manifest_path, &json_str)?;
            ui::ok(&format!("manifest.json -> {}", manifest_path.display()));

            if !no_index {
                ui::phase("INDEX");
                let index = indexer::index_repo(&target)?;
                let index_path = out_dir.join("code-index.json");
                let index_json = serde_json::to_string_pretty(&index)?;
                std::fs::write(&index_path, &index_json)?;
                ui::ok(&format!("code-index.json -> {}", index_path.display()));

                if verbose {
                    let meta = &index["_meta"];
                    ui::phase_detail(&format!(
                        "{} files, {} symbols, {} edges",
                        meta["total_files"], meta["total_symbols"], meta["total_edges"]
                    ));
                }
            }

            // Telemetry
            telemetry::send_event("discover", &json!({}));

            println!();
            Ok(())
        }

        Command::Generate {
            target,
            manifest,
            tier: cli_tier,
        } => {
            ui::banner();
            ui::phase("GENERATE");

            let manifest_path =
                manifest.unwrap_or_else(|| target.join(".aiframework/manifest.json"));
            let manifest_str = std::fs::read_to_string(&manifest_path)?;
            let manifest: serde_json::Value = serde_json::from_str(&manifest_str)?;

            let index_path = target.join(".aiframework/code-index.json");
            let code_index = if index_path.exists() {
                let idx_str = std::fs::read_to_string(&index_path)?;
                Some(serde_json::from_str::<serde_json::Value>(&idx_str)?)
            } else {
                None
            };

            // Resolve tier
            let cfg = config::load_config(&target, &manifest, cli_tier.as_deref());
            ui::phase_kv("tier", &cfg.tier.to_string());

            let generated = generator::generate_with_tier(
                &target,
                &manifest,
                code_index.as_ref(),
                cfg.tier,
            )?;
            for f in &generated {
                ui::ok(f);
            }
            println!();
            ui::info(&format!("{} files generated", generated.len()));
            println!();
            Ok(())
        }

        Command::Verify { target, .. } => {
            ui::banner();
            ui::phase("VERIFY");

            let results = validator::verify(&target)?;

            let name_width = results
                .iter()
                .map(|r| r.name.len())
                .max()
                .unwrap_or(10)
                .max(10);

            ui::verify_header(name_width);

            let mut pass = 0usize;
            let mut warn_count = 0usize;
            let mut fail_count = 0usize;

            for r in &results {
                let status_str = format!("{}", r.status);
                ui::verify_row(&r.name, &status_str, &r.detail, name_width);
                match r.status {
                    validator::CheckStatus::Pass => pass += 1,
                    validator::CheckStatus::Warn => warn_count += 1,
                    validator::CheckStatus::Fail => fail_count += 1,
                }
            }

            ui::verify_footer(name_width, pass, warn_count, fail_count);
            println!();

            if fail_count > 0 {
                std::process::exit(1);
            }
            Ok(())
        }

        Command::Refresh { target } => {
            ui::banner();

            // Check if already bootstrapped
            let manifest_path = target.join(".aiframework/manifest.json");
            if !manifest_path.exists() {
                ui::error("No manifest found. Run `aiframework run` first.");
                ui::help_hint("aiframework run --target .");
                return Ok(());
            }

            // Check if source files changed since last manifest
            let manifest_modified = std::fs::metadata(&manifest_path)?
                .modified()?;

            // Find any source file newer than manifest
            let needs_refresh = walkdir::WalkDir::new(&target)
                .into_iter()
                .filter_map(|e| e.ok())
                .filter(|e| e.file_type().is_file())
                .filter(|e| {
                    let path = e.path().to_string_lossy();
                    !path.contains(".git/")
                        && !path.contains(".aiframework/")
                        && !path.contains("node_modules/")
                        && !path.contains("target/")
                })
                .any(|e| {
                    e.metadata()
                        .ok()
                        .and_then(|m| m.modified().ok())
                        .map(|t| t > manifest_modified)
                        .unwrap_or(false)
                });

            if !needs_refresh {
                ui::ok("No drift detected — everything up to date.");
                ui::dim("Last scanned: manifest.json is current.");
                println!();
                return Ok(());
            }

            ui::info("Drift detected — refreshing...");
            println!();

            // Re-run the full pipeline
            let start = std::time::Instant::now();

            ui::phase("DISCOVER");
            let manifest = scanner::discover(&target)?;
            let aif_dir = target.join(".aiframework");
            let manifest_json = serde_json::to_string_pretty(&manifest)?;
            std::fs::write(aif_dir.join("manifest.json"), &manifest_json)?;

            let lang = manifest["stack"]["language"].as_str().unwrap_or("unknown");
            let arch = manifest["archetype"]["type"].as_str().unwrap_or("unknown");
            ui::phase_detail(&format!("{lang} / {arch}"));

            ui::phase("INDEX");
            let index = indexer::index_repo(&target)?;
            let meta = &index["_meta"];
            ui::phase_detail(&format!(
                "{} files, {} symbols, {} edges",
                meta["total_files"], meta["total_symbols"], meta["total_edges"]
            ));
            let index_json = serde_json::to_string_pretty(&index)?;
            std::fs::write(aif_dir.join("code-index.json"), &index_json)?;

            // Resolve tier from config/manifest for refresh
            let cfg = config::load_config(&target, &manifest, None);

            ui::phase("GENERATE");
            let generated = generator::generate_with_tier(
                &target, &manifest, Some(&index), cfg.tier,
            )?;
            for f in &generated {
                ui::ok(f);
            }

            let elapsed = start.elapsed();
            let symbols = meta["total_symbols"].as_u64().unwrap_or(0);
            let edges = meta["total_edges"].as_u64().unwrap_or(0);
            ui::done(elapsed.as_secs_f64(), generated.len(), symbols, edges);

            Ok(())
        }

        Command::Report { target } => {
            let manifest_path = target.join(".aiframework/manifest.json");
            if !manifest_path.exists() {
                ui::error("No manifest found. Run `aiframework run` first.");
                ui::help_hint("aiframework run --target .");
                return Ok(());
            }

            let manifest_str = std::fs::read_to_string(&manifest_path)?;
            let manifest: serde_json::Value = serde_json::from_str(&manifest_str)?;

            let index_path = target.join(".aiframework/code-index.json");
            let code_index = if index_path.exists() {
                let idx_str = std::fs::read_to_string(&index_path)?;
                Some(serde_json::from_str::<serde_json::Value>(&idx_str)?)
            } else {
                None
            };

            let report = generator::report::generate(&manifest, code_index.as_ref());
            print!("{report}");
            Ok(())
        }

        Command::Mcp { target } => {
            crate::mcp::serve(&target)?;
            Ok(())
        }

        Command::Stats { target } => {
            ui::banner();
            ui::phase("STATS");

            let mut total_repos = 0u64;
            let mut total_files = 0u64;
            let mut total_symbols = 0u64;
            let mut all_languages: std::collections::HashSet<String> = std::collections::HashSet::new();

            // Check knowledge store: ~/.aiframework/knowledge/*.json
            let home = std::env::var("HOME").unwrap_or_default();
            let knowledge_dir = std::path::PathBuf::from(&home).join(".aiframework/knowledge");

            if knowledge_dir.is_dir() {
                if let Ok(entries) = std::fs::read_dir(&knowledge_dir) {
                    for entry in entries.filter_map(|e| e.ok()) {
                        let path = entry.path();
                        if path.extension().and_then(|e| e.to_str()) == Some("json") {
                            if let Ok(content) = std::fs::read_to_string(&path) {
                                if let Ok(val) = serde_json::from_str::<serde_json::Value>(&content) {
                                    total_repos += 1;
                                    if let Some(meta) = val.get("_meta") {
                                        total_files += meta["total_files"].as_u64().unwrap_or(0);
                                        total_symbols += meta["total_symbols"].as_u64().unwrap_or(0);
                                        if let Some(langs) = meta["languages"].as_object() {
                                            for lang in langs.keys() {
                                                all_languages.insert(lang.clone());
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Fallback: if no knowledge store, try current repo
            if total_repos == 0 {
                let manifest_path = target.join(".aiframework/manifest.json");
                let index_path = target.join(".aiframework/code-index.json");

                if index_path.exists() {
                    if let Ok(content) = std::fs::read_to_string(&index_path) {
                        if let Ok(val) = serde_json::from_str::<serde_json::Value>(&content) {
                            total_repos = 1;
                            if let Some(meta) = val.get("_meta") {
                                total_files = meta["total_files"].as_u64().unwrap_or(0);
                                total_symbols = meta["total_symbols"].as_u64().unwrap_or(0);
                                if let Some(langs) = meta["languages"].as_object() {
                                    for lang in langs.keys() {
                                        all_languages.insert(lang.clone());
                                    }
                                }
                            }
                        }
                    }
                } else if manifest_path.exists() {
                    total_repos = 1;
                    ui::dim("  (no code-index.json — run `aiframework index` for full stats)");
                }
            }

            // Beautiful box output
            let lang_count = all_languages.len();
            println!(
                "\n{}{}  \u{250c}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2510}{}",
                "\x1b[1m", "\x1b[36m", "\x1b[0m"
            );
            println!(
                "{}{}  \u{2502}  Knowledge Store                    \u{2502}{}",
                "\x1b[1m", "\x1b[36m", "\x1b[0m"
            );
            println!(
                "{}{}  \u{251c}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2524}{}",
                "\x1b[1m", "\x1b[36m", "\x1b[0m"
            );
            println!(
                "{}{}  \u{2502}{}  Repos bootstrapped:  {:<13}{}{}\u{2502}{}",
                "\x1b[1m", "\x1b[36m", "\x1b[0m",
                total_repos,
                "\x1b[1m", "\x1b[36m", "\x1b[0m"
            );
            println!(
                "{}{}  \u{2502}{}  Total files indexed: {:<13}{}{}\u{2502}{}",
                "\x1b[1m", "\x1b[36m", "\x1b[0m",
                format_number(total_files),
                "\x1b[1m", "\x1b[36m", "\x1b[0m"
            );
            println!(
                "{}{}  \u{2502}{}  Total symbols:       {:<13}{}{}\u{2502}{}",
                "\x1b[1m", "\x1b[36m", "\x1b[0m",
                format_number(total_symbols),
                "\x1b[1m", "\x1b[36m", "\x1b[0m"
            );
            println!(
                "{}{}  \u{2502}{}  Languages detected:  {:<13}{}{}\u{2502}{}",
                "\x1b[1m", "\x1b[36m", "\x1b[0m",
                lang_count,
                "\x1b[1m", "\x1b[36m", "\x1b[0m"
            );
            println!(
                "{}{}  \u{2514}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2518}{}",
                "\x1b[1m", "\x1b[36m", "\x1b[0m"
            );

            if !all_languages.is_empty() {
                let mut langs: Vec<&str> = all_languages.iter().map(|s| s.as_str()).collect();
                langs.sort();
                println!();
                ui::phase_kv("languages", &langs.join(", "));
            }
            println!();

            Ok(())
        }

        Command::Update => {
            ui::banner();
            ui::phase("UPDATE");

            // Check current version
            let current_version = env!("CARGO_PKG_VERSION");
            ui::phase_kv("current", current_version);

            // Try to fetch latest version from GitHub
            ui::info("Checking for updates...");

            let latest = fetch_latest_version();
            match latest {
                Some(ref v) if v != current_version => {
                    ui::ok(&format!("New version available: {v}"));
                    println!();
                    ui::info("To update, re-run the installer:");
                    ui::dim("  curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh");
                    println!();
                    ui::dim("Or if installed via Homebrew:");
                    ui::dim("  brew upgrade aiframework");
                    println!();
                }
                Some(_) => {
                    ui::ok(&format!("Already at latest version ({current_version})"));
                    println!();
                }
                None => {
                    ui::warn("Could not reach GitHub to check for updates.");
                    ui::dim("Check manually: https://github.com/evergonlabs/aiframework/releases");
                    println!();
                }
            }

            // Telemetry
            telemetry::send_event("upgrade", &json!({}));

            Ok(())
        }
    }
}

/// Format a number with comma separators (e.g. 2100 -> "2,100")
fn format_number(n: u64) -> String {
    let s = n.to_string();
    let mut result = String::new();
    for (i, ch) in s.chars().rev().enumerate() {
        if i > 0 && i % 3 == 0 {
            result.push(',');
        }
        result.push(ch);
    }
    result.chars().rev().collect()
}

/// Fetch latest version from GitHub releases (non-blocking, with timeout)
fn fetch_latest_version() -> Option<String> {
    // Try to read VERSION from GitHub raw
    let output = std::process::Command::new("curl")
        .args([
            "-fsSL",
            "--connect-timeout",
            "3",
            "--max-time",
            "5",
            "https://raw.githubusercontent.com/evergonlabs/aiframework/main/VERSION",
        ])
        .output()
        .ok()?;

    if output.status.success() {
        let version = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if version.contains('.') && version.len() < 20 {
            return Some(version);
        }
    }
    None
}
