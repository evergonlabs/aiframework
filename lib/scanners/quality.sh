#!/usr/bin/env bash
# Scanner: Quality Tools
# Discovers linter, formatter, type checker, test framework, hooks

scan_quality() {
  set +eo pipefail
  local linter_tool="" linter_config=""
  local formatter_tool="" formatter_config=""
  local typechecker_tool="" typechecker_config=""
  local test_tool="" test_config=""
  local hook_system="" hook_dir=""
  local missing_tools=()

  # --- Data-driven quality tool detection from languages.json ---
  local qual_data="$ROOT_DIR/lib/data/languages.json"
  local data_driven_quality=false
  if [[ -f "$qual_data" ]] && command -v jq &>/dev/null; then
    local lang
    lang=$(echo "$MANIFEST" | jq -r '.stack.language // "unknown"')
    if [[ "$lang" != "unknown" ]]; then
      # Find matching package manager and extract tool names from commands
      for pm_key in $(jq -r --arg l "$lang" '.languages[$l].package_managers // {} | keys[]' "$qual_data" 2>/dev/null); do
        local pm_lock pm_marker
        pm_lock=$(jq -r --arg l "$lang" --arg p "$pm_key" '.languages[$l].package_managers[$p].lock_file // empty' "$qual_data" 2>/dev/null)
        pm_marker=$(jq -r --arg l "$lang" --arg p "$pm_key" '.languages[$l].package_managers[$p].manifest // empty' "$qual_data" 2>/dev/null)

        if [[ -n "$pm_lock" && -f "$TARGET_DIR/$pm_lock" ]] || [[ -n "$pm_marker" && -f "$TARGET_DIR/$pm_marker" ]]; then
          local pm_cmds
          pm_cmds=$(jq -c --arg l "$lang" --arg p "$pm_key" '.languages[$l].package_managers[$p].commands // {}' "$qual_data" 2>/dev/null)

          # Extract linter tool name from lint command
          if [[ -z "$linter_tool" ]]; then
            local lint_cmd_str
            lint_cmd_str=$(echo "$pm_cmds" | jq -r '.lint // empty' 2>/dev/null)
            if [[ -n "$lint_cmd_str" ]]; then
              # Extract the core tool name (last token before flags, strip runner prefixes)
              local extracted_tool
              extracted_tool=$(echo "$lint_cmd_str" | sed 's/^.*run //' | sed 's/^.*exec //' | awk '{print $1}')
              if [[ -n "$extracted_tool" ]]; then
                linter_tool="$extracted_tool"
                linter_config="data-driven"
                data_driven_quality=true
              fi
            fi
          fi

          # Extract formatter tool name from format command
          if [[ -z "$formatter_tool" ]]; then
            local fmt_cmd_str
            fmt_cmd_str=$(echo "$pm_cmds" | jq -r '.format // empty' 2>/dev/null)
            if [[ -n "$fmt_cmd_str" ]]; then
              local extracted_fmt
              extracted_fmt=$(echo "$fmt_cmd_str" | sed 's/^.*run //' | sed 's/^.*exec //' | sed 's/^bunx //' | sed 's/^npx //' | awk '{print $1}')
              if [[ -n "$extracted_fmt" ]]; then
                formatter_tool="$extracted_fmt"
                formatter_config="data-driven"
                data_driven_quality=true
              fi
            fi
          fi

          # Extract test tool name from test command
          if [[ -z "$test_tool" ]]; then
            local test_cmd_str
            test_cmd_str=$(echo "$pm_cmds" | jq -r '.test // empty' 2>/dev/null)
            if [[ -n "$test_cmd_str" ]]; then
              local extracted_test
              extracted_test=$(echo "$test_cmd_str" | sed 's/^.*run //' | sed 's/^.*exec //' | awk '{print $1}')
              if [[ -n "$extracted_test" ]]; then
                test_tool="$extracted_test"
                test_config="data-driven"
                # shellcheck disable=SC2034
                data_driven_quality=true
              fi
            fi
          fi

          break
        fi
      done
    fi
  fi

  # --- Linter ---
  # ESLint
  for f in .eslintrc.js .eslintrc.json .eslintrc.yml .eslintrc.yaml .eslintrc eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts; do
    if [[ -f "$TARGET_DIR/$f" ]]; then
      linter_tool="eslint"
      linter_config="$f"
      break
    fi
  done

  # Ruff (Python)
  if [[ -z "$linter_tool" ]]; then
    if [[ -f "$TARGET_DIR/.ruff.toml" || -f "$TARGET_DIR/ruff.toml" ]]; then
      linter_tool="ruff"
      linter_config=".ruff.toml"
    elif [[ -f "$TARGET_DIR/pyproject.toml" ]] && grep -q '\[tool\.ruff\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      linter_tool="ruff"
      linter_config="pyproject.toml [tool.ruff]"
    fi
  fi

  # Clippy (Rust) — always available with Rust
  if [[ -z "$linter_tool" && -f "$TARGET_DIR/Cargo.toml" ]]; then
    linter_tool="clippy"
    linter_config="built-in"
  fi

  # Pylint
  if [[ -z "$linter_tool" && -f "$TARGET_DIR/.pylintrc" ]]; then
    linter_tool="pylint"
    linter_config=".pylintrc"
  fi

  # golangci-lint
  if [[ -z "$linter_tool" ]]; then
    for f in .golangci.yml .golangci.yaml .golangci.json .golangci.toml; do
      if [[ -f "$TARGET_DIR/$f" ]]; then
        linter_tool="golangci-lint"
        linter_config="$f"
        break
      fi
    done
  fi

  [[ -z "$linter_tool" ]] && missing_tools+=("linter")

  # --- Formatter ---
  for f in .prettierrc .prettierrc.json .prettierrc.js .prettierrc.yaml .prettierrc.yml .prettierrc.toml prettier.config.js prettier.config.mjs prettier.config.cjs; do
    if [[ -f "$TARGET_DIR/$f" ]]; then
      formatter_tool="prettier"
      formatter_config="$f"
      break
    fi
  done

  # Check package.json for prettier config
  if [[ -z "$formatter_tool" && -f "$TARGET_DIR/package.json" ]]; then
    if jq -e '.prettier' "$TARGET_DIR/package.json" >/dev/null 2>&1; then
      formatter_tool="prettier"
      formatter_config="package.json"
    fi
  fi

  # Ruff format (Python)
  if [[ -z "$formatter_tool" && "$linter_tool" == "ruff" ]]; then
    formatter_tool="ruff-format"
    formatter_config="$linter_config"
  fi

  # Black (Python)
  if [[ -z "$formatter_tool" ]]; then
    if [[ -f "$TARGET_DIR/pyproject.toml" ]] && grep -q '\[tool\.black\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      formatter_tool="black"
      formatter_config="pyproject.toml [tool.black]"
    fi
  fi

  # rustfmt
  if [[ -z "$formatter_tool" && -f "$TARGET_DIR/Cargo.toml" ]]; then
    formatter_tool="rustfmt"
    formatter_config="built-in"
    [[ -f "$TARGET_DIR/rustfmt.toml" ]] && formatter_config="rustfmt.toml"
    [[ -f "$TARGET_DIR/.rustfmt.toml" ]] && formatter_config=".rustfmt.toml"
  fi

  # gofmt / goimports
  if [[ -z "$formatter_tool" && -f "$TARGET_DIR/go.mod" ]]; then
    formatter_tool="gofmt"
    formatter_config="built-in"
  fi

  [[ -z "$formatter_tool" ]] && missing_tools+=("formatter")

  # --- Type Checker ---
  if [[ -f "$TARGET_DIR/tsconfig.json" ]]; then
    typechecker_tool="tsc"
    typechecker_config="tsconfig.json"
    # Check strict mode
    local strict
    strict=$(jq -r '.compilerOptions.strict // false' "$TARGET_DIR/tsconfig.json" 2>/dev/null)
    [[ "$strict" == "true" ]] && typechecker_config="tsconfig.json (strict)"
  fi

  # mypy
  if [[ -z "$typechecker_tool" ]]; then
    if [[ -f "$TARGET_DIR/mypy.ini" || -f "$TARGET_DIR/.mypy.ini" ]]; then
      typechecker_tool="mypy"
      typechecker_config="mypy.ini"
    elif [[ -f "$TARGET_DIR/pyproject.toml" ]] && grep -q '\[tool\.mypy\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      typechecker_tool="mypy"
      typechecker_config="pyproject.toml [tool.mypy]"
    fi
  fi

  # pyright
  if [[ -z "$typechecker_tool" ]]; then
    if [[ -f "$TARGET_DIR/pyrightconfig.json" ]]; then
      typechecker_tool="pyright"
      typechecker_config="pyrightconfig.json"
    elif [[ -f "$TARGET_DIR/pyproject.toml" ]] && grep -q '\[tool\.pyright\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      typechecker_tool="pyright"
      typechecker_config="pyproject.toml [tool.pyright]"
    fi
  fi

  # Rust/Go — compiler IS the type checker
  if [[ -z "$typechecker_tool" && -f "$TARGET_DIR/Cargo.toml" ]]; then
    typechecker_tool="cargo-check"
    typechecker_config="built-in"
  fi
  if [[ -z "$typechecker_tool" && -f "$TARGET_DIR/go.mod" ]]; then
    typechecker_tool="go-vet"
    typechecker_config="built-in"
  fi

  [[ -z "$typechecker_tool" ]] && missing_tools+=("type-checker")

  # --- Test Framework ---
  # Jest
  for f in jest.config.ts jest.config.js jest.config.json jest.config.mjs jest.config.cjs; do
    if [[ -f "$TARGET_DIR/$f" ]]; then
      test_tool="jest"
      test_config="$f"
      break
    fi
  done

  # Vitest
  if [[ -z "$test_tool" ]]; then
    for f in vitest.config.ts vitest.config.js vitest.config.mts vitest.config.mjs; do
      if [[ -f "$TARGET_DIR/$f" ]]; then
        test_tool="vitest"
        test_config="$f"
        break
      fi
    done
  fi

  # Check package.json for jest config
  if [[ -z "$test_tool" && -f "$TARGET_DIR/package.json" ]]; then
    if jq -e '.jest' "$TARGET_DIR/package.json" >/dev/null 2>&1; then
      test_tool="jest"
      test_config="package.json"
    fi
  fi

  # Pytest
  if [[ -z "$test_tool" ]]; then
    if [[ -f "$TARGET_DIR/pytest.ini" || -f "$TARGET_DIR/conftest.py" ]]; then
      test_tool="pytest"
      test_config="pytest.ini"
      [[ -f "$TARGET_DIR/conftest.py" ]] && test_config="conftest.py"
    elif [[ -f "$TARGET_DIR/pyproject.toml" ]] && grep -q '\[tool\.pytest\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      test_tool="pytest"
      test_config="pyproject.toml [tool.pytest]"
    fi
  fi

  # Cargo test (Rust)
  if [[ -z "$test_tool" && -f "$TARGET_DIR/Cargo.toml" ]]; then
    test_tool="cargo-test"
    test_config="built-in"
  fi

  # Go test
  if [[ -z "$test_tool" && -f "$TARGET_DIR/go.mod" ]]; then
    test_tool="go-test"
    test_config="built-in"
  fi

  [[ -z "$test_tool" ]] && missing_tools+=("test-framework")

  # --- Hooks ---
  if [[ -d "$TARGET_DIR/.husky" ]]; then
    hook_system="husky"
    hook_dir=".husky"
  elif [[ -d "$TARGET_DIR/.githooks" ]]; then
    hook_system="githooks"
    hook_dir=".githooks"
  elif [[ -f "$TARGET_DIR/.pre-commit-config.yaml" ]]; then
    hook_system="pre-commit"
    hook_dir=".pre-commit-config.yaml"
  fi

  # Check what hooks exist
  local has_precommit=false has_prepush=false has_commitmsg=false
  if [[ -n "$hook_dir" && -d "$TARGET_DIR/$hook_dir" ]]; then
    [[ -f "$TARGET_DIR/$hook_dir/pre-commit" ]] && has_precommit=true
    [[ -f "$TARGET_DIR/$hook_dir/pre-push" ]] && has_prepush=true
    [[ -f "$TARGET_DIR/$hook_dir/commit-msg" ]] && has_commitmsg=true
  fi

  local missing_json
  if [[ ${#missing_tools[@]} -eq 0 ]]; then
    missing_json="[]"
  else
    missing_json=$(printf '%s\n' "${missing_tools[@]}" | jq -R '.' | jq -s '.')
  fi

  MANIFEST=$(echo "$MANIFEST" | jq \
    --arg lint_tool "$linter_tool" \
    --arg lint_cfg "$linter_config" \
    --arg fmt_tool "$formatter_tool" \
    --arg fmt_cfg "$formatter_config" \
    --arg tc_tool "$typechecker_tool" \
    --arg tc_cfg "$typechecker_config" \
    --arg test_tool "$test_tool" \
    --arg test_cfg "$test_config" \
    --arg hook_sys "$hook_system" \
    --arg hook_d "$hook_dir" \
    --argjson precommit "$has_precommit" \
    --argjson prepush "$has_prepush" \
    --argjson commitmsg "$has_commitmsg" \
    --argjson missing "$missing_json" \
    '. + {
      "quality": {
        "linter": {
          "tool": ($lint_tool | if . == "" then null else . end),
          "config": ($lint_cfg | if . == "" then null else . end),
          "configured": ($lint_tool != "")
        },
        "formatter": {
          "tool": ($fmt_tool | if . == "" then null else . end),
          "config": ($fmt_cfg | if . == "" then null else . end),
          "configured": ($fmt_tool != "")
        },
        "type_checker": {
          "tool": ($tc_tool | if . == "" then null else . end),
          "config": ($tc_cfg | if . == "" then null else . end),
          "configured": ($tc_tool != "")
        },
        "test_framework": {
          "tool": ($test_tool | if . == "" then null else . end),
          "config": ($test_cfg | if . == "" then null else . end),
          "configured": ($test_tool != "")
        },
        "hooks": {
          "system": ($hook_sys | if . == "" then null else . end),
          "directory": ($hook_d | if . == "" then null else . end),
          "pre_commit": $precommit,
          "pre_push": $prepush,
          "commit_msg": $commitmsg
        },
        "missing_tools": $missing
      }
    }')

  set -eo pipefail
  log_ok "Quality: lint=$linter_tool fmt=$formatter_tool tc=$typechecker_tool test=$test_tool hooks=$hook_system"
  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_warn "Missing: ${missing_tools[*]}"
  fi
}
