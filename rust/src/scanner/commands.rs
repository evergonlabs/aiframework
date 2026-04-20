use serde_json::{json, Value};
use std::path::Path;

/// Scan for commands: package manager, lint, test, build, etc.
pub fn scan(target: &Path, files: &[String], stack: &Value) -> Value {
    let language = stack["language"].as_str().unwrap_or("unknown");

    let pkg_manager = detect_package_manager(files);
    let (install, dev, build, lint, test, format, typecheck) = detect_commands(target, language, &pkg_manager);

    // Makefile targets
    let makefile_targets = detect_makefile_targets(target);

    // GitHub URL
    let github_url = detect_github_url(target);

    // New fields
    let dev_port = detect_dev_port(target);
    let prod_port = detect_prod_port(target);
    let scripts = detect_scripts(target);
    let lock_file = detect_lock_file(files);
    let has_buildspec = target.join("buildspec.yml").exists();
    let local_path = target.canonicalize()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|_| target.to_string_lossy().to_string());
    let production_url = detect_production_url(target);

    json!({
        "package_manager": pkg_manager,
        "install": install,
        "dev": dev,
        "build": build,
        "lint": lint,
        "test": test,
        "format": format,
        "typecheck": typecheck,
        "makefile_targets": makefile_targets,
        "github_url": github_url,
        "dev_port": dev_port,
        "prod_port": prod_port,
        "scripts": scripts,
        "lock_file": lock_file,
        "has_buildspec": has_buildspec,
        "local_path": local_path,
        "production_url": production_url,
    })
}

fn detect_package_manager(files: &[String]) -> String {
    // Priority order: pnpm > yarn > npm > cargo > pip > go > mix > bundle > composer
    for f in files {
        let name = Path::new(f).file_name().and_then(|n| n.to_str()).unwrap_or("");
        match name {
            "pnpm-lock.yaml" => return "pnpm".into(),
            "yarn.lock" => return "yarn".into(),
            "package-lock.json" => return "npm".into(),
            "bun.lockb" | "bun.lock" => return "bun".into(),
            "Cargo.lock" => return "cargo".into(),
            "poetry.lock" => return "poetry".into(),
            "Pipfile.lock" => return "pipenv".into(),
            "uv.lock" => return "uv".into(),
            "go.sum" => return "go".into(),
            "mix.lock" => return "mix".into(),
            "Gemfile.lock" => return "bundler".into(),
            "composer.lock" => return "composer".into(),
            _ => {}
        }
    }

    // Fallback: check manifest files (check Makefile BEFORE Cargo.toml for multi-lang repos)
    for f in files {
        let name = Path::new(f).file_name().and_then(|n| n.to_str()).unwrap_or("");
        match name {
            "go.mod" => return "go".into(),
            "Cargo.toml" => return "cargo".into(),
            "requirements.txt" | "setup.py" | "pyproject.toml" => return "pip".into(),
            "package.json" => return "npm".into(),
            "Gemfile" => return "bundler".into(),
            "composer.json" => return "composer".into(),
            "mix.exs" => return "mix".into(),
            _ => {}
        }
    }

    "NOT_CONFIGURED".into()
}

