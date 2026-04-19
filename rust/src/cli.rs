use clap::{Parser, Subcommand};
use std::path::PathBuf;

use crate::indexer;

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

        Command::Run { target, .. } => {
            eprintln!("TODO: full pipeline for {}", target.display());
            Ok(())
        }
        Command::Discover { target, .. } => {
            eprintln!("TODO: discover for {}", target.display());
            Ok(())
        }
        Command::Generate { target, .. } => {
            eprintln!("TODO: generate for {}", target.display());
            Ok(())
        }
        Command::Verify { target, .. } => {
            eprintln!("TODO: verify for {}", target.display());
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
