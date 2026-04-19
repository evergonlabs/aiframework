use std::path::Path;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CheckStatus { Pass, Fail, Warn }

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

fn cr(name: &str, status: CheckStatus, detail: String) -> CheckResult {
    CheckResult { name: name.into(), status, detail }
}

/// Run all verification checks against a target directory.
pub fn verify(target: &Path) -> Result<Vec<CheckResult>, Box<dyn std::error::Error>> {
    let mut r = Vec::new();
    r.push(check_file_exists(target, "CLAUDE.md"));
    r.push(check_file_exists(target, "AGENTS.md"));
    r.push(check_claude_md_wellformed(target));
    r.push(check_manifest_json(target));
    r.push(check_githooks(target));
    r.push(check_commands_configured(target));
    let manifest = load_manifest(target);
    r.extend(check_consistency(target));
    r.extend(check_security(target));
    r.extend(check_freshness(target));
    r.extend(check_quality_gate(target, manifest.as_ref()));
    Ok(r)
}

fn load_manifest(target: &Path) -> Option<serde_json::Value> {
    let content = std::fs::read_to_string(target.join(".aiframework/manifest.json")).ok()?;
    serde_json::from_str(&content).ok()
}

fn read_file(target: &Path, name: &str) -> String {
    std::fs::read_to_string(target.join(name)).unwrap_or_default()
}

fn check_file_exists(target: &Path, filename: &str) -> CheckResult {
    let path = target.join(filename);
    if !path.exists() {
        return cr(filename, CheckStatus::Fail, "missing".into());
    }
    match std::fs::read_to_string(&path) {
        Ok(content) => cr(filename, CheckStatus::Pass, format!("exists, {} lines", content.lines().count())),
        Err(e) => cr(filename, CheckStatus::Warn, format!("exists but unreadable: {e}")),
    }
}

fn check_claude_md_wellformed(target: &Path) -> CheckResult {
    match std::fs::read_to_string(target.join("CLAUDE.md")) {
        Ok(c) if c.contains("## Commands") => cr("CLAUDE.md structure", CheckStatus::Pass, "has ## Commands section".into()),
        Ok(_) => cr("CLAUDE.md structure", CheckStatus::Warn, "missing ## Commands section".into()),
        Err(_) => cr("CLAUDE.md structure", CheckStatus::Fail, "file not found or unreadable".into()),
    }
}

fn check_manifest_json(target: &Path) -> CheckResult {
    match std::fs::read_to_string(target.join(".aiframework/manifest.json")) {
        Ok(content) => match serde_json::from_str::<serde_json::Value>(&content) {
            Ok(_) => cr("manifest.json", CheckStatus::Pass, "valid JSON".into()),
            Err(e) => cr("manifest.json", CheckStatus::Fail, format!("invalid JSON: {e}")),
        },
        Err(_) => cr("manifest.json", CheckStatus::Warn, "not found at .aiframework/manifest.json".into()),
    }
}

fn check_githooks(target: &Path) -> CheckResult {
    let hooks_dir = target.join(".githooks");
    if !hooks_dir.exists() {
        return cr(".githooks/", CheckStatus::Warn, "directory missing".into());
    }
    let pc = hooks_dir.join("pre-commit").exists();
    let pp = hooks_dir.join("pre-push").exists();
    match (pc, pp) {
        (true, true) => cr(".githooks/", CheckStatus::Pass, "pre-commit + pre-push present".into()),
        (true, false) => cr(".githooks/", CheckStatus::Warn, "pre-push missing".into()),
        (false, true) => cr(".githooks/", CheckStatus::Warn, "pre-commit missing".into()),
        (false, false) => cr(".githooks/", CheckStatus::Warn, "both hooks missing".into()),
    }
}

fn check_commands_configured(target: &Path) -> CheckResult {
    let manifest: serde_json::Value = match std::fs::read_to_string(target.join(".aiframework/manifest.json"))
        .ok()
        .and_then(|c| serde_json::from_str(&c).ok())
    {
        Some(v) => v,
        None => return cr("commands", CheckStatus::Warn, "manifest not found or invalid".into()),
    };
    let mut issues = Vec::new();
    for cmd in ["lint", "test"] {
        if manifest["commands"][cmd].as_str().unwrap_or("NOT_CONFIGURED") == "NOT_CONFIGURED" {
            issues.push(cmd);
        }
    }
    if issues.is_empty() {
        cr("commands", CheckStatus::Pass, "lint + test configured".into())
    } else {
        cr("commands", CheckStatus::Warn, format!("{} not configured", issues.join(", ")))
    }
}

