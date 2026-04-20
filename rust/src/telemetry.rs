/// Fire-and-forget telemetry to PostHog.
/// Matches bin/aiframework-telemetry from the bash version.
///
/// - Reads POSTHOG_API_KEY from env (skips if absent)
/// - Checks ~/.aiframework/config for `telemetry: false` opt-out
/// - Spawns curl in background — never blocks the CLI
/// - Machine ID = hash of hostname:user (same as bash version)

use serde_json::{json, Value};

const POSTHOG_HOST: &str = "https://eu.i.posthog.com";

/// Check if telemetry is disabled via ~/.aiframework/config.
fn is_disabled() -> bool {
    let home = std::env::var("HOME").unwrap_or_default();
    let config = std::path::PathBuf::from(&home).join(".aiframework/config");
    if config.exists() {
        if let Ok(content) = std::fs::read_to_string(&config) {
            return content.contains("telemetry: false")
                || content.contains("telemetry:false");
        }
    }
    false
}

/// Stable machine ID from hostname:user (djb2 hash, matches bash shasum approach).
fn machine_id() -> String {
    let hostname = std::env::var("HOSTNAME").unwrap_or_else(|_| "unknown".into());
    let user = std::env::var("USER").unwrap_or_else(|_| "unknown".into());
    let input = format!("{hostname}:{user}");
    let mut hash: u64 = 5381;
    for b in input.bytes() {
        hash = hash.wrapping_mul(33).wrapping_add(b as u64);
    }
    format!("{hash:016x}")
}

/// Detect platform string matching the bash version output.
fn platform() -> &'static str {
    match std::env::consts::OS {
        "macos" => "macos",
        "linux" => "linux",
        "windows" => "windows",
        other => other,
    }
}

/// Send a telemetry event. Fire-and-forget — spawns curl in background.
/// Silently no-ops if:
/// - telemetry is disabled
/// - POSTHOG_API_KEY is not set
/// - curl is not available
pub fn send_event(event: &str, properties: &Value) {
    if is_disabled() {
        return;
    }

    let api_key = match std::env::var("POSTHOG_API_KEY") {
        Ok(k) if !k.is_empty() => k,
        _ => return, // No API key — skip silently (matches bash: exits if empty)
    };

    let host = std::env::var("POSTHOG_HOST").unwrap_or_else(|_| POSTHOG_HOST.into());
    let distinct_id = machine_id();

    let mut props = properties.as_object().cloned().unwrap_or_default();
    props.insert("version".into(), json!(env!("CARGO_PKG_VERSION")));
    props.insert("platform".into(), json!(platform()));
    props.insert("arch".into(), json!(std::env::consts::ARCH));
    props.insert("engine".into(), json!("rust"));

    let body = json!({
        "api_key": api_key,
        "event": event,
        "distinct_id": distinct_id,
        "properties": props,
    });

    let body_str = match serde_json::to_string(&body) {
        Ok(s) => s,
        Err(_) => return,
    };

    let url = format!("{host}/capture/");

    // Fire and forget — don't block the CLI
    let _ = std::process::Command::new("curl")
        .args([
            "-fsSL",
            "--connect-timeout",
            "2",
            "--max-time",
            "3",
            "-X",
            "POST",
            "-H",
            "Content-Type: application/json",
            "-d",
            &body_str,
            &url,
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn(); // Non-blocking
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn machine_id_is_stable() {
        let id1 = machine_id();
        let id2 = machine_id();
        assert_eq!(id1, id2);
        assert_eq!(id1.len(), 16); // 16 hex chars
    }

    #[test]
    fn send_event_does_not_panic() {
        // Should silently no-op (no API key in test env)
        send_event("test", &json!({"foo": "bar"}));
    }
}
