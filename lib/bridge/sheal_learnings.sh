#!/usr/bin/env bash
# Bridge: Sheal ↔ aiframework learning sync
# Bidirectional conversion between JSONL (aiframework) and markdown (sheal)
#
# Security: Only reads/writes local files. No network access.
# All JSON construction uses jq --arg for safe escaping (INV-1 compliant).

# Convert aiframework JSONL learnings → sheal markdown learnings
# Usage: bridge_jsonl_to_sheal [target_dir]
bridge_jsonl_to_sheal() {
  local target="${1:-$TARGET_DIR}"
  local sheal_dir="$target/.sheal/learnings"
  local jsonl_files

  jsonl_files=$(find "$target/tools/learnings" -name '*-learnings.jsonl' 2>/dev/null)
  [[ -z "$jsonl_files" ]] && return 0

  mkdir -p "$sheal_dir"

  # Find next available LEARN number
  local max_num=0
  local existing
  existing=$(find "$sheal_dir" -name 'LEARN-*.md' 2>/dev/null | sed 's/.*LEARN-0*\([0-9]*\).*/\1/' | sort -n | tail -1)
  [[ -n "$existing" ]] && max_num="$existing"

  # Cap at 500 files to prevent unbounded growth
  local current_count
  current_count=$(find "$sheal_dir" -name 'LEARN-*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
  if [[ "$current_count" -ge 500 ]]; then
    return 0
  fi

  local synced=0

  while IFS= read -r jsonl_file; do
    [[ -z "$jsonl_file" ]] && continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue

      # Batch all fields in a single jq call for performance
      local summary date_val category detail
      summary=$(printf '%s' "$line" | jq -r '.summary // empty' 2>/dev/null)
      [[ -z "$summary" ]] && continue

      date_val=$(printf '%s' "$line" | jq -r '.date // empty' 2>/dev/null)
      category=$(printf '%s' "$line" | jq -r '.category // "pattern"' 2>/dev/null)
      detail=$(printf '%s' "$line" | jq -r '.detail // ""' 2>/dev/null)

      # Check for duplicates by searching quoted title field (matches written format)
      if grep -rqF -- "title: \"${summary}\"" "$sheal_dir" 2>/dev/null; then
        continue
      fi

      # Cap check inside loop
      if [[ $((max_num + 1)) -gt 500 ]]; then
        break 2
      fi

      # Map aiframework categories to sheal categories
      local sheal_category
      case "$category" in
        bug)      sheal_category="failure-loop" ;;
        gotcha)   sheal_category="missing-context" ;;
        pattern)  sheal_category="workflow" ;;
        decision) sheal_category="decision" ;;
        *)        sheal_category="workflow" ;;
      esac

      # Generate slug from summary using printf (not echo, to preserve backslashes)
      local slug
      slug=$(printf '%s' "$summary" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed -e 's/^-//' -e 's/-$//' | cut -c1-40)
      [[ -z "$slug" ]] && slug="entry"

      max_num=$((max_num + 1))
      local num
      num=$(printf "%03d" "$max_num")
      local out_file="$sheal_dir/LEARN-${num}-${slug}.md"

      # Write markdown safely using printf (no heredoc, no shell expansion)
      # Strip newlines from summary to prevent YAML frontmatter injection
      local safe_summary
      safe_summary=$(printf '%s' "$summary" | tr -d '\n\r')
      local safe_date
      safe_date=$(printf '%s' "$date_val" | tr -d '\n\r' | cut -c1-20)
      {
        printf '%s\n' "---"
        printf 'title: "%s"\n' "$(printf '%s' "$safe_summary" | sed 's/"/\\"/g')"
        printf 'category: %s\n' "$sheal_category"
        printf '%s\n' "severity: medium"
        printf '%s\n' "status: active"
        printf 'date: %s\n' "$safe_date"
        printf '%s\n' "source: aiframework"
        printf '%s\n' "---"
        printf '\n'
        printf '%s\n' "${detail:-$summary}"
      } > "$out_file"

      synced=$((synced + 1))
    done < "$jsonl_file"
  done <<< "$jsonl_files"

  [[ $synced -gt 0 ]] && echo "Synced $synced learnings from JSONL to sheal"
}

