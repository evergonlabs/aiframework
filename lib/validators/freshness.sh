#!/usr/bin/env bash
# Validator: Freshness — detects when generated files are stale

validate_freshness() {
  # Temporarily relax strict mode for grep pipelines
  set +eo pipefail

  local m="$MANIFEST"

  # --- Check 1: Manifest age ---
  local manifest_ts
  manifest_ts=$(echo "$m" | jq -r '._meta.generated_at // empty')
  if [[ -n "$manifest_ts" ]]; then
    # Compare manifest timestamp to current time
    local manifest_epoch
    manifest_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$manifest_ts" "+%s" 2>/dev/null || date -d "$manifest_ts" "+%s" 2>/dev/null || echo "0")
    local now_epoch
    now_epoch=$(date "+%s")
    local age_days=$(( (now_epoch - manifest_epoch) / 86400 ))

    if [[ "$age_days" -gt 14 ]]; then
      report_row "Manifest freshness" "WARN" "Manifest is ${age_days}d old — rescan"
    elif [[ "$age_days" -gt 7 ]]; then
      report_row "Manifest freshness" "WARN" "Manifest is ${age_days}d old"
    else
      report_row "Manifest freshness" "PASS" "Manifest is ${age_days}d old"
    fi
  fi

  # --- Check 2: Key file hash drift ---
  # Compare hash of critical files against what manifest captured
  local key_files=("package.json" "pyproject.toml" "Cargo.toml" "go.mod" "Gemfile" "tsconfig.json" "composer.json")
  local drift_detected=false

  for kf in "${key_files[@]}"; do
    if [[ -f "$TARGET_DIR/$kf" ]]; then
      local current_hash
      current_hash=$(md5 -q "$TARGET_DIR/$kf" 2>/dev/null || md5sum "$TARGET_DIR/$kf" 2>/dev/null | cut -d' ' -f1 || true)
      # Store hash in .aiframework for future comparison
      local hash_file="$TARGET_DIR/.aiframework/.file_hashes"
      if [[ -f "$hash_file" ]]; then
        local stored_hash
        stored_hash=$(grep "^${kf}:" "$hash_file" 2>/dev/null | cut -d: -f2 || true)
        if [[ -n "$stored_hash" && "$stored_hash" != "$current_hash" ]]; then
          drift_detected=true
        fi
      fi
    fi
  done

  if [[ "$drift_detected" == true ]]; then
    report_row "File drift detection" "WARN" "Key files changed — refresh"
  else
    report_row "File drift detection" "PASS" "No drift in key files"
  fi

  # --- Check 3: Code index freshness ---
  local index_file="$TARGET_DIR/.aiframework/code-index.json"
  if [[ -f "$index_file" ]]; then
    local index_files
    index_files=$(jq -r '._meta.total_files // 0' "$index_file" 2>/dev/null)
    # Quick check: count current source files vs indexed count
    local current_files
    current_files=$(find "$TARGET_DIR" -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.go' -o -name '*.rs' -o -name '*.rb' -o -name '*.sh' -o -name '*.java' -o -name '*.cs' -o -name '*.php' -o -name '*.kt' -o -name '*.swift' -o -name '*.ex' 2>/dev/null | grep -v node_modules | grep -v '.git/' | grep -v __pycache__ | wc -l | tr -d ' ')
    local diff=$(( current_files - index_files ))
    if [[ "$diff" -gt 5 ]] || [[ "$diff" -lt -5 ]]; then
      report_row "Code index freshness" "WARN" "Index: ${index_files}, repo: ~${current_files}"
    else
      report_row "Code index freshness" "PASS" "Index matches (~${current_files} files)"
    fi
  else
    report_row "Code index freshness" "SKIP" "No code index found"
  fi

  # --- Check 4: CLAUDE.md mentions correct project name ---
  if [[ -f "$TARGET_DIR/CLAUDE.md" ]]; then
    local project_name
    project_name=$(echo "$m" | jq -r '.identity.name // empty')
    if [[ -n "$project_name" ]] && ! head -5 "$TARGET_DIR/CLAUDE.md" | grep -q "$project_name"; then
      report_row "CLAUDE.md identity" "WARN" "Missing project name '$project_name'"
    else
      report_row "CLAUDE.md identity" "PASS" "CLAUDE.md matches identity"
    fi
  fi

  set -eo pipefail
}
