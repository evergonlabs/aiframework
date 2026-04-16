#!/usr/bin/env bash
# Scanner: Project Identity
# Discovers project name, description, version from actual files

scan_identity() {
  local name=""
  local description=""
  local version=""

  # --- Name ---
  # Priority: (1) repo directory name, (2) package.json name, (3) Cargo.toml name
  name="$(basename "$TARGET_DIR")"

  if [[ -f "$TARGET_DIR/package.json" ]]; then
    local pkg_name
    pkg_name=$(jq -r '.name // empty' "$TARGET_DIR/package.json" 2>/dev/null)
    [[ -n "$pkg_name" ]] && name="$pkg_name"
  fi

  if [[ -f "$TARGET_DIR/Cargo.toml" ]]; then
    local cargo_name
    cargo_name=$(grep -m1 '^name' "$TARGET_DIR/Cargo.toml" 2>/dev/null | sed 's/name *= *"\(.*\)"/\1/' || true)
    [[ -n "$cargo_name" ]] && name="$cargo_name"
  fi

  if [[ -f "$TARGET_DIR/pyproject.toml" ]]; then
    local py_name
    py_name=$(grep -m1 '^name' "$TARGET_DIR/pyproject.toml" 2>/dev/null | sed 's/name *= *"\(.*\)"/\1/' || true)
    [[ -n "$py_name" ]] && name="$py_name"
  fi

  if [[ -f "$TARGET_DIR/go.mod" ]]; then
    local go_mod
    go_mod=$(head -1 "$TARGET_DIR/go.mod" | awk '{print $2}' 2>/dev/null)
    [[ -n "$go_mod" ]] && name="$(basename "$go_mod")"
  fi

  # Fallback: Parse Gemfile for project name (infer from gem spec or directory)
  if [[ "$name" == "$(basename "$TARGET_DIR")" && -f "$TARGET_DIR/Gemfile" ]]; then
    local gem_name
    gem_name=$(grep -m1 "gemspec" "$TARGET_DIR/Gemfile" 2>/dev/null)
    if [[ -n "$gem_name" ]]; then
      # If gemspec is referenced, look for .gemspec file
      local gemspec_file
      gemspec_file=$(ls "$TARGET_DIR"/*.gemspec 2>/dev/null | head -1)
      if [[ -n "$gemspec_file" ]]; then
        local spec_name
        spec_name=$(grep -m1 '\.name' "$gemspec_file" 2>/dev/null | grep -oE '"[^"]*"|'\''[^'\'']*'\''' | tr -d '\"'\''' || true)
        [[ -n "$spec_name" ]] && name="$spec_name"
      fi
    fi
  fi

  # --- Docker image name from Makefile ---
  local docker_image_name=""
  if [[ -f "$TARGET_DIR/Makefile" ]]; then
    docker_image_name=$(grep -oE 'docker build\s+.*-t\s+([^ ]+)' "$TARGET_DIR/Makefile" 2>/dev/null | grep -oE '\-t\s+([^ ]+)' | sed 's/-t\s*//' | head -1 || true)
    [[ -z "$docker_image_name" ]] && docker_image_name=$(grep -oE 'docker\s+build\s+.*-t\s+([^ ]+)' "$TARGET_DIR/Makefile" 2>/dev/null | grep -oE '\-t\s+\S+' | sed 's/-t //' | head -1 || true)
  fi

  # Docker image name from CI workflows
  if [[ -z "$docker_image_name" && -d "$TARGET_DIR/.github/workflows" ]]; then
    docker_image_name=$(grep -rhE 'docker\s+build\s+.*-t\s+' "$TARGET_DIR/.github/workflows/" 2>/dev/null | grep -oE '\-t\s+\S+' | sed 's/-t //' | head -1 || true)
  fi
  if [[ -z "$docker_image_name" && -d "$TARGET_DIR/.github/workflows" ]]; then
    docker_image_name=$(grep -rhE 'image:\s*\S+' "$TARGET_DIR/.github/workflows/" 2>/dev/null | grep -v 'actions/' | grep -v 'ubuntu' | grep -v 'node:' | sed 's/.*image:\s*//' | head -1 || true)
  fi

  # --- Description ---
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    description=$(jq -r '.description // empty' "$TARGET_DIR/package.json" 2>/dev/null)
  fi

  if [[ -z "$description" && -f "$TARGET_DIR/pyproject.toml" ]]; then
    description=$(grep -m1 '^description' "$TARGET_DIR/pyproject.toml" 2>/dev/null | sed 's/description *= *"\(.*\)"/\1/' || true)
  fi

  if [[ -z "$description" && -f "$TARGET_DIR/Cargo.toml" ]]; then
    description=$(grep -m1 '^description' "$TARGET_DIR/Cargo.toml" 2>/dev/null | sed 's/description *= *"\(.*\)"/\1/' || true)
  fi

  if [[ -z "$description" && -f "$TARGET_DIR/README.md" ]]; then
    # First non-heading, non-empty, non-HTML, non-code-block paragraph
    description=$(awk '
      /^```/   { in_code=!in_code; next }
      in_code  { next }
      /^#/     { next }
      /^\[/    { next }
      /^<[a-zA-Z]/ { next }
      /^[>*_~`|-]/ && length < 3 { next }
      /^\s*$/ { next }
      NF { gsub(/^[>*_ ]+/, ""); gsub(/[*_]+$/, ""); gsub(/\*\*/, ""); print; exit }
    ' "$TARGET_DIR/README.md" 2>/dev/null)
  fi

  [[ -z "$description" ]] && description="NOT_FOUND"

  # --- Version ---
  if [[ -f "$TARGET_DIR/package.json" ]]; then
    version=$(jq -r '.version // empty' "$TARGET_DIR/package.json" 2>/dev/null)
  fi

  if [[ -z "$version" && -f "$TARGET_DIR/pyproject.toml" ]]; then
    version=$(grep -m1 '^version' "$TARGET_DIR/pyproject.toml" 2>/dev/null | sed 's/version *= *"\(.*\)"/\1/' || true)
  fi

  if [[ -z "$version" && -f "$TARGET_DIR/Cargo.toml" ]]; then
    version=$(grep -m1 '^version' "$TARGET_DIR/Cargo.toml" 2>/dev/null | sed 's/version *= *"\(.*\)"/\1/' || true)
  fi

  if [[ -z "$version" && -f "$TARGET_DIR/VERSION" ]]; then
    version=$(cat "$TARGET_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')
  fi

  [[ -z "$version" ]] && version="0.1.0"

  # --- Short name (kebab-case slug) ---
  local short_name
  short_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

  # --- Dockerfile info ---
  local dockerfile_base=""
  local dockerfile_port=""
  if [[ -f "$TARGET_DIR/Dockerfile" ]]; then
    dockerfile_base=$(grep -m1 '^FROM' "$TARGET_DIR/Dockerfile" 2>/dev/null | awk '{print $2}' || true)
    dockerfile_port=$(grep -m1 'EXPOSE' "$TARGET_DIR/Dockerfile" 2>/dev/null | awk '{print $2}' || true)
  fi

  # --- Docker Compose services ---
  local compose_services="[]"
  if [[ -f "$TARGET_DIR/docker-compose.yml" || -f "$TARGET_DIR/docker-compose.yaml" || -f "$TARGET_DIR/compose.yml" || -f "$TARGET_DIR/compose.yaml" ]]; then
    local compose_file=""
    for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
      [[ -f "$TARGET_DIR/$f" ]] && compose_file="$TARGET_DIR/$f" && break
    done
    if [[ -n "$compose_file" ]]; then
      # Extract service names from docker-compose
      compose_services=$(grep -E '^\s{2}\w+:' "$compose_file" 2>/dev/null | sed 's/:.*//' | sed 's/^ *//' | jq -R '.' | jq -s '.' 2>/dev/null || true)
      [[ -z "$compose_services" || "$compose_services" == "null" ]] && compose_services="[]"
    fi
  fi

  MANIFEST=$(echo "$MANIFEST" | jq \
    --arg name "$name" \
    --arg desc "$description" \
    --arg ver "$version" \
    --arg short "$short_name" \
    --arg docker_base "$dockerfile_base" \
    --arg docker_port "$dockerfile_port" \
    --arg docker_img "$docker_image_name" \
    --argjson compose "$compose_services" \
    '. + {
      "identity": {
        "name": $name,
        "description": $desc,
        "version": $ver,
        "short_name": $short,
        "dockerfile": {
          "base_image": ($docker_base | if . == "" then null else . end),
          "port": ($docker_port | if . == "" then null else . end)
        },
        "docker_image_name": ($docker_img | if . == "" then null else . end),
        "compose_services": $compose
      }
    }')

  log_ok "Identity: $name v$version ($short_name)"
}
