use serde_json::{json, Value};
use std::path::Path;

/// Suggest custom skills based on detected patterns in the repo.
pub fn scan(_target: &Path, files: &[String]) -> Value {
    let mut suggestions = Vec::new();

    // Docker/compose → deploy skill
    if files.iter().any(|f| f == "docker-compose.yml" || f == "docker-compose.yaml" || f == "Dockerfile") {
        suggestions.push(json!({
            "name": "deploy",
            "reason": "Docker/compose files detected",
            "description": "Build and deploy containers",
        }));
    }

    // Migrations → migrate skill
    if files.iter().any(|f| f.contains("migration") || f.contains("migrate")) {
        suggestions.push(json!({
            "name": "migrate",
            "reason": "Migration files detected",
            "description": "Run database migrations safely",
        }));
    }

    // Seed files → seed skill
    if files.iter().any(|f| f.contains("seed") || f.contains("fixtures")) {
        suggestions.push(json!({
            "name": "seed",
            "reason": "Seed/fixture files detected",
            "description": "Populate development database",
        }));
    }

    // OpenAPI/Swagger → api-docs skill
    if files.iter().any(|f| {
        f.contains("openapi") || f.contains("swagger") || f.ends_with("api.yaml") || f.ends_with("api.json")
    }) {
        suggestions.push(json!({
            "name": "api-docs",
            "reason": "API spec files detected",
            "description": "Generate and validate API documentation",
        }));
    }

    // Storybook → storybook skill
    if files.iter().any(|f| f.contains(".storybook") || f.contains(".stories.")) {
        suggestions.push(json!({
            "name": "storybook",
            "reason": "Storybook config detected",
            "description": "Run and maintain component stories",
        }));
    }

    // Terraform/Pulumi → infra skill
    if files.iter().any(|f| f.ends_with(".tf") || f.contains("Pulumi")) {
        suggestions.push(json!({
            "name": "plan-infra",
            "reason": "Infrastructure-as-code detected",
            "description": "Plan and apply infrastructure changes",
        }));
    }

    // E2E tests → e2e skill
    if files.iter().any(|f| {
        f.contains("e2e") || f.contains("playwright") || f.contains("cypress") || f.contains("selenium")
    }) {
        suggestions.push(json!({
            "name": "e2e",
            "reason": "E2E test framework detected",
            "description": "Run end-to-end tests",
        }));
    }

    // Benchmark files → benchmark skill
    if files.iter().any(|f| f.contains("bench") || f.contains("perf")) {
        suggestions.push(json!({
            "name": "benchmark",
            "reason": "Benchmark files detected",
            "description": "Run performance benchmarks",
        }));
    }

    json!(suggestions)
}
