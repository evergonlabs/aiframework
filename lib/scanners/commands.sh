#!/usr/bin/env bash
# Scanner: Commands & Package Manager
# Discovers install, dev, build, lint, test, format commands from actual files

scan_commands() {
  set +eo pipefail
  local pkg_manager=""
  local install_cmd=""
  local dev_cmd=""
  local build_cmd=""
  local lint_cmd=""
  local format_cmd=""
  local typecheck_cmd=""
  local test_cmd=""
  local dev_port=""
  local prod_port=""
  local lock_file=""
  local github_url=""
  local local_path="$TARGET_DIR"

  # --- Package Manager ---
  if [[ -f "$TARGET_DIR/pnpm-lock.yaml" ]]; then
    pkg_manager="pnpm"
    lock_file="pnpm-lock.yaml"
  elif [[ -f "$TARGET_DIR/yarn.lock" ]]; then
    pkg_manager="yarn"
    lock_file="yarn.lock"
  elif [[ -f "$TARGET_DIR/package-lock.json" ]]; then
    pkg_manager="npm"
    lock_file="package-lock.json"
  elif [[ -f "$TARGET_DIR/bun.lockb" || -f "$TARGET_DIR/bun.lock" ]]; then
    pkg_manager="bun"
    lock_file="bun.lockb"
    [[ -f "$TARGET_DIR/bun.lock" ]] && lock_file="bun.lock"
  elif [[ -f "$TARGET_DIR/Pipfile.lock" ]]; then
    pkg_manager="pipenv"
    lock_file="Pipfile.lock"
  elif [[ -f "$TARGET_DIR/poetry.lock" ]]; then
    pkg_manager="poetry"
    lock_file="poetry.lock"
  elif [[ -f "$TARGET_DIR/uv.lock" ]]; then
    pkg_manager="uv"
    lock_file="uv.lock"
  elif [[ -f "$TARGET_DIR/Cargo.lock" ]]; then
    pkg_manager="cargo"
    lock_file="Cargo.lock"
  elif [[ -f "$TARGET_DIR/go.sum" ]]; then
    pkg_manager="go"
    lock_file="go.sum"
  elif [[ -f "$TARGET_DIR/Gemfile.lock" ]]; then
    pkg_manager="bundler"
    lock_file="Gemfile.lock"
  elif [[ -f "$TARGET_DIR/package.json" ]]; then
    pkg_manager="npm"
    lock_file=""
  elif [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
    pkg_manager="pip"
    lock_file=""
  fi

  # --- Commands from package.json scripts ---
  local scripts="{}"
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    scripts=$(jq '.scripts // {}' "$TARGET_DIR/package.json" 2>/dev/null || echo "{}")

    local run_prefix="$pkg_manager run"
    [[ "$pkg_manager" == "yarn" ]] && run_prefix="yarn"
    [[ "$pkg_manager" == "bun" ]] && run_prefix="bun run"

    install_cmd="$pkg_manager install"

    # Dev command
    for key in dev start serve develop; do
      if echo "$scripts" | jq -e ".[\"$key\"]" >/dev/null 2>&1; then
        dev_cmd="$run_prefix $key"
        break
      fi
    done

    # Build command
    for key in build compile; do
      if echo "$scripts" | jq -e ".[\"$key\"]" >/dev/null 2>&1; then
        build_cmd="$run_prefix $key"
        break
      fi
    done

    # Lint command
    for key in lint "lint:check" eslint; do
      if echo "$scripts" | jq -e ".[\"$key\"]" >/dev/null 2>&1; then
        lint_cmd="$run_prefix $key"
        break
      fi
    done

    # Format command
    for key in format fmt "format:check" prettier; do
      if echo "$scripts" | jq -e ".[\"$key\"]" >/dev/null 2>&1; then
        format_cmd="$run_prefix $key"
        break
      fi
    done

    # Typecheck command
    for key in typecheck "type-check" "types:check" tsc; do
      if echo "$scripts" | jq -e ".[\"$key\"]" >/dev/null 2>&1; then
        typecheck_cmd="$run_prefix $key"
        break
      fi
    done
    # Fallback: if tsconfig exists
    if [[ -z "$typecheck_cmd" && -f "$TARGET_DIR/tsconfig.json" ]]; then
      typecheck_cmd="npx tsc --noEmit"
    fi

    # Test command
    for key in test "test:run" "test:unit"; do
      if echo "$scripts" | jq -e ".[\"$key\"]" >/dev/null 2>&1; then
        test_cmd="$run_prefix $key"
        break
      fi
    done
  fi

  # --- Commands for Python ---
  if [[ -f "$TARGET_DIR/pyproject.toml" && -z "$install_cmd" ]]; then
    case "$pkg_manager" in
      poetry)  install_cmd="poetry install" ;;
      pipenv)  install_cmd="pipenv install --dev" ;;
      uv)      install_cmd="uv pip install -e '.[dev]'" ;;
      *)       install_cmd="pip install -e '.[dev]'" ;;
    esac

    # Check for ruff
    if grep -q 'ruff' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      lint_cmd="ruff check ."
      format_cmd="ruff format ."
    fi

    # Check for mypy/pyright
    if grep -q 'mypy' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      typecheck_cmd="mypy src/"
    elif grep -q 'pyright' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      typecheck_cmd="pyright"
    fi

    # Check for pytest
    if grep -q 'pytest' "$TARGET_DIR/pyproject.toml" 2>/dev/null || [[ -f "$TARGET_DIR/pytest.ini" ]] || [[ -f "$TARGET_DIR/conftest.py" ]]; then
      test_cmd="pytest"
    fi

    # Check for uvicorn/gunicorn/python -m
    if grep -q 'uvicorn' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
      dev_cmd="uvicorn app.main:app --reload"
    fi
  fi

  # --- Commands for Rust ---
  if [[ -f "$TARGET_DIR/Cargo.toml" && -z "$install_cmd" ]]; then
    install_cmd="cargo build"
    dev_cmd="cargo run"
    build_cmd="cargo build --release"
    lint_cmd="cargo clippy --workspace -- -D warnings"
    format_cmd="cargo fmt --all -- --check"
    typecheck_cmd="cargo check --workspace"
    test_cmd="cargo test --workspace"
  fi

  # --- Commands for Go ---
  if [[ -f "$TARGET_DIR/go.mod" && -z "$install_cmd" ]]; then
    install_cmd="go mod download"
    dev_cmd="go run ."
    build_cmd="go build ./..."
    lint_cmd="go vet ./..."
    typecheck_cmd="go vet ./..."
    test_cmd="go test ./..."
  fi

  # --- Commands for Shell/Bash projects ---
  # If no package manager detected and shell scripts exist, detect shell tools
  if [[ -z "$pkg_manager" ]]; then
    local sh_count
    sh_count=$(find "$TARGET_DIR" -maxdepth 3 -name '*.sh' -not -path '*/.git/*' -not -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d '[:space:]')
    if [[ "$sh_count" -gt 3 ]]; then
      # ShellCheck is the standard shell linter — always recommend for bash projects
      [[ -z "$lint_cmd" ]] && lint_cmd="find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs shellcheck"
      # bash -n for syntax checking
      [[ -z "$typecheck_cmd" || "$typecheck_cmd" == "NOT_CONFIGURED" ]] && typecheck_cmd="find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n"
    fi
  fi

  # --- Makefile targets ---
  local makefile_targets="[]"
  if [[ -f "$TARGET_DIR/Makefile" ]]; then
    makefile_targets=$(grep -E '^[a-zA-Z_-]+:' "$TARGET_DIR/Makefile" 2>/dev/null | sed 's/:.*//' | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    # Override with Makefile targets if they exist and commands aren't set
    for target in dev run serve start; do
      if grep -q "^${target}:" "$TARGET_DIR/Makefile" 2>/dev/null && [[ -z "$dev_cmd" ]]; then
        dev_cmd="make $target"
        break
      fi
    done
    for target in build compile; do
      if grep -q "^${target}:" "$TARGET_DIR/Makefile" 2>/dev/null && [[ -z "$build_cmd" ]]; then
        build_cmd="make $target"
        break
      fi
    done
    for target in lint check; do
      if grep -q "^${target}:" "$TARGET_DIR/Makefile" 2>/dev/null && [[ -z "$lint_cmd" ]]; then
        lint_cmd="make $target"
        break
      fi
    done
    for target in test tests; do
      if grep -q "^${target}:" "$TARGET_DIR/Makefile" 2>/dev/null && [[ -z "$test_cmd" ]]; then
        test_cmd="make $target"
        break
      fi
    done
  fi

  # --- Port detection ---
  # From .env.example
  if [[ -f "$TARGET_DIR/.env.example" ]]; then
    dev_port=$(grep -iE '^(PORT|DEV_PORT|APP_PORT|SERVER_PORT)=' "$TARGET_DIR/.env.example" 2>/dev/null | head -1 | cut -d= -f2 | tr -d '[:space:]"'\''')
  fi
  # From Dockerfile
  if [[ -f "$TARGET_DIR/Dockerfile" ]]; then
    prod_port=$(grep -m1 'EXPOSE' "$TARGET_DIR/Dockerfile" 2>/dev/null | awk '{print $2}')
  fi
  # From dev script
  if [[ -z "$dev_port" && -f "$TARGET_DIR/package.json" ]]; then
    local dev_script
    dev_script=$(echo "$scripts" | jq -r '.dev // .start // empty' 2>/dev/null)
    if [[ -n "$dev_script" ]]; then
      dev_port=$(echo "$dev_script" | grep -oE 'port[= ]+([0-9]+)' | grep -oE '[0-9]+' | head -1)
      [[ -z "$dev_port" ]] && dev_port=$(echo "$dev_script" | grep -oE '\-p[= ]+([0-9]+)' | grep -oE '[0-9]+' | head -1)
    fi
  fi

  # --- GitHub URL ---
  if [[ -d "$TARGET_DIR/.git" ]]; then
    github_url=$(cd "$TARGET_DIR" && git remote get-url origin 2>/dev/null | sed 's/ghp_[a-zA-Z0-9]*@//' | sed 's/\.git$//')
  fi

  # --- CI: Check for buildspec.yml (AWS CodeBuild) ---
  local has_buildspec=false
  [[ -f "$TARGET_DIR/buildspec.yml" || -f "$TARGET_DIR/buildspec.yaml" ]] && has_buildspec=true

  # --- Production URL (placeholder for user interaction) ---
  local production_url=""

  # Set NOT_CONFIGURED for missing commands
  [[ -z "$install_cmd" ]] && install_cmd="NOT_CONFIGURED"
  [[ -z "$dev_cmd" ]] && dev_cmd="NOT_CONFIGURED"
  [[ -z "$build_cmd" ]] && build_cmd="NOT_CONFIGURED"
  [[ -z "$lint_cmd" ]] && lint_cmd="NOT_CONFIGURED"
  [[ -z "$format_cmd" ]] && format_cmd="NOT_CONFIGURED"
  [[ -z "$typecheck_cmd" ]] && typecheck_cmd="NOT_CONFIGURED"
  [[ -z "$test_cmd" ]] && test_cmd="NOT_CONFIGURED"

  MANIFEST=$(echo "$MANIFEST" | jq \
    --arg pkg "$pkg_manager" \
    --arg install "$install_cmd" \
    --arg dev "$dev_cmd" \
    --arg build "$build_cmd" \
    --arg lint "$lint_cmd" \
    --arg format "$format_cmd" \
    --arg typecheck "$typecheck_cmd" \
    --arg test "$test_cmd" \
    --arg dev_port "$dev_port" \
    --arg prod_port "$prod_port" \
    --arg lock "$lock_file" \
    --arg gh_url "$github_url" \
    --arg local "$local_path" \
    --argjson scripts "$scripts" \
    --argjson make_targets "$makefile_targets" \
    --argjson has_buildspec "$has_buildspec" \
    --arg prod_url "$production_url" \
    '. + {
      "commands": {
        "package_manager": ($pkg | if . == "" then null else . end),
        "install": $install,
        "dev": $dev,
        "build": $build,
        "lint": $lint,
        "format": $format,
        "typecheck": $typecheck,
        "test": $test,
        "dev_port": ($dev_port | if . == "" then null else . end),
        "prod_port": ($prod_port | if . == "" then null else . end),
        "lock_file": ($lock | if . == "" then null else . end),
        "github_url": ($gh_url | if . == "" then null else . end),
        "local_path": $local,
        "production_url": ($prod_url | if . == "" then null else . end),
        "scripts": $scripts,
        "makefile_targets": $make_targets,
        "has_buildspec": $has_buildspec
      }
    }')

  set -eo pipefail
  log_ok "Commands: pkg=$pkg_manager install=$install_cmd"
}
