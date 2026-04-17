#!/usr/bin/env bash
# Validator: File Existence
# Checks all expected files exist

report_row() {
  local check="$1"
  local status="$2"
  local details="$3"

  local status_color
  case "$status" in
    PASS)  status_color="${GREEN}PASS${NC}" ; passed=$((passed + 1)) ;;
    FAIL)  status_color="${RED}FAIL${NC}"   ; failed=$((failed + 1)) ;;
    WARN)  status_color="${YELLOW}WARN${NC}" ; warnings=$((warnings + 1)) ;;
    SKIP)  status_color="${BLUE}SKIP${NC}"  ;;
  esac
  total_checks=$((total_checks + 1))

  printf "│ %-28s │ %-17b │ %-27s │\n" "$check" "$status_color" "$details"
}

validate_files() {
  local m="$MANIFEST"
  local short
  short=$(echo "$m" | jq -r '.identity.short_name')

  # Expected files
  local expected_files=(
    "CLAUDE.md"
    "CHANGELOG.md"
    "VERSION"
    "STATUS.md"
    "SETUP-DEV.md"
    "CONTRIBUTING.md"
    "docs/README.md"
  )

  local expected_dirs=(
    "docs/onboarding"
    "docs/guides"
    "docs/reference"
    "docs/explanation"
    "docs/decisions"
    "tools/learnings"
  )

  # Check files
  local found=0
  local total=${#expected_files[@]}

  for f in "${expected_files[@]}"; do
    if [[ -f "$TARGET_DIR/$f" ]]; then
      found=$((found + 1))
    else
      report_row "$f" "FAIL" "File missing"
    fi
  done

  if [[ $found -eq $total ]]; then
    report_row "Core files ($total)" "PASS" "All present"
  else
    report_row "Core files" "FAIL" "$found/$total present"
  fi

  # Check dirs
  local dir_found=0
  local dir_total=${#expected_dirs[@]}
  for d in "${expected_dirs[@]}"; do
    [[ -d "$TARGET_DIR/$d" ]] && dir_found=$((dir_found + 1))
  done

  if [[ $dir_found -eq $dir_total ]]; then
    report_row "Directories ($dir_total)" "PASS" "All present"
  else
    report_row "Directories" "FAIL" "$dir_found/$dir_total present"
  fi

  # Check hooks
  local hook_system
  hook_system=$(echo "$m" | jq -r '.quality.hooks.system // empty')

  if [[ "$hook_system" == "husky" || "$hook_system" == "pre-commit" ]]; then
    report_row "Git hooks" "SKIP" "Uses $hook_system"
  elif [[ -f "$TARGET_DIR/.githooks/pre-commit" && -f "$TARGET_DIR/.githooks/pre-push" ]]; then
    report_row "Git hooks (2)" "PASS" "pre-commit + pre-push"
  elif [[ -f "$TARGET_DIR/.githooks/pre-push" ]]; then
    if [[ -f "$TARGET_DIR/.githooks/pre-commit-SKIPPED.md" ]]; then
      report_row "Git hooks (1)" "PASS" "pre-push + skip documented"
    else
      report_row "Git hooks (1)" "WARN" "pre-push only (no pre-commit)"
    fi
  else
    report_row "Git hooks" "FAIL" "Not created"
  fi

  # Check hooks activation
  local hooks_path
  hooks_path=$(cd "$TARGET_DIR" && git config core.hooksPath 2>/dev/null)
  if [[ "$hooks_path" == ".githooks" ]]; then
    report_row "Hooks activated" "PASS" "core.hooksPath = .githooks"
  elif [[ "$hook_system" == "husky" || "$hook_system" == "pre-commit" ]]; then
    report_row "Hooks activated" "SKIP" "Uses $hook_system"
  else
    report_row "Hooks activated" "FAIL" "core.hooksPath not set"
  fi

  # Check skills
  if [[ -f "$TARGET_DIR/.claude/skills/${short}-review/SKILL.md" ]]; then
    report_row "Review skill" "PASS" "/${short}-review"
  else
    report_row "Review skill" "FAIL" "Not created"
  fi

  if [[ -f "$TARGET_DIR/.claude/skills/${short}-ship/SKILL.md" ]]; then
    report_row "Ship skill" "PASS" "/${short}-ship"
  else
    report_row "Ship skill" "FAIL" "Not created"
  fi

  # Check review specialists
  local specialist_count
  specialist_count=$(find "$TARGET_DIR/tools/review-specialists" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
  if [[ "$specialist_count" -gt 0 ]]; then
    report_row "Review specialists" "PASS" "$specialist_count created"
  else
    report_row "Review specialists" "WARN" "None created"
  fi

  # Check learnings file
  if [[ -f "$TARGET_DIR/tools/learnings/${short}-learnings.jsonl" ]]; then
    report_row "Learnings file" "PASS" "${short}-learnings.jsonl"
  else
    report_row "Learnings file" "FAIL" "Not created"
  fi

  # Check CI
  if [[ -f "$TARGET_DIR/.github/workflows/ci.yml" ]]; then
    report_row "CI workflow" "PASS" "ci.yml"
  else
    local ci_provider
    ci_provider=$(echo "$m" | jq -r '.ci.provider // "none"')
    if [[ "$ci_provider" != "none" ]]; then
      report_row "CI workflow" "SKIP" "Existing CI: $ci_provider"
    else
      report_row "CI workflow" "WARN" "Not created"
    fi
  fi

  # Check CI workflow content matches language
  if [[ -f "$TARGET_DIR/.github/workflows/ci.yml" ]]; then
    local language
    language=$(echo "$m" | jq -r '.identity.language // empty')
    local ci_content_ok=true
    local ci_detail=""

    case "$language" in
      typescript|javascript)
        if grep -q 'setup-node' "$TARGET_DIR/.github/workflows/ci.yml" 2>/dev/null; then
          ci_detail="setup-node found"
        else
          ci_content_ok=false
          ci_detail="Missing setup-node for $language"
        fi
        ;;
      python)
        if grep -q 'setup-python' "$TARGET_DIR/.github/workflows/ci.yml" 2>/dev/null; then
          ci_detail="setup-python found"
        else
          ci_content_ok=false
          ci_detail="Missing setup-python for $language"
        fi
        ;;
      rust)
        if grep -q 'toolchain' "$TARGET_DIR/.github/workflows/ci.yml" 2>/dev/null || \
           grep -q 'rust' "$TARGET_DIR/.github/workflows/ci.yml" 2>/dev/null; then
          ci_detail="Rust toolchain found"
        else
          ci_content_ok=false
          ci_detail="Missing Rust setup for $language"
        fi
        ;;
      go)
        if grep -q 'setup-go' "$TARGET_DIR/.github/workflows/ci.yml" 2>/dev/null; then
          ci_detail="setup-go found"
        else
          ci_content_ok=false
          ci_detail="Missing setup-go for $language"
        fi
        ;;
      java|kotlin)
        if grep -q 'setup-java' "$TARGET_DIR/.github/workflows/ci.yml" 2>/dev/null; then
          ci_detail="setup-java found"
        else
          ci_content_ok=false
          ci_detail="Missing setup-java for $language"
        fi
        ;;
      *)
        ci_detail="No lang check for $language"
        ;;
    esac

    if $ci_content_ok; then
      report_row "CI lang setup" "PASS" "$ci_detail"
    else
      report_row "CI lang setup" "FAIL" "$ci_detail"
    fi
  fi

  # Check vault structure
  local vault_dirs=(
    "vault/raw"
    "vault/wiki/sources"
    "vault/wiki/concepts"
    "vault/wiki/entities"
    "vault/wiki/comparisons"
    "vault/memory/decisions"
    "vault/memory/notes"
    "vault/.vault/scripts"
    "vault/.vault/rules"
    "vault/.vault/schemas"
  )

  local vault_found=0
  local vault_total=${#vault_dirs[@]}
  for vd in "${vault_dirs[@]}"; do
    [[ -d "$TARGET_DIR/$vd" ]] && vault_found=$((vault_found + 1))
  done

  if [[ $vault_found -eq $vault_total ]]; then
    report_row "Vault dirs ($vault_total)" "PASS" "All present"
  elif [[ $vault_found -eq 0 ]]; then
    report_row "Vault dirs" "WARN" "Vault not initialized"
  else
    report_row "Vault dirs" "FAIL" "$vault_found/$vault_total present"
  fi

  # Check vault key files
  local vault_files=(
    "vault/wiki/index.md"
    "vault/memory/status.md"
    "vault/.vault/rules/hard-rules.md"
    "vault/.vault/staleness-config.json"
    "vault/.vault/scripts/vault-tools.sh"
  )

  local vf_found=0
  local vf_total=${#vault_files[@]}
  for vf in "${vault_files[@]}"; do
    [[ -f "$TARGET_DIR/$vf" ]] && vf_found=$((vf_found + 1))
  done

  if [[ $vf_found -eq $vf_total ]]; then
    report_row "Vault files ($vf_total)" "PASS" "All present"
  elif [[ $vf_found -eq 0 ]]; then
    report_row "Vault files" "WARN" "Vault not initialized"
  else
    report_row "Vault files" "FAIL" "$vf_found/$vf_total present"
  fi

  # Check manifest
  if [[ -f "$TARGET_DIR/.aiframework/manifest.json" ]]; then
    report_row "Manifest" "PASS" "manifest.json"
  else
    report_row "Manifest" "WARN" "Not in default location"
  fi

  # Check extended rules (moderate/complex/enterprise only)
  local proj_complexity
  proj_complexity=$(echo "$m" | jq -r '.archetype.complexity // "simple"')
  if [[ "$proj_complexity" == "moderate" || "$proj_complexity" == "complex" || "$proj_complexity" == "enterprise" ]]; then
    local ext_rules=(
      ".claude/rules/pipeline.md"
      ".claude/rules/session-protocol.md"
      ".claude/rules/invariants.md"
    )
    local ext_found=0
    local ext_total=${#ext_rules[@]}
    for er in "${ext_rules[@]}"; do
      [[ -f "$TARGET_DIR/$er" ]] && ext_found=$((ext_found + 1))
    done
    if [[ $ext_found -eq $ext_total ]]; then
      report_row "Extended rules ($ext_total)" "PASS" "All present"
    else
      report_row "Extended rules" "FAIL" "$ext_found/$ext_total present"
    fi
  fi
}
