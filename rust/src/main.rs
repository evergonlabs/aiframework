mod cli;
mod config;
mod generator;
mod indexer;
mod mcp;
mod scanner;
mod telemetry;
mod ui;
mod validator;

use std::process;

fn main() {
    let args = cli::parse();
    if let Err(e) = cli::run(args) {
        let err_msg = e.to_string();
        ui::error(&err_msg);
        telemetry::send_event(
            "error",
            &serde_json::json!({"error_type": err_msg}),
        );
        process::exit(1);
    }
}
