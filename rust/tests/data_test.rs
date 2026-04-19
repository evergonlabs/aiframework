use aiframework::indexer::data;

#[test]
fn test_languages_loaded() {
    let langs = data::all_languages();
    assert!(langs.len() >= 10, "Expected at least 10 languages, got {}", langs.len());
}

#[test]
fn test_detect_python() {
    let files = vec![
        "requirements.txt".to_string(),
        "app.py".to_string(),
        "lib/utils.py".to_string(),
    ];
    let result = data::detect_language(&files);
    assert!(result.is_some());
    let (lang, _) = result.unwrap();
    assert_eq!(lang, "python", "Expected python, got {lang}");
}

#[test]
fn test_detect_typescript() {
    let files = vec![
        "package.json".to_string(),
        "tsconfig.json".to_string(),
        "src/index.ts".to_string(),
        "src/app.tsx".to_string(),
    ];
    let result = data::detect_language(&files);
    assert!(result.is_some());
    let (lang, _) = result.unwrap();
    assert!(
        lang == "typescript" || lang == "javascript",
        "Expected typescript or javascript, got {lang}"
    );
}

#[test]
fn test_detect_rust() {
    let files = vec![
        "Cargo.toml".to_string(),
        "src/main.rs".to_string(),
        "src/lib.rs".to_string(),
    ];
    let result = data::detect_language(&files);
    assert!(result.is_some());
    let (lang, _) = result.unwrap();
    assert_eq!(lang, "rust", "Expected rust, got {lang}");
}

#[test]
fn test_detect_go() {
    let files = vec![
        "go.mod".to_string(),
        "go.sum".to_string(),
        "main.go".to_string(),
        "handlers/api.go".to_string(),
    ];
    let result = data::detect_language(&files);
    assert!(result.is_some());
    let (lang, _) = result.unwrap();
    assert_eq!(lang, "go", "Expected go, got {lang}");
}

#[test]
fn test_get_language() {
    let py = data::get_language("python");
    assert!(py.is_some());
    let py = py.unwrap();
    assert!(py.extensions.is_some());
    let exts = py.extensions.as_ref().unwrap();
    assert!(exts.contains(&".py".to_string()));
}
