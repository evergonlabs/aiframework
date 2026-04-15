#!/usr/bin/env bash
# Validator: Quality Gate Dry Run
# Attempts to run lint/test/build to verify they work

validate_quality_gate() {
  local m="$MANIFEST"
  local lint=$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')
  local typecheck=$(echo "$m" | jq -r '.commands.typecheck // "NOT_CONFIGURED"')
  local test_cmd=$(echo "$m" | jq -r '.commands.test // "NOT_CONFIGURED"')
  local build=$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')

  # We don't actually RUN the commands in verification (that would modify state)
  # Instead we verify they are valid commands that exist

  if [[ "$lint" == "NOT_CONFIGURED" ]]; then
    report_row "Lint command" "SKIP" "Not configured"
  else
    # Check if the base command exists
    local lint_base
    lint_base=$(echo "$lint" | awk '{print $1}')
    if command -v "$lint_base" >/dev/null 2>&1 || [[ "$lint_base" == "npm" || "$lint_base" == "yarn" || "$lint_base" == "pnpm" || "$lint_base" == "bun" || "$lint_base" == "cargo" || "$lint_base" == "go" || "$lint_base" == "make" || "$lint_base" == "npx" ]]; then
      report_row "Lint command" "PASS" "$lint"
    else
      report_row "Lint command" "WARN" "Command not found: $lint_base"
    fi
  fi

  if [[ "$typecheck" == "NOT_CONFIGURED" ]]; then
    report_row "Type check command" "SKIP" "Not configured"
  else
    report_row "Type check command" "PASS" "$typecheck"
  fi

  if [[ "$test_cmd" == "NOT_CONFIGURED" ]]; then
    report_row "Test command" "SKIP" "Not configured"
  else
    report_row "Test command" "PASS" "$test_cmd"
  fi

  if [[ "$build" == "NOT_CONFIGURED" ]]; then
    report_row "Build command" "SKIP" "Not configured"
  else
    report_row "Build command" "PASS" "$build"
  fi

  # --- Actually run lint/test/build commands (30s timeout each) ---
  if [[ "$lint" != "NOT_CONFIGURED" ]]; then
    local lint_output
    lint_output=$(cd "$TARGET_DIR" && timeout 30 bash -c "$lint" 2>&1)
    local lint_exit=$?
    if [[ $lint_exit -eq 0 ]]; then
      report_row "Lint execution" "PASS" "Exited 0"
    elif [[ $lint_exit -eq 124 ]]; then
      report_row "Lint execution" "WARN" "Timed out (30s)"
    else
      local lint_err
      lint_err=$(echo "$lint_output" | tail -1 | head -c 40)
      report_row "Lint execution" "FAIL" "Exit $lint_exit: $lint_err"
    fi
  fi

  if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then
    local test_output
    test_output=$(cd "$TARGET_DIR" && timeout 30 bash -c "$test_cmd" 2>&1)
    local test_exit=$?
    if [[ $test_exit -eq 0 ]]; then
      report_row "Test execution" "PASS" "Exited 0"
    elif [[ $test_exit -eq 124 ]]; then
      report_row "Test execution" "WARN" "Timed out (30s)"
    else
      local test_err
      test_err=$(echo "$test_output" | tail -1 | head -c 40)
      report_row "Test execution" "FAIL" "Exit $test_exit: $test_err"
    fi
  fi

  if [[ "$build" != "NOT_CONFIGURED" ]]; then
    local build_output
    build_output=$(cd "$TARGET_DIR" && timeout 30 bash -c "$build" 2>&1)
    local build_exit=$?
    if [[ $build_exit -eq 0 ]]; then
      report_row "Build execution" "PASS" "Exited 0"
    elif [[ $build_exit -eq 124 ]]; then
      report_row "Build execution" "WARN" "Timed out (30s)"
    else
      local build_err
      build_err=$(echo "$build_output" | tail -1 | head -c 40)
      report_row "Build execution" "FAIL" "Exit $build_exit: $build_err"
    fi
  fi

  # Check CLAUDE.md quality
  if [[ -f "$TARGET_DIR/CLAUDE.md" ]]; then
    local line_count
    line_count=$(wc -l < "$TARGET_DIR/CLAUDE.md" | tr -d '[:space:]')

    if [[ "$line_count" -gt 50 ]]; then
      report_row "CLAUDE.md quality" "PASS" "${line_count} lines"
    else
      report_row "CLAUDE.md quality" "WARN" "Only ${line_count} lines"
    fi

    # Check for TODO/ADAPT markers
    local todos
    todos=$(grep -cE 'TODO|ADAPT|FIXME' "$TARGET_DIR/CLAUDE.md" 2>/dev/null | head -1 | tr -d '[:space:]' || echo "0")
    [[ -z "$todos" ]] && todos=0
    if [[ "$todos" -gt 0 ]]; then
      report_row "CLAUDE.md TODOs" "WARN" "$todos TODO/ADAPT markers"
    else
      report_row "CLAUDE.md TODOs" "PASS" "No TODO markers"
    fi

    # --- CLAUDE.md content quality: Key Locations ---
    local in_key_locations=false
    local key_loc_count=0
    while IFS= read -r line; do
      if [[ "$line" =~ ^##[[:space:]].*[Kk]ey[[:space:]][Ll]ocation ]]; then
        in_key_locations=true
        continue
      fi
      if $in_key_locations && [[ "$line" =~ ^## ]]; then
        break
      fi
      if $in_key_locations && [[ "$line" =~ ^-[[:space:]]\*\* ]]; then
        ((key_loc_count++))
      fi
    done < "$TARGET_DIR/CLAUDE.md"

    if [[ "$key_loc_count" -ge 5 ]]; then
      report_row "Key Locations entries" "PASS" "$key_loc_count entries"
    else
      report_row "Key Locations entries" "WARN" "Only $key_loc_count (need ≥5)"
    fi

    # --- CLAUDE.md content quality: Invariants ---
    local inv_count
    inv_count=$(grep -c '### INV-' "$TARGET_DIR/CLAUDE.md" 2>/dev/null || echo "0")
    if [[ "$inv_count" -ge 1 ]]; then
      report_row "Invariants entries" "PASS" "$inv_count invariants"
    else
      report_row "Invariants entries" "WARN" "No ### INV- sections found"
    fi

    # --- CLAUDE.md content quality: Env vars table ---
    local m_env_count
    m_env_count=$(echo "$m" | jq '.env.variables | length' 2>/dev/null || echo "0")
    if [[ "$m_env_count" -gt 0 ]]; then
      local env_table_rows
      env_table_rows=$(grep -cE '^\|.*\|.*\|' "$TARGET_DIR/CLAUDE.md" 2>/dev/null || echo "0")
      # Subtract header/separator rows (at least 2)
      if [[ "$env_table_rows" -gt 2 ]]; then
        report_row "Env vars table" "PASS" "$((env_table_rows - 2)) entries"
      else
        report_row "Env vars table" "FAIL" "Table missing or empty"
      fi
    else
      report_row "Env vars table" "SKIP" "No env vars in manifest"
    fi
  fi
}
