#!/usr/bin/env bash
# Scanner: archetype — classifies repos into archetypes
# Reads from $MANIFEST (which already has stack, structure, domain data)
# Writes 'archetype' key to $MANIFEST via jq

scan_archetype() {
  local m="$MANIFEST"
  local lang
  # shellcheck disable=SC2034
  lang=$(echo "$m" | jq -r '.stack.language')
  local fw
  fw=$(echo "$m" | jq -r '.stack.framework // "none"')
  local has_frontend
  has_frontend=$(echo "$m" | jq '[.domain.detected_domains[]? | select(.name == "frontend")] | length > 0')
  local has_api
  has_api=$(echo "$m" | jq '[.domain.detected_domains[]? | select(.name == "api")] | length > 0')
  local has_db
  # shellcheck disable=SC2034
  has_db=$(echo "$m" | jq '[.domain.detected_domains[]? | select(.name == "database")] | length > 0')
  local is_mono
  is_mono=$(echo "$m" | jq -r '.stack.is_monorepo')
  local total_files
  total_files=$(echo "$m" | jq -r '.structure.total_files // 0')
  local has_tests
  # shellcheck disable=SC2034
  has_tests=$(echo "$m" | jq '[.structure.test_dirs[]?] | length > 0')
  local entry_points
  entry_points=$(echo "$m" | jq -r '.structure.entry_points | length')

  # Classification logic
  local archetype="unknown"
  local maturity="unknown"
  local complexity="simple"

  # Monorepo takes priority
  if [[ "$is_mono" == "true" ]]; then
    archetype="monorepo"
  # Data pipeline: airflow, dagster, dbt, prefect in dependencies
  elif echo "$m" | jq -e '.stack.key_dependencies[]? | select(test("airflow|dagster|dbt|prefect|luigi"))' &>/dev/null; then
    archetype="data-pipeline"
  # ML project: pytorch, tensorflow, scikit-learn, transformers
  elif echo "$m" | jq -e '.stack.key_dependencies[]? | select(test("torch|tensorflow|scikit|transformers|keras"))' &>/dev/null; then
    archetype="ml-project"
  # Mobile: react-native, flutter, expo
  elif echo "$m" | jq -e '.stack.key_dependencies[]? | select(test("react-native|flutter|expo"))' &>/dev/null; then
    archetype="mobile-app"
  # Full-stack: both frontend and API domains
  elif [[ "$has_frontend" == "true" && "$has_api" == "true" ]]; then
    archetype="full-stack"
  # Web app: frontend domain, no API
  elif [[ "$has_frontend" == "true" ]]; then
    archetype="web-app"
  # API service: API domain, no frontend
  elif [[ "$has_api" == "true" ]]; then
    archetype="api-service"
  # Web app: web framework detected (Next.js, Nuxt, SvelteKit, etc.)
  elif echo "$m" | jq -e '.stack.framework // "none" | test("next|nuxt|svelte|remix|gatsby|angular|vue")' &>/dev/null; then
    archetype="web-app"
  # CLI tool: bin/ directory, no web framework
  elif echo "$m" | jq -e '.structure.script_dirs[]? | select(test("^bin"))' &>/dev/null && [[ "$fw" == "none" ]]; then
    archetype="cli-tool"
  # Library: no entry points (or only index), no web framework, has package publish config
  elif [[ "$entry_points" -le 1 ]] && [[ "$total_files" -gt 5 ]] && [[ "$fw" == "none" ]]; then
    archetype="library"
  # Documentation site: mostly markdown, docusaurus/vitepress/mkdocs/hugo
  elif echo "$m" | jq -e '.stack.key_dependencies[]? | select(test("docusaurus|vitepress|mkdocs|hugo|gatsby|eleventy|astro"))' &>/dev/null; then
    archetype="documentation-site"
  elif [[ "$total_files" -gt 3 ]]; then
    # Check if >50% of files are .md/.mdx
    local md_count
    md_count=$(find "$TARGET_DIR" -maxdepth 3 -name "*.md" -o -name "*.mdx" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$md_count" -gt 0 ]] && [[ $((md_count * 2)) -gt "$total_files" ]]; then
      archetype="documentation-site"
    fi
  # Infrastructure: mostly IaC files
  elif echo "$m" | jq -e '.structure.config_files[]? | select(test("terraform|pulumi|cdk|ansible"))' &>/dev/null; then
    archetype="infrastructure"
  fi

  # Final fallback — classify by file count
  if [[ "$archetype" == "unknown" ]]; then
    if [[ "$total_files" -lt 5 ]]; then
      archetype="minimal"
    else
      archetype="application"
    fi
  fi

  # Maturity detection from git
  local commit_count
  commit_count=$(cd "$TARGET_DIR" && git rev-list --count HEAD 2>/dev/null || echo "0")
  local has_ci
  has_ci=$(echo "$m" | jq -r '.ci.provider != "none"')
  local has_quality_tools
  has_quality_tools=$(echo "$m" | jq '[.quality | to_entries[] | select(.value | type == "object" and .configured == true)] | length')

  if [[ "$commit_count" -lt 20 ]]; then
    maturity="greenfield"
  elif [[ "$has_ci" == "true" ]] && [[ "$has_quality_tools" -ge 3 ]]; then
    maturity="mature"
  elif [[ "$has_ci" == "true" ]]; then
    maturity="active"
  else
    maturity="established"
  fi

  # Complexity
  if [[ "$total_files" -lt 20 ]]; then
    complexity="simple"
  elif [[ "$total_files" -lt 100 ]]; then
    complexity="moderate"
  elif [[ "$total_files" -lt 500 ]]; then
    complexity="complex"
  else
    complexity="enterprise"
  fi

  MANIFEST=$(echo "$MANIFEST" | jq \
    --arg arch "$archetype" \
    --arg mat "$maturity" \
    --arg comp "$complexity" \
    '. + { "archetype": { "type": $arch, "maturity": $mat, "complexity": $comp } }')
}
