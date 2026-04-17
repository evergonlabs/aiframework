#!/usr/bin/env bash
# Generator: Sheal Integration
# Generates .self-heal.json config and runs sheal init/rules when available.
#
# Security: Runs sheal CLI commands locally. No network access from this script.
# sheal itself may access npm registry during init — that's sheal's responsibility.

generate_sheal() {
  local m="$MANIFEST"

  # Only run when sheal is installed
  local sheal_installed
  sheal_installed=$(echo "$m" | jq -r '.sheal.installed // false')
  if [[ "$sheal_installed" != "true" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would generate .self-heal.json and run sheal init"
    return 0
  fi

  # --- 3a: Generate .self-heal.json ---
  local test_cmd lang
  test_cmd=$(echo "$m" | jq -r '.commands.test // ""')
  lang=$(echo "$m" | jq -r '.stack.language // "unknown"')
  local fw
  fw=$(echo "$m" | jq -r '.stack.framework // ""')

  # Build tags array
  local tags="[\"${lang}\""
  if [[ -n "$fw" && "$fw" != "none" && "$fw" != "null" ]]; then
    tags+=",\"${fw}\""
  fi
  tags+="]"

  # Build required env vars array
  local env_json="[]"
  env_json=$(echo "$m" | jq '[.env.variables[]?.name // empty]' 2>/dev/null || echo "[]")

  local config_file="$TARGET_DIR/.self-heal.json"
  cat > "$config_file" << SHEALCFG
{
  "checkers": {
    "tests": {
      "command": "${test_cmd}"
    },
    "dependencies": {
      "ecosystems": ["${lang}"]
    },
    "environment": {
      "requiredVars": $(echo "$env_json" | jq -c '.')
    }
  },
  "learnings": {
    "tags": ${tags}
  }
}
SHEALCFG
  log_ok "Generated .self-heal.json"

  # --- 3b: Run sheal init if .sheal/ doesn't exist ---
  local sheal_initialized
  sheal_initialized=$(echo "$m" | jq -r '.sheal.initialized // false')
  if [[ "$sheal_initialized" != "true" ]]; then
    if command -v sheal &>/dev/null; then
      if sheal init --project "$TARGET_DIR" 2>/dev/null; then
        log_ok "Initialized sheal in project"
      else
        log_warn "sheal init failed (non-fatal)"
      fi
    fi
  fi

  # --- 3c: Run sheal rules to inject learnings ---
  if command -v sheal &>/dev/null; then
    sheal rules --project "$TARGET_DIR" 2>/dev/null && log_ok "Injected sheal rules" || true
  fi

  # --- Bridge existing learnings ---
  if [[ -f "$LIB_DIR/bridge/sheal_learnings.sh" ]]; then
    source "$LIB_DIR/bridge/sheal_learnings.sh"
    bridge_jsonl_to_sheal "$TARGET_DIR" 2>/dev/null || true
  fi
}
