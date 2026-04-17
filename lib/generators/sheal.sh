#!/usr/bin/env bash
# Generator: Sheal Integration
# Generates .self-heal.json config and runs sheal init/rules when available.
#
# Security: Runs sheal CLI commands locally. No network access from this script.
# sheal itself may access npm registry during init — that's sheal's responsibility.
# All manifest values are passed through jq --arg for safe JSON construction (INV-1).

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

  # --- 3a: Generate .self-heal.json safely via jq (INV-1 compliant) ---
  local test_cmd lang fw env_json
  test_cmd=$(echo "$m" | jq -r '.commands.test // ""')
  lang=$(echo "$m" | jq -r '.stack.language // "unknown"')
  fw=$(echo "$m" | jq -r '.stack.framework // ""')
  env_json=$(echo "$m" | jq -c '[.env.variables[]?.name // empty]' 2>/dev/null || echo '[]')

  # Build tags array safely via jq
  local tags_json
  if [[ -n "$fw" && "$fw" != "none" && "$fw" != "null" ]]; then
    tags_json=$(jq -n --arg l "$lang" --arg f "$fw" '[$l, $f]')
  else
    tags_json=$(jq -n --arg l "$lang" '[$l]')
  fi

  # Build entire JSON via jq — no heredoc interpolation of untrusted data
  # Write atomically via temp file to prevent corrupt .self-heal.json on failure
  local config_file="$TARGET_DIR/.self-heal.json"
  local _sheal_tmp
  _sheal_tmp=$(mktemp "${TARGET_DIR}/.self-heal.json.XXXXXX" 2>/dev/null || mktemp)
  if jq -n \
    --arg test_cmd "$test_cmd" \
    --argjson env_vars "$env_json" \
    --arg ecosystem "$lang" \
    --argjson tags "$tags_json" \
    '{
      checkers: {
        tests: { command: $test_cmd },
        dependencies: { ecosystems: [$ecosystem] },
        environment: { requiredVars: $env_vars }
      },
      learnings: { tags: $tags }
    }' > "$_sheal_tmp" 2>/dev/null; then
    mv "$_sheal_tmp" "$config_file"
    log_ok "Generated .self-heal.json"
  else
    rm -f "$_sheal_tmp"
    log_warn ".self-heal.json generation failed — check manifest fields .commands.test, .stack.language (non-fatal)"
  fi

  # --- 3b: Run sheal init if .sheal/ doesn't exist ---
  local sheal_initialized
  sheal_initialized=$(echo "$m" | jq -r '.sheal.initialized // false')
  if [[ "$sheal_initialized" != "true" ]]; then
    if command -v sheal &>/dev/null; then
      local _init_err
      _init_err=$(mktemp "${_AIF_TMPDIR:-/tmp}/sheal-init.XXXXXX" 2>/dev/null || mktemp)
      if _aif_timeout 30 sheal init --project "$TARGET_DIR" 2>"$_init_err"; then
        log_ok "Initialized sheal in project"
      else
        log_warn "sheal init failed — run 'sheal init --project . --verbose' to debug (non-fatal)"
        [[ -s "$_init_err" ]] && log_warn "  $(head -3 "$_init_err")"
      fi
      rm -f "$_init_err"
    fi
  fi

  # --- 3c: Run sheal rules to inject learnings ---
  if command -v sheal &>/dev/null; then
    local _rules_err
    _rules_err=$(mktemp "${_AIF_TMPDIR:-/tmp}/sheal-rules.XXXXXX" 2>/dev/null || mktemp)
    if _aif_timeout 15 sheal rules --project "$TARGET_DIR" 2>"$_rules_err"; then
      log_ok "Injected sheal rules"
    else
      log_warn "sheal rules failed — run 'sheal rules --project . --verbose' to debug (non-fatal)"
      [[ -s "$_rules_err" ]] && log_warn "  $(head -3 "$_rules_err")"
    fi
    rm -f "$_rules_err"
  fi
}
