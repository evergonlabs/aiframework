#!/usr/bin/env bash
# Scanner: User Context (Step 1.8b)
# Interactively collects operational context from the user
# Skips gracefully in non-interactive mode (piped, --non-interactive)

scan_user_context() {
  local production_url="null"
  local active_workstream="null"
  local credentials_location="null"
  local team_conventions="null"
  local known_pitfalls="null"

  # Determine if we should prompt the user
  local interactive=true
  if [[ "${NON_INTERACTIVE:-false}" == true ]]; then
    interactive=false
  elif [[ ! -t 0 ]]; then
    # stdin is not a terminal (piped or redirected)
    interactive=false
  fi

  if [[ "$interactive" == false ]]; then
    log_warn "Non-interactive mode — skipping user context questions"
    _store_user_context "$production_url" "$active_workstream" \
      "$credentials_location" "$team_conventions" "$known_pitfalls"
    return 0
  fi

  echo ""
  echo -e "${BOLD}User Context — 5 quick questions (press Enter to skip any)${NC}"
  echo ""

  # Q1: Production URLs
  read -rp "$(echo -e "${CYAN}Q1/5${NC}") What are the production/staging URLs for this app? " answer
  if [[ -n "$answer" ]]; then
    production_url=$(echo "$answer" | jq -Rs '.')
  fi

  # Q2: Active workstream / scope restrictions
  read -rp "$(echo -e "${CYAN}Q2/5${NC}") Is there a current task with scope restrictions? (files you're allowed to edit, modules off-limits) " answer
  if [[ -n "$answer" ]]; then
    active_workstream=$(echo "$answer" | jq -Rs '.')
  fi

  # Q3: Credentials location
  read -rp "$(echo -e "${CYAN}Q3/5${NC}") Where are credentials stored? (e.g., 1Password, ~/.zshrc.local, Vault) " answer
  if [[ -n "$answer" ]]; then
    credentials_location=$(echo "$answer" | jq -Rs '.')
  fi

  # Q4: Team conventions
  read -rp "$(echo -e "${CYAN}Q4/5${NC}") Any team rules I should know about? (e.g., 'never push without asking', 'French UI') " answer
  if [[ -n "$answer" ]]; then
    team_conventions=$(echo "$answer" | jq -Rs '.')
  fi

  # Q5: Known pitfalls
  read -rp "$(echo -e "${CYAN}Q5/5${NC}") Any gotchas or past incidents I should be aware of? " answer
  if [[ -n "$answer" ]]; then
    known_pitfalls=$(echo "$answer" | jq -Rs '.')
  fi

  # Show summary
  echo ""
  echo -e "${BOLD}User Context Summary:${NC}"
  echo "  Production URL:       $(echo "$production_url" | jq -r 'if . == null then "(skipped)" else . end' 2>/dev/null || echo "(skipped)")"
  echo "  Active workstream:    $(echo "$active_workstream" | jq -r 'if . == null then "(skipped)" else . end' 2>/dev/null || echo "(skipped)")"
  echo "  Credentials location: $(echo "$credentials_location" | jq -r 'if . == null then "(skipped)" else . end' 2>/dev/null || echo "(skipped)")"
  echo "  Team conventions:     $(echo "$team_conventions" | jq -r 'if . == null then "(skipped)" else . end' 2>/dev/null || echo "(skipped)")"
  echo "  Known pitfalls:       $(echo "$known_pitfalls" | jq -r 'if . == null then "(skipped)" else . end' 2>/dev/null || echo "(skipped)")"
  echo ""

  # Confirmation
  read -rp "$(echo -e "${CYAN}Does this look right? (y/n)${NC} ")" confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    log_warn "User context discarded — re-run to try again"
    production_url="null"
    active_workstream="null"
    credentials_location="null"
    team_conventions="null"
    known_pitfalls="null"
  fi

  _store_user_context "$production_url" "$active_workstream" \
    "$credentials_location" "$team_conventions" "$known_pitfalls"
}

_store_user_context() {
  local production_url="$1"
  local active_workstream="$2"
  local credentials_location="$3"
  local team_conventions="$4"
  local known_pitfalls="$5"

  MANIFEST=$(echo "$MANIFEST" | jq \
    --argjson prod_url "$production_url" \
    --argjson workstream "$active_workstream" \
    --argjson creds "$credentials_location" \
    --argjson conventions "$team_conventions" \
    --argjson pitfalls "$known_pitfalls" \
    '. + {
      "user_context": {
        "production_url": $prod_url,
        "active_workstream": $workstream,
        "credentials_location": $creds,
        "team_conventions": $conventions,
        "known_pitfalls": $pitfalls
      }
    }')

  local filled=0
  [[ "$production_url" != "null" ]] && filled=$((filled + 1))
  [[ "$active_workstream" != "null" ]] && filled=$((filled + 1))
  [[ "$credentials_location" != "null" ]] && filled=$((filled + 1))
  [[ "$team_conventions" != "null" ]] && filled=$((filled + 1))
  [[ "$known_pitfalls" != "null" ]] && filled=$((filled + 1))

  log_ok "User context: $filled/5 fields populated"
}
