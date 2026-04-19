use serde_json::{json, Value};
use std::path::Path;

/// Scan for CI/CD configuration: provider, workflows, coverage, deploy target.
pub fn scan(target: &Path, _files: &[String]) -> Value {
    let provider = detect_provider(target);
    let workflows = if provider == "github-actions" {
        parse_github_workflows(target)
    } else {
        vec![]
    };
    let all_content = collect_ci_content(target, &provider);
    let coverage = detect_coverage(&all_content);
    let gaps = detect_gaps(&coverage);
    let deploy_target = detect_deploy_target(target);
    let secrets = collect_github_secrets(target, &provider);

    json!({
        "provider": provider,
        "workflows": workflows,
        "coverage": coverage,
        "gaps": gaps,
        "deploy_target": deploy_target,
        "github_secrets": secrets,
    })
}

fn detect_provider(target: &Path) -> String {
    if target.join(".github/workflows").is_dir() {
        "github-actions".into()
    } else if target.join(".gitlab-ci.yml").exists() {
        "gitlab-ci".into()
    } else if target.join(".circleci/config.yml").exists() {
        "circleci".into()
    } else if target.join("Jenkinsfile").exists() {
        "jenkins".into()
    } else if target.join(".travis.yml").exists() {
        "travis".into()
    } else {
        "none".into()
    }
}

fn parse_github_workflows(target: &Path) -> Vec<Value> {
    let wf_dir = target.join(".github/workflows");
    let mut workflows = Vec::new();

    let entries = match std::fs::read_dir(&wf_dir) {
        Ok(e) => e,
        Err(_) => return workflows,
    };

    for entry in entries.flatten() {
        let path = entry.path();
        let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
        if ext != "yml" && ext != "yaml" {
            continue;
        }
        let filename = path.file_name().unwrap_or_default().to_string_lossy().to_string();
        let content = match std::fs::read_to_string(&path) {
            Ok(c) => c,
            Err(_) => continue,
        };

        let name = extract_yaml_name(&content).unwrap_or_else(|| filename.clone());
        let triggers = extract_triggers(&content);
        let jobs = extract_jobs(&content);
        let secrets = extract_secrets_from_content(&content);
        let purpose = derive_purpose(&jobs, &content);

        workflows.push(json!({
            "file": filename,
            "name": name,
            "triggers": triggers,
            "jobs": jobs,
            "secrets": secrets,
            "purpose": purpose,
        }));
    }
    workflows
}

fn extract_yaml_name(content: &str) -> Option<String> {
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("name:") {
            let val = trimmed.trim_start_matches("name:").trim();
            return Some(val.trim_matches('"').trim_matches('\'').to_string());
        }
    }
    None
}

fn extract_triggers(content: &str) -> Vec<String> {
    let mut triggers = Vec::new();
    let mut in_on = false;
    for line in content.lines() {
        if line.starts_with("on:") {
            // Inline form: on: [push, pull_request]
            let rest = line.trim_start_matches("on:").trim();
            if rest.starts_with('[') {
                for t in rest.trim_matches(|c| c == '[' || c == ']').split(',') {
                    let t = t.trim().trim_matches('"').trim_matches('\'');
                    if !t.is_empty() { triggers.push(t.to_string()); }
                }
                return triggers;
            }
            in_on = true;
            continue;
        }
        if in_on {
            if !line.starts_with(' ') && !line.starts_with('\t') && !line.is_empty() {
                break;
            }
            let trimmed = line.trim();
            if let Some(key) = trimmed.strip_suffix(':') {
                triggers.push(key.to_string());
            } else if !trimmed.is_empty() && !trimmed.starts_with('#') && !trimmed.starts_with('-') {
                if let Some(key) = trimmed.split(':').next() {
                    triggers.push(key.trim().to_string());
                }
            }
        }
    }
    triggers
}

fn extract_jobs(content: &str) -> Vec<String> {
    let mut jobs = Vec::new();
    let mut in_jobs = false;
    for line in content.lines() {
        if line.starts_with("jobs:") {
            in_jobs = true;
            continue;
        }
        if in_jobs {
            if !line.starts_with(' ') && !line.starts_with('\t') && !line.is_empty() {
                break;
            }
            // Job names are at 2-space indent
            if line.starts_with("  ") && !line.starts_with("    ") {
                let trimmed = line.trim();
                if let Some(name) = trimmed.strip_suffix(':') {
                    jobs.push(name.to_string());
                }
            }
        }
    }
    jobs
}

