#!/usr/bin/env bash
# Scanner: Directory Structure
# Discovers source dirs, test dirs, config files, key locations

# Helper: convert bash array to JSON array safely
_arr_to_json() {
  if [[ $# -eq 0 ]]; then
    echo "[]"
  else
    printf '%s\n' "$@" | jq -R '.' | jq -s '.'
  fi
}

scan_structure() {
  local source_dirs="[]"
  local test_dirs="[]"
  local test_pattern=""
  local doc_dirs="[]"
  local config_files="[]"
  local script_dirs="[]"
  local ci_dirs="[]"

  # --- Top-level directories ---
  local all_dirs="[]"
  if [[ -d "$TARGET_DIR" ]]; then
    local dirs_output
    # shellcheck disable=SC2011
    dirs_output=$(ls -1d "$TARGET_DIR"/*/ 2>/dev/null | xargs -I{} basename {} 2>/dev/null || true)
    if [[ -n "$dirs_output" ]]; then
      all_dirs=$(echo "$dirs_output" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
    fi
  fi

  # --- Source directories ---
  local src_candidates=("src" "app" "lib" "source" "pkg" "internal" "cmd" "api" "server" "backend" "frontend" "web" "core" "modules")
  local found_src=()
  for dir in "${src_candidates[@]}"; do
    [[ -d "$TARGET_DIR/$dir" ]] && found_src+=("$dir")
  done
  if [[ -d "$TARGET_DIR/apps" ]]; then
    for d in "$TARGET_DIR/apps"/*/; do
      [[ -d "$d" ]] && found_src+=("apps/$(basename "$d")")
    done
  fi
  source_dirs=$(_arr_to_json "${found_src[@]+"${found_src[@]}"}")

  # --- Test directories ---
  local test_candidates=("test" "tests" "__tests__" "spec" "specs" "test_" "e2e" "integration")
  local found_test=()
  for dir in "${test_candidates[@]}"; do
    [[ -d "$TARGET_DIR/$dir" ]] && found_test+=("$dir")
  done
  if [[ -d "$TARGET_DIR/src" ]]; then
    while IFS= read -r d; do
      [[ -n "$d" ]] && found_test+=("$d")
    done < <(find "$TARGET_DIR/src" -maxdepth 3 -type d \( -name "test" -o -name "tests" -o -name "__tests__" -o -name "spec" \) 2>/dev/null | sed "s|$TARGET_DIR/||" || true)
  fi
  test_dirs=$(_arr_to_json "${found_test[@]+"${found_test[@]}"}")

  # --- Test pattern ---
  local test_ts_count test_py_count test_go_count test_rs_count
  test_ts_count=$(find "$TARGET_DIR" -maxdepth 8 \( -name "*.test.ts" -o -name "*.test.tsx" -o -name "*.spec.ts" -o -name "*.spec.tsx" \) -not -path "*/node_modules/*" 2>/dev/null | wc -l | tr -d '[:space:]')
  test_py_count=$(find "$TARGET_DIR" -maxdepth 8 \( -name "test_*.py" -o -name "*_test.py" \) -not -path "*/.venv/*" 2>/dev/null | wc -l | tr -d '[:space:]')
  test_go_count=$(find "$TARGET_DIR" -maxdepth 8 -name "*_test.go" 2>/dev/null | wc -l | tr -d '[:space:]')
  test_rs_count=$(find "$TARGET_DIR" -maxdepth 8 -path "*/tests/*.rs" 2>/dev/null | wc -l | tr -d '[:space:]')

  if [[ "$test_ts_count" -gt 0 ]]; then
    test_pattern="*.test.ts / *.spec.ts"
  elif [[ "$test_py_count" -gt 0 ]]; then
    test_pattern="test_*.py / *_test.py"
  elif [[ "$test_go_count" -gt 0 ]]; then
    test_pattern="*_test.go"
  elif [[ "$test_rs_count" -gt 0 ]]; then
    test_pattern="tests/*.rs"
  else
    test_pattern="NOT_FOUND"
  fi

  local total_test_files=$((test_ts_count + test_py_count + test_go_count + test_rs_count))

  # --- Documentation directories ---
  local doc_candidates=("docs" "doc" "documentation" "wiki")
  local found_docs=()
  for dir in "${doc_candidates[@]}"; do
    [[ -d "$TARGET_DIR/$dir" ]] && found_docs+=("$dir")
  done
  doc_dirs=$(_arr_to_json "${found_docs[@]+"${found_docs[@]}"}")

  # --- Config files ---
  local found_configs=()
  local config_candidates=("package.json" "tsconfig.json" "tsconfig.base.json" "pyproject.toml" "Cargo.toml" "go.mod" "Makefile" "Dockerfile" "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml" ".eslintrc.js" ".eslintrc.json" ".eslintrc.yml" "eslint.config.js" "eslint.config.mjs" ".prettierrc" ".prettierrc.json" ".prettierrc.js" "prettier.config.js" "vitest.config.ts" "vitest.config.js" "jest.config.ts" "jest.config.js" "jest.config.json" "tailwind.config.ts" "tailwind.config.js" "postcss.config.js" "postcss.config.mjs" "next.config.ts" "next.config.js" "next.config.mjs" "vite.config.ts" "vite.config.js" "turbo.json" "nx.json" "lerna.json" ".env.example" ".env.template" ".env.sample" ".gitignore" ".editorconfig" "renovate.json" ".nvmrc" ".node-version" ".python-version" ".tool-versions")
  for f in "${config_candidates[@]}"; do
    [[ -f "$TARGET_DIR/$f" ]] && found_configs+=("$f")
  done
  config_files=$(_arr_to_json "${found_configs[@]+"${found_configs[@]}"}")

  # --- Script directories ---
  local script_candidates=("scripts" "script" "bin" "tools" "hack" "build")
  local found_scripts=()
  for dir in "${script_candidates[@]}"; do
    [[ -d "$TARGET_DIR/$dir" ]] && found_scripts+=("$dir")
  done
  script_dirs=$(_arr_to_json "${found_scripts[@]+"${found_scripts[@]}"}")

  # --- CI directories ---
  local found_ci=()
  [[ -d "$TARGET_DIR/.github" ]] && found_ci+=(".github")
  [[ -d "$TARGET_DIR/.circleci" ]] && found_ci+=(".circleci")
  [[ -f "$TARGET_DIR/.gitlab-ci.yml" ]] && found_ci+=(".gitlab-ci.yml")
  [[ -f "$TARGET_DIR/Jenkinsfile" ]] && found_ci+=("Jenkinsfile")
  ci_dirs=$(_arr_to_json "${found_ci[@]+"${found_ci[@]}"}")

  # --- File counts by extension ---
  local file_counts="{}"
  if [[ -d "$TARGET_DIR" ]]; then
    local raw_counts
    raw_counts=$(find "$TARGET_DIR" -maxdepth 8 -type f \
      -not -path "*/node_modules/*" \
      -not -path "*/.git/*" \
      -not -path "*/.venv/*" \
      -not -path "*/target/*" \
      -not -path "*/dist/*" \
      -not -path "*/build/*" \
      -not -path "*/__pycache__/*" \
      2>/dev/null | grep -oE '\.[a-zA-Z0-9]+$' | sort | uniq -c | sort -rn | head -20 || true)

    if [[ -n "$raw_counts" ]]; then
      file_counts=$(echo "$raw_counts" | awk '{printf "\"%s\": %d,\n", $2, $1}' | sed '$ s/,$//' | awk 'BEGIN{print "{"} {print} END{print "}"}')
      file_counts=$(echo "$file_counts" | jq '.' 2>/dev/null || echo "{}")
    fi
  fi

  # --- Total file count ---
  local total_files
  total_files=$(find "$TARGET_DIR" -maxdepth 8 -type f \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/.venv/*" \
    -not -path "*/target/*" \
    -not -path "*/dist/*" \
    -not -path "*/build/*" \
    -not -path "*/__pycache__/*" \
    2>/dev/null | wc -l | tr -d '[:space:]')

  # --- Key locations (entry points) ---
  local found_entries=()
  local entry_candidates=("src/main.ts" "src/main.tsx" "src/index.ts" "src/index.tsx" "src/app.ts" "app/main.py" "main.py" "app.py" "src/main.py" "src/main.rs" "src/lib.rs" "main.go" "cmd/main.go" "src/App.tsx" "src/App.vue" "app/layout.tsx" "app/page.tsx" "pages/index.tsx" "pages/_app.tsx")
  for f in "${entry_candidates[@]}"; do
    [[ -f "$TARGET_DIR/$f" ]] && found_entries+=("$f")
  done
  local entry_points
  entry_points=$(_arr_to_json "${found_entries[@]+"${found_entries[@]}"}")

  # --- Key files detection (A10) ---
  # Scan for important source files, service/module files, and subdirectory READMEs
  local found_key_files=()
  local key_file_count=0

  # Source code files in src/, app/, lib/ directories (first 5 of each)
  for sdir in src app lib bin; do
    if [[ -d "$TARGET_DIR/$sdir" ]]; then
      while IFS= read -r f; do
        [[ -n "$f" ]] && found_key_files+=("$f") && key_file_count=$((key_file_count + 1))
        [[ "$key_file_count" -ge 30 ]] && break
      done < <(find "$TARGET_DIR/$sdir" -maxdepth 2 -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.rb" -o -name "*.sh" \) \
        -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/__pycache__/*" \
        -not -name "*.test.*" -not -name "*.spec.*" -not -name "test_*" \
        2>/dev/null | head -15 | sed "s|$TARGET_DIR/||")
    fi
    [[ "$key_file_count" -ge 30 ]] && break
  done

  # Key service/module files (across entire project)
  if [[ "$key_file_count" -lt 30 ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] && found_key_files+=("$f") && key_file_count=$((key_file_count + 1))
      [[ "$key_file_count" -ge 30 ]] && break
    done < <(find "$TARGET_DIR" -maxdepth 6 -type f \
      \( -name "*service*" -o -name "*controller*" -o -name "*model*" -o -name "*schema*" -o -name "*route*" -o -name "*handler*" -o -name "*middleware*" -o -name "*config*" -o -name "*util*" -o -name "*helper*" \) \
      -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" -not -path "*/dist/*" -not -path "*/build/*" -not -path "*/__pycache__/*" \
      -not -name "*.test.*" -not -name "*.spec.*" -not -name "test_*" \
      -not -name "*.md" -not -name "*.txt" -not -name "*.json" -not -name "*.lock" -not -name "*.yml" -not -name "*.yaml" \
      2>/dev/null | head -20 | sed "s|$TARGET_DIR/||")
  fi

  # README files in subdirectories
  if [[ "$key_file_count" -lt 30 ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] && found_key_files+=("$f") && key_file_count=$((key_file_count + 1))
      [[ "$key_file_count" -ge 30 ]] && break
    done < <(find "$TARGET_DIR" -maxdepth 4 -mindepth 2 -type f -name "README*" \
      -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
      2>/dev/null | head -10 | sed "s|$TARGET_DIR/||")
  fi

  # Deduplicate and convert to JSON
  local key_files_json
  if [[ ${#found_key_files[@]} -eq 0 ]]; then
    key_files_json="[]"
  else
    key_files_json=$(printf '%s\n' "${found_key_files[@]}" | sort -u | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
  fi

  local src_count=${#found_src[@]}

  MANIFEST=$(echo "$MANIFEST" | jq \
    --argjson all_dirs "$all_dirs" \
    --argjson src "$source_dirs" \
    --argjson tests "$test_dirs" \
    --arg test_pat "$test_pattern" \
    --arg test_count "$total_test_files" \
    --argjson docs "$doc_dirs" \
    --argjson configs "$config_files" \
    --argjson scripts "$script_dirs" \
    --argjson ci "$ci_dirs" \
    --argjson file_counts "$file_counts" \
    --arg total "$total_files" \
    --argjson entries "$entry_points" \
    --argjson key_files "$key_files_json" \
    '. + {
      "structure": {
        "directories": $all_dirs,
        "source_dirs": $src,
        "test_dirs": $tests,
        "test_pattern": $test_pat,
        "test_file_count": ($test_count | tonumber),
        "doc_dirs": $docs,
        "config_files": $configs,
        "script_dirs": $scripts,
        "ci_dirs": $ci,
        "file_counts": $file_counts,
        "total_files": ($total | tonumber),
        "entry_points": $entries,
        "key_files": $key_files
      }
    }')

  log_ok "Structure: $total_files files, $src_count source dirs, $total_test_files test files"
}
