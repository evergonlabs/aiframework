#!/usr/bin/env bash
# lib/knowledge/store.sh — Cross-repo learning system
# Tracks repo profiles, scanner misses, and patterns across all analyzed repos.
# Data stored at ~/.aiframework/knowledge/
# All JSON construction uses jq --arg for safe escaping (INV-1 compliant).

# Initialize knowledge store at ~/.aiframework/knowledge/
knowledge_init() {
  local dir="${HOME}/.aiframework/knowledge"
  mkdir -p "$dir"
  # Create files if they don't exist
  [[ -f "$dir/repo_profiles.jsonl" ]] || touch "$dir/repo_profiles.jsonl"
  [[ -f "$dir/scanner_misses.jsonl" ]] || touch "$dir/scanner_misses.jsonl"
  [[ -f "$dir/patterns.jsonl" ]] || touch "$dir/patterns.jsonl"
  echo "$dir"
}

# Record a repo profile after discover
knowledge_record_profile() {
  local manifest="$1"
  local dir
  dir=$(knowledge_init)
  local lang fw arch files domains ts
  lang=$(echo "$manifest" | jq -r '.stack.language')
  fw=$(echo "$manifest" | jq -r '.stack.framework // "none"')
  arch=$(echo "$manifest" | jq -r '.archetype.type // "unknown"')
  files=$(echo "$manifest" | jq -r '.structure.total_files // 0')
  domains=$(echo "$manifest" | jq -c '[.domain.detected_domains[]?.name]')
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Build JSON safely via jq --arg (INV-1 compliant)
  jq -n -c \
    --arg ts "$ts" \
    --arg lang "$lang" \
    --arg fw "$fw" \
    --arg arch "$arch" \
    --argjson files "$files" \
    --argjson domains "$domains" \
    '{timestamp:$ts, language:$lang, framework:$fw, archetype:$arch, total_files:$files, domains:$domains}' \
    >> "$dir/repo_profiles.jsonl" 2>/dev/null || true
}

# Record what enhance found that scanners missed
knowledge_record_miss() {
  local gap_id="$1"
  local description="$2"
  local dir
  dir=$(knowledge_init)
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Build JSON safely via jq --arg (INV-1 compliant)
  jq -n -c \
    --arg ts "$ts" \
    --arg gap "$gap_id" \
    --arg desc "$description" \
    '{timestamp:$ts, gap_id:$gap, description:$desc}' \
    >> "$dir/scanner_misses.jsonl" 2>/dev/null || true
}

# Show stats across all analyzed repos
knowledge_stats() {
  local dir="${HOME}/.aiframework/knowledge"
  [[ -d "$dir" ]] || { echo "No knowledge store found."; return; }

  local total
  total=$(wc -l < "$dir/repo_profiles.jsonl" 2>/dev/null || echo "0")
  # Trim whitespace from wc output
  total=$(echo "$total" | tr -d ' ')
  echo "Repos analyzed: $total"

  if [[ "$total" -gt 0 ]]; then
    echo ""
    echo "Languages:"
    jq -r '.language' "$dir/repo_profiles.jsonl" | sort | uniq -c | sort -rn | head -10
    echo ""
    echo "Archetypes:"
    jq -r '.archetype' "$dir/repo_profiles.jsonl" | sort | uniq -c | sort -rn | head -10
    echo ""
    local misses
    misses=$(wc -l < "$dir/scanner_misses.jsonl" 2>/dev/null || echo "0")
    misses=$(echo "$misses" | tr -d ' ')
    echo "Scanner misses recorded: $misses"
  fi
}
