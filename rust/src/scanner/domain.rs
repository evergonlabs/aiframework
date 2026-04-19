use serde_json::{json, Value};
use std::path::Path;

/// Scan for domain-specific concerns by matching file path patterns.
pub fn scan(_target: &Path, files: &[String]) -> Value {
    let mut domains = Vec::new();

    let domain_defs: &[(&str, &str, &[&str])] = &[
        ("auth", "Authentication & Authorization", &[
            "auth/", "auth.", "login", "session", "jwt", "oauth", "guard", "permission",
        ]),
        ("database", "Database & Data Layer", &[
            "migration", "schema.", "models/", "model.", "entity", "prisma",
            "sequelize", "sqlalchemy", "drizzle", ".sql",
        ]),
        ("api", "API Endpoints", &[
            "routes/", "controllers/", "handlers/", "endpoints/",
            "controller.", "route.", "handler.",
        ]),
        ("ai", "AI/LLM Integration", &[
            "openai", "anthropic", "langchain", "llm", "prompt", "embedding",
            "agent", "rag",
        ]),
        ("frontend", "Frontend UI", &[
            "components/", "pages/", "views/", "layouts/",
            ".tsx", ".vue", ".svelte",
        ]),
        ("workers", "Background Workers / Jobs", &[
            "workers/", "jobs/", "queues/", "worker.", "job.", "queue.",
            "consumer.", "cron",
        ]),
        ("file-upload", "File Upload / Storage", &[
            "upload", "storage", "s3", "multer", "busboy", "gcs",
        ]),
        ("financial", "Financial Calculations", &[
            "payment", "billing", "stripe", "invoice", "transaction",
            "payroll",
        ]),
    ];

    let excluded_prefixes = [
        "node_modules/", ".git/", ".venv/", "target/", "vault/",
        "review-specialists/", "templates/", ".aiframework/", ".claude/",
        "docs/", "tools/",
    ];

    let source_files: Vec<&String> = files.iter()
        .filter(|f| !excluded_prefixes.iter().any(|p| f.starts_with(p)))
        .filter(|f| !f.contains(".test.") && !f.contains(".spec."))
        .collect();

    for &(name, display, patterns) in domain_defs {
        let matching: Vec<String> = source_files.iter()
            .filter(|f| {
                let lower = f.to_lowercase();
                patterns.iter().any(|p| lower.contains(p))
            })
            .take(10)
            .map(|f| f.to_string())
            .collect();

        if !matching.is_empty() {
            domains.push(json!({
                "name": name,
                "display": display,
                "paths": matching,
            }));
        }
    }

    json!({
        "detected_domains": domains,
    })
}