// ---------------------------------------------------------------------------
// New validator checks
// ---------------------------------------------------------------------------

/// Extract first code-fenced command matching a label from markdown content.
fn extract_md_command(content: &str, label: &str) -> Option<String> {
    let lower = label.to_lowercase();
    let mut in_block = false;
    for line in content.lines() {
        if line.trim_start().starts_with("```") {
            in_block = !in_block;
            continue;
        }
        if in_block {
            let trimmed = line.trim();
            if !trimmed.is_empty() && trimmed.to_lowercase().contains(&lower) {
                return Some(trimmed.to_string());
            }
        }
    }
    None
}

/// Check consistency between CLAUDE.md commands, githooks, and manifest.
fn check_consistency(target: &Path) -> Vec<CheckResult> {
    let mut results = Vec::new();
    let claude_md = read_file(target, "CLAUDE.md");
    let manifest = load_manifest(target);

    let claude_lint = extract_md_command(&claude_md, "shellcheck")
        .or_else(|| extract_md_command(&claude_md, "lint"));
    let hook_pre_commit = read_file(target, ".githooks/pre-commit");
    if let Some(ref cl) = claude_lint {
        if !hook_pre_commit.is_empty() && !hook_pre_commit.contains(cl.as_str()) {
            results.push(cr("consistency-lint", CheckStatus::Warn,
                format!("CLAUDE.md lint command not found in pre-commit hook: {cl}")));
        }
    }

    let claude_test = extract_md_command(&claude_md, "make test")
        .or_else(|| extract_md_command(&claude_md, "test"));
    let hook_pre_push = read_file(target, ".githooks/pre-push");
    if let Some(ref ct) = claude_test {
        if !hook_pre_push.is_empty() && !hook_pre_push.contains(ct.as_str()) {
            results.push(cr("consistency-test", CheckStatus::Warn,
                format!("CLAUDE.md test command not found in pre-push hook: {ct}")));
        }
    }

    if let Some(ref m) = manifest {
        for key in ["lint", "test"] {
            if let Some(cmd) = m["commands"][key].as_str() {
                if cmd != "NOT_CONFIGURED" && !claude_md.contains(cmd) {
                    results.push(cr(&format!("consistency-manifest-{key}"), CheckStatus::Warn,
                        format!("manifest {key} command not found in CLAUDE.md: {cmd}")));
                }
            }
        }
    }

    if results.is_empty() {
        results.push(cr("consistency", CheckStatus::Pass,
            "commands consistent across CLAUDE.md, hooks, manifest".into()));
    }
    results
}

/// Check for security issues: .gitignore, secret patterns, tracked .env files.
fn check_security(target: &Path) -> Vec<CheckResult> {
    let mut results = Vec::new();

    // .gitignore contains .env
    let gi_path = target.join(".gitignore");
    let gitignore = std::fs::read_to_string(&gi_path).unwrap_or_default();
    if !gi_path.exists() {
        results.push(cr("security-gitignore", CheckStatus::Warn, ".gitignore missing".into()));
    } else if !gitignore.lines().any(|l| { let t = l.trim(); t == ".env" || t == ".env*" }) {
        results.push(cr("security-gitignore", CheckStatus::Warn, ".gitignore does not contain .env entry".into()));
    } else {
        results.push(cr("security-gitignore", CheckStatus::Pass, ".gitignore includes .env".into()));
    }

    // Scan generated files for secret patterns
    let secret_re = regex::Regex::new(
        r#"(?i)(API_KEY|SECRET|PASSWORD|TOKEN)\s*=\s*['"]?[A-Za-z0-9/+=]{8,}"#,
    ).expect("valid secret regex");

    let gen_files = ["CLAUDE.md", "AGENTS.md", ".aiframework/manifest.json", ".cursorrules"];
    let mut secrets_found: Vec<String> = Vec::new();
    for name in &gen_files {
        if let Ok(content) = std::fs::read_to_string(target.join(name)) {
            if secret_re.is_match(&content) {
                secrets_found.push((*name).to_string());
            }
        }
    }
    if secrets_found.is_empty() {
        results.push(cr("security-secrets", CheckStatus::Pass, "no secret patterns in generated files".into()));
    } else {
        results.push(cr("security-secrets", CheckStatus::Fail,
            format!("potential secrets in: {}", secrets_found.join(", "))));
    }

    // Check if .env is tracked by git
    match std::process::Command::new("git").args(["ls-files", ".env"]).current_dir(target).output() {
        Ok(output) => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            if stdout.trim().is_empty() {
                results.push(cr("security-env-tracked", CheckStatus::Pass, ".env not tracked in git".into()));
            } else {
                results.push(cr("security-env-tracked", CheckStatus::Fail, ".env is tracked in git -- remove it".into()));
            }
        }
        Err(_) => {
            results.push(cr("security-env-tracked", CheckStatus::Warn, "could not run git ls-files".into()));
        }
    }
    results
}

