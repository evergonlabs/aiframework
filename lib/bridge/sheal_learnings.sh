#!/usr/bin/env bash
# Bridge: Sheal ↔ aiframework learning sync
# Bidirectional conversion between JSONL (aiframework) and markdown (sheal)
#
# Security: Only reads/writes local files. No network access.

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

  local synced=0

  while IFS= read -r jsonl_file; do
    [[ -z "$jsonl_file" ]] && continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue

      local summary date category detail
      summary=$(echo "$line" | jq -r '.summary // empty' 2>/dev/null)
      [[ -z "$summary" ]] && continue

      date=$(echo "$line" | jq -r '.date // empty' 2>/dev/null)
      category=$(echo "$line" | jq -r '.category // "pattern"' 2>/dev/null)
      detail=$(echo "$line" | jq -r '.detail // ""' 2>/dev/null)

      # Check for duplicates by title match
      if grep -rql "$summary" "$sheal_dir" 2>/dev/null; then
        continue
      fi

      # Map aiframework categories to sheal categories
      local sheal_category
      case "$category" in
        bug)      sheal_category="failure-loop" ;;
        gotcha)   sheal_category="missing-context" ;;
        pattern)  sheal_category="workflow" ;;
        decision) sheal_category="workflow" ;;
        *)        sheal_category="workflow" ;;
      esac

      # Generate slug from summary
      local slug
      slug=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | cut -c1-40)

      max_num=$((max_num + 1))
      local num
      num=$(printf "%03d" "$max_num")
      local out_file="$sheal_dir/LEARN-${num}-${slug}.md"

      cat > "$out_file" << LEARNMD
---
title: "${summary}"
category: ${sheal_category}
severity: medium
status: active
date: ${date}
source: aiframework
---

${detail:-$summary}
LEARNMD

      synced=$((synced + 1))
    done < "$jsonl_file"
  done <<< "$jsonl_files"

  [[ $synced -gt 0 ]] && echo "Synced $synced learnings from JSONL → sheal"
}

# Convert sheal markdown learnings → aiframework JSONL
# Usage: bridge_sheal_to_jsonl [target_dir]
bridge_sheal_to_jsonl() {
  local target="${1:-$TARGET_DIR}"
  local sheal_dir="$target/.sheal/learnings"
  local jsonl_dir="$target/tools/learnings"

  [[ -d "$sheal_dir" ]] || return 0

  # Determine the JSONL file to append to
  local short_name
  short_name=$(jq -r '.identity.short_name // "project"' "$target/.aiframework/manifest.json" 2>/dev/null || echo "project")
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
            title:*)    title=$(echo "$fmline" | sed 's/^title:[[:space:]]*//' | tr -d '"') ;;
            category:*) category="${fmline#category:}"; category="${category# }" ;;
            date:*)     date_val="${fmline#date:}"; date_val="${date_val# }" ;;
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

    # Check for duplicates by summary match in JSONL
    if grep -Fq "$title" "$jsonl_file" 2>/dev/null; then
      continue
    fi

    # Reverse category mapping
    local aif_category
    case "$category" in
      failure-loop)    aif_category="bug" ;;
      missing-context) aif_category="gotcha" ;;
      workflow)        aif_category="pattern" ;;
      *)               aif_category="pattern" ;;
    esac

    [[ -z "$date_val" ]] && date_val=$(date +%Y-%m-%d)

    # Clean body for JSON
    body=$(echo "$body" | tr -d '\n' | sed 's/"/\\"/g' | sed 's/[[:space:]]*$//')

    echo "{\"date\":\"${date_val}\",\"category\":\"${aif_category}\",\"summary\":\"${title}\",\"detail\":\"${body}\",\"files\":[],\"source\":\"sheal\"}" >> "$jsonl_file"
    synced=$((synced + 1))
  done

  [[ $synced -gt 0 ]] && echo "Synced $synced learnings from sheal → JSONL"
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
    # Remove old retro section if present
    local tmp_status
    tmp_status=$(mktemp)
    sed '/^## Recent Retro Insights$/,/^## /{ /^## Recent Retro Insights$/d; /^## /!d; }' "$vault_status" > "$tmp_status"
    mv "$tmp_status" "$vault_status"

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
        echo "### ${retro_name}"
        # Extract key learnings (first 10 lines of body after frontmatter)
        sed -n '/^---$/,/^---$/!p' "$retro_file" | head -10
        echo ""
      done <<< "$recent_retros"
    } >> "$vault_status"
  fi

  echo "Synced retro insights to vault/memory/status.md"
}
