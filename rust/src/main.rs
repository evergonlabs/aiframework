mod cli;
mod generator;
mod indexer;
mod mcp;
mod scanner;
mod ui;
mod validator;

use std::process;

fn main() {
    let args = cli::parse();
    if let Err(e) = cli::run(args) {
        ui::error(&e.to_string());
        process::exit(1);
    }
}
