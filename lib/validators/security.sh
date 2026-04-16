#!/usr/bin/env bash
# Validator: Security
# Checks for secrets and sensitive data in generated files

validate_security() {
  local scan_files=("CLAUDE.md" "SETUP-DEV.md" "CONTRIBUTING.md" "STATUS.md")
  local scan_dirs=(".githooks" ".claude" "tools")

  # Secret patterns to check
  local patterns=(
    'ghp_[a-zA-Z0-9]{36}'
    'sk-[a-zA-Z0-9]{48}'
    'sk-ant-[a-zA-Z0-9-]{93}'
    'AKIA[0-9A-Z]{16}'
    'sk_live_[a-zA-Z0-9]{24,}'
    'rk_live_[a-zA-Z0-9]{24,}'
    'xoxb-[0-9]+-[a-zA-Z0-9]+'
    'xoxp-[0-9]+-[a-zA-Z0-9]+'
    'SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}'
    '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'
    'postgres://[^ ]+:[^ ]+@'
    'mysql://[^ ]+:[^ ]+@'
    'mongodb(\+srv)?://[^ ]+:[^ ]+@'
    'AIza[0-9A-Za-z_-]{35}'
    'ya29\.[0-9A-Za-z_-]+'
    'azure[_-]?(?:storage|account)[_-]?key["\s:=]+[A-Za-z0-9+/=]{20,}'
  )

  local found_secrets=0

  # Check individual files
  for f in "${scan_files[@]}"; do
    [[ -f "$TARGET_DIR/$f" ]] || continue
    for pattern in "${patterns[@]}"; do
      if grep -qE "$pattern" "$TARGET_DIR/$f" 2>/dev/null; then
        local count
        count=$(grep -cE "$pattern" "$TARGET_DIR/$f" 2>/dev/null | head -1 | tr -d '[:space:]')
        report_row "Secret in $f" "FAIL" "$count potential secret(s)"
        found_secrets=$((found_secrets + count))
      fi
    done
  done

  # Check recursive dirs
  for d in "${scan_dirs[@]}"; do
    [[ -d "$TARGET_DIR/$d" ]] || continue
    for pattern in "${patterns[@]}"; do
      if grep -rqE "$pattern" "$TARGET_DIR/$d" 2>/dev/null; then
        local count
        count=$(grep -rlE "$pattern" "$TARGET_DIR/$d" 2>/dev/null | wc -l | tr -d '[:space:]')
        report_row "Secret in $d/" "FAIL" "$count file(s) with secrets"
        found_secrets=$((found_secrets + count))
      fi
    done
  done

  if [[ $found_secrets -eq 0 ]]; then
    report_row "Security scan" "PASS" "No secrets found"
  fi

  # Check .env files aren't tracked
  if [[ -f "$TARGET_DIR/.gitignore" ]]; then
    if grep -q '\.env' "$TARGET_DIR/.gitignore" 2>/dev/null; then
      report_row ".env in .gitignore" "PASS" "Protected"
    else
      report_row ".env in .gitignore" "WARN" "Not in .gitignore"
    fi
  else
    report_row ".gitignore" "WARN" "No .gitignore found"
  fi
}
