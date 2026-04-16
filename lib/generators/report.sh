#!/usr/bin/env bash
# Generator: Report
# Produces a human-readable markdown report of everything aiframework detected
# and generated. Written to TARGET_DIR/.aiframework/report.md
#
# Purpose: Let the developer verify that aiframework understood their project
# correctly, and provide feedback on anything that's wrong.

generate_report() {
  local m="$MANIFEST"
  local report="$TARGET_DIR/.aiframework/report.md"
  local today
  today=$(date +%Y-%m-%d)

  mkdir -p "$TARGET_DIR/.aiframework"

  # --- Header ---
  cat > "$report" << HEADER
# aiframework Report

> Generated: ${today} | aiframework v$(cat "$ROOT_DIR/VERSION")
> Target: \`${TARGET_DIR}\`

**Review this report to verify aiframework understood your project correctly.**
If anything is wrong, run \`/aif-feedback\` in Claude Code or edit the manifest directly.

---

HEADER

  # --- 1. Project Identity ---
  local name desc lang fw version arch_type arch_maturity complexity
  name=$(echo "$m" | jq -r '.identity.name // "unknown"')
  desc=$(echo "$m" | jq -r '.identity.description // "No description"')
  lang=$(echo "$m" | jq -r '.stack.language // "unknown"')
  fw=$(echo "$m" | jq -r '.stack.framework // "none"')
  version=$(echo "$m" | jq -r '.identity.version // "0.1.0"')
  arch_type=$(echo "$m" | jq -r '.archetype.type // "unknown"')
  arch_maturity=$(echo "$m" | jq -r '.archetype.maturity // "unknown"')
  complexity=$(echo "$m" | jq -r '.archetype.complexity // "unknown"')

  cat >> "$report" << IDENTITY
## 1. Project Identity

| Field | Detected Value |
|-------|---------------|
| Name | **${name}** |
| Description | ${desc} |
| Version | ${version} |
| Language | ${lang} |
| Framework | ${fw} |
| Archetype | ${arch_type} |
| Maturity | ${arch_maturity} |
| Complexity | ${complexity} |

IDENTITY

  # Languages array
  local languages
  languages=$(echo "$m" | jq -r '.stack.languages // [] | join(", ")' 2>/dev/null)
  if [[ -n "$languages" ]]; then
    echo "**Languages detected**: ${languages}" >> "$report"
    echo "" >> "$report"
  fi

  # Key deps
  local key_deps
  key_deps=$(echo "$m" | jq -r '.stack.key_dependencies // [] | join(", ")' 2>/dev/null)
  if [[ -n "$key_deps" && "$key_deps" != "" ]]; then
    echo "**Key dependencies**: ${key_deps}" >> "$report"
    echo "" >> "$report"
  fi

  # Monorepo
  local is_mono
  is_mono=$(echo "$m" | jq -r '.stack.is_monorepo // false')
  if [[ "$is_mono" == "true" ]]; then
    echo "**Monorepo**: Yes" >> "$report"
    local apps libs
    apps=$(echo "$m" | jq -r '.stack.monorepo_apps // [] | join(", ")' 2>/dev/null)
    libs=$(echo "$m" | jq -r '.stack.monorepo_libs // [] | join(", ")' 2>/dev/null)
    [[ -n "$apps" ]] && echo "  - Apps: ${apps}" >> "$report"
    [[ -n "$libs" ]] && echo "  - Libs: ${libs}" >> "$report"
    echo "" >> "$report"
  fi

  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 2. Commands ---
  cat >> "$report" << 'CMDS_HEADER'
## 2. Detected Commands

| Command | Value | Status |
|---------|-------|--------|
CMDS_HEADER

  local cmd_fields=("install" "dev" "build" "lint" "typecheck" "test" "format")
  local cmd_labels=("Install" "Dev" "Build" "Lint" "Type check" "Test" "Format")
  for i in "${!cmd_fields[@]}"; do
    local val
    val=$(echo "$m" | jq -r ".commands.${cmd_fields[$i]} // \"NOT_CONFIGURED\"")
    local status_icon
    if [[ "$val" == "NOT_CONFIGURED" ]]; then
      status_icon="not configured"
    else
      status_icon="detected"
    fi
    echo "| ${cmd_labels[$i]} | \`${val}\` | ${status_icon} |" >> "$report"
  done

  local dev_port
  dev_port=$(echo "$m" | jq -r '.commands.dev_port // empty')
  if [[ -n "$dev_port" ]]; then
    echo "| Dev Port | \`${dev_port}\` | detected |" >> "$report"
  fi

  local pkg_mgr
  pkg_mgr=$(echo "$m" | jq -r '.commands.package_manager // empty')
  if [[ -n "$pkg_mgr" ]]; then
    echo "| Package Manager | \`${pkg_mgr}\` | detected |" >> "$report"
  fi

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 3. Domains ---
  local domain_count
  domain_count=$(echo "$m" | jq '.domain.detected_domains | length' 2>/dev/null || echo "0")

  echo "## 3. Detected Domains (${domain_count})" >> "$report"
  echo "" >> "$report"

  if [[ "$domain_count" -gt 0 ]]; then
    echo "| Domain | Trigger Files | Details |" >> "$report"
    echo "|--------|--------------|---------|" >> "$report"
    echo "$m" | jq -r '.domain.detected_domains[] | "| \(.display) | \(.paths[:3] | join(", ")) | \(.orm // .detail // "-") |"' 2>/dev/null >> "$report" || true
  else
    echo "*No domains detected. This is normal for simple utility projects.*" >> "$report"
  fi

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 4. Directory Structure ---
  echo "## 4. Directory Structure" >> "$report"
  echo "" >> "$report"
  echo '```' >> "$report"
  echo "$m" | jq -r '.structure.directories[]' 2>/dev/null | while IFS= read -r dir; do
    echo "  ${dir}/"
  done >> "$report"
  echo '```' >> "$report"
  echo "" >> "$report"

  # Config files
  local config_files
  config_files=$(echo "$m" | jq -r '.structure.config_files // [] | join(", ")' 2>/dev/null)
  if [[ -n "$config_files" ]]; then
    echo "**Config files**: ${config_files}" >> "$report"
    echo "" >> "$report"
  fi

  # Entry points
  local entry_points
  entry_points=$(echo "$m" | jq -r '.structure.entry_points // [] | join(", ")' 2>/dev/null)
  if [[ -n "$entry_points" ]]; then
    echo "**Entry points**: ${entry_points}" >> "$report"
    echo "" >> "$report"
  fi

  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 5. Environment Variables ---
  local env_count
  env_count=$(echo "$m" | jq '.env.variables | length' 2>/dev/null || echo "0")

  echo "## 5. Environment Variables (${env_count})" >> "$report"
  echo "" >> "$report"

  if [[ "$env_count" -gt 0 ]]; then
    echo "| Variable | Required | Description |" >> "$report"
    echo "|----------|----------|-------------|" >> "$report"
    echo "$m" | jq -r '.env.variables[] | "| `\(.name)` | \(if .required then "Yes" else "No" end) | \(.description // "-") |"' 2>/dev/null >> "$report"
  else
    echo "*No environment variables found. If your project uses .env files, create a .env.example.*" >> "$report"
  fi

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 6. CI/CD ---
  local ci_provider deploy_target
  ci_provider=$(echo "$m" | jq -r '.ci.provider // "none"')
  deploy_target=$(echo "$m" | jq -r '.ci.deploy_target // "none"')

  echo "## 6. CI/CD" >> "$report"
  echo "" >> "$report"
  echo "| Field | Value |" >> "$report"
  echo "|-------|-------|" >> "$report"
  echo "| CI Provider | ${ci_provider} |" >> "$report"
  echo "| Deploy Target | ${deploy_target} |" >> "$report"

  local workflow_count
  workflow_count=$(echo "$m" | jq '.ci.workflows | length' 2>/dev/null || echo "0")
  if [[ "$workflow_count" -gt 0 ]]; then
    echo "" >> "$report"
    echo "**Workflows**:" >> "$report"
    echo "$m" | jq -r '.ci.workflows[] | "- `\(.file)` — \(.purpose // "unknown")"' 2>/dev/null >> "$report"
  fi

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 7. Quality Tools ---
  echo "## 7. Quality Tools" >> "$report"
  echo "" >> "$report"

  local quality_tools
  quality_tools=$(echo "$m" | jq -r '[.quality | to_entries[] | select(.value.configured == true) | .key] | join(", ")' 2>/dev/null || echo "none")

  if [[ -n "$quality_tools" && "$quality_tools" != "none" ]]; then
    echo "**Configured**: ${quality_tools}" >> "$report"
  else
    echo "*No quality tools detected.*" >> "$report"
  fi

  local missing_tools
  missing_tools=$(echo "$m" | jq -r '.quality.missing_tools // [] | join(", ")' 2>/dev/null)
  if [[ -n "$missing_tools" ]]; then
    echo "" >> "$report"
    echo "**Missing (recommended)**: ${missing_tools}" >> "$report"
  fi

  # Test info
  local test_tool test_count
  test_tool=$(echo "$m" | jq -r '.quality.test_framework.tool // empty')
  test_count=$(echo "$m" | jq -r '.structure.test_file_count // 0' 2>/dev/null || echo "0")
  if [[ -n "$test_tool" ]]; then
    echo "" >> "$report"
    echo "**Test framework**: ${test_tool} (${test_count} test files)" >> "$report"
  fi

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 8. Code Index ---
  local index_file="$TARGET_DIR/.aiframework/code-index.json"
  echo "## 8. Code Index" >> "$report"
  echo "" >> "$report"

  if [[ -f "$index_file" ]]; then
    local total_files total_symbols total_edges module_count
    total_files=$(jq '._meta.total_files // 0' "$index_file" 2>/dev/null)
    total_symbols=$(jq '._meta.total_symbols // 0' "$index_file" 2>/dev/null)
    total_edges=$(jq '.edges | length' "$index_file" 2>/dev/null || echo "0")
    module_count=$(jq '.modules | length' "$index_file" 2>/dev/null || echo "0")

    echo "| Metric | Count |" >> "$report"
    echo "|--------|-------|" >> "$report"
    echo "| Files indexed | ${total_files} |" >> "$report"
    echo "| Symbols extracted | ${total_symbols} |" >> "$report"
    echo "| Import edges | ${total_edges} |" >> "$report"
    echo "| Modules | ${module_count} |" >> "$report"

    # Top files
    local top_files
    top_files=$(jq -r '._meta.top_files // [] | .[:5][] | "- `\(.[0])`"' "$index_file" 2>/dev/null)
    if [[ -n "$top_files" ]]; then
      echo "" >> "$report"
      echo "**Most important files** (by dependency count):" >> "$report"
      echo "$top_files" >> "$report"
    fi

    # Circular deps
    local circular
    circular=$(jq -r '._meta.circular_deps // [] | length' "$index_file" 2>/dev/null || echo "0")
    if [[ "$circular" -gt 0 ]]; then
      echo "" >> "$report"
      echo "**Circular dependencies**: ${circular} detected" >> "$report"
    fi
  else
    echo "*No code index found. Run with \`--no-index\` disabled to generate.*" >> "$report"
  fi

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 9. Generated Files ---
  echo "## 9. Generated Files" >> "$report"
  echo "" >> "$report"
  echo "| File | Status |" >> "$report"
  echo "|------|--------|" >> "$report"

  local gen_files=(
    "CLAUDE.md"
    "AGENTS.md"
    ".claude/rules/workflow.md"
    ".claude/settings.json"
    ".githooks/pre-commit"
    ".githooks/pre-push"
    ".github/workflows/ci.yml"
    "CHANGELOG.md"
    "VERSION"
    "STATUS.md"
    "SETUP-DEV.md"
    "CONTRIBUTING.md"
    "docs/README.md"
    "vault/wiki/index.md"
    "vault/memory/status.md"
  )

  local short
  short=$(echo "$m" | jq -r '.identity.short_name')
  gen_files+=(".claude/skills/${short}-review/SKILL.md")
  gen_files+=(".claude/skills/${short}-ship/SKILL.md")
  gen_files+=("tools/learnings/${short}-learnings.jsonl")

  for f in "${gen_files[@]}"; do
    if [[ -f "$TARGET_DIR/$f" ]]; then
      local lines
      lines=$(wc -l < "$TARGET_DIR/$f" 2>/dev/null | tr -d '[:space:]')
      echo "| \`${f}\` | created (${lines} lines) |" >> "$report"
    else
      echo "| \`${f}\` | not created |" >> "$report"
    fi
  done

  # Count vault files
  local vault_file_count
  vault_file_count=$(find "$TARGET_DIR/vault" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
  echo "| \`vault/\` (total) | ${vault_file_count} files |" >> "$report"

  # Review specialists
  local specialist_count
  specialist_count=$(ls "$TARGET_DIR/tools/review-specialists/"*.md 2>/dev/null | wc -l | tr -d '[:space:]')
  echo "| \`tools/review-specialists/\` | ${specialist_count} specialists |" >> "$report"

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 10. Invariants Generated ---
  echo "## 10. Invariants" >> "$report"
  echo "" >> "$report"

  if [[ -f "$TARGET_DIR/CLAUDE.md" ]]; then
    local inv_lines
    inv_lines=$(grep -E '### INV-' "$TARGET_DIR/CLAUDE.md" 2>/dev/null)
    if [[ -n "$inv_lines" ]]; then
      while IFS= read -r inv; do
        local inv_id inv_title
        inv_id=$(echo "$inv" | grep -oE 'INV-[0-9]+')
        inv_title=$(echo "$inv" | sed 's/### INV-[0-9]*: //')
        echo "- **${inv_id}**: ${inv_title}" >> "$report"
      done <<< "$inv_lines"
    else
      echo "*No invariants generated yet.*" >> "$report"
    fi
  else
    echo "*CLAUDE.md not yet generated.*" >> "$report"
  fi

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 11. Verification Results ---
  echo "## 11. Verification" >> "$report"
  echo "" >> "$report"

  # Note: verification results are displayed by cmd_verify in the pipeline.
  # We do not re-run cmd_verify here to avoid duplicate output and wasted time.
  echo "Verification is performed as a separate pipeline step." >> "$report"
  echo "See the **verify** output above (or run \`aiframework verify\` standalone)." >> "$report"

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 12. Skill Suggestions ---
  local suggestion_count
  suggestion_count=$(echo "$m" | jq '.skill_suggestions | length' 2>/dev/null || echo "0")

  echo "## 12. Skill Suggestions (${suggestion_count})" >> "$report"
  echo "" >> "$report"

  if [[ "$suggestion_count" -gt 0 ]]; then
    echo "Based on your repo structure, these custom skills could be useful:" >> "$report"
    echo "" >> "$report"
    echo "| Skill | Why | What it would do |" >> "$report"
    echo "|-------|-----|-----------------|" >> "$report"
    echo "$m" | jq -r '.skill_suggestions[] | "| `/\(.name)` | \(.reason) | \(.description) |"' 2>/dev/null >> "$report" || true
    echo "" >> "$report"
    echo "> These are suggestions only. To create a skill, add a SKILL.md file to \`.claude/skills/<name>/\`." >> "$report"
    echo "> See \`docs/guides/creating-custom-skills.md\` for the format." >> "$report"
  else
    echo "*No additional skill suggestions. Your project setup is clean.*" >> "$report"
  fi

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"

  # --- 13. What To Do Next ---
  cat >> "$report" << 'NEXT'
## 13. What To Do Next

### Verify This Report

Review each section above. If anything is wrong:
1. **Wrong language/framework?** — Check `lib/data/languages.json` markers
2. **Missing commands?** — Add them to your `package.json` scripts, `Makefile`, or `pyproject.toml`
3. **Missing env vars?** — Create a `.env.example` file
4. **Wrong domains?** — Domains are detected from file patterns and dependencies
5. **Wrong archetype?** — The archetype affects CLAUDE.md verbosity (lean vs full)

### Give Feedback

Run `/aif-feedback` in Claude Code to rate the output quality and report issues.

### Customize

1. **Edit CLAUDE.md** — Add project-specific invariants, gotchas, env vars
2. **Run `/aif-enhance`** — Let Claude research your framework's conventions
3. **Drop docs in `vault/raw/`** — Claude will process them into knowledge pages

### Keep Updated

- `aiframework refresh` — Re-scan when dependencies change
- `/aif-evolve` — Weekly rule evolution from session data
- `/aif-pulse` — Check for new Claude Code features
NEXT

  echo "" >> "$report"
  echo "---" >> "$report"
  echo "" >> "$report"
  echo "*Report generated by aiframework v$(cat "$ROOT_DIR/VERSION"). File: \`.aiframework/report.md\`*" >> "$report"

  log_ok "Report written to $report"
}
