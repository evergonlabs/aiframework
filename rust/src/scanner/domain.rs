use serde_json::{json, Value};
use std::path::Path;

/// Scan for domain-specific concerns by matching file path patterns AND dependencies.
pub fn scan(target: &Path, files: &[String]) -> Value {
    let mut domains = Vec::new();

    // Load dependency content for dependency-based domain detection
    let dep_text = load_all_deps(target, files);

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

        // Also check dependencies for this domain
        let dep_match = patterns.iter().any(|p| {
            let clean = p.trim_end_matches('/').trim_end_matches('.');
            dep_text.contains(clean)
        });

        if !matching.is_empty() || dep_match {
            domains.push(json!({
                "name": name,
                "display": display,
                "paths": matching,
            }));
        }
    }

    let domain_names: Vec<&str> = domains.iter()
        .filter_map(|d| d["name"].as_str())
        .collect();

    let invariants = derive_invariants(&domain_names);
    let security_concerns = derive_security_concerns(&domain_names);
    let core_principles = detect_core_principles(target, files);
    let component_counts = count_components(files);
    let cross_package_imports = detect_cross_package_imports(files);

    json!({
        "detected_domains": domains,
        "invariants": invariants,
        "security_concerns": security_concerns,
        "core_principles": core_principles,
        "component_counts": component_counts,
        "cross_package_imports": cross_package_imports,
    })
}

fn derive_invariants(domains: &[&str]) -> Vec<String> {
    let mut invariants = Vec::new();
    for &domain in domains {
        match domain {
            "auth" => {
                invariants.push("no-credentials-in-code".to_string());
                invariants.push("session-validation-required".to_string());
            }
            "database" => {
                invariants.push("migrations-required".to_string());
                invariants.push("no-raw-sql-without-parameterization".to_string());
            }
            "api" => {
                invariants.push("input-validation-required".to_string());
                invariants.push("rate-limiting-recommended".to_string());
            }
            "ai" => {
                invariants.push("llm-trust-boundary".to_string());
                invariants.push("output-sanitization-required".to_string());
            }
            "financial" => {
                invariants.push("decimal-precision-required".to_string());
                invariants.push("audit-logging-required".to_string());
            }
            "file-upload" => {
                invariants.push("file-size-limits-required".to_string());
                invariants.push("file-type-validation-required".to_string());
            }
            _ => {}
        }
    }
    invariants.sort();
    invariants.dedup();
    invariants
}

fn derive_security_concerns(domains: &[&str]) -> Vec<String> {
    let mut concerns = Vec::new();
    for &domain in domains {
        match domain {
            "auth" => {
                concerns.push("credential-exposure".to_string());
                concerns.push("session-hijacking".to_string());
            }
            "api" => {
                concerns.push("injection-attacks".to_string());
                concerns.push("broken-access-control".to_string());
            }
            "ai" => {
                concerns.push("llm-trust-boundary".to_string());
                concerns.push("prompt-injection".to_string());
            }
            "database" => {
                concerns.push("sql-injection".to_string());
                concerns.push("data-leakage".to_string());
            }
            "financial" => {
                concerns.push("payment-data-exposure".to_string());
                concerns.push("transaction-integrity".to_string());
            }
            "file-upload" => {
                concerns.push("path-traversal".to_string());
                concerns.push("malicious-file-upload".to_string());
            }
            _ => {}
        }
    }
    concerns.sort();
    concerns.dedup();
    concerns
}

fn detect_core_principles(target: &Path, _files: &[String]) -> Vec<String> {
    let mut principles = Vec::new();

    // Check for strict TypeScript
    let tsconfig = target.join("tsconfig.json");
    if tsconfig.exists() {
        if let Ok(content) = std::fs::read_to_string(&tsconfig) {
            if content.contains("\"strict\": true") || content.contains("\"strict\":true") {
                principles.push("strict-typescript".to_string());
            }
        }
    }

    // Check for ORM usage
    let orm_markers = [
        ("prisma", "prisma-orm"),
        ("drizzle", "drizzle-orm"),
        ("sequelize", "sequelize-orm"),
        ("sqlalchemy", "sqlalchemy-orm"),
        ("typeorm", "typeorm"),
        ("django.db", "django-orm"),
    ];
    let pkg_json = target.join("package.json");
    let pyproject = target.join("pyproject.toml");
    let mut dep_content = String::new();
    if let Ok(c) = std::fs::read_to_string(&pkg_json) { dep_content.push_str(&c); }
    if let Ok(c) = std::fs::read_to_string(&pyproject) { dep_content.push_str(&c); }
    let lower = dep_content.to_lowercase();
    for (marker, principle) in &orm_markers {
        if lower.contains(marker) {
            principles.push(principle.to_string());
            break;
        }
    }

    // Check for env-based config patterns
    if target.join(".env.example").exists()
        || target.join(".env.template").exists()
        || target.join(".env.sample").exists()
    {
        principles.push("env-based-config".to_string());
    }

    principles
}

fn count_components(files: &[String]) -> Value {
    let excluded = [
        "node_modules/", ".git/", ".venv/", "target/", "vault/",
        ".aiframework/", ".claude/", "docs/", "tools/",
    ];
    let source_files: Vec<&String> = files.iter()
        .filter(|f| !excluded.iter().any(|p| f.starts_with(p)))
        .collect();

    let mut controllers = 0usize;
    let mut services = 0usize;
    let mut models = 0usize;
    let mut dtos = 0usize;
    let mut routes = 0usize;
    let mut middlewares = 0usize;
    let mut tests = 0usize;

    for f in &source_files {
        let lower = f.to_lowercase();
        if lower.contains("controller") { controllers += 1; }
        if lower.contains("service") && !lower.contains(".test.") && !lower.contains(".spec.") { services += 1; }
        if lower.contains("model") || lower.contains("entity") || lower.contains("schema.") { models += 1; }
        if lower.contains("dto") || lower.contains("types.") { dtos += 1; }
        if lower.contains("route") || lower.contains("router") { routes += 1; }
        if lower.contains("middleware") { middlewares += 1; }
        if lower.contains(".test.") || lower.contains(".spec.") || lower.contains("test_") || lower.contains("_test.") {
            tests += 1;
        }
    }

    json!({
        "controllers": controllers,
        "services": services,
        "models": models,
        "dtos": dtos,
        "routes": routes,
        "middlewares": middlewares,
        "tests": tests,
    })
}

fn detect_cross_package_imports(_files: &[String]) -> Vec<Value> {
    vec![]
}

/// Load all dependency file contents for domain detection.
fn load_all_deps(target: &Path, files: &[String]) -> String {
    let mut content = String::new();
    // Root manifests
    for name in &["package.json", "Cargo.toml", "requirements.txt", "go.mod", "Gemfile", "composer.json", "pyproject.toml"] {
        if let Ok(c) = std::fs::read_to_string(target.join(name)) {
            content.push_str(&c.to_lowercase());
            content.push('\n');
        }
    }
    // Workspace package.json files
    for f in files {
        if f.ends_with("package.json") && f.contains('/') && !f.contains("node_modules") {
            if let Ok(c) = std::fs::read_to_string(target.join(f)) {
                content.push_str(&c.to_lowercase());
                content.push('\n');
            }
        }
    }
    content
}