fn extract_secrets_from_content(content: &str) -> Vec<String> {
    let re = regex::Regex::new(r"secrets\.([A-Z_][A-Z0-9_]*)").unwrap();
    let mut secrets: Vec<String> = re.captures_iter(content)
        .filter_map(|c| c.get(1).map(|m| m.as_str().to_string()))
        .collect();
    secrets.sort();
    secrets.dedup();
    secrets
}

fn derive_purpose(jobs: &[String], content: &str) -> String {
    let mut parts = Vec::new();
    let lower = content.to_lowercase();
    let jobs_lower: Vec<String> = jobs.iter().map(|j| j.to_lowercase()).collect();
    let jobs_str = jobs_lower.join(" ");

    if jobs_str.contains("lint") || jobs_str.contains("check") { parts.push("lint"); }
    if jobs_str.contains("test") || jobs_str.contains("spec") { parts.push("test"); }
    if jobs_str.contains("build") || jobs_str.contains("compile") { parts.push("build"); }
    if jobs_str.contains("deploy") || jobs_str.contains("release") || jobs_str.contains("publish") {
        parts.push("deploy");
    }
    if lower.contains("security") || lower.contains("codeql") || lower.contains("snyk") {
        parts.push("security");
    }
    if parts.is_empty() { "general".into() } else { parts.join(" + ") }
}

fn collect_ci_content(target: &Path, provider: &str) -> String {
    if provider != "github-actions" { return String::new(); }
    let wf_dir = target.join(".github/workflows");
    let mut buf = String::new();
    if let Ok(entries) = std::fs::read_dir(&wf_dir) {
        for entry in entries.flatten() {
            if let Ok(c) = std::fs::read_to_string(entry.path()) {
                buf.push_str(&c);
                buf.push('\n');
            }
        }
    }
    buf
}

fn detect_coverage(content: &str) -> Vec<String> {
    let lower = content.to_lowercase();
    let mut cov = Vec::new();
    if regex::Regex::new(r"lint|eslint|ruff|clippy|golint").unwrap().is_match(&lower) { cov.push("lint".into()); }
    if regex::Regex::new(r"test|pytest|jest|vitest|cargo.test|go.test").unwrap().is_match(&lower) { cov.push("test".into()); }
    if regex::Regex::new(r"build|compile|cargo.build|go.build").unwrap().is_match(&lower) { cov.push("build".into()); }
    if regex::Regex::new(r"tsc|typecheck|type-check|mypy|pyright").unwrap().is_match(&lower) { cov.push("typecheck".into()); }
    if regex::Regex::new(r"audit|snyk|trivy|security|dependabot").unwrap().is_match(&lower) { cov.push("security".into()); }
    cov
}

fn detect_gaps(coverage: &[String]) -> Vec<String> {
    let all = ["lint", "test", "build", "typecheck", "security"];
    all.iter()
        .filter(|s| !coverage.iter().any(|c| c == **s))
        .map(|s| s.to_string())
        .collect()
}

fn detect_deploy_target(target: &Path) -> String {
    let checks: &[(&str, &str)] = &[
        ("fly.toml", "fly.io"),
        ("vercel.json", "vercel"),
        ("netlify.toml", "netlify"),
        ("render.yaml", "render"),
        ("appspec.yml", "aws-codedeploy"),
        ("serverless.yml", "serverless"),
        ("serverless.yaml", "serverless"),
        ("wrangler.toml", "cloudflare-workers"),
        ("Dockerfile", "docker"),
        ("firebase.json", "firebase"),
    ];
    for (file, name) in checks {
        if target.join(file).exists() {
            return name.to_string();
        }
    }
    let dir_checks: &[(&str, &str)] = &[
        ("terraform", "terraform"),
        ("k8s", "kubernetes"),
        ("kubernetes", "kubernetes"),
        ("helm", "kubernetes"),
        ("supabase", "supabase"),
    ];
    for (dir, name) in dir_checks {
        if target.join(dir).is_dir() {
            return name.to_string();
        }
    }
    // Check for .tf files at root
    if std::fs::read_dir(target)
        .map(|entries| entries.flatten().any(|e| {
            e.path().extension().and_then(|x| x.to_str()) == Some("tf")
        }))
        .unwrap_or(false)
    {
        return "terraform".into();
    }
    "none".into()
}

fn collect_github_secrets(target: &Path, provider: &str) -> Vec<String> {
    if provider != "github-actions" { return vec![]; }
    let content = collect_ci_content(target, provider);
    extract_secrets_from_content(&content)
}
