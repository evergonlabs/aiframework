#!/usr/bin/env bash
# Scanner: Sheal Integration
# Detects sheal (runtime session intelligence) installation and state.
#
# Security: This scanner only reads local files and runs `sheal --version`.
# No web requests. Version output is sanitized.

scan_sheal() {
  local sheal_installed=false
  local sheal_version="unknown"
  local sheal_initialized=false
  local project_learnings=0
  local global_learnings=0
  local has_rules_block=false
  local has_retro_skill=false

  # 1. Is sheal installed globally?
  if command -v sheal &>/dev/null; then
    sheal_installed=true
    # Use timeout to prevent hanging; sanitize version output
    local _raw_ver
    _raw_ver=$(_aif_timeout 5 sheal --version 2>/dev/null | head -1 | tr -dc '0-9.' || true)
    if [[ -n "$_raw_ver" ]]; then
      sheal_version="$_raw_ver"
    fi
  fi

  # 2. Is sheal initialized in this project? (check for meaningful content, not just dir)
  if [[ -d "$TARGET_DIR/.sheal" ]] && [[ -n "$(ls -A "$TARGET_DIR/.sheal" 2>/dev/null)" ]]; then
    sheal_initialized=true
  fi

  # 3. Project-local learnings count
  if [[ -d "$TARGET_DIR/.sheal/learnings" ]]; then
    project_learnings=$(find "$TARGET_DIR/.sheal/learnings" -name 'LEARN-*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
    project_learnings="${project_learnings:-0}"
  fi

  # 4. Global learnings count
  if [[ -d "$HOME/.sheal/learnings" ]]; then
    global_learnings=$(find "$HOME/.sheal/learnings" -name 'LEARN-*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
    global_learnings="${global_learnings:-0}"
  fi

  # 5. Rules block already injected? (check each file independently)
  if [[ -f "$TARGET_DIR/AGENTS.md" ]] && grep -qF 'SHEAL RULES' "$TARGET_DIR/AGENTS.md" 2>/dev/null; then
    has_rules_block=true
  elif [[ -f "$TARGET_DIR/CLAUDE.md" ]] && grep -qF 'SHEAL RULES' "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
    has_rules_block=true
  fi

  # 6. Retro skill present? (correct path: sheal-retro, not retro)
  if [[ -f "$TARGET_DIR/.claude/skills/sheal-retro/SKILL.md" ]]; then
    has_retro_skill=true
  fi

  # Store in manifest (preserve MANIFEST on jq failure — don't clobber with empty)
  local _sheal_manifest
  _sheal_manifest=$(echo "$MANIFEST" | jq \
    --argjson installed "$sheal_installed" \
    --arg version "$sheal_version" \
    --argjson initialized "$sheal_initialized" \
    --argjson proj_learn "$project_learnings" \
    --argjson glob_learn "$global_learnings" \
    --argjson rules "$has_rules_block" \
    --argjson retro "$has_retro_skill" \
    '. + {
      "sheal": {
        "installed": $installed,
        "version": $version,
        "initialized": $initialized,
        "project_learnings_count": $proj_learn,
        "global_learnings_count": $glob_learn,
        "has_rules_block": $rules,
        "has_retro_skill": $retro
      }
    }' 2>/dev/null) && MANIFEST="$_sheal_manifest" || true

  if [[ "$sheal_installed" == true ]]; then
    log_ok "Sheal detected v${sheal_version} (project learnings: ${project_learnings}, global: ${global_learnings})"
  fi
}
