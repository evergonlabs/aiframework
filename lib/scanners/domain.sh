#!/usr/bin/env bash
# Scanner: Domain-Specific Concerns
# Discovers auth, DB, API, AI, sandbox patterns from actual code

scan_domain() {
  set +eo pipefail
  local domains="[]"
  local invariants="[]"
  local security_concerns="[]"

  # --- Auth/AuthZ ---
  local auth_files
  auth_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "auth*" -o -name "guard*" -o -name "middleware*" -o -name "permission*" -o -name "session*" -o -name "jwt*" -o -name "oauth*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    2>/dev/null | head -20)

  if [[ -n "$auth_files" ]]; then
    local auth_count
    auth_count=$(echo "$auth_files" | wc -l | tr -d '[:space:]')
    local auth_paths
    auth_paths=$(echo "$auth_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$auth_paths" --arg count "$auth_count" \
      '. + [{"name": "auth", "display": "Authentication & Authorization", "file_count": ($count | tonumber), "paths": $paths}]')

    security_concerns=$(echo "$security_concerns" | jq '. + ["auth-bypass", "session-management", "jwt-validation"]')
  fi

  # --- Database ---
  local db_files
  db_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "migration*" -o -name "schema*" -o -name "model*" -o -name "entity*" -o -name "repository*" -o -name "prisma*" -o -name "drizzle*" -o -name "*.sql" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    2>/dev/null | head -30)

  # Also check for ORM config
  local has_prisma=false has_drizzle=false has_typeorm=false has_sqlalchemy=false has_diesel=false
  [[ -f "$TARGET_DIR/prisma/schema.prisma" ]] && has_prisma=true
  [[ -d "$TARGET_DIR/drizzle" ]] && has_drizzle=true
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    jq -e '.dependencies.typeorm // .devDependencies.typeorm' "$TARGET_DIR/package.json" >/dev/null 2>&1 && has_typeorm=true
    jq -e '.dependencies.drizzle-orm // .devDependencies.drizzle-orm' "$TARGET_DIR/package.json" >/dev/null 2>&1 && has_drizzle=true
  fi

  if [[ -n "$db_files" || "$has_prisma" == true || "$has_drizzle" == true || "$has_typeorm" == true ]]; then
    local db_count=0
    [[ -n "$db_files" ]] && db_count=$(echo "$db_files" | wc -l | tr -d '[:space:]')
    local db_paths
    db_paths=$(echo "$db_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    local orm="unknown"
    $has_prisma && orm="prisma"
    $has_drizzle && orm="drizzle"
    $has_typeorm && orm="typeorm"
    $has_sqlalchemy && orm="sqlalchemy"
    $has_diesel && orm="diesel"

    domains=$(echo "$domains" | jq --argjson paths "$db_paths" --arg count "$db_count" --arg orm "$orm" \
      '. + [{"name": "database", "display": "Database & Data Layer", "file_count": ($count | tonumber), "paths": $paths, "orm": $orm}]')

    security_concerns=$(echo "$security_concerns" | jq '. + ["sql-injection", "migration-safety"]')
  fi

  # --- API/HTTP Endpoints ---
  local api_files
  api_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "controller*" -o -name "route*" -o -name "endpoint*" -o -name "api*" -o -name "handler*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" \
    2>/dev/null | head -30)

  if [[ -n "$api_files" ]]; then
    local api_count
    api_count=$(echo "$api_files" | wc -l | tr -d '[:space:]')
    local api_paths
    api_paths=$(echo "$api_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$api_paths" --arg count "$api_count" \
      '. + [{"name": "api", "display": "API Endpoints", "file_count": ($count | tonumber), "paths": $paths}]')

    security_concerns=$(echo "$security_concerns" | jq '. + ["input-validation", "rate-limiting"]')
  fi

  # --- AI/LLM ---
  local ai_files
  ai_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "prompt*" -o -name "llm*" -o -name "agent*" -o -name "ai*" -o -name "openai*" -o -name "anthropic*" -o -name "embedding*" -o -name "rag*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" \
    2>/dev/null | head -20)

  # Also check dependencies
  local has_openai=false has_anthropic=false has_langchain=false
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    jq -e '.dependencies.openai // .devDependencies.openai' "$TARGET_DIR/package.json" >/dev/null 2>&1 && has_openai=true
    jq -e '.dependencies["@anthropic-ai/sdk"] // .devDependencies["@anthropic-ai/sdk"]' "$TARGET_DIR/package.json" >/dev/null 2>&1 && has_anthropic=true
    jq -e '.dependencies.langchain // .devDependencies.langchain' "$TARGET_DIR/package.json" >/dev/null 2>&1 && has_langchain=true
  fi

  if [[ -n "$ai_files" || "$has_openai" == true || "$has_anthropic" == true || "$has_langchain" == true ]]; then
    local ai_count=0
    [[ -n "$ai_files" ]] && ai_count=$(echo "$ai_files" | wc -l | tr -d '[:space:]')
    local ai_paths
    ai_paths=$(echo "$ai_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$ai_paths" --arg count "$ai_count" \
      '. + [{"name": "ai", "display": "AI/LLM Integration", "file_count": ($count | tonumber), "paths": $paths}]')

    security_concerns=$(echo "$security_concerns" | jq '. + ["prompt-injection", "llm-trust-boundary"]')
  fi

  # --- Sandbox/Code Execution ---
  local sandbox_files
  sandbox_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "sandbox*" -o -name "executor*" -o -name "runner*" -o -name "e2b*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    2>/dev/null | head -10)

  if [[ -n "$sandbox_files" || -f "$TARGET_DIR/e2b.toml" ]]; then
    local sandbox_count=0
    [[ -n "$sandbox_files" ]] && sandbox_count=$(echo "$sandbox_files" | wc -l | tr -d '[:space:]')
    local sandbox_paths
    sandbox_paths=$(echo "$sandbox_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$sandbox_paths" --arg count "$sandbox_count" \
      '. + [{"name": "sandbox", "display": "Code Execution / Sandbox", "file_count": ($count | tonumber), "paths": $paths}]')

    security_concerns=$(echo "$security_concerns" | jq '. + ["code-execution-escape", "resource-limits"]')
  fi

  # --- Frontend ---
  local frontend_files
  frontend_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "*.tsx" -o -name "*.vue" -o -name "*.svelte" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" \
    2>/dev/null | head -50)

  if [[ -n "$frontend_files" ]]; then
    local fe_count
    fe_count=$(echo "$frontend_files" | wc -l | tr -d '[:space:]')

    local fe_pages=0 fe_components=0
    fe_pages=$(echo "$frontend_files" | grep -ciE '(page|route|view)\.' 2>/dev/null || true)
    fe_components=$(echo "$frontend_files" | grep -ciE 'component' 2>/dev/null || true)

    domains=$(echo "$domains" | jq --arg count "$fe_count" --arg pages "$fe_pages" --arg components "$fe_components" \
      '. + [{"name": "frontend", "display": "Frontend UI", "file_count": ($count | tonumber), "pages": ($pages | tonumber), "components": ($components | tonumber)}]')
  fi

  # --- External APIs ---
  local ext_api_files
  ext_api_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "provider*" -o -name "client*" -o -name "integration*" -o -name "connector*" -o -name "adapter*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" \
    2>/dev/null | head -20)

  if [[ -n "$ext_api_files" ]]; then
    local ext_count
    ext_count=$(echo "$ext_api_files" | wc -l | tr -d '[:space:]')
    local ext_paths
    ext_paths=$(echo "$ext_api_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$ext_paths" --arg count "$ext_count" \
      '. + [{"name": "external-apis", "display": "External API Integrations", "file_count": ($count | tonumber), "paths": $paths}]')
  fi

  # --- Workers/Jobs ---
  local worker_files
  worker_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "worker*" -o -name "job*" -o -name "queue*" -o -name "cron*" -o -name "task*" -o -name "consumer*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" \
    2>/dev/null | head -15)

  if [[ -n "$worker_files" ]]; then
    local worker_count
    worker_count=$(echo "$worker_files" | wc -l | tr -d '[:space:]')
    local worker_paths
    worker_paths=$(echo "$worker_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$worker_paths" --arg count "$worker_count" \
      '. + [{"name": "workers", "display": "Background Workers / Jobs", "file_count": ($count | tonumber), "paths": $paths}]')
  fi

  # --- File Upload / Storage ---
  local upload_files
  upload_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "*upload*" -o -name "*storage*" -o -name "*multer*" -o -name "*busboy*" -o -name "*s3*" -o -name "*gcs*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" \
    2>/dev/null | head -20)

  if [[ -n "$upload_files" ]]; then
    local upload_count
    upload_count=$(echo "$upload_files" | wc -l | tr -d '[:space:]')
    local upload_paths
    upload_paths=$(echo "$upload_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$upload_paths" --arg count "$upload_count" \
      '. + [{"name": "file-upload", "display": "File Upload / Storage", "file_count": ($count | tonumber), "paths": $paths}]')

    security_concerns=$(echo "$security_concerns" | jq '. + ["file-upload-validation", "storage-access-control"]')
  fi

  # --- Financial Calculations ---
  local finance_files
  finance_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "*payroll*" -o -name "*billing*" -o -name "*transaction*" -o -name "*invoice*" -o -name "*payment*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" \
    2>/dev/null | head -20)

  if [[ -n "$finance_files" ]]; then
    local finance_count
    finance_count=$(echo "$finance_files" | wc -l | tr -d '[:space:]')
    local finance_paths
    finance_paths=$(echo "$finance_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$finance_paths" --arg count "$finance_count" \
      '. + [{"name": "financial", "display": "Financial Calculations", "file_count": ($count | tonumber), "paths": $paths}]')

    invariants=$(echo "$invariants" | jq '. + ["monetary-precision", "transaction-atomicity"]')
    security_concerns=$(echo "$security_concerns" | jq '. + ["payment-data-protection", "financial-audit-trail"]')
  fi

  # --- Compliance Requirements ---
  local compliance_files
  compliance_files=$(find "$TARGET_DIR" -maxdepth 6 -type f \
    \( -name "*compliance*" -o -name "*audit*" -o -name "*gdpr*" -o -name "*hipaa*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    2>/dev/null | head -20)

  if [[ -n "$compliance_files" ]]; then
    local compliance_count
    compliance_count=$(echo "$compliance_files" | wc -l | tr -d '[:space:]')
    local compliance_paths
    compliance_paths=$(echo "$compliance_files" | sed "s|$TARGET_DIR/||" | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

    domains=$(echo "$domains" | jq --argjson paths "$compliance_paths" --arg count "$compliance_count" \
      '. + [{"name": "compliance", "display": "Compliance & Audit", "file_count": ($count | tonumber), "paths": $paths}]')

    security_concerns=$(echo "$security_concerns" | jq '. + ["data-retention", "audit-logging", "pii-handling"]')
  fi

  # --- Monorepo boundary rules ---
  local cross_package_imports="[]"
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    local has_workspaces
    has_workspaces=$(jq -r '.workspaces // empty' "$TARGET_DIR/package.json" 2>/dev/null)
    if [[ -n "$has_workspaces" && "$has_workspaces" != "null" ]]; then
      # Check for cross-package relative imports (e.g., ../../packages/other)
      local cross_imports
      cross_imports=$(grep -rn "from ['\"]\.\./" "$TARGET_DIR/apps" "$TARGET_DIR/packages" "$TARGET_DIR/libs" 2>/dev/null | \
        grep -v node_modules | grep -v '.git' | head -10)
      if [[ -n "$cross_imports" ]]; then
        cross_package_imports=$(echo "$cross_imports" | sed "s|$TARGET_DIR/||" | cut -d: -f1 | sort -u | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")
        invariants=$(echo "$invariants" | jq '. + ["monorepo-boundary-enforcement"]')
      fi
    fi
  fi

  # --- CORE_PRINCIPLES inference ---
  local core_principles="[]"

  # Check for strict TypeScript
  if [[ -f "$TARGET_DIR/tsconfig.json" ]]; then
    local ts_strict
    ts_strict=$(jq -r '.compilerOptions.strict // false' "$TARGET_DIR/tsconfig.json" 2>/dev/null)
    if [[ "$ts_strict" == "true" ]]; then
      core_principles=$(echo "$core_principles" | jq '. + ["Strict TypeScript (strict: true)"]')
    fi
  fi

  # Check for ORM usage (no raw SQL)
  local has_orm=false
  [[ -f "$TARGET_DIR/prisma/schema.prisma" ]] && has_orm=true
  [[ -d "$TARGET_DIR/drizzle" ]] && has_orm=true
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    jq -e '.dependencies.typeorm // .dependencies["drizzle-orm"] // .dependencies["@prisma/client"] // .dependencies.sequelize' "$TARGET_DIR/package.json" >/dev/null 2>&1 && has_orm=true
  fi
  if [[ "$has_orm" == true ]]; then
    core_principles=$(echo "$core_principles" | jq '. + ["No raw SQL — uses ORM"]')
  fi

  # Check for env-based config patterns
  local env_config_files
  env_config_files=$(find "$TARGET_DIR" -maxdepth 3 -type f \( -name "config.ts" -o -name "config.py" -o -name "env.ts" -o -name "settings.py" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -5)
  if [[ -n "$env_config_files" ]]; then
    core_principles=$(echo "$core_principles" | jq '. + ["All config via env vars"]')
  fi

  # Check linter config strictness
  if [[ -f "$TARGET_DIR/.eslintrc.json" || -f "$TARGET_DIR/.eslintrc.js" || -f "$TARGET_DIR/.eslintrc.yml" || -f "$TARGET_DIR/eslint.config.js" || -f "$TARGET_DIR/eslint.config.mjs" ]]; then
    core_principles=$(echo "$core_principles" | jq '. + ["ESLint enforced"]')
  fi
  if [[ -f "$TARGET_DIR/pyproject.toml" ]] && grep -q '\[tool\.ruff\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
    core_principles=$(echo "$core_principles" | jq '. + ["Ruff linter enforced"]')
  fi
  if [[ -f "$TARGET_DIR/.prettierrc" || -f "$TARGET_DIR/.prettierrc.json" || -f "$TARGET_DIR/.prettierrc.js" || -f "$TARGET_DIR/prettier.config.js" ]]; then
    core_principles=$(echo "$core_principles" | jq '. + ["Prettier formatting enforced"]')
  fi

  # --- COMPONENT_COUNTS ---
  local component_counts="{}"
  local count_controllers count_services count_models count_dtos count_routes count_middlewares count_tests

  count_controllers=$(find "$TARGET_DIR" -maxdepth 6 -type f -name "*controller*" \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" 2>/dev/null | wc -l | tr -d '[:space:]')

  count_services=$(find "$TARGET_DIR" -maxdepth 6 -type f -name "*service*" \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" 2>/dev/null | wc -l | tr -d '[:space:]')

  count_models=$(find "$TARGET_DIR" -maxdepth 6 -type f \( -name "*model*" -o -name "*entity*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" 2>/dev/null | wc -l | tr -d '[:space:]')

  count_dtos=$(find "$TARGET_DIR" -maxdepth 6 -type f \( -name "*dto*" -o -name "*schema*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" 2>/dev/null | wc -l | tr -d '[:space:]')

  count_routes=$(find "$TARGET_DIR" -maxdepth 6 -type f \( -name "*route*" -o -name "*router*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" 2>/dev/null | wc -l | tr -d '[:space:]')

  count_middlewares=$(find "$TARGET_DIR" -maxdepth 6 -type f -name "*middleware*" \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    -not -name "*.test.*" -not -name "*.spec.*" 2>/dev/null | wc -l | tr -d '[:space:]')

  count_tests=$(find "$TARGET_DIR" -maxdepth 6 -type f \( -name "*.test.*" -o -name "*.spec.*" -o -name "test_*" -o -name "*_test.*" \) \
    -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" -not -path "*/target/*" \
    2>/dev/null | wc -l | tr -d '[:space:]')

  component_counts=$(jq -n \
    --arg controllers "$count_controllers" \
    --arg services "$count_services" \
    --arg models "$count_models" \
    --arg dtos "$count_dtos" \
    --arg routes "$count_routes" \
    --arg middlewares "$count_middlewares" \
    --arg tests "$count_tests" \
    '{
      "controllers": ($controllers | tonumber),
      "services": ($services | tonumber),
      "models": ($models | tonumber),
      "dtos": ($dtos | tonumber),
      "routes": ($routes | tonumber),
      "middlewares": ($middlewares | tonumber),
      "tests": ($tests | tonumber)
    }')

  # --- ENFORCED vs ASPIRATIONAL marking (A16b) ---
  # Check each invariant against linter/type-checker config to determine enforcement
  local eslint_config_content=""
  local has_eslint=false has_mypy=false has_pyright=false has_tsc_strict=false has_ruff=false

  # Read ESLint config if present
  for eslint_file in ".eslintrc.json" ".eslintrc.js" ".eslintrc.yml" "eslint.config.js" "eslint.config.mjs"; do
    if [[ -f "$TARGET_DIR/$eslint_file" ]]; then
      has_eslint=true
      eslint_config_content=$(cat "$TARGET_DIR/$eslint_file" 2>/dev/null || true)
      break
    fi
  done

  # Check for Python type checkers
  if [[ -f "$TARGET_DIR/mypy.ini" || -f "$TARGET_DIR/.mypy.ini" || -f "$TARGET_DIR/setup.cfg" ]]; then
    has_mypy=true
  fi
  if [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
    grep -q '\[tool\.mypy\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null && has_mypy=true
    grep -q '\[tool\.pyright\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null && has_pyright=true
    grep -q '\[tool\.ruff\]' "$TARGET_DIR/pyproject.toml" 2>/dev/null && has_ruff=true
  fi
  if [[ -f "$TARGET_DIR/pyrightconfig.json" ]]; then
    has_pyright=true
  fi

  # Check for strict TypeScript
  if [[ -f "$TARGET_DIR/tsconfig.json" ]]; then
    local strict_val
    strict_val=$(jq -r '.compilerOptions.strict // false' "$TARGET_DIR/tsconfig.json" 2>/dev/null)
    [[ "$strict_val" == "true" ]] && has_tsc_strict=true
  fi

  # Build enforcement-annotated invariants array
  local annotated_invariants="[]"
  local inv_count
  inv_count=$(echo "$invariants" | jq 'length' 2>/dev/null || echo "0")
  local idx=0
  while [[ "$idx" -lt "$inv_count" ]]; do
    local inv_name
    inv_name=$(echo "$invariants" | jq -r ".[$idx]" 2>/dev/null)
    local enforcement="ASPIRATIONAL"

    case "$inv_name" in
      *no-explicit-any*|*no-any*|*no\ as\ any*)
        if [[ "$has_eslint" == true ]] && echo "$eslint_config_content" | grep -q 'no-explicit-any' 2>/dev/null; then
          enforcement="ENFORCED"
        elif [[ "$has_tsc_strict" == true ]]; then
          enforcement="ENFORCED"
        fi
        ;;
      *type-safety*|*strict-type*|*typescript-strict*)
        if [[ "$has_tsc_strict" == true ]]; then
          enforcement="ENFORCED"
        elif [[ "$has_mypy" == true || "$has_pyright" == true ]]; then
          enforcement="ENFORCED"
        fi
        ;;
      *monorepo-boundary*)
        # Check if there's an eslint rule for import boundaries
        if [[ "$has_eslint" == true ]] && echo "$eslint_config_content" | grep -qE '(import/no-relative-packages|boundaries/element-types|no-restricted-imports)' 2>/dev/null; then
          enforcement="ENFORCED"
        fi
        ;;
      *monetary-precision*|*transaction-atomicity*)
        # These are typically not enforced by linters
        enforcement="ASPIRATIONAL"
        ;;
      *no-raw-sql*)
        if [[ "$has_eslint" == true ]] && echo "$eslint_config_content" | grep -q 'no-raw-sql' 2>/dev/null; then
          enforcement="ENFORCED"
        fi
        ;;
      *)
        # Check if any linter rule name matches the invariant name
        if [[ "$has_eslint" == true ]] && echo "$eslint_config_content" | grep -qi "${inv_name}" 2>/dev/null; then
          enforcement="ENFORCED"
        elif [[ "$has_ruff" == true ]] && grep -qi "${inv_name}" "$TARGET_DIR/pyproject.toml" 2>/dev/null; then
          enforcement="ENFORCED"
        fi
        ;;
    esac

    annotated_invariants=$(echo "$annotated_invariants" | jq \
      --arg name "$inv_name" \
      --arg enf "$enforcement" \
      '. + [{"name": $name, "enforcement": $enf}]')

    idx=$((idx + 1))
  done

  MANIFEST=$(echo "$MANIFEST" | jq \
    --argjson domains "$domains" \
    --argjson invariants "$annotated_invariants" \
    --argjson security "$security_concerns" \
    --argjson cross_imports "$cross_package_imports" \
    --argjson principles "$core_principles" \
    --argjson comp_counts "$component_counts" \
    '. + {
      "domain": {
        "detected_domains": $domains,
        "invariants": $invariants,
        "security_concerns": ($security | unique),
        "cross_package_imports": $cross_imports,
        "core_principles": $principles,
        "component_counts": $comp_counts
      }
    }')

  set -eo pipefail

  local domain_names
  domain_names=$(echo "$domains" | jq -r '[.[].name] | join(", ")' 2>/dev/null)
  log_ok "Domains: ${domain_names:-none detected}"
}
