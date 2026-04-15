#!/usr/bin/env bash
# Scanner: Stack Detection
# Discovers language, framework, monorepo status from actual files

scan_stack() {
  local language="unknown"
  local framework="none"
  local is_monorepo=false
  local monorepo_tool=""
  local monorepo_apps="[]"
  local monorepo_libs="[]"

  # --- Language Detection ---
  if [[ -f "$TARGET_DIR/Cargo.toml" ]]; then
    language="rust"
  elif [[ -f "$TARGET_DIR/go.mod" ]]; then
    language="go"
  elif [[ -f "$TARGET_DIR/tsconfig.json" || -f "$TARGET_DIR/tsconfig.base.json" ]]; then
    language="typescript"
  elif [[ -f "$TARGET_DIR/pyproject.toml" || -f "$TARGET_DIR/setup.py" || -f "$TARGET_DIR/requirements.txt" || -f "$TARGET_DIR/Pipfile" ]]; then
    language="python"
  elif [[ -f "$TARGET_DIR/Gemfile" ]]; then
    language="ruby"
  elif [[ -f "$TARGET_DIR/package.json" ]]; then
    language="javascript"
  fi

  # --- Framework Detection ---
  case "$language" in
    python)
      if [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
        local deps
        deps=$(cat "$TARGET_DIR/pyproject.toml" 2>/dev/null)
        if echo "$deps" | grep -qi 'fastapi'; then framework="fastapi"
        elif echo "$deps" | grep -qi 'django'; then framework="django"
        elif echo "$deps" | grep -qi 'flask'; then framework="flask"
        elif echo "$deps" | grep -qi 'starlette'; then framework="starlette"
        fi
      fi
      if [[ "$framework" == "none" && -f "$TARGET_DIR/requirements.txt" ]]; then
        local reqs
        reqs=$(cat "$TARGET_DIR/requirements.txt" 2>/dev/null)
        if echo "$reqs" | grep -qi 'fastapi'; then framework="fastapi"
        elif echo "$reqs" | grep -qi 'django'; then framework="django"
        elif echo "$reqs" | grep -qi 'flask'; then framework="flask"
        fi
      fi
      ;;
    typescript|javascript)
      if [[ -f "$TARGET_DIR/package.json" ]]; then
        local pkg
        pkg=$(cat "$TARGET_DIR/package.json" 2>/dev/null)
        if echo "$pkg" | jq -e '.dependencies.next // .devDependencies.next' >/dev/null 2>&1; then
          framework="nextjs"
        elif echo "$pkg" | jq -e '.dependencies["@nestjs/core"] // .devDependencies["@nestjs/core"]' >/dev/null 2>&1; then
          framework="nestjs"
        elif echo "$pkg" | jq -e '.dependencies.nuxt // .devDependencies.nuxt' >/dev/null 2>&1; then
          framework="nuxt"
        elif echo "$pkg" | jq -e '.dependencies.vue // .devDependencies.vue' >/dev/null 2>&1; then
          framework="vue"
        elif echo "$pkg" | jq -e '.dependencies.react // .devDependencies.react' >/dev/null 2>&1; then
          framework="react"
        elif echo "$pkg" | jq -e '.dependencies.express // .devDependencies.express' >/dev/null 2>&1; then
          framework="express"
        elif echo "$pkg" | jq -e '.dependencies.hono // .devDependencies.hono' >/dev/null 2>&1; then
          framework="hono"
        elif echo "$pkg" | jq -e '.dependencies.svelte // .devDependencies.svelte' >/dev/null 2>&1; then
          framework="svelte"
        fi
      fi
      ;;
    go)
      if [[ -f "$TARGET_DIR/go.mod" ]]; then
        local gomod
        gomod=$(cat "$TARGET_DIR/go.mod" 2>/dev/null)
        if echo "$gomod" | grep -q 'gin-gonic/gin'; then framework="gin"
        elif echo "$gomod" | grep -q 'labstack/echo'; then framework="echo"
        elif echo "$gomod" | grep -q 'go-chi/chi'; then framework="chi"
        elif echo "$gomod" | grep -q 'gofiber/fiber'; then framework="fiber"
        fi
      fi
      ;;
    rust)
      if [[ -f "$TARGET_DIR/Cargo.toml" ]]; then
        local cargo
        cargo=$(cat "$TARGET_DIR/Cargo.toml" 2>/dev/null)
        if echo "$cargo" | grep -q 'actix-web'; then framework="actix"
        elif echo "$cargo" | grep -q 'axum'; then framework="axum"
        elif echo "$cargo" | grep -q 'rocket'; then framework="rocket"
        elif echo "$cargo" | grep -q 'warp'; then framework="warp"
        fi
      fi
      ;;
  esac

  # --- Monorepo Detection ---
  # JS/TS workspaces
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    local workspaces
    workspaces=$(jq -r '.workspaces // empty' "$TARGET_DIR/package.json" 2>/dev/null)
    if [[ -n "$workspaces" && "$workspaces" != "null" ]]; then
      is_monorepo=true
      monorepo_tool="workspaces"
    fi
  fi

  # Rust workspace
  if [[ -f "$TARGET_DIR/Cargo.toml" ]] && grep -q '\[workspace\]' "$TARGET_DIR/Cargo.toml" 2>/dev/null; then
    is_monorepo=true
    monorepo_tool="cargo-workspace"
  fi

  # Go workspace
  if [[ -f "$TARGET_DIR/go.work" ]]; then
    is_monorepo=true
    monorepo_tool="go-workspace"
  fi

  # Nx / Turborepo / Lerna
  if [[ -f "$TARGET_DIR/nx.json" ]]; then
    is_monorepo=true
    monorepo_tool="nx"
  elif [[ -f "$TARGET_DIR/turbo.json" ]]; then
    is_monorepo=true
    monorepo_tool="turborepo"
  elif [[ -f "$TARGET_DIR/lerna.json" ]]; then
    is_monorepo=true
    monorepo_tool="lerna"
  fi

  # apps/ + libs/ directories
  if [[ -d "$TARGET_DIR/apps" && -d "$TARGET_DIR/libs" ]] && [[ "$is_monorepo" == false ]]; then
    is_monorepo=true
    monorepo_tool="directory-convention"
  fi

  # Scan apps/ and libs/ if they exist
  if [[ -d "$TARGET_DIR/apps" ]]; then
    monorepo_apps=$(ls -1 "$TARGET_DIR/apps" 2>/dev/null | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
  fi
  if [[ -d "$TARGET_DIR/libs" || -d "$TARGET_DIR/packages" ]]; then
    local lib_dir="$TARGET_DIR/libs"
    [[ ! -d "$lib_dir" ]] && lib_dir="$TARGET_DIR/packages"
    monorepo_libs=$(ls -1 "$lib_dir" 2>/dev/null | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
  fi

  # --- Multi-package detection ---
  local multi_package_dirs="[]"

  # Detect subdirectories with their own package.json (e.g., frontend/, backend/)
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    local sub_pkg_dirs
    sub_pkg_dirs=$(find "$TARGET_DIR" -maxdepth 3 -name "package.json" \
      -not -path "*/node_modules/*" -not -path "*/.git/*" \
      -not -path "$TARGET_DIR/package.json" 2>/dev/null | \
      sed "s|$TARGET_DIR/||" | sed 's|/package.json||' | sort)
    if [[ -n "$sub_pkg_dirs" ]]; then
      multi_package_dirs=$(echo "$sub_pkg_dirs" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
    fi
  fi

  # Detect multiple pyproject.toml files as Python monorepo
  if [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
    local sub_pyproject_dirs
    sub_pyproject_dirs=$(find "$TARGET_DIR" -maxdepth 3 -name "pyproject.toml" \
      -not -path "*/.git/*" -not -path "*/.venv/*" \
      -not -path "$TARGET_DIR/pyproject.toml" 2>/dev/null | \
      sed "s|$TARGET_DIR/||" | sed 's|/pyproject.toml||' | sort)
    if [[ -n "$sub_pyproject_dirs" ]]; then
      local py_mono_dirs
      py_mono_dirs=$(echo "$sub_pyproject_dirs" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
      multi_package_dirs=$(echo "$multi_package_dirs" | jq --argjson py "$py_mono_dirs" '. + $py')
      if [[ "$is_monorepo" == false ]]; then
        is_monorepo=true
        monorepo_tool="python-multi-package"
      fi
    fi
  fi

  # Mark as multi-package if subdirectories found
  local multi_pkg_count
  multi_pkg_count=$(echo "$multi_package_dirs" | jq 'length' 2>/dev/null || echo "0")
  if [[ "$multi_pkg_count" -gt 0 && "$is_monorepo" == false ]]; then
    is_monorepo=true
    monorepo_tool="multi-package"
  fi

  # --- Key Dependencies ---
  local key_deps="[]"
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    key_deps=$(jq '[(.dependencies // {} | keys[]), (.devDependencies // {} | keys[])]' "$TARGET_DIR/package.json" 2>/dev/null || echo "[]")
  elif [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
    key_deps=$(grep -A 100 '^\[project\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null | grep -A 50 'dependencies' | grep '"' | sed 's/.*"\([^"]*\)".*/\1/' | head -20 | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
  fi

  # --- Node version ---
  local node_version=""
  if [[ -f "$TARGET_DIR/.nvmrc" ]]; then
    node_version=$(cat "$TARGET_DIR/.nvmrc" 2>/dev/null | tr -d '[:space:]' | sed 's/^v//')
  elif [[ -f "$TARGET_DIR/.node-version" ]]; then
    node_version=$(cat "$TARGET_DIR/.node-version" 2>/dev/null | tr -d '[:space:]' | sed 's/^v//')
  elif [[ -f "$TARGET_DIR/package.json" ]]; then
    node_version=$(jq -r '.engines.node // empty' "$TARGET_DIR/package.json" 2>/dev/null)
  fi
  [[ -z "$node_version" ]] && node_version="20"

  # --- Python version ---
  local python_version=""
  if [[ -f "$TARGET_DIR/.python-version" ]]; then
    python_version=$(cat "$TARGET_DIR/.python-version" 2>/dev/null | tr -d '[:space:]')
  elif [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
    python_version=$(grep 'requires-python' "$TARGET_DIR/pyproject.toml" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
  fi
  [[ -z "$python_version" ]] && python_version="3.12"

  MANIFEST=$(echo "$MANIFEST" | jq \
    --arg lang "$language" \
    --arg fw "$framework" \
    --argjson mono "$is_monorepo" \
    --arg mono_tool "$monorepo_tool" \
    --argjson mono_apps "$monorepo_apps" \
    --argjson mono_libs "$monorepo_libs" \
    --argjson deps "$key_deps" \
    --arg node_ver "$node_version" \
    --arg py_ver "$python_version" \
    --argjson multi_pkg "$multi_package_dirs" \
    '. + {
      "stack": {
        "language": $lang,
        "framework": $fw,
        "is_monorepo": $mono,
        "monorepo_tool": ($mono_tool | if . == "" then null else . end),
        "monorepo_apps": $mono_apps,
        "monorepo_libs": $mono_libs,
        "multi_package_dirs": $multi_pkg,
        "key_dependencies": $deps,
        "node_version": ($node_ver | if . == "" then null else . end),
        "python_version": ($py_ver | if . == "" then null else . end)
      }
    }')

  log_ok "Stack: $language / $framework (monorepo: $is_monorepo)"
}
