use serde_json::Value;
use std::path::Path;

/// Generate .claude/skills/{short}-review/SKILL.md and {short}-ship/SKILL.md.
/// Returns the list of files created relative to target.
pub fn generate(
    target: &Path,
    manifest: &Value,
) -> Result<Vec<String>, Box<dyn std::error::Error>> {
    let mut created = Vec::new();

    let short = str_or(manifest, &["identity", "short_name"], "project");
    let name = str_or(manifest, &["identity", "name"], "Project");
    let lint = str_or(manifest, &["commands", "lint"], "");
    let typecheck = str_or(manifest, &["commands", "typecheck"], "");
    let test_cmd = str_or(manifest, &["commands", "test"], "");

    // --- Review skill ---
    let review_dir = target.join(format!(".claude/skills/{short}-review"));
    let review_path = review_dir.join("SKILL.md");
    if !review_path.exists() {
        std::fs::create_dir_all(&review_dir)?;
        std::fs::write(&review_path, generate_review_skill(&short, &name, &lint, &typecheck))?;
        created.push(format!(".claude/skills/{short}-review/SKILL.md"));
    }

    // --- Ship skill ---
    let ship_dir = target.join(format!(".claude/skills/{short}-ship"));
    let ship_path = ship_dir.join("SKILL.md");
    if !ship_path.exists() {
        std::fs::create_dir_all(&ship_dir)?;
        std::fs::write(&ship_path, generate_ship_skill(&short, &name, &lint, &typecheck, &test_cmd))?;
        created.push(format!(".claude/skills/{short}-ship/SKILL.md"));
    }

    Ok(created)
}

fn generate_review_skill(short: &str, name: &str, lint: &str, typecheck: &str) -> String {
    let mut out = String::with_capacity(2048);

    out.push_str(&format!(
        "---\nname: {short}-review\ndescription: |\n  {name} pre-landing code review.\n  Checks invariants, runs lint, looks for NOT_CONFIGURED placeholders.\nallowed-tools:\n  - Bash\n  - Read\n  - Glob\n  - Grep\n  - Agent\n---\n\n"
    ));
    out.push_str(&format!("# /{short}-review — Code Review\n\n"));

    out.push_str("## Step 1: Invariant Check\n\n");
    out.push_str("For each changed file (`git diff --name-only HEAD~1 HEAD`), verify:\n\n");
    out.push_str("- [ ] No secrets, API keys, or credentials in source code\n");
    out.push_str("- [ ] All LLM/AI output is validated before use\n");
    out.push_str("- [ ] No `NOT_CONFIGURED` placeholders left in generated files\n\n");

    out.push_str("## Step 2: Lint & Type Check\n\n```bash\n");
    if !lint.is_empty() {
        out.push_str(&format!("# Lint\n{lint}\n\n"));
    }
    if !typecheck.is_empty() {
        out.push_str(&format!("# Type check\n{typecheck}\n\n"));
    }
    out.push_str("```\n\n");

    out.push_str("## Step 3: Quality Review\n\n");
    out.push_str("- [ ] Error handling is complete (no swallowed errors)\n");
    out.push_str("- [ ] Edge cases are covered\n");
    out.push_str("- [ ] No regressions in existing functionality\n");
    out.push_str("- [ ] Documentation updated if needed\n\n");

    out.push_str("## Output\n\n");
    out.push_str("Summarize: files reviewed, issues found, verdict (PASS / NEEDS_FIX).\n");

    out
}

fn generate_ship_skill(
    short: &str,
    name: &str,
    lint: &str,
    typecheck: &str,
    test_cmd: &str,
) -> String {
    let mut out = String::with_capacity(2048);

    out.push_str(&format!(
        "---\nname: {short}-ship\ndescription: |\n  {name} ship workflow: lint + test + review + changelog + commit.\n  Never pushes without explicit user approval.\nallowed-tools:\n  - Bash\n  - Read\n  - Edit\n  - Write\n  - Glob\n  - Grep\n  - Agent\n---\n\n"
    ));
    out.push_str(&format!("# /{short}-ship — Ship Workflow\n\n"));

    out.push_str("## Step 1: Verify\n\n```bash\n");
    if !lint.is_empty() {
        out.push_str(&format!("{lint}\n"));
    }
    if !typecheck.is_empty() {
        out.push_str(&format!("{typecheck}\n"));
    }
    if !test_cmd.is_empty() {
        out.push_str(&format!("{test_cmd}\n"));
    }
    out.push_str("```\n\nAll commands must pass with zero errors.\n\n");

    out.push_str(&format!("## Step 2: Review\n\nRun `/{short}-review` on all staged changes.\n\n"));

    out.push_str("## Step 3: Changelog\n\n");
    out.push_str("1. Update `CHANGELOG.md` with user-facing description\n");
    out.push_str("2. Bump `VERSION` (PATCH for fixes, MINOR for features, MAJOR for breaking)\n\n");

    out.push_str("## Step 4: Commit\n\n");
    out.push_str("```bash\ngit add -A\ngit commit -m \"<descriptive message>\"\n```\n\n");

    out.push_str("## Step 5: Push (requires approval)\n\n");
    out.push_str("**NEVER push without explicit user confirmation.**\n");
    out.push_str("Ask: \"Ready to push to remote? (y/n)\"\n");

    out
}

/// Navigate nested JSON safely, filtering out NOT_CONFIGURED.
fn str_or(value: &Value, path: &[&str], default: &str) -> String {
    let mut current = value;
    for key in path {
        current = &current[*key];
    }
    match current.as_str() {
        Some(s) if s != "NOT_CONFIGURED" => s.to_string(),
        _ => default.to_string(),
    }
}
