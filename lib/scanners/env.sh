#!/usr/bin/env bash
# Scanner: Environment Variables
# Discovers env vars from .env.example, config files, Dockerfile, docker-compose, CI

scan_env() {
  set +eo pipefail
  local env_vars="[]"
  local env_source="none"

  # --- Priority 1: Typed config files (Zod, Pydantic) ---
  local typed_config=""
  for f in src/config.ts src/env.ts config/env.ts src/config.py config.py src/settings.py app/config.py app/settings.py; do
    if [[ -f "$TARGET_DIR/$f" ]]; then
      typed_config="$f"
      break
    fi
  done

  if [[ -n "$typed_config" ]]; then
    env_source="typed_config:$typed_config"
    # Extract env var names from typed config
    # Look for patterns like: process.env.VAR_NAME, os.environ["VAR_NAME"], env("VAR_NAME")
    local config_vars
    config_vars=$(grep -oE '(process\.env\.[A-Z_][A-Z0-9_]*|os\.environ\[."[A-Z_][A-Z0-9_]*".\]|env\(."[A-Z_][A-Z0-9_]*".\)|getenv\(."[A-Z_][A-Z0-9_]*".\)|[A-Z_][A-Z0-9_]*\s*:\s*(z\.|str|int|bool|Field))' "$TARGET_DIR/$typed_config" 2>/dev/null | \
      grep -oE '[A-Z_][A-Z0-9_]+' | sort -u)

    while IFS= read -r var; do
      [[ -z "$var" ]] && continue
      env_vars=$(echo "$env_vars" | jq --arg name "$var" --arg src "$typed_config" \
        '. + [{"name": $name, "source": $src, "required": true, "default": null, "description": null}]')
    done <<< "$config_vars"
  fi

  # --- Priority 2: .env.example / .env.template / .env.sample ---
  local env_example=""
  for f in .env.example .env.template .env.sample; do
    [[ -f "$TARGET_DIR/$f" ]] && env_example="$f" && break
  done

  if [[ -n "$env_example" ]]; then
    [[ "$env_source" == "none" ]] && env_source="$env_example"

    while IFS= read -r line; do
      # Skip comments and empty lines
      [[ -z "$line" || "$line" =~ ^# ]] && continue

      local var_name var_default
      var_name=$(echo "$line" | cut -d= -f1 | tr -d '[:space:]')
      var_default=$(echo "$line" | cut -d= -f2- | tr -d '"'\''' | tr -d '[:space:]')

      [[ -z "$var_name" ]] && continue
      # Skip if it's not an env var pattern
      [[ ! "$var_name" =~ ^[A-Z_][A-Z0-9_]*$ ]] && continue

      # Check if already found from typed config
      local already_found
      already_found=$(echo "$env_vars" | jq --arg name "$var_name" '[.[] | select(.name == $name)] | length')
      if [[ "$already_found" == "0" ]]; then
        local required="true"
        [[ -n "$var_default" && "$var_default" != "your-"* && "$var_default" != "xxx"* && "$var_default" != "CHANGE"* ]] && required="false"

        env_vars=$(echo "$env_vars" | jq --arg name "$var_name" --arg src "$env_example" \
          --arg default "$var_default" --argjson req "$required" \
          '. + [{"name": $name, "source": $src, "required": $req, "default": ($default | if . == "" then null else . end), "description": null}]')
      fi
    done < "$TARGET_DIR/$env_example"
  fi

  # --- Priority 3: Dockerfile ENV/ARG ---
  if [[ -f "$TARGET_DIR/Dockerfile" ]]; then
    local docker_vars
    docker_vars=$(grep -E '^(ENV|ARG)\s+[A-Z_]' "$TARGET_DIR/Dockerfile" 2>/dev/null | \
      awk '{print $2}' | cut -d= -f1 | sort -u)

    while IFS= read -r var; do
      [[ -z "$var" ]] && continue
      local already_found
      already_found=$(echo "$env_vars" | jq --arg name "$var" '[.[] | select(.name == $name)] | length')
      if [[ "$already_found" == "0" ]]; then
        env_vars=$(echo "$env_vars" | jq --arg name "$var" \
          '. + [{"name": $name, "source": "Dockerfile", "required": false, "default": null, "description": null}]')
      fi
    done <<< "$docker_vars"
  fi

  # --- Priority 4: Docker Compose environment ---
  local compose_file=""
  for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
    [[ -f "$TARGET_DIR/$f" ]] && compose_file="$f" && break
  done

  if [[ -n "$compose_file" ]]; then
    local compose_vars
    compose_vars=$(grep -oE '\$\{[A-Z_][A-Z0-9_]*' "$TARGET_DIR/$compose_file" 2>/dev/null | sed 's/\${//' | sort -u)

    while IFS= read -r var; do
      [[ -z "$var" ]] && continue
      local already_found
      already_found=$(echo "$env_vars" | jq --arg name "$var" '[.[] | select(.name == $name)] | length')
      if [[ "$already_found" == "0" ]]; then
        env_vars=$(echo "$env_vars" | jq --arg name "$var" --arg src "$compose_file" \
          '. + [{"name": $name, "source": $src, "required": false, "default": null, "description": null}]')
      fi
    done <<< "$compose_vars"
  fi

  # --- Priority 5: CI secrets references ---
  if [[ -d "$TARGET_DIR/.github/workflows" ]]; then
    local ci_env_vars
    ci_env_vars=$(grep -rhoE 'env\.[A-Z_][A-Z0-9_]*' "$TARGET_DIR/.github/workflows/" 2>/dev/null | sed 's/env\.//' | sort -u)

    while IFS= read -r var; do
      [[ -z "$var" ]] && continue
      local already_found
      already_found=$(echo "$env_vars" | jq --arg name "$var" '[.[] | select(.name == $name)] | length')
      if [[ "$already_found" == "0" ]]; then
        env_vars=$(echo "$env_vars" | jq --arg name "$var" \
          '. + [{"name": $name, "source": "ci-workflow", "required": false, "default": null, "description": null}]')
      fi
    done <<< "$ci_env_vars"
  fi

  # --- Priority 6: Makefile --secret flags in docker build commands ---
  if [[ -f "$TARGET_DIR/Makefile" ]]; then
    local makefile_secrets
    makefile_secrets=$(grep -oE '\-\-secret\s+id=[A-Za-z_][A-Za-z0-9_]*' "$TARGET_DIR/Makefile" 2>/dev/null | \
      sed 's/--secret id=//' | sort -u)

    while IFS= read -r secret_name; do
      [[ -z "$secret_name" ]] && continue
      # Convert to uppercase env var convention
      local env_name
      env_name=$(echo "$secret_name" | tr '[:lower:]' '[:upper:]')
      local already_found
      already_found=$(echo "$env_vars" | jq --arg name "$env_name" '[.[] | select(.name == $name)] | length')
      if [[ "$already_found" == "0" ]]; then
        env_vars=$(echo "$env_vars" | jq --arg name "$env_name" --arg orig "$secret_name" \
          '. + [{"name": $name, "source": "Makefile (build-time secret)", "required": true, "default": null, "description": ("Docker build secret: " + $orig)}]')
      fi
    done <<< "$makefile_secrets"
  fi

  # --- Check for NEXT_PUBLIC_ vars (frontend scope) ---
  local has_public_env=false
  if echo "$env_vars" | jq -e '[.[] | select(.name | startswith("NEXT_PUBLIC_"))] | length > 0' >/dev/null 2>&1; then
    has_public_env=true
  fi

  local var_count
  var_count=$(echo "$env_vars" | jq 'length')

  MANIFEST=$(echo "$MANIFEST" | jq \
    --argjson vars "$env_vars" \
    --arg source "$env_source" \
    --argjson has_public "$has_public_env" \
    '. + {
      "env": {
        "variables": $vars,
        "source": $source,
        "has_public_env": $has_public
      }
    }')

  set -eo pipefail
  log_ok "Env vars: $var_count found (source: $env_source)"
}
