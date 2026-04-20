/// Embedded data registries — compiled into the binary.
/// These match lib/data/*.json from the bash version.

use serde::Deserialize;
use serde_json::Value;
use std::collections::HashMap;
use std::sync::LazyLock;

// Embed JSON registries at compile time
const LANGUAGES_JSON: &str = include_str!("../../data/languages.json");

/// Top-level JSON structure: {"$schema": ..., "$description": ..., "languages": {...}}
#[derive(Debug, Deserialize)]
struct LanguagesFile {
    #[serde(default)]
    languages: HashMap<String, LanguageEntry>,
}

static LANGUAGES: LazyLock<HashMap<String, LanguageEntry>> = LazyLock::new(|| {
    let file: LanguagesFile = serde_json::from_str(LANGUAGES_JSON).unwrap_or(LanguagesFile {
        languages: HashMap::new(),
    });
    file.languages
});

/// A language registry entry matching lib/data/languages.json structure.
#[derive(Debug, Deserialize, Clone)]
#[allow(dead_code)]
pub struct LanguageEntry {
    pub display: Option<String>,
    pub marker_files: Option<Vec<String>>,
    pub extensions: Option<Vec<String>>,
    #[serde(default)]
    pub package_managers: Option<HashMap<String, PackageManager>>,
    #[serde(default)]
    pub frameworks: Option<HashMap<String, FrameworkEntry>>,
    #[serde(default)]
    pub qa_rules: Option<Vec<String>>,
}

#[derive(Debug, Deserialize, Clone)]
#[allow(dead_code)]
pub struct PackageManager {
    pub manifest: Option<String>,
    pub lock_file: Option<Value>,
    pub commands: Option<HashMap<String, Value>>,
}

#[derive(Debug, Deserialize, Clone)]
#[allow(dead_code)]
pub struct FrameworkDetection {
    pub dependency_markers: Option<Vec<String>>,
    pub file_patterns: Option<Vec<String>>,
}

#[derive(Debug, Deserialize, Clone)]
#[allow(dead_code)]
pub struct FrameworkEntry {
    pub display: Option<String>,
    pub detection: Option<FrameworkDetection>,
    // Legacy fields (some registries use flat format)
    pub marker: Option<String>,
    pub marker_file: Option<String>,
    pub marker_content: Option<String>,
    #[serde(default)]
    pub archetype: Option<String>,
}

/// Look up a language by name.
#[allow(dead_code)]
pub fn get_language(name: &str) -> Option<&LanguageEntry> {
    LANGUAGES.get(name)
}

/// Get all registered languages.
#[allow(dead_code)]
pub fn all_languages() -> &'static HashMap<String, LanguageEntry> {
    &LANGUAGES
}

/// Detect the primary language of a repo by checking marker files.
pub fn detect_language(files: &[String]) -> Option<(String, &'static LanguageEntry)> {
    let file_set: std::collections::HashSet<&str> = files.iter().map(|s| s.as_str()).collect();

    // Score each language by how many markers match
    let mut scores: Vec<(String, usize, &LanguageEntry)> = Vec::new();

    for (lang, entry) in LANGUAGES.iter() {
        let mut score = 0;
        if let Some(markers) = &entry.marker_files {
            for marker in markers {
                if file_set.contains(marker.as_str()) {
                    score += 1;
                }
            }
        }
        if let Some(exts) = &entry.extensions {
            for ext in exts {
                let suffix = format!(".{}", ext);
                let matches = files.iter().filter(|f| f.ends_with(&suffix)).count();
                score += matches.min(10); // cap at 10 per extension
            }
        }
        if score > 0 {
            scores.push((lang.clone(), score, entry));
        }
    }

    scores.sort_by(|a, b| b.1.cmp(&a.1));
    scores
        .into_iter()
        .next()
        .map(|(lang, _, entry)| (lang, entry))
}

/// Detect framework within a language.
pub fn detect_framework(
    lang_entry: &LanguageEntry,
    files: &[String],
    file_contents: &HashMap<String, String>,
) -> Option<String> {
    let frameworks = lang_entry.frameworks.as_ref()?;

    for (fw_name, fw) in frameworks {
        // New format: detection.dependency_markers + detection.file_patterns
        if let Some(ref det) = fw.detection {
            // Check dependency markers in package files
            if let Some(ref markers) = det.dependency_markers {
                for (_, content) in file_contents {
                    let lower = content.to_lowercase();
                    if markers.iter().any(|m| lower.contains(&m.to_lowercase())) {
                        return Some(fw_name.clone());
                    }
                }
            }
            // Check file patterns
            if let Some(ref patterns) = det.file_patterns {
                for pattern in patterns {
                    let clean = pattern.replace("**/", "");
                    if files.iter().any(|f| f.contains(&clean) || f.ends_with(&clean)) {
                        return Some(fw_name.clone());
                    }
                }
            }
        }

        // Legacy format: marker_file
        if let Some(marker_file) = &fw.marker_file {
            if files.iter().any(|f| f.contains(marker_file)) {
                return Some(fw_name.clone());
            }
        }

        // Legacy format: marker_content
        if let Some(marker_content) = &fw.marker_content {
            for (path, content) in file_contents {
                if path.ends_with("package.json")
                    || path.ends_with("Cargo.toml")
                    || path.ends_with("requirements.txt")
                    || path.ends_with("go.mod")
                    || path.ends_with("Gemfile")
                {
                    if content.contains(marker_content) {
                        return Some(fw_name.clone());
                    }
                }
            }
        }

        // Check marker (dependency name in common configs)
        if let Some(marker) = &fw.marker {
            for (_, content) in file_contents {
                if content.contains(marker) {
                    return Some(fw_name.clone());
                }
            }
        }
    }

    None
}
