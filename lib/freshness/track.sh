#!/usr/bin/env bash
# Freshness tracking — records file hashes to detect drift between scans

# Save hashes of key files after a successful discover
freshness_save_hashes() {
  local target_dir="$1"
  local hash_file="$target_dir/.aiframework/.file_hashes"

  mkdir -p "$(dirname "$hash_file")"
  : > "$hash_file"  # truncate

  local key_files=("package.json" "pyproject.toml" "Cargo.toml" "go.mod" "Gemfile"
                    "tsconfig.json" "composer.json" "pom.xml" "build.gradle"
                    "mix.exs" "pubspec.yaml" ".github/workflows")

  # Also track the aiframework version — if we upgrade, repos should refresh
  local _aif_root
  _aif_root="$(cd "$(dirname "$(command -v aiframework 2>/dev/null || echo /dev/null)")/.." 2>/dev/null && pwd)" || true
  if [[ -f "$_aif_root/VERSION" ]]; then
    local aif_ver
    aif_ver=$(cat "$_aif_root/VERSION" 2>/dev/null | tr -d '[:space:]')
    echo "_aiframework_version:${aif_ver}" >> "$hash_file"
  fi

  for kf in "${key_files[@]}"; do
    if [[ -f "$target_dir/$kf" ]]; then
      local hash
      hash=$(md5 -q "$target_dir/$kf" 2>/dev/null || md5sum "$target_dir/$kf" 2>/dev/null | cut -d' ' -f1 || true)
      [[ -n "$hash" ]] && echo "${kf}:${hash}" >> "$hash_file"
    elif [[ -d "$target_dir/$kf" ]]; then
      # For directories, hash the listing
      local hash
      hash=$(ls -la "$target_dir/$kf" 2>/dev/null | md5 -q 2>/dev/null || ls -la "$target_dir/$kf" 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1 || true)
      [[ -n "$hash" ]] && echo "${kf}:${hash}" >> "$hash_file"
    fi
  done
}

# Check if key files changed since last scan
freshness_check_drift() {
  local target_dir="$1"
  local hash_file="$target_dir/.aiframework/.file_hashes"

  [[ -f "$hash_file" ]] || { echo "no-baseline"; return; }

  local drifted=""
  while IFS=: read -r filename stored_hash; do
    [[ -z "$filename" ]] && continue

    # Special case: aiframework version check (not a file in the target repo)
    if [[ "$filename" == "_aiframework_version" ]]; then
      local _aif_root
      _aif_root="$(cd "$(dirname "$(command -v aiframework 2>/dev/null || echo /dev/null)")/.." 2>/dev/null && pwd)" || true
      local current_ver=""
      [[ -f "$_aif_root/VERSION" ]] && current_ver=$(cat "$_aif_root/VERSION" 2>/dev/null | tr -d '[:space:]')
      if [[ -n "$current_ver" && "$current_ver" != "$stored_hash" ]]; then
        drifted="$drifted aiframework($stored_hash→$current_ver)"
      fi
      continue
    fi

    local current_hash=""
    if [[ -f "$target_dir/$filename" ]]; then
      current_hash=$(md5 -q "$target_dir/$filename" 2>/dev/null || md5sum "$target_dir/$filename" 2>/dev/null | cut -d' ' -f1 || true)
    elif [[ -d "$target_dir/$filename" ]]; then
      current_hash=$(ls -la "$target_dir/$filename" 2>/dev/null | md5 -q 2>/dev/null || ls -la "$target_dir/$filename" 2>/dev/null | md5sum 2>/dev/null | cut -d' ' -f1 || true)
    fi
    if [[ -n "$current_hash" && "$current_hash" != "$stored_hash" ]]; then
      drifted="$drifted $filename"
    fi
  done < "$hash_file"

  if [[ -n "$drifted" ]]; then
    echo "drifted:$drifted"
  else
    echo "clean"
  fi
}