fn detect_commands(
    target: &Path,
    language: &str,
    pkg_manager: &str,
) -> (String, String, String, String, String, String, String) {
    // If Makefile exists, check for standard targets first
    let makefile = target.join("Makefile");
    if makefile.exists() {
        if let Ok(content) = std::fs::read_to_string(&makefile) {
            let has = |t: &str| content.lines().any(|l| l.starts_with(&format!("{t}:")));
            let lint = if has("lint") { "make lint".to_string() } else { "NOT_CONFIGURED".to_string() };
            let test = if has("test") { "make test".to_string() } else { "NOT_CONFIGURED".to_string() };
            let build = if has("build") { "make build".to_string() } else { "NOT_CONFIGURED".to_string() };
            let install = if has("install") { "make install".to_string() } else { "NOT_CONFIGURED".to_string() };
            let check = if has("check") { "make check".to_string() } else { "NOT_CONFIGURED".to_string() };

            // If Makefile has at least lint or test, use it as primary
            if lint != "NOT_CONFIGURED" || test != "NOT_CONFIGURED" {
                return (install, "NOT_CONFIGURED".into(), build, lint, test, "NOT_CONFIGURED".into(), check);
            }
        }
    }

    // Try package.json scripts
    let pkg_json = target.join("package.json");
    if pkg_json.exists() {
        if let Ok(content) = std::fs::read_to_string(&pkg_json) {
            if let Ok(pkg) = serde_json::from_str::<Value>(&content) {
                if let Some(scripts) = pkg["scripts"].as_object() {
                    let run = match pkg_manager {
                        "pnpm" => "pnpm",
                        "yarn" => "yarn",
                        "bun" => "bun",
                        _ => "npm run",
                    };

                    return (
                        format!("{pkg_manager} install"),
                        scripts.get("dev").map_or("NOT_CONFIGURED".into(), |_| format!("{run} dev")),
                        scripts.get("build").map_or("NOT_CONFIGURED".into(), |_| format!("{run} build")),
                        scripts.get("lint").map_or("NOT_CONFIGURED".into(), |_| format!("{run} lint")),
                        scripts.get("test").map_or("NOT_CONFIGURED".into(), |_| format!("{run} test")),
                        scripts.get("format").map_or("NOT_CONFIGURED".into(), |_| format!("{run} format")),
                        scripts.get("typecheck")
                            .or_else(|| scripts.get("type-check"))
                            .map_or("NOT_CONFIGURED".into(), |_| format!("{run} typecheck")),
                    );
                }
            }
        }
    }

    // Language-specific defaults
    match language {
        "rust" => (
            "cargo build".into(),
            "cargo run".into(),
            "cargo build --release".into(),
            "cargo clippy".into(),
            "cargo test".into(),
            "cargo fmt".into(),
            "NOT_CONFIGURED".into(),
        ),
        "go" => (
            "go mod download".into(),
            "go run .".into(),
            "go build .".into(),
            "golangci-lint run".into(),
            "go test ./...".into(),
            "gofmt -w .".into(),
            "NOT_CONFIGURED".into(),
        ),
        "python" => (
            match pkg_manager {
                "poetry" => "poetry install",
                "uv" => "uv sync",
                "pipenv" => "pipenv install",
                _ => "pip install -r requirements.txt",
            }.into(),
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            if target.join("ruff.toml").exists() || target.join(".ruff.toml").exists() {
                "ruff check .".into()
            } else {
                "NOT_CONFIGURED".into()
            },
            if target.join("pytest.ini").exists() || target.join("pyproject.toml").exists() {
                "pytest".into()
            } else {
                "python -m unittest discover".into()
            },
            "NOT_CONFIGURED".into(),
            if target.join("mypy.ini").exists() || target.join(".mypy.ini").exists() {
                "mypy .".into()
            } else if let Ok(content) = std::fs::read_to_string(target.join("pyproject.toml")) {
                if content.contains("[tool.mypy]") { "mypy .".into() } else { "NOT_CONFIGURED".into() }
            } else {
                "NOT_CONFIGURED".into()
            },
        ),
        "ruby" => (
            "bundle install".into(),
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            "rubocop".into(),
            if target.join("Rakefile").exists() { "rake test".into() } else { "NOT_CONFIGURED".into() },
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
        ),
        "bash" => (
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            "find . -name '*.sh' -not -path '*/.git/*' | xargs shellcheck".into(),
            if target.join("Makefile").exists() { "make test".into() } else { "NOT_CONFIGURED".into() },
            "NOT_CONFIGURED".into(),
            "find . -name '*.sh' -not -path '*/.git/*' | xargs bash -n".into(),
        ),
        _ => (
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
            "NOT_CONFIGURED".into(),
        ),
    }
}

fn detect_makefile_targets(target: &Path) -> Vec<String> {
    let makefile = target.join("Makefile");
    if !makefile.exists() {
        return vec![];
    }

    let content = match std::fs::read_to_string(&makefile) {
        Ok(c) => c,
        Err(_) => return vec![],
    };

    content
        .lines()
        .filter_map(|line| {
            if line.ends_with(':') || line.contains(": ") {
                let target = line.split(':').next()?.trim();
                if !target.is_empty()
                    && !target.starts_with('.')
                    && !target.starts_with('\t')
                    && !target.contains('$')
                    && !target.contains('%')
                {
                    return Some(target.to_string());
                }
            }
            None
        })
        .collect()
}

