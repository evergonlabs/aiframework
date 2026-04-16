#!/usr/bin/env bash
# config.sh — Loads .aiframework/config.json and resolves tier/format settings.
# No yq dependency — uses jq for JSON parsing.

# Defaults
AIF_FORMATS="claude agents cursor"
AIF_TIER="auto"
AIF_VAULT=true
AIF_CUSTOM_INVARIANTS=""
AIF_EXCLUDE_DIRS=""
AIF_RESOLVED_TIER=""

# Load config from .aiframework/config.json if it exists
load_config() {
  local config_path="$TARGET_DIR/.aiframework/config.json"

  if [[ ! -f "$config_path" ]]; then
    # No config file — use defaults
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    log_warn "jq not found — cannot parse config.json, using defaults"
    return 0
  fi

  # Validate JSON
  if ! jq empty "$config_path" 2>/dev/null; then
    log_warn "Invalid JSON in config.json — using defaults"
    return 0
  fi

  # Read formats array → space-separated string
  local formats_json
  formats_json=$(jq -r '.formats // empty | join(" ")' "$config_path" 2>/dev/null)
  if [[ -n "$formats_json" ]]; then
    AIF_FORMATS="$formats_json"
  fi

  # Read tier
  local tier_json
  tier_json=$(jq -r '.tier // empty' "$config_path" 2>/dev/null)
  if [[ -n "$tier_json" ]]; then
    AIF_TIER="$tier_json"
  fi

  # Read vault toggle
  local vault_json
  vault_json=$(jq -r '.vault // empty' "$config_path" 2>/dev/null)
  if [[ "$vault_json" == "false" ]]; then
    AIF_VAULT=false
  fi

  # Read custom invariants
  local custom_inv
  custom_inv=$(jq -r '.custom_invariants // empty | join("\n")' "$config_path" 2>/dev/null)
  if [[ -n "$custom_inv" ]]; then
    AIF_CUSTOM_INVARIANTS="$custom_inv"
  fi

  # Read exclude dirs
  local excludes
  excludes=$(jq -r '.exclude_dirs // empty | join(" ")' "$config_path" 2>/dev/null)
  if [[ -n "$excludes" ]]; then
    AIF_EXCLUDE_DIRS="$excludes"
  fi

  log_info "Loaded config from .aiframework/config.json"
}

# Resolve tier: config override > --tier flag > auto-detect from complexity
resolve_tier() {
  local manifest="$MANIFEST"
  local cli_tier="${1:-}"

  # Priority: CLI flag > config > default (full — backward compat)
  if [[ -n "$cli_tier" && "$cli_tier" != "auto" ]]; then
    AIF_RESOLVED_TIER="$cli_tier"
  elif [[ "$AIF_TIER" != "auto" ]]; then
    AIF_RESOLVED_TIER="$AIF_TIER"
  else
    # Default: "full" for backward compatibility (all generators run)
    # Users can set tier in config to restrict output
    AIF_RESOLVED_TIER="full"
  fi
}

# Check if a format is enabled
format_enabled() {
  local fmt="$1"
  echo "$AIF_FORMATS" | grep -qw "$fmt"
}

# Check if current tier includes a feature
tier_includes() {
  local feature="$1"
  case "$feature" in
    claude|agents)
      return 0  # Always included
      ;;
    cursor|hooks|ci|skills|rules)
      [[ "$AIF_RESOLVED_TIER" == "standard" || "$AIF_RESOLVED_TIER" == "full" || "$AIF_RESOLVED_TIER" == "enterprise" ]]
      ;;
    docs|tracking|vault-memory)
      # Docs, tracking, and vault memory available at standard+
      [[ "$AIF_RESOLVED_TIER" == "standard" || "$AIF_RESOLVED_TIER" == "full" || "$AIF_RESOLVED_TIER" == "enterprise" ]]
      ;;
    vault-full|specialists)
      [[ "$AIF_RESOLVED_TIER" == "full" || "$AIF_RESOLVED_TIER" == "enterprise" ]]
      ;;
    *)
      return 1
      ;;
  esac
}
