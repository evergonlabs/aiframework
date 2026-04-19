use clap::{Parser, Subcommand};
use std::path::PathBuf;

use crate::generator;
use crate::indexer;
use crate::scanner;
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
    },

    /// Read manifest, generate all files
    Generate {
        /// Path to manifest.json
        #[arg(long)]
        manifest: Option<PathBuf>,

        /// Target directory
        #[arg(long, default_value = ".")]
        target: PathBuf,
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
                println!(
                    "Indexed {} files, {} symbols, {} edges in {}ms",
                    meta["total_files"], meta["total_symbols"], meta["total_edges"], meta["elapsed_ms"]
                );
                if let Some(langs) = meta["languages"].as_object() {
                    let lang_list: Vec<&str> = langs.keys().map(|k| k.as_str()).collect();
                    println!("Languages: {}", lang_list.join(", "));
                }
                if let Some(top) = meta["top_files"].as_array() {
                    println!("Top files by PageRank:");
                    for f in top.iter().take(10) {
                        println!(
                            "  {:>4}  {}",
                            f["importance"].as_u64().unwrap_or(0),
                            f["file"].as_str().unwrap_or("?")
                        );
                    }
                }
            } else {
                let out_path = output.unwrap_or_else(|| target.join(".aiframework/code-index.json"));
                if let Some(parent) = out_path.parent() {
                    std::fs::create_dir_all(parent)?;
                }
                let json = serde_json::to_string_pretty(&result)?;
                std::fs::write(&out_path, &json)?;
                println!("Wrote {}", out_path.display());
            }
            Ok(())
        }

        Command::Run {
            target,
            no_index,
            dry_run,
            verbose,
            ..
        } => {
            let start = std::time::Instant::now();

            // Phase 1: DISCOVER
            println!("\n  DISCOVER");
            let manifest = scanner::discover(&target)?;

            let aif_dir = target.join(".aiframework");
            std::fs::create_dir_all(&aif_dir)?;

            let manifest_path = aif_dir.join("manifest.json");
            let manifest_json = serde_json::to_string_pretty(&manifest)?;
            std::fs::write(&manifest_path, &manifest_json)?;

            let lang = manifest["stack"]["language"].as_str().unwrap_or("unknown");
            let fw = manifest["stack"]["framework"].as_str().unwrap_or("none");
            let arch = manifest["archetype"]["type"].as_str().unwrap_or("unknown");
            println!("    {lang} / {fw} / {arch}");

            // Phase 2: INDEX
            let code_index = if !no_index {
                println!("\n  INDEX");
                let index = indexer::index_repo(&target)?;
                let meta = &index["_meta"];
                println!(
                    "    {} files, {} symbols, {} edges",
                    meta["total_files"], meta["total_symbols"], meta["total_edges"]
                );

                let index_path = aif_dir.join("code-index.json");
                let index_json = serde_json::to_string_pretty(&index)?;
                std::fs::write(&index_path, &index_json)?;
                Some(index)
            } else {
                None
            };

            // Phase 3: GENERATE
            if !dry_run {
                println!("\n  GENERATE");
                let generated = generator::generate(
                    &target,
                    &manifest,
                    code_index.as_ref(),
                )?;
                println!("    {} files written", generated.len());
                if verbose {
                    for f in &generated {
                        println!("      {f}");
                    }
                }
            } else {
                println!("\n  GENERATE (dry-run — no files written)");
            }

            let elapsed = start.elapsed();
            println!(
                "\n  Done in {:.1}s",
                elapsed.as_secs_f64()
            );

            Ok(())
        }
        Command::Discover { target, output, no_index, verbose } => {
            let manifest = scanner::discover(&target)?;

            let out_dir = output.unwrap_or_else(|| target.join(".aiframework"));
            std::fs::create_dir_all(&out_dir)?;

            let manifest_path = out_dir.join("manifest.json");
            let json = serde_json::to_string_pretty(&manifest)?;
            std::fs::write(&manifest_path, &json)?;
            println!("Wrote {}", manifest_path.display());

            // Also run code indexer unless --no-index
            if !no_index {
                let index = indexer::index_repo(&target)?;
                let index_path = out_dir.join("code-index.json");
                let index_json = serde_json::to_string_pretty(&index)?;
                std::fs::write(&index_path, &index_json)?;
                println!("Wrote {}", index_path.display());

                if verbose {
                    let meta = &index["_meta"];
                    println!(
                        "  {} files, {} symbols, {} edges",
                        meta["total_files"], meta["total_symbols"], meta["total_edges"]
                    );
                }
            }

            Ok(())
        }
        Command::Generate { target, manifest } => {
            let manifest_path = manifest.unwrap_or_else(|| target.join(".aiframework/manifest.json"));
            let manifest_str = std::fs::read_to_string(&manifest_path)?;
            let manifest: serde_json::Value = serde_json::from_str(&manifest_str)?;

            // Try to load code index if it exists
            let index_path = target.join(".aiframework/code-index.json");
            let code_index = if index_path.exists() {
                let idx_str = std::fs::read_to_string(&index_path)?;
                Some(serde_json::from_str::<serde_json::Value>(&idx_str)?)
            } else {
                None
            };

            let generated = generator::generate(&target, &manifest, code_index.as_ref())?;
            println!("Generated {} files", generated.len());
            for f in &generated {
                println!("  {f}");
            }
            Ok(())
        }
        Command::Verify { target, .. } => {
            let results = validator::verify(&target)?;

            // Calculate column widths
            let name_width = results.iter().map(|r| r.name.len()).max().unwrap_or(10).max(5);
            let detail_width = results.iter().map(|r| r.detail.len()).max().unwrap_or(10).max(7);

            // Print table header
            println!(
                "{:<name_width$}   {:<6}   {}",
                "Check", "Status", "Details",
                name_width = name_width,
            );
            println!(
                "{:<name_width$}   {:<6}   {}",
                "-".repeat(name_width), "------", "-".repeat(detail_width),
                name_width = name_width,
            );

            let mut fail_count = 0;
            for r in &results {
                let status_str = format!("{}", r.status);
                println!(
                    "{:<name_width$}   {:<6}   {}",
                    r.name, status_str, r.detail,
                    name_width = name_width,
                );
                if r.status == validator::CheckStatus::Fail {
                    fail_count += 1;
                }
            }

            let total = results.len();
            let pass = results.iter().filter(|r| r.status == validator::CheckStatus::Pass).count();
            let warn = results.iter().filter(|r| r.status == validator::CheckStatus::Warn).count();
            println!("\n{pass}/{total} passed, {warn} warnings, {fail_count} failures");

            if fail_count > 0 {
                std::process::exit(1);
            }
            Ok(())
        }
        Command::Refresh { target } => {
            eprintln!("TODO: refresh for {}", target.display());
            Ok(())
        }
        Command::Update => {
            eprintln!("TODO: self-update");
            Ok(())
        }
    }
}
