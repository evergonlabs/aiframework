use std::path::Path;

/// Status of a single validation check.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CheckStatus {
    Pass,
    Fail,
    Warn,
}

/// Result of a single validation check.
#[derive(Debug, Clone)]
pub struct CheckResult {
    pub name: String,
    pub status: CheckStatus,
    pub detail: String,
}

impl std::fmt::Display for CheckStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CheckStatus::Pass => write!(f, "PASS"),
            CheckStatus::Fail => write!(f, "FAIL"),
            CheckStatus::Warn => write!(f, "WARN"),
        }
    }
}

/// Run all verification checks against a target directory.
pub fn verify(target: &Path) -> Result<Vec<CheckResult>, Box<dyn std::error::Error>> {
    let mut results = Vec::new();

    results.push(check_file_exists(target, "CLAUDE.md"));
    results.push(check_file_exists(target, "AGENTS.md"));
    results.push(check_claude_md_wellformed(target));
    results.push(check_manifest_json(target));
    results.push(check_githooks(target));
    results.push(check_commands_configured(target));

    Ok(results)
}

/// Check if a file exists and report its line count.
fn check_file_exists(target: &Path, filename: &str) -> CheckResult {
    let path = target.join(filename);
    if path.exists() {
        match std::fs::read_to_string(&path) {
            Ok(content) => {
                let lines = content.lines().count();
                CheckResult {
                    name: filename.to_string(),
                    status: CheckStatus::Pass,
                    detail: format!("exists, {lines} lines"),
                }
            }
            Err(e) => CheckResult {
                name: filename.to_string(),
                status: CheckStatus::Warn,
                detail: format!("exists but unreadable: {e}"),
            },
        }
    } else {
        CheckResult {
            name: filename.to_string(),
            status: CheckStatus::Fail,
            detail: "missing".to_string(),
        }
    }
}

/// Check that CLAUDE.md has a ## Commands section (well-formed).
fn check_claude_md_wellformed(target: &Path) -> CheckResult {
    let path = target.join("CLAUDE.md");
    match std::fs::read_to_string(&path) {
        Ok(content) => {
            if content.contains("## Commands") {
                CheckResult {
                    name: "CLAUDE.md structure".to_string(),
                    status: CheckStatus::Pass,
                    detail: "has ## Commands section".to_string(),
                }
            } else {
                CheckResult {
                    name: "CLAUDE.md structure".to_string(),
                    status: CheckStatus::Warn,
                    detail: "missing ## Commands section".to_string(),
                }
            }
        }
        Err(_) => CheckResult {
            name: "CLAUDE.md structure".to_string(),
            status: CheckStatus::Fail,
            detail: "file not found or unreadable".to_string(),
        },
    }
}

/// Check that manifest.json exists and is valid JSON.
fn check_manifest_json(target: &Path) -> CheckResult {
    let path = target.join(".aiframework/manifest.json");
    match std::fs::read_to_string(&path) {
        Ok(content) => match serde_json::from_str::<serde_json::Value>(&content) {
            Ok(_) => CheckResult {
                name: "manifest.json".to_string(),
                status: CheckStatus::Pass,
                detail: "valid JSON".to_string(),
            },
            Err(e) => CheckResult {
                name: "manifest.json".to_string(),
                status: CheckStatus::Fail,
                detail: format!("invalid JSON: {e}"),
            },
        },
        Err(_) => CheckResult {
            name: "manifest.json".to_string(),
            status: CheckStatus::Warn,
            detail: "not found at .aiframework/manifest.json".to_string(),
        },
    }
}

/// Check that .githooks directory has pre-commit and pre-push.
fn check_githooks(target: &Path) -> CheckResult {
    let hooks_dir = target.join(".githooks");
    if !hooks_dir.exists() {
        return CheckResult {
            name: ".githooks/".to_string(),
            status: CheckStatus::Warn,
            detail: "directory missing".to_string(),
        };
    }

    let pre_commit = hooks_dir.join("pre-commit").exists();
    let pre_push = hooks_dir.join("pre-push").exists();

    match (pre_commit, pre_push) {
        (true, true) => CheckResult {
            name: ".githooks/".to_string(),
            status: CheckStatus::Pass,
            detail: "pre-commit + pre-push present".to_string(),
        },
        (true, false) => CheckResult {
            name: ".githooks/".to_string(),
            status: CheckStatus::Warn,
            detail: "pre-push missing".to_string(),
        },
        (false, true) => CheckResult {
            name: ".githooks/".to_string(),
            status: CheckStatus::Warn,
            detail: "pre-commit missing".to_string(),
        },
        (false, false) => CheckResult {
            name: ".githooks/".to_string(),
            status: CheckStatus::Warn,
            detail: "both hooks missing".to_string(),
        },
    }
}

/// Check that lint/test commands are configured (not NOT_CONFIGURED).
fn check_commands_configured(target: &Path) -> CheckResult {
    let path = target.join(".aiframework/manifest.json");
    let content = match std::fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => {
            return CheckResult {
                name: "commands".to_string(),
                status: CheckStatus::Warn,
                detail: "manifest not found, cannot check commands".to_string(),
            };
        }
    };

    let manifest: serde_json::Value = match serde_json::from_str(&content) {
        Ok(v) => v,
        Err(_) => {
            return CheckResult {
                name: "commands".to_string(),
                status: CheckStatus::Warn,
                detail: "manifest invalid, cannot check commands".to_string(),
            };
        }
    };

    let mut issues = Vec::new();
    for cmd in ["lint", "test"] {
        let val = manifest["commands"][cmd].as_str().unwrap_or("NOT_CONFIGURED");
        if val == "NOT_CONFIGURED" {
            issues.push(cmd);
        }
    }

    if issues.is_empty() {
        CheckResult {
            name: "commands".to_string(),
            status: CheckStatus::Pass,
            detail: "lint + test configured".to_string(),
        }
    } else {
        CheckResult {
            name: "commands".to_string(),
            status: CheckStatus::Warn,
            detail: format!("{} not configured", issues.join(", ")),
        }
    }
}
