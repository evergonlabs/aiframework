#!/usr/bin/env bash
# Validator: Consistency
# Cross-checks that all generated files agree with each other and the manifest

validate_consistency() {
  local m="$MANIFEST"
  local short
  short=$(echo "$m" | jq -r '.identity.short_name')

  # --- E1: CLAUDE.md Stage 4 commands match pre-push hook ---
  if [[ -f "$TARGET_DIR/CLAUDE.md" && -f "$TARGET_DIR/.githooks/pre-push" ]]; then
    local lint_cmd
    lint_cmd=$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')

    if [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then
      if grep -Fq "$lint_cmd" "$TARGET_DIR/.githooks/pre-push" 2>/dev/null; then
        report_row "Cmd sync: pre-push" "PASS" "Commands match"
      else
        # Also check for the core command (e.g., "shellcheck" from "find ... | xargs shellcheck")
        local lint_core
        lint_core=$(echo "$lint_cmd" | grep -oE '[a-z]+$' || true)
        if [[ -n "$lint_core" ]] && grep -Fq "$lint_core" "$TARGET_DIR/.githooks/pre-push" 2>/dev/null; then
          report_row "Cmd sync: pre-push" "PASS" "Core lint tool matches"
        else
          report_row "Cmd sync: pre-push" "FAIL" "Lint cmd mismatch"
        fi
      fi
    else
      report_row "Cmd sync: pre-push" "SKIP" "No lint configured"
    fi
  else
    report_row "Cmd sync: pre-push" "SKIP" "Files missing"
  fi

  # --- E2: CLAUDE.md commands match ship skill ---
  if [[ -f "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md" ]]; then
    local build_cmd
    build_cmd=$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')

    if [[ "$build_cmd" != "NOT_CONFIGURED" ]]; then
      if grep -q "$build_cmd" "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md" 2>/dev/null; then
        report_row "Cmd sync: ship skill" "PASS" "Commands match"
      else
        report_row "Cmd sync: ship skill" "FAIL" "Build cmd mismatch"
      fi
    else
      report_row "Cmd sync: ship skill" "SKIP" "No build configured"
    fi
  else
    report_row "Cmd sync: ship skill" "SKIP" "Skill missing"
  fi

  # --- E6: PROJECT_SHORT_NAME consistency ---
  local name_in_skills=true
  if [[ -d "$TARGET_DIR/.claude/skills/${short}-review" && -d "$TARGET_DIR/.claude/skills/${short}-ship" ]]; then
    report_row "Short name consistency" "PASS" "${short} across all files"
  else
    report_row "Short name consistency" "FAIL" "Skill dirs don't match"
  fi

  # --- E7: SETUP-DEV.md commands match CLAUDE.md ---
  if [[ -f "$TARGET_DIR/SETUP-DEV.md" && -f "$TARGET_DIR/CLAUDE.md" ]]; then
    local install_cmd
    install_cmd=$(echo "$m" | jq -r '.commands.install // "NOT_CONFIGURED"')

    if [[ "$install_cmd" != "NOT_CONFIGURED" ]]; then
      if grep -q "$install_cmd" "$TARGET_DIR/SETUP-DEV.md" 2>/dev/null; then
        report_row "Cmd sync: SETUP-DEV" "PASS" "Install cmd matches"
      else
        report_row "Cmd sync: SETUP-DEV" "FAIL" "Install cmd mismatch"
      fi
    else
      report_row "Cmd sync: SETUP-DEV" "SKIP" "No install configured"
    fi
  else
    report_row "Cmd sync: SETUP-DEV" "SKIP" "Files missing"
  fi

  # --- E8: Doc-sync matrix in CLAUDE.md (or rules/pipeline.md) matches doc-sync in ship skill ---
  if [[ -f "$TARGET_DIR/CLAUDE.md" && -f "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md" ]]; then
    local has_docsync_claude=false
    local has_docsync_ship=false
    grep -q 'Doc.Sync\|doc.sync\|Doc Sync' "$TARGET_DIR/CLAUDE.md" 2>/dev/null && has_docsync_claude=true
    # Also check .claude/rules/pipeline.md (extended rules for complex projects)
    if [[ "$has_docsync_claude" == false && -f "$TARGET_DIR/.claude/rules/pipeline.md" ]]; then
      grep -q 'Doc.Sync\|doc.sync\|Doc Sync' "$TARGET_DIR/.claude/rules/pipeline.md" 2>/dev/null && has_docsync_claude=true
    fi
    grep -q 'Doc Sync\|doc.sync\|documentation' "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md" 2>/dev/null && has_docsync_ship=true

    if $has_docsync_claude && $has_docsync_ship; then
      report_row "Doc-sync: CLAUDE↔ship" "PASS" "Both reference doc sync"
    elif ! $has_docsync_claude && ! $has_docsync_ship; then
      report_row "Doc-sync: CLAUDE↔ship" "SKIP" "No doc-sync in either"
    else
      report_row "Doc-sync: CLAUDE↔ship" "WARN" "Doc-sync not in both files"
    fi
  else
    report_row "Doc-sync: CLAUDE↔ship" "SKIP" "Files missing"
  fi

  # --- E9/E10: No unresolved {{}} placeholders ---
  local placeholder_files=("CLAUDE.md" ".githooks/pre-push" ".githooks/pre-commit" "SETUP-DEV.md" "CONTRIBUTING.md")

  for f in "${placeholder_files[@]}"; do
    if [[ -f "$TARGET_DIR/$f" ]]; then
      local placeholders
      placeholders=$({ grep '{{' "$TARGET_DIR/$f" 2>/dev/null | grep -v '\${{' | wc -l | tr -d '[:space:]'; } || echo "0")
      if [[ "$placeholders" -gt 0 ]]; then
        report_row "Placeholders: $f" "FAIL" "$placeholders {{}} found"
      fi
    fi
  done

  # Check CI too
  if [[ -f "$TARGET_DIR/.github/workflows/ci.yml" ]]; then
    local ci_placeholders
    ci_placeholders=$({ grep '{{' "$TARGET_DIR/.github/workflows/ci.yml" 2>/dev/null | grep -v '\${{' | wc -l | tr -d '[:space:]'; } || echo "0")
    if [[ "$ci_placeholders" -gt 0 ]]; then
      report_row "Placeholders: ci.yml" "FAIL" "$ci_placeholders {{}} found"
    else
      report_row "No placeholders" "PASS" "0 {{}} in generated files"
    fi
  else
    # Check other files for placeholders
    local total_placeholders=0
    for f in "${placeholder_files[@]}"; do
      if [[ -f "$TARGET_DIR/$f" ]]; then
        local count
        count=$({ grep '{{' "$TARGET_DIR/$f" 2>/dev/null | grep -v '\${{' | wc -l | tr -d '[:space:]'; } || echo "0")
        total_placeholders=$((total_placeholders + count))
      fi
    done
    if [[ "$total_placeholders" -eq 0 ]]; then
      report_row "No placeholders" "PASS" "0 {{}} in generated files"
    fi
  fi

  # --- E11: No credentials in generated files ---
  local cred_check
  cred_check=$(grep -rl 'ghp_\|sk-ant\|sk-proj' "$TARGET_DIR/CLAUDE.md" "$TARGET_DIR/SETUP-DEV.md" 2>/dev/null | wc -l | tr -d '[:space:]' || echo "0")
  if [[ "$cred_check" -gt 0 ]]; then
    report_row "No credentials leak" "FAIL" "Tokens found in files"
  else
    report_row "No credentials leak" "PASS" "Clean"
  fi

  # --- E3: Stage 4 commands match CI workflow ---
  if [[ -f "$TARGET_DIR/.github/workflows/ci.yml" ]]; then
    local ci_file="$TARGET_DIR/.github/workflows/ci.yml"
    local ci_match=true
    local ci_details=""

    local lint_cmd
    lint_cmd=$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')
    if [[ "$lint_cmd" != "NOT_CONFIGURED" ]]; then
      local lint_core
      lint_core=$(echo "$lint_cmd" | grep -oE '[a-z]+$' || true)
      if ! grep -Fq "$lint_cmd" "$ci_file" 2>/dev/null && ! { [[ -n "$lint_core" ]] && grep -Fq "$lint_core" "$ci_file" 2>/dev/null; }; then
        ci_match=false
        ci_details="lint cmd missing from CI"
      fi
    fi

    local test_cmd
    test_cmd=$(echo "$m" | jq -r '.commands.test // "NOT_CONFIGURED"')
    if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then
      if ! grep -Fq "$test_cmd" "$ci_file" 2>/dev/null; then
        ci_match=false
        ci_details="${ci_details:+$ci_details; }test cmd missing from CI"
      fi
    fi

    local build_cmd
    build_cmd=$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')
    if [[ "$build_cmd" != "NOT_CONFIGURED" ]]; then
      if ! grep -Fq "$build_cmd" "$ci_file" 2>/dev/null; then
        ci_match=false
        ci_details="${ci_details:+$ci_details; }build cmd missing from CI"
      fi
    fi

    if $ci_match; then
      report_row "Cmd sync: CI workflow" "PASS" "Commands match ci.yml"
    else
      report_row "Cmd sync: CI workflow" "FAIL" "$ci_details"
    fi
  else
    report_row "Cmd sync: CI workflow" "SKIP" "No ci.yml found"
  fi

  # --- E4: Invariants in CLAUDE.md match review skill ---
  if [[ -f "$TARGET_DIR/CLAUDE.md" && -f "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md" ]]; then
    local inv_in_claude
    inv_in_claude=$(grep -cE '(### INV-|\*\*INV-)' "$TARGET_DIR/CLAUDE.md" 2>/dev/null | head -1 | tr -d '[:space:]' || echo "0")
    local inv_in_review
    inv_in_review=$(grep -c 'INV-' "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md" 2>/dev/null | head -1 | tr -d '[:space:]' || echo "0")

    if [[ "$inv_in_claude" -eq 0 ]]; then
      report_row "Invariants: CLAUDE↔review" "SKIP" "No invariants in CLAUDE.md"
    elif [[ "$inv_in_claude" -le "$inv_in_review" ]]; then
      report_row "Invariants: CLAUDE↔review" "PASS" "$inv_in_claude INV sections match"
    else
      report_row "Invariants: CLAUDE↔review" "FAIL" "CLAUDE=$inv_in_claude vs review=$inv_in_review"
    fi
  else
    report_row "Invariants: CLAUDE↔review" "SKIP" "Files missing"
  fi

  # --- E5: Invariants match pre-push invariant checks ---
  if [[ -f "$TARGET_DIR/CLAUDE.md" && -f "$TARGET_DIR/.githooks/pre-push" ]]; then
    local inv_in_claude
    inv_in_claude=$(grep -cE '(### INV-|\*\*INV-)' "$TARGET_DIR/CLAUDE.md" 2>/dev/null | head -1 | tr -d '[:space:]' || echo "0")
    local inv_in_prepush
    inv_in_prepush=$(grep -cE '# INV[-:]' "$TARGET_DIR/.githooks/pre-push" 2>/dev/null || true)
    inv_in_prepush=$(echo "$inv_in_prepush" | head -1 | tr -d '[:space:]')
    [[ -z "$inv_in_prepush" ]] && inv_in_prepush=0

    if [[ "$inv_in_claude" -eq 0 ]]; then
      report_row "Invariants: CLAUDE↔pre-push" "SKIP" "No invariants in CLAUDE.md"
    elif [[ "$inv_in_claude" -le "$inv_in_prepush" ]]; then
      report_row "Invariants: CLAUDE↔pre-push" "PASS" "$inv_in_claude INV checks in hook"
    else
      # Not a hard fail — hooks may only enforce a subset of invariants
      report_row "Invariants: CLAUDE↔pre-push" "WARN" "CLAUDE=$inv_in_claude, hook=$inv_in_prepush (subset OK)"
    fi
  else
    report_row "Invariants: CLAUDE↔pre-push" "SKIP" "Files missing"
  fi

  # --- E12: DEV_PORT matches .env.example ---
  if [[ -f "$TARGET_DIR/CLAUDE.md" && -f "$TARGET_DIR/.env.example" ]]; then
    local manifest_port
    manifest_port=$(echo "$m" | jq -r '.env.dev_port // empty')
    if [[ -n "$manifest_port" ]]; then
      local claude_port
      claude_port=$(grep -oE 'DEV_PORT[^0-9]*([0-9]+)' "$TARGET_DIR/CLAUDE.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
      local env_port
      env_port=$(grep -oE 'DEV_PORT[^0-9]*([0-9]+)' "$TARGET_DIR/.env.example" 2>/dev/null | grep -oE '[0-9]+' | head -1)

      if [[ -n "$claude_port" && -n "$env_port" ]]; then
        if [[ "$claude_port" == "$env_port" ]]; then
          report_row "DEV_PORT sync" "PASS" "Port $claude_port matches"
        else
          report_row "DEV_PORT sync" "FAIL" "CLAUDE=$claude_port vs .env=$env_port"
        fi
      else
        report_row "DEV_PORT sync" "SKIP" "Port not found in both files"
      fi
    else
      report_row "DEV_PORT sync" "SKIP" "No dev_port in manifest"
    fi
  else
    report_row "DEV_PORT sync" "SKIP" "Files missing"
  fi

  # --- E13: Env var names match actual files (stronger check) ---
  local env_count
  env_count=$(echo "$m" | jq '.env.variables | length' 2>/dev/null || echo "0")
  if [[ "$env_count" -gt 0 ]]; then
    local env_missing=0
    local env_checked=0
    local missing_vars=""

    for i in $(seq 0 $((env_count - 1))); do
      local var_name
      var_name=$(echo "$m" | jq -r ".env.variables[$i].name // empty" 2>/dev/null)
      [[ -z "$var_name" ]] && continue
      env_checked=$((env_checked + 1))

      local found_in_file=false
      # Check .env.example
      if [[ -f "$TARGET_DIR/.env.example" ]] && grep -q "$var_name" "$TARGET_DIR/.env.example" 2>/dev/null; then
        found_in_file=true
      fi
      # Check CLAUDE.md
      if [[ -f "$TARGET_DIR/CLAUDE.md" ]] && grep -q "$var_name" "$TARGET_DIR/CLAUDE.md" 2>/dev/null; then
        found_in_file=true
      fi
      # Check Dockerfile
      if [[ -f "$TARGET_DIR/Dockerfile" ]] && grep -q "$var_name" "$TARGET_DIR/Dockerfile" 2>/dev/null; then
        found_in_file=true
      fi
      # Check CI workflow
      if [[ -f "$TARGET_DIR/.github/workflows/ci.yml" ]] && grep -q "$var_name" "$TARGET_DIR/.github/workflows/ci.yml" 2>/dev/null; then
        found_in_file=true
      fi
      # Check docker-compose
      if [[ -f "$TARGET_DIR/docker-compose.yml" ]] && grep -q "$var_name" "$TARGET_DIR/docker-compose.yml" 2>/dev/null; then
        found_in_file=true
      fi

      if ! $found_in_file; then
        env_missing=$((env_missing + 1))
        missing_vars="${missing_vars:+$missing_vars, }$var_name"
      fi
    done

    if [[ "$env_missing" -eq 0 ]]; then
      report_row "Env vars in sources" "PASS" "$env_checked vars found in files"
    else
      report_row "Env vars in sources" "FAIL" "Missing: $missing_vars"
    fi
  else
    report_row "Env vars in sources" "SKIP" "No env vars discovered"
  fi

  # --- E14: Component counts match actual ---
  local has_counts
  has_counts=$(echo "$m" | jq 'has("component_counts")' 2>/dev/null || echo "false")
  if [[ "$has_counts" == "true" ]]; then
    local count_keys
    count_keys=$(echo "$m" | jq -r '.component_counts | keys[]' 2>/dev/null)

    for key in $count_keys; do
      local expected_count
      expected_count=$(echo "$m" | jq -r ".component_counts[\"$key\"].count // empty" 2>/dev/null)
      local count_pattern
      count_pattern=$(echo "$m" | jq -r ".component_counts[\"$key\"].pattern // empty" 2>/dev/null)

      if [[ -n "$expected_count" && -n "$count_pattern" ]]; then
        local actual_count
        actual_count=$(find "$TARGET_DIR" -path "$TARGET_DIR/$count_pattern" 2>/dev/null | wc -l | tr -d '[:space:]')
        if [[ "$actual_count" -eq "$expected_count" ]]; then
          report_row "Count: $key" "PASS" "$actual_count matches"
        else
          report_row "Count: $key" "FAIL" "Expected $expected_count, found $actual_count"
        fi
      fi
    done
  else
    report_row "Component counts" "SKIP" "Not in manifest"
  fi

  # --- E15: Test file count matches actual ---
  local test_file_count
  test_file_count=$(echo "$m" | jq -r '.quality.test_file_count // empty' 2>/dev/null)
  if [[ -n "$test_file_count" && "$test_file_count" != "null" ]]; then
    local test_pattern
    test_pattern=$(echo "$m" | jq -r '.quality.test_pattern // empty' 2>/dev/null)

    if [[ -n "$test_pattern" && "$test_pattern" != "null" ]]; then
      local actual_test_count
      actual_test_count=$(find "$TARGET_DIR" -name "$test_pattern" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | wc -l | tr -d '[:space:]')
      if [[ "$actual_test_count" -eq "$test_file_count" ]]; then
        report_row "Test file count" "PASS" "$actual_test_count matches"
      else
        report_row "Test file count" "WARN" "Manifest=$test_file_count, actual=$actual_test_count"
      fi
    else
      report_row "Test file count" "SKIP" "No test pattern in manifest"
    fi
  else
    report_row "Test file count" "SKIP" "Not in manifest"
  fi
}
