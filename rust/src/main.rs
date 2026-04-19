mod cli;
mod generator;
mod indexer;
mod scanner;
mod validator;

use std::process;

fn main() {
    let args = cli::parse();
    if let Err(e) = cli::run(args) {
        eprintln!("error: {e}");
        process::exit(1);
    }
}