/// Check freshness: manifest vs source files, code-index existence.
fn check_freshness(target: &Path) -> Vec<CheckResult> {
    let mut results = Vec::new();
    let manifest_path = target.join(".aiframework/manifest.json");

    let manifest_mtime = std::fs::metadata(&manifest_path).and_then(|m| m.modified()).ok();

    if let Some(m_time) = manifest_mtime {
        let mut stale = false;
        for name in ["CLAUDE.md", "AGENTS.md", ".cursorrules", "Makefile"] {
            if let Ok(meta) = std::fs::metadata(target.join(name)) {
                if let Ok(t) = meta.modified() {
                    if t > m_time { stale = true; break; }
                }
            }
        }
        if !stale {
            'outer: for entry in ["bin", "lib", "src", "tools"] {
                let dir = target.join(entry);
                if dir.is_dir() {
                    if let Ok(rd) = std::fs::read_dir(&dir) {
                        for e in rd.flatten() {
                            if let Ok(t) = e.metadata().and_then(|m| m.modified()) {
                                if t > m_time { stale = true; break 'outer; }
                            }
                        }
                    }
                }
            }
        }
        results.push(if stale {
            cr("freshness-manifest", CheckStatus::Warn, "manifest may be stale, run aiframework refresh".into())
        } else {
            cr("freshness-manifest", CheckStatus::Pass, "manifest is up to date".into())
        });
    } else {
        results.push(cr("freshness-manifest", CheckStatus::Warn, "manifest.json missing, cannot check freshness".into()));
    }

    // code-index.json existence
    results.push(if target.join(".aiframework/code-index.json").exists() {
        cr("freshness-code-index", CheckStatus::Pass, "code-index.json present".into())
    } else {
        cr("freshness-code-index", CheckStatus::Warn, "no code index, run aiframework index".into())
    });
    results
}

/// Check that lint and test commands are configured in the manifest (gate check).
fn check_quality_gate(target: &Path, manifest: Option<&serde_json::Value>) -> Vec<CheckResult> {
    let manifest = match manifest {
        Some(m) => m,
        None => return vec![cr("quality-gate", CheckStatus::Warn,
            format!("manifest not available at {}", target.join(".aiframework/manifest.json").display()))],
    };

    let lint_cmd = manifest["commands"]["lint"].as_str().unwrap_or("NOT_CONFIGURED");
    let test_cmd = manifest["commands"]["test"].as_str().unwrap_or("NOT_CONFIGURED");
    let lint_ok = lint_cmd != "NOT_CONFIGURED";
    let test_ok = test_cmd != "NOT_CONFIGURED";

    let mut results = Vec::new();
    if !lint_ok {
        results.push(cr("quality-gate-lint", CheckStatus::Warn, "lint command not configured in manifest".into()));
    }
    if !test_ok {
        results.push(cr("quality-gate-test", CheckStatus::Warn, "test command not configured in manifest".into()));
    }
    if lint_ok && test_ok {
        results.push(cr("quality-gate", CheckStatus::Pass, format!("lint: {lint_cmd}, test: {test_cmd}")));
    }
    results
}
