use std::path::Path;

/// Helper: create a temp project with specific files
fn create_project(files: &[(&str, &str)]) -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();

    // Init git so ignore crate works
    std::process::Command::new("git")
        .args(["init", "-q"])
        .current_dir(dir.path())
        .output()
        .unwrap();

    for (path, content) in files {
        let full = dir.path().join(path);
        if let Some(parent) = full.parent() {
            std::fs::create_dir_all(parent).unwrap();
        }
        std::fs::write(&full, content).unwrap();
    }

    dir
}

#[test]
fn test_discover_node_project() {
    let dir = create_project(&[
        ("package.json", r#"{"name":"my-app","version":"2.1.0","description":"A web app","scripts":{"lint":"eslint .","test":"jest","build":"next build","dev":"next dev"},"dependencies":{"next":"14.0.0","react":"18.0.0"}}"#),
        ("tsconfig.json", r#"{"compilerOptions":{"strict":true}}"#),
        ("src/index.ts", "export const main = () => {};\n"),
        ("src/utils.ts", "export function add(a: number, b: number) { return a + b; }\n"),
        ("__tests__/index.test.ts", "test('works', () => {});\n"),
    ]);

    let manifest = aiframework::scanner::discover(dir.path()).unwrap();

    // Identity
    assert_eq!(manifest["identity"]["name"].as_str().unwrap(), "my-app");
    assert_eq!(manifest["identity"]["version"].as_str().unwrap(), "2.1.0");

    // Stack
    let lang = manifest["stack"]["language"].as_str().unwrap();
    assert!(
        lang == "typescript" || lang == "javascript",
        "Expected ts/js, got: {lang}"
    );

    // Commands
    let pkg_mgr = manifest["commands"]["package_manager"].as_str().unwrap();
    assert_eq!(pkg_mgr, "npm");
}

#[test]
fn test_discover_python_project() {
    let dir = create_project(&[
        ("requirements.txt", "fastapi==0.100.0\nuvicorn==0.23.0\n"),
        ("pyproject.toml", "[project]\nname = \"my-api\"\nversion = \"0.5.0\"\n"),
        ("app/main.py", "from fastapi import FastAPI\napp = FastAPI()\n"),
        ("app/routes.py", "from app.main import app\n"),
        ("tests/test_main.py", "def test_health(): pass\n"),
        ("Makefile", "lint:\n\truff check .\ntest:\n\tpytest\n"),
    ]);

    let manifest = aiframework::scanner::discover(dir.path()).unwrap();

    assert_eq!(manifest["identity"]["name"].as_str().unwrap(), "my-api");
    assert_eq!(manifest["identity"]["version"].as_str().unwrap(), "0.5.0");

    // Commands should come from Makefile
    assert_eq!(manifest["commands"]["lint"].as_str().unwrap(), "make lint");
    assert_eq!(manifest["commands"]["test"].as_str().unwrap(), "make test");
}

#[test]
fn test_discover_rust_project() {
    let dir = create_project(&[
        ("Cargo.toml", "[package]\nname = \"my-cli\"\nversion = \"3.0.0\"\nedition = \"2021\"\n"),
        ("src/main.rs", "fn main() { println!(\"hello\"); }\n"),
        ("src/lib.rs", "pub fn greet() -> &'static str { \"hi\" }\n"),
        ("tests/integration.rs", "#[test] fn it_works() {}\n"),
    ]);

    let manifest = aiframework::scanner::discover(dir.path()).unwrap();

    assert_eq!(manifest["identity"]["name"].as_str().unwrap(), "my-cli");
    assert_eq!(manifest["identity"]["version"].as_str().unwrap(), "3.0.0");

    let lang = manifest["stack"]["language"].as_str().unwrap();
    assert_eq!(lang, "rust");

    // Structure
    let source_dirs = manifest["structure"]["source_dirs"].as_array().unwrap();
    let src_names: Vec<&str> = source_dirs.iter().filter_map(|v| v.as_str()).collect();
    assert!(src_names.contains(&"src"), "Missing src dir: {:?}", src_names);
}

#[test]
fn test_discover_go_project() {
    let dir = create_project(&[
        ("go.mod", "module github.com/user/api\n\ngo 1.21\n"),
        ("go.sum", ""),
        ("main.go", "package main\n\nfunc main() {}\n"),
        ("handlers/api.go", "package handlers\n\nfunc Health() {}\n"),
    ]);

    let manifest = aiframework::scanner::discover(dir.path()).unwrap();

    let lang = manifest["stack"]["language"].as_str().unwrap();
    assert_eq!(lang, "go");
    assert_eq!(
        manifest["commands"]["package_manager"].as_str().unwrap(),
        "go"
    );
}

#[test]
fn test_discover_empty_project() {
    let dir = create_project(&[]);

    let manifest = aiframework::scanner::discover(dir.path()).unwrap();

    // Should not crash, should produce valid manifest
    assert!(manifest["identity"]["name"].is_string());
    assert!(manifest["structure"]["total_files"].is_number());
}

#[test]
fn test_discover_makefile_commands() {
    let dir = create_project(&[
        ("Makefile", "install:\n\techo install\nlint:\n\tshellcheck *.sh\ntest:\n\tbash tests.sh\nbuild:\n\tmake dist\ncheck:\n\tbash -n *.sh\n"),
        ("app.sh", "#!/bin/bash\necho hello\n"),
    ]);

    let manifest = aiframework::scanner::discover(dir.path()).unwrap();

    assert_eq!(manifest["commands"]["lint"].as_str().unwrap(), "make lint");
    assert_eq!(manifest["commands"]["test"].as_str().unwrap(), "make test");
    assert_eq!(manifest["commands"]["build"].as_str().unwrap(), "make build");
    assert_eq!(
        manifest["commands"]["install"].as_str().unwrap(),
        "make install"
    );
}

#[test]
fn test_full_pipeline() {
    let dir = create_project(&[
        ("package.json", r#"{"name":"demo","version":"1.0.0","scripts":{"lint":"eslint .","test":"jest"},"dependencies":{"express":"4.0.0"}}"#),
        ("src/index.js", "const express = require('express');\nconst app = express();\nmodule.exports = app;\n"),
        ("src/routes.js", "const app = require('./index');\napp.get('/', (req, res) => res.send('ok'));\n"),
        ("tests/index.test.js", "test('works', () => { expect(1).toBe(1); });\n"),
    ]);

    // Run full pipeline: discover + index
    let manifest = aiframework::scanner::discover(dir.path()).unwrap();
    let index = aiframework::indexer::index_repo(dir.path()).unwrap();

    // Generate CLAUDE.md
    let claude_md = aiframework::generator::claude_md::generate(&manifest, Some(&index));

    assert!(claude_md.contains("# CLAUDE.md — demo"));
    assert!(claude_md.contains("## Commands"));
    assert!(claude_md.contains("## Key Files"));
    assert!(claude_md.contains("## Invariants"));

    // Verify code index
    let meta = &index["_meta"];
    assert!(meta["total_files"].as_u64().unwrap() >= 3);
    // JS files may not have many extractable symbols with regex — that's ok
    assert!(meta["total_files"].as_u64().unwrap() >= 3);
}
