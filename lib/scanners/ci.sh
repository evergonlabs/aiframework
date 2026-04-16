#!/usr/bin/env bash
# Scanner: CI/CD & Deploy
# Discovers CI provider, workflows, deploy target from actual files

_ci_arr_to_json() {
  if [[ $# -eq 0 ]]; then echo "[]"; else printf '%s\n' "$@" | jq -R '.' | jq -s '.'; fi
}

scan_ci() {
  # Temporarily disable strict error mode — grep pipelines return non-zero when no matches
  set +eo pipefail

  local ci_provider="none"
  local ci_workflows="[]"
  local ci_coverage="[]"
  local ci_gaps="[]"
  local deploy_target="none"
  local deploy_trigger=""
  local deploy_registry=""
  local github_secrets="[]"

  # --- CI Provider Detection ---
  if [[ -d "$TARGET_DIR/.github/workflows" ]]; then
    ci_provider="github-actions"

    # Read each workflow file
    local workflows=()
    for wf in "$TARGET_DIR/.github/workflows"/*.yml "$TARGET_DIR/.github/workflows"/*.yaml; do
      [[ -f "$wf" ]] || continue
      local wf_name wf_triggers wf_jobs wf_basename

      wf_basename=$(basename "$wf")

      # Extract name
      wf_name=$(grep -m1 '^name:' "$wf" 2>/dev/null | sed 's/^name: *//' | tr -d '"'\''')
      [[ -z "$wf_name" ]] && wf_name="$wf_basename"

      # Extract triggers (on:)
      wf_triggers=$(awk '/^on:/{found=1; next} found && /^[^ ]/{exit} found{print}' "$wf" 2>/dev/null | grep -oE '^\s+\w+' | tr -d '[:space:]' | tr '\n' ',' | sed 's/,$//' || true)
      if [[ -z "$wf_triggers" ]]; then
        wf_triggers=$(grep -A1 '^on:' "$wf" 2>/dev/null | tail -1 | tr -d '[:space:]' | sed 's/:.*//' || true)
      fi

      # Extract job names
      wf_jobs=$(awk '/^jobs:/{found=1; next} found && /^[^ ]/{exit} found && /^  [a-zA-Z_-]+:/{print}' "$wf" 2>/dev/null | sed 's/:.*//' | tr -d ' ' | tr '\n' ',' | sed 's/,$//' || true)

      # Extract secrets
      local wf_secrets
      wf_secrets=$(grep -oE 'secrets\.[A-Z_]+' "$wf" 2>/dev/null | sort -u | sed 's/secrets\.//' | tr '\n' ',' | sed 's/,$//' || true)

      workflows+=("{\"file\": \"$wf_basename\", \"name\": \"$wf_name\", \"triggers\": \"$wf_triggers\", \"jobs\": \"$wf_jobs\", \"secrets\": \"$wf_secrets\"}")
    done

    if [[ ${#workflows[@]} -eq 0 ]]; then
      ci_workflows="[]"
    else
      ci_workflows=$(printf '%s\n' "${workflows[@]}" | jq -s '.' 2>/dev/null || echo "[]")
    fi

    # Collect all secrets
    github_secrets=$(grep -rhoE 'secrets\.[A-Z_]+' "$TARGET_DIR/.github/workflows/" 2>/dev/null | sort -u | sed 's/secrets\.//' | jq -R '.' | jq -s '.' 2>/dev/null || echo "[]")

  elif [[ -f "$TARGET_DIR/.gitlab-ci.yml" ]]; then
    ci_provider="gitlab-ci"
  elif [[ -f "$TARGET_DIR/.circleci/config.yml" ]]; then
    ci_provider="circleci"
  elif [[ -f "$TARGET_DIR/Jenkinsfile" ]]; then
    ci_provider="jenkins"
  elif [[ -f "$TARGET_DIR/.travis.yml" ]]; then
    ci_provider="travis"
  fi

  # --- CI Coverage Analysis ---
  local has_lint=false has_test=false has_build=false has_typecheck=false has_security=false
  if [[ "$ci_provider" == "github-actions" ]]; then
    local all_ci_content
    all_ci_content=$(cat "$TARGET_DIR/.github/workflows"/*.yml "$TARGET_DIR/.github/workflows"/*.yaml 2>/dev/null)
    echo "$all_ci_content" | grep -qiE 'lint|eslint|ruff|clippy|golint' && has_lint=true
    echo "$all_ci_content" | grep -qiE 'test|pytest|jest|vitest|cargo test|go test' && has_test=true
    echo "$all_ci_content" | grep -qiE 'build|compile|cargo build|go build' && has_build=true
    echo "$all_ci_content" | grep -qiE 'tsc|typecheck|type-check|mypy|pyright' && has_typecheck=true
    echo "$all_ci_content" | grep -qiE 'audit|snyk|trivy|security|dependabot' && has_security=true
  fi

  local coverage=()
  $has_lint && coverage+=("lint")
  $has_test && coverage+=("test")
  $has_build && coverage+=("build")
  $has_typecheck && coverage+=("typecheck")
  $has_security && coverage+=("security")
  ci_coverage=$(_ci_arr_to_json "${coverage[@]+"${coverage[@]}"}")

  local gaps=()
  $has_lint || gaps+=("lint")
  $has_test || gaps+=("test")
  $has_build || gaps+=("build")
  $has_typecheck || gaps+=("typecheck")
  $has_security || gaps+=("security")
  ci_gaps=$(_ci_arr_to_json "${gaps[@]+"${gaps[@]}"}")

  # --- Deploy Target Detection ---

  # Data-driven deploy target detection (single jq call for performance)
  local deploy_file="$ROOT_DIR/lib/data/deploy_targets.json"
  if [[ -f "$deploy_file" ]] && command -v jq &>/dev/null; then
    local deploy_checks
    deploy_checks=$(jq -r '.targets | to_entries[] | .key as $k | (.value.marker_files[]? // empty | "file \($k) \(.)"), (.value.marker_dirs[]? // empty | "dir \($k) \(.)")' "$deploy_file" 2>/dev/null || true)
    if [[ -n "$deploy_checks" ]]; then
      while IFS=' ' read -r check_type check_target check_path; do
        [[ -z "$check_type" ]] && continue
        if [[ "$check_type" == "file" && -f "$TARGET_DIR/$check_path" ]]; then
          deploy_target="$check_target"
          break
        elif [[ "$check_type" == "dir" && -d "$TARGET_DIR/$check_path" ]]; then
          deploy_target="$check_target"
          break
        fi
      done <<< "$deploy_checks"
    fi
  fi

  # Fallback to hardcoded detection if data-driven didn't find anything
  if [[ "$deploy_target" == "none" ]]; then
    if [[ -f "$TARGET_DIR/fly.toml" ]]; then
      deploy_target="fly.io"
    elif [[ -f "$TARGET_DIR/vercel.json" || -f "$TARGET_DIR/.vercel" ]]; then
      deploy_target="vercel"
    elif [[ -f "$TARGET_DIR/netlify.toml" ]]; then
      deploy_target="netlify"
    elif [[ -f "$TARGET_DIR/render.yaml" ]]; then
      deploy_target="render"
    elif [[ -f "$TARGET_DIR/appspec.yml" ]]; then
      deploy_target="aws-codedeploy"
    elif [[ -f "$TARGET_DIR/serverless.yml" || -f "$TARGET_DIR/serverless.yaml" ]]; then
      deploy_target="serverless"
    elif [[ -f "$TARGET_DIR/wrangler.toml" ]]; then
      deploy_target="cloudflare-workers"
    elif [[ -d "$TARGET_DIR/terraform" ]] || ls "$TARGET_DIR"/*.tf >/dev/null 2>&1; then
      deploy_target="terraform"
    elif [[ -d "$TARGET_DIR/k8s" || -d "$TARGET_DIR/kubernetes" || -d "$TARGET_DIR/helm" ]]; then
      deploy_target="kubernetes"
    elif [[ -f "$TARGET_DIR/Dockerfile" ]]; then
      deploy_target="docker"
    elif [[ -d "$TARGET_DIR/supabase" ]]; then
      deploy_target="supabase"
    elif [[ -f "$TARGET_DIR/firebase.json" ]]; then
      deploy_target="firebase"
    fi
  fi

  # --- E2B / Sandbox ---
  local has_e2b=false
  [[ -f "$TARGET_DIR/e2b.toml" ]] && has_e2b=true

  # --- Docker compose for local infra ---
  local compose_file=""
  for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    [[ -f "$TARGET_DIR/$f" ]] && compose_file="$f" && break
  done

  MANIFEST=$(echo "$MANIFEST" | jq \
    --arg provider "$ci_provider" \
    --argjson workflows "$ci_workflows" \
    --argjson coverage "$ci_coverage" \
    --argjson gaps "$ci_gaps" \
    --arg deploy "$deploy_target" \
    --arg trigger "$deploy_trigger" \
    --arg registry "$deploy_registry" \
    --argjson secrets "$github_secrets" \
    --argjson e2b "$has_e2b" \
    --arg compose "$compose_file" \
    '. + {
      "ci": {
        "provider": $provider,
        "workflows": $workflows,
        "coverage": $coverage,
        "gaps": $gaps,
        "deploy_target": $deploy,
        "deploy_trigger": ($trigger | if . == "" then null else . end),
        "deploy_registry": ($registry | if . == "" then null else . end),
        "github_secrets": $secrets,
        "has_e2b": $e2b,
        "compose_file": ($compose | if . == "" then null else . end)
      }
    }')

  # Restore strict mode
  set -eo pipefail

  log_ok "CI: $ci_provider, deploy: $deploy_target, coverage: ${coverage[*]:-none}"
}
