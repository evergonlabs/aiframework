/// Terminal UI — beautiful, nerdy, retro-inspired output.
/// All user-facing output goes through this module.

use std::io::Write;

// ANSI color codes
const RESET: &str = "\x1b[0m";
const BOLD: &str = "\x1b[1m";
const DIM: &str = "\x1b[2m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const RED: &str = "\x1b[31m";
const CYAN: &str = "\x1b[36m";
const MAGENTA: &str = "\x1b[35m";
const WHITE: &str = "\x1b[97m";

/// Check if stdout is a TTY (skip colors if piped)
fn is_tty() -> bool {
    unsafe { libc_isatty() }
}

#[cfg(unix)]
fn libc_isatty() -> bool {
    unsafe {
        extern "C" {
            fn isatty(fd: i32) -> i32;
        }
        isatty(1) != 0
    }
}

#[cfg(not(unix))]
fn libc_isatty() -> bool {
    false
}

/// Color helper — returns empty string if not TTY
fn c(code: &str) -> &str {
    if is_tty() { code } else { "" }
}

/// Print the banner — nerdy retro ASCII art
pub fn banner() {
    println!(
        "\n{}{}  ┌─────────────────────────────────────┐{}",
        c(BOLD), c(CYAN), c(RESET)
    );
    println!(
        "{}{}  │  ▓▓▓ aiframework {}v2{}               │{}",
        c(BOLD), c(CYAN), c(DIM), c(CYAN), c(RESET)
    );
    println!(
        "{}{}  │  {}Make Claude Code understand your{}   │{}",
        c(BOLD), c(CYAN), c(WHITE), c(CYAN), c(RESET)
    );
    println!(
        "{}{}  │  {}project instantly.{}               │{}",
        c(BOLD), c(CYAN), c(WHITE), c(CYAN), c(RESET)
    );
    println!(
        "{}{}  └─────────────────────────────────────┘{}",
        c(BOLD), c(CYAN), c(RESET)
    );
}

/// Print a phase header (DISCOVER, INDEX, GENERATE, VERIFY)
pub fn phase(name: &str) {
    let bar = "█".repeat(20);
    println!(
        "\n  {}{}{name}{}  {}{bar}{}",
        c(BOLD), c(WHITE), c(RESET), c(DIM), c(RESET)
    );
}

/// Print a phase sub-item
pub fn phase_detail(msg: &str) {
    println!("  {}│{} {}", c(DIM), c(RESET), msg);
}

/// Print a phase item with a value
pub fn phase_kv(key: &str, value: &str) {
    println!(
        "  {}│{} {}{key}:{} {value}",
        c(DIM), c(RESET), c(DIM), c(RESET)
    );
}

/// Print a success item (green checkmark)
pub fn ok(msg: &str) {
    println!("  {}✓{} {}", c(GREEN), c(RESET), msg);
}

/// Print a warning item
pub fn warn(msg: &str) {
    println!("  {}!{} {}", c(YELLOW), c(RESET), msg);
}

/// Print a failure item
pub fn fail(msg: &str) {
    eprintln!("  {}✗{} {}", c(RED), c(RESET), msg);
}

/// Print an info item
pub fn info(msg: &str) {
    println!("  {}>{} {}", c(CYAN), c(RESET), msg);
}

/// Print a dim/muted line
pub fn dim(msg: &str) {
    println!("  {}{msg}{}", c(DIM), c(RESET));
}

/// Print the pipeline completion summary
pub fn done(elapsed_secs: f64, files_generated: usize, symbols: u64, edges: u64) {
    println!();
    println!(
        "  {}{}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{}",
        c(BOLD), c(GREEN), c(RESET)
    );
    println!(
        "  {}{}✓ Pipeline complete{} in {}{:.1}s{}",
        c(BOLD), c(GREEN), c(RESET), c(BOLD), elapsed_secs, c(RESET)
    );
    println!(
        "    {}{files_generated}{} files generated  {}·{}  {}{symbols}{} symbols  {}·{}  {}{edges}{} edges",
        c(BOLD), c(RESET), c(DIM), c(RESET), c(BOLD), c(RESET), c(DIM), c(RESET), c(BOLD), c(RESET)
    );
    println!(
        "  {}{}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━{}",
        c(BOLD), c(GREEN), c(RESET)
    );
}

/// Print a verification table row
pub fn verify_row(name: &str, status: &str, detail: &str, name_width: usize) {
    let (color, icon) = match status {
        "PASS" => (GREEN, "✓"),
        "WARN" => (YELLOW, "!"),
        "FAIL" => (RED, "✗"),
        _ => (WHITE, " "),
    };
    println!(
        "  {}│{} {:<width$}  {}{}{icon} {status:<4}{}  {}",
        c(DIM), c(RESET),
        name,
        c(BOLD), c(color), c(RESET),
        detail,
        width = name_width,
    );
}

/// Print the verify table header
pub fn verify_header(name_width: usize) {
    println!(
        "\n  {}┌─{}─┬────────┬─────────────────────────────┐{}",
        c(DIM),
        "─".repeat(name_width),
        c(RESET),
    );
    println!(
        "  {}│{} {:<width$}  {}Status{}  {}Details{}                       {}│{}",
        c(DIM), c(RESET),
        "Check",
        c(BOLD), c(RESET),
        c(DIM), c(RESET),
        c(DIM), c(RESET),
        width = name_width,
    );
    println!(
        "  {}├─{}─┼────────┼─────────────────────────────┤{}",
        c(DIM),
        "─".repeat(name_width),
        c(RESET),
    );
}

/// Print the verify table footer
pub fn verify_footer(name_width: usize, pass: usize, warn: usize, fail: usize) {
    let total = pass + warn + fail;
    println!(
        "  {}└─{}─┴────────┴─────────────────────────────┘{}",
        c(DIM),
        "─".repeat(name_width),
        c(RESET),
    );

    let status_color = if fail > 0 { RED } else if warn > 0 { YELLOW } else { GREEN };
    let status_word = if fail > 0 { "FAIL" } else { "PASS" };
    println!(
        "\n  {}{}{status_word}{}  {pass}/{total} passed, {warn} warnings, {fail} failures",
        c(BOLD), c(status_color), c(RESET),
    );
}

/// Print retro-style progress dots
pub fn progress(label: &str, current: usize, total: usize) {
    let pct = if total > 0 { current * 100 / total } else { 0 };
    let filled = pct / 5;
    let bar: String = (0..20)
        .map(|i| if i < filled { '█' } else { '░' })
        .collect();
    print!(
        "\r  {}│{} {label} {}{bar}{} {current}/{total}",
        c(DIM), c(RESET), c(CYAN), c(RESET)
    );
    let _ = std::io::stdout().flush();
    if current >= total {
        println!();
    }
}

/// Print an error with help suggestion (Rust compiler style)
pub fn error(msg: &str) {
    eprintln!("\n  {}{}error:{} {msg}", c(BOLD), c(RED), c(RESET));
}

pub fn help_hint(msg: &str) {
    eprintln!("  {}help:{} {msg}", c(CYAN), c(RESET));
}

/// Print a section divider
pub fn divider() {
    println!(
        "  {}────────────────────────────────────────{}",
        c(DIM), c(RESET)
    );
}
