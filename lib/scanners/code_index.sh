#!/usr/bin/env bash
# Scanner: Code Index
# Builds a code index (symbols, functions, classes) or falls back to file-level index

scan_code_index() {
  local index_file="$OUTPUT_DIR/code-index.json"

  if command -v python3 &>/dev/null; then
    # Full index via Python parser
    local py_output
    py_output=$(cd "$ROOT_DIR" && python3 -m lib.indexers.parse --target "$TARGET_DIR" --output "$index_file" 2>&1) || {
      log_warn "Python indexer failed, falling back to bash file index"
      log_warn "$py_output"
      _code_index_bash_fallback "$index_file"
    }
    if [[ -n "$py_output" ]] && [[ "$VERBOSE" == "true" ]]; then
      log_info "$py_output"
    fi
  else
    log_warn "python3 not available — using bash file-level index"
    _code_index_bash_fallback "$index_file"
  fi

  # Add summary to manifest
  if [[ -f "$index_file" ]]; then
    local file_count
    file_count=$(jq '.files | length' "$index_file" 2>/dev/null || echo "0")
    MANIFEST=$(echo "$MANIFEST" | jq \
      --arg count "$file_count" \
      --arg path "$index_file" \
      '. + {
        "code_index": {
          "file_count": ($count | tonumber),
          "index_path": $path,
          "method": (if $count == "0" then "none" else "indexed" end)
        }
      }')
    log_ok "Code index: $file_count files indexed → $index_file"
  else
    MANIFEST=$(echo "$MANIFEST" | jq '. + {
      "code_index": {
        "file_count": 0,
        "index_path": null,
        "method": "none"
      }
    }')
    log_warn "Code index: no files indexed"
  fi
}

_code_index_bash_fallback() {
  local out_file="$1"
  local files_json="[]"

  while IFS= read -r -d '' file; do
    local rel_path="${file#"$TARGET_DIR"/}"
    local ext="${file##*.}"
    local lang="unknown"
    local lines size

    # Map extension to language
    case "$ext" in
      sh|bash)    lang="bash" ;;
      py)         lang="python" ;;
      js)         lang="javascript" ;;
      ts)         lang="typescript" ;;
      jsx)        lang="jsx" ;;
      tsx)        lang="tsx" ;;
      rb)         lang="ruby" ;;
      go)         lang="go" ;;
      rs)         lang="rust" ;;
      java)       lang="java" ;;
      c)          lang="c" ;;
      cpp|cc|cxx) lang="cpp" ;;
      h|hpp)      lang="c-header" ;;
      cs)         lang="csharp" ;;
      php)        lang="php" ;;
      swift)      lang="swift" ;;
      kt|kts)     lang="kotlin" ;;
      lua)        lang="lua" ;;
      r|R)        lang="r" ;;
      sql)        lang="sql" ;;
      toml)       lang="toml" ;;
      yaml|yml)   lang="yaml" ;;
      json)       lang="json" ;;
      md)         lang="markdown" ;;
    esac

    lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")

    files_json=$(echo "$files_json" | jq \
      --arg path "$rel_path" \
      --arg lang "$lang" \
      --arg lines "$lines" \
      --arg size "$size" \
      '. + [{
        "path": $path,
        "language": $lang,
        "lines": ($lines | tonumber),
        "size": ($size | tonumber)
      }]')
  done < <(find "$TARGET_DIR" -type f \
    \( -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.ts' \
       -o -name '*.jsx' -o -name '*.tsx' -o -name '*.rb' -o -name '*.go' \
       -o -name '*.rs' -o -name '*.java' -o -name '*.c' -o -name '*.cpp' \
       -o -name '*.h' -o -name '*.hpp' -o -name '*.cs' -o -name '*.php' \
       -o -name '*.swift' -o -name '*.kt' -o -name '*.lua' -o -name '*.r' \
       -o -name '*.R' -o -name '*.sql' -o -name '*.toml' -o -name '*.yaml' \
       -o -name '*.yml' -o -name '*.json' -o -name '*.md' \) \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/vendor/*' \
    -not -path '*/.aiframework/*' \
    -print0 2>/dev/null)

  echo "$files_json" | jq '{
    "_meta": {
      "method": "bash-fallback",
      "languages": (reduce .[] as $f ({}; .[$f.language] = ((.[$f.language] // 0) + 1)))
    },
    "files": .,
    "symbols": [],
    "edges": [],
    "modules": {},
    "method": "bash-fallback"
  }' > "$out_file"
}