fn detect_dev_port(target: &Path) -> String {
    // Check package.json scripts.dev for --port or PORT=
    let pkg_json = target.join("package.json");
    if pkg_json.exists() {
        if let Ok(content) = std::fs::read_to_string(&pkg_json) {
            if let Ok(pkg) = serde_json::from_str::<Value>(&content) {
                if let Some(dev_script) = pkg["scripts"]["dev"].as_str() {
                    // Look for --port NNNN or --port=NNNN
                    if let Some(pos) = dev_script.find("--port") {
                        let after = &dev_script[pos + 6..];
                        let after = after.trim_start_matches('=').trim_start();
                        let port: String = after.chars().take_while(|c| c.is_ascii_digit()).collect();
                        if !port.is_empty() {
                            return port;
                        }
                    }
                    // Look for PORT=NNNN
                    if let Some(pos) = dev_script.find("PORT=") {
                        let after = &dev_script[pos + 5..];
                        let port: String = after.chars().take_while(|c| c.is_ascii_digit()).collect();
                        if !port.is_empty() {
                            return port;
                        }
                    }
                }
            }
        }
    }
    // Check Dockerfile EXPOSE
    let dockerfile = target.join("Dockerfile");
    if dockerfile.exists() {
        if let Ok(content) = std::fs::read_to_string(&dockerfile) {
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.to_uppercase().starts_with("EXPOSE ") {
                    let port: String = trimmed[7..].split_whitespace().next().unwrap_or("").to_string();
                    if !port.is_empty() {
                        return port;
                    }
                }
            }
        }
    }
    // Check .env PORT=
    let env_file = target.join(".env");
    if env_file.exists() {
        if let Ok(content) = std::fs::read_to_string(&env_file) {
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.starts_with("PORT=") {
                    let port = trimmed[5..].trim().trim_matches('"').trim_matches('\'');
                    if !port.is_empty() {
                        return port.to_string();
                    }
                }
            }
        }
    }
    String::new()
}

fn detect_prod_port(target: &Path) -> String {
    // Check .env for PRODUCTION_PORT or similar
    let env_file = target.join(".env");
    if env_file.exists() {
        if let Ok(content) = std::fs::read_to_string(&env_file) {
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.starts_with("PRODUCTION_PORT=") || trimmed.starts_with("PROD_PORT=") {
                    let val = trimmed.split('=').nth(1).unwrap_or("").trim().trim_matches('"').trim_matches('\'');
                    if !val.is_empty() {
                        return val.to_string();
                    }
                }
            }
        }
    }
    // Dockerfile EXPOSE as fallback for common prod ports
    let dockerfile = target.join("Dockerfile");
    if dockerfile.exists() {
        if let Ok(content) = std::fs::read_to_string(&dockerfile) {
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.to_uppercase().starts_with("EXPOSE ") {
                    let port = trimmed[7..].split_whitespace().next().unwrap_or("");
                    if matches!(port, "80" | "443" | "3000" | "8080") {
                        return port.to_string();
                    }
                }
            }
        }
    }
    String::new()
}

fn detect_scripts(target: &Path) -> Value {
    let pkg_json = target.join("package.json");
    if pkg_json.exists() {
        if let Ok(content) = std::fs::read_to_string(&pkg_json) {
            if let Ok(pkg) = serde_json::from_str::<Value>(&content) {
                if let Some(scripts) = pkg.get("scripts") {
                    return scripts.clone();
                }
            }
        }
    }
    Value::Null
}

fn detect_lock_file(files: &[String]) -> String {
    for f in files {
        let name = Path::new(f).file_name().and_then(|n| n.to_str()).unwrap_or("");
        match name {
            "package-lock.json" | "yarn.lock" | "pnpm-lock.yaml" | "bun.lockb" | "bun.lock"
            | "Cargo.lock" | "poetry.lock" | "Pipfile.lock" | "uv.lock" | "go.sum"
            | "mix.lock" | "Gemfile.lock" | "composer.lock" => return name.to_string(),
            _ => {}
        }
    }
    String::new()
}

fn detect_production_url(target: &Path) -> String {
    // Check .env PRODUCTION_URL
    let env_file = target.join(".env");
    if env_file.exists() {
        if let Ok(content) = std::fs::read_to_string(&env_file) {
            for line in content.lines() {
                let trimmed = line.trim();
                if trimmed.starts_with("PRODUCTION_URL=") {
                    let val = trimmed[15..].trim().trim_matches('"').trim_matches('\'');
                    if !val.is_empty() {
                        return val.to_string();
                    }
                }
            }
        }
    }
    // Check package.json homepage
    let pkg_json = target.join("package.json");
    if pkg_json.exists() {
        if let Ok(content) = std::fs::read_to_string(&pkg_json) {
            if let Ok(pkg) = serde_json::from_str::<Value>(&content) {
                if let Some(url) = pkg["homepage"].as_str() {
                    return url.to_string();
                }
            }
        }
    }
    String::new()
}

fn detect_github_url(target: &Path) -> String {
    let git_config = target.join(".git/config");
    if !git_config.exists() {
        return String::new();
    }

    let content = match std::fs::read_to_string(&git_config) {
        Ok(c) => c,
        Err(_) => return String::new(),
    };

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("url = ") {
            let url = trimmed.trim_start_matches("url = ");
            if url.contains("github.com") {
                // Convert SSH to HTTPS
                let https = url
                    .replace("git@github.com:", "https://github.com/")
                    .replace(".git", "");
                return https;
            }
        }
    }

    String::new()
}