# Convert sheal markdown learnings → aiframework JSONL
# Usage: bridge_sheal_to_jsonl [target_dir]
bridge_sheal_to_jsonl() {
  local target="${1:-$TARGET_DIR}"
  local sheal_dir="$target/.sheal/learnings"
  local jsonl_dir="$target/tools/learnings"

  [[ -d "$sheal_dir" ]] || return 0

  # Determine the JSONL file to append to (sanitize short_name to prevent path traversal)
  local short_name
  short_name=$(jq -r '.identity.short_name // "project"' "$target/.aiframework/manifest.json" 2>/dev/null || echo "project")
  short_name=$(printf '%s' "$short_name" | tr -dc 'a-zA-Z0-9_-')
  [[ -z "$short_name" ]] && short_name="project"
  local jsonl_file="$jsonl_dir/${short_name}-learnings.jsonl"

  mkdir -p "$jsonl_dir"
  touch "$jsonl_file"

  local synced=0

  for learn_file in "$sheal_dir"/LEARN-*.md; do
    [[ -f "$learn_file" ]] || continue

    # Parse YAML frontmatter (simple key-value)
    local title="" category="" date_val=""
    local in_frontmatter=false
    local body=""
    local frontmatter_done=false

    while IFS= read -r fmline; do
      if [[ "$frontmatter_done" == false ]]; then
        if [[ "$fmline" == "---" && "$in_frontmatter" == false ]]; then
          in_frontmatter=true
          continue
        elif [[ "$fmline" == "---" && "$in_frontmatter" == true ]]; then
          in_frontmatter=false
          frontmatter_done=true
          continue
        fi
        if [[ "$in_frontmatter" == true ]]; then
          case "$fmline" in
            title:*)    title="${fmline#title:}"; title="${title# }"; title="${title#\"}"; title="${title%\"}" ;;
            category:*) category="${fmline#category:}"; category="${category# }"; category="${category%% *}" ;;
            date:*)     date_val="${fmline#date:}"; date_val="${date_val# }"; date_val="${date_val%% *}" ;;
            severity:*) ;; # parsed but not used in JSONL conversion
          esac
        fi
      else
        body+="$fmline "
      fi
    done < "$learn_file"

    [[ -z "$title" ]] && continue

    # Skip if source is aiframework (avoid round-trip duplication)
    if grep -q 'source: aiframework' "$learn_file" 2>/dev/null; then
      continue
    fi

    # Check for duplicates by searching the summary field specifically
    if grep -Fq -- "\"summary\":\"${title}\"" "$jsonl_file" 2>/dev/null || \
       grep -Fq -- "\"summary\": \"${title}\"" "$jsonl_file" 2>/dev/null; then
      continue
    fi

    # Reverse category mapping (preserves decision category)
    local aif_category
    case "$category" in
      failure-loop)    aif_category="bug" ;;
      missing-context) aif_category="gotcha" ;;
      decision)        aif_category="decision" ;;
      workflow)        aif_category="pattern" ;;
      *)               aif_category="pattern" ;;
    esac

    [[ -z "$date_val" ]] && date_val=$(date +%Y-%m-%d)

    # Trim trailing whitespace and cap body length (prevent unbounded memory in jq)
    body=$(printf '%s' "$body" | sed 's/[[:space:]]*$//' | cut -c1-10000)

    # Build JSON safely via jq --arg (INV-1 compliant)
    jq -n \
      --arg date "$date_val" \
      --arg cat "$aif_category" \
      --arg sum "$title" \
      --arg det "$body" \
      '{date:$date, category:$cat, summary:$sum, detail:$det, files:[], source:"sheal"}' \
      -c >> "$jsonl_file"
    synced=$((synced + 1))
  done

  [[ $synced -gt 0 ]] && echo "Synced $synced learnings from sheal to JSONL"
}

# Bidirectional dedup sync
# Usage: bridge_sync [target_dir]
bridge_sync() {
  local target="${1:-$TARGET_DIR}"

  echo "Running bidirectional learning sync..."
  bridge_jsonl_to_sheal "$target"
  bridge_sheal_to_jsonl "$target"
  echo "Learning bridge sync complete."
}

# Convert sheal retro files to vault entries
# Usage: bridge_retros_to_vault [target_dir]
bridge_retros_to_vault() {
  local target="${1:-$TARGET_DIR}"
  local retros_dir="$target/.sheal/retros"
  local vault_status="$target/vault/memory/status.md"

  [[ -d "$retros_dir" ]] || return 0
  [[ -d "$target/vault/memory" ]] || return 0

  # Get the 5 most recent retros
  local recent_retros
  recent_retros=$(find "$retros_dir" -name '*.md' -type f 2>/dev/null | sort | tail -5)
  [[ -z "$recent_retros" ]] && return 0

  # Append retro insights to vault status
  if [[ -f "$vault_status" ]]; then
    # Remove old retro section safely using awk (handles EOF correctly unlike sed range)
    local tmp_status
    tmp_status=$(mktemp "$(dirname "$vault_status")/.status.XXXXXX" 2>/dev/null || mktemp)
    # Trap to clean up temp file on failure
    trap 'rm -f "$tmp_status"' RETURN

    awk '
      /^## Recent Retro Insights$/ { skip=1; next }
      /^## / && skip { skip=0 }
      !skip { print }
    ' "$vault_status" > "$tmp_status"

    # Only replace if temp file is non-empty (safety check)
    if [[ -s "$tmp_status" ]] || [[ ! -s "$vault_status" ]]; then
      mv "$tmp_status" "$vault_status"
    else
      rm -f "$tmp_status"
      return 1
    fi

    # Append new section
    {
      echo ""
      echo "## Recent Retro Insights"
      echo ""
      echo "_(Auto-synced from sheal retros on $(date +%Y-%m-%d))_"
      echo ""
      while IFS= read -r retro_file; do
        [[ -f "$retro_file" ]] || continue
        local retro_name
        retro_name=$(basename "$retro_file" .md)
        printf '### %s\n' "${retro_name}"
        # Extract key learnings (first 10 lines of body after frontmatter, portable awk)
        awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print; if(++n>=10) exit}' "$retro_file"
        echo ""
      done <<< "$recent_retros"
    } >> "$vault_status"
    trap - RETURN
  fi

  echo "Synced retro insights to vault/memory/status.md"
}
