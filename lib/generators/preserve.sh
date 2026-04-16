#!/usr/bin/env bash
# preserve.sh — Handles existing file detection, backup, and merge strategies
#
# Strategy for each file type:
#   SKIP     — file exists → do nothing (user owns it)
#   BACKUP   — file exists → backup to .bak, write new, log diff hint
#   MERGE    — file exists → extract user sections, merge with generated
#   CREATE   — file doesn't exist → create as normal
#
# Called by generators before writing. Each function returns:
#   0 = proceed with write
#   1 = skip (file preserved)

# Backup directory for this run
_PRESERVE_BACKUP_DIR=""

_init_preserve() {
  _PRESERVE_BACKUP_DIR="$TARGET_DIR/.aiframework/backups/$(date +%Y%m%d-%H%M%S)"
}

# Check if a file exists and is non-empty
_file_exists() {
  [[ -f "$1" ]] && [[ -s "$1" ]]
}

# Backup a file before overwriting
_backup_file() {
  local file="$1"
  if [[ -L "$file" ]]; then
    log_warn "Skipping backup of symlink: $file"
    return
  fi
  if _file_exists "$file"; then
    if [[ -z "$_PRESERVE_BACKUP_DIR" ]]; then
      _init_preserve
    fi
    mkdir -p "$_PRESERVE_BACKUP_DIR"
    local norm_file norm_target
    norm_file=$(cd "$(dirname "$file")" 2>/dev/null && echo "$(pwd)/$(basename "$file")" || echo "$file")
    norm_target=$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")
    local rel="${norm_file#"$norm_target"/}"
    local backup_path="$_PRESERVE_BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$backup_path")"
    cp "$file" "$backup_path"
  fi
}

# --- CLAUDE.md merge strategy ---
# If CLAUDE.md exists, extract user-added content and merge with new generation.
# User sections: anything after "<!-- USER SECTIONS BELOW -->" or custom invariants
# that don't match our generated pattern.
preserve_claude_md() {
  local target="$TARGET_DIR/CLAUDE.md"

  if ! _file_exists "$target"; then
    return 0  # proceed with creation
  fi

  _backup_file "$target"

  # Extract user-added content after the aiframework footer (user's own sections)
  local user_custom_sections=""
  user_custom_sections=$(sed -n '/^\*Generated:.*aiframework/,$ p' "$target" 2>/dev/null | tail -n +2 || true)

  # Strip known generated sections that were previously appended after the footer
  # (execution matrices, session protocol, previous session comments, etc.)
  if [[ -n "$user_custom_sections" ]]; then
    # Remove everything starting from known generated markers
    local cleaned=""
    cleaned=$(echo "$user_custom_sections" | sed '/^<!-- CLAUDE\.md Guidance:/,/^-->$/d' | sed '/^<!-- Previous Session Summary:/,/^-->$/d' | sed '/^## Execution Matrices$/,/^---$/d' | sed '/^## Execution Matrices$/,$d' || true)
    # If only whitespace remains, discard
    if [[ -z "$(echo "$cleaned" | tr -d '[:space:]')" ]]; then
      user_custom_sections=""
    else
      user_custom_sections="$cleaned"
    fi
  fi

  # Extract user-added session summary comments
  local user_sessions=""
  user_sessions=$(sed -n '/^<!-- Previous Session Summary:/,/^-->$/p' "$target" 2>/dev/null || true)

  # Store extracted content for merge after generation (no export — same process)
  _PRESERVE_USER_SESSIONS="$user_sessions"
  _PRESERVE_USER_CUSTOM="$user_custom_sections"

  log_info "Existing CLAUDE.md backed up — merging user content into new generation"
  return 0  # proceed with write, merge happens after
}

# After CLAUDE.md is generated, append preserved user content
merge_claude_md_user_content() {
  local target="$TARGET_DIR/CLAUDE.md"

  if [[ -n "${_PRESERVE_USER_CUSTOM:-}" ]]; then
    # Append user's custom sections before the closing comment
    echo "" >> "$target"
    echo "$_PRESERVE_USER_CUSTOM" >> "$target"
    log_info "Merged user custom sections into CLAUDE.md"
  fi
}

# --- Tracking files (CHANGELOG, VERSION, STATUS) ---
# CHANGELOG: skip if exists (user's changelog is sacred)
# VERSION: skip if exists (user controls versioning)
# STATUS: skip if exists (user's progress tracker)
preserve_tracking() {
  local file="$1"
  local basename="${file##*/}"

  if _file_exists "$file"; then
    log_info "Preserved existing ${basename} (not overwritten)"
    return 1  # skip
  fi
  return 0  # proceed
}

# --- Documentation files ---
# docs/README.md: skip if exists
# SETUP-DEV.md: skip if exists
# CONTRIBUTING.md: skip if exists
preserve_doc() {
  local file="$1"
  local basename="${file##*/}"

  if _file_exists "$file"; then
    log_info "Preserved existing ${basename} (not overwritten)"
    return 1  # skip
  fi
  return 0  # proceed
}

# --- Skills ---
# .claude/skills/NAME-review/SKILL.md: backup + overwrite (we improve these)
# .claude/settings.json: skip if exists (already handled)
# User's own custom skills in .claude/skills/: NEVER touch
preserve_skill() {
  local file="$1"
  local short="$2"

  # Only touch our generated skills (NAME-review, NAME-ship, NAME-learn)
  local dir_name
  dir_name=$(basename "$(dirname "$file")")

  case "$dir_name" in
    "${short}-review"|"${short}-ship"|"${short}-learn")
      # These are ours — backup and overwrite
      if _file_exists "$file"; then
        _backup_file "$file"
        log_info "Updating ${dir_name}/SKILL.md (backup saved)"
      fi
      return 0  # proceed
      ;;
    *)
      # This is a user's custom skill — never touch
      if _file_exists "$file"; then
        log_info "Preserved user skill: ${dir_name}/"
        return 1  # skip
      fi
      return 0
      ;;
  esac
}

# --- CI workflow ---
# Skip if exists — user's CI is sacred
preserve_ci() {
  local file="$1"

  if _file_exists "$file"; then
    log_info "Preserved existing CI workflow (not overwritten)"
    return 1  # skip
  fi
  return 0
}

# --- Git hooks ---
# Skip if exists — user may have custom hooks
preserve_hook() {
  local file="$1"
  local basename="${file##*/}"

  if _file_exists "$file"; then
    log_info "Preserved existing ${basename} hook (not overwritten)"
    return 1  # skip
  fi
  return 0
}

# --- Review specialists ---
# These are generated checklists — safe to overwrite
# But preserve any user-created specialists that don't match our domains
preserve_specialist() {
  local file="$1"
  local basename="${file##*/}"

  # Known generated specialists
  local generated_names="auth database api ai-llm sandbox frontend external-apis workers financial web3 monorepo"

  local name_without_ext="${basename%.md}"
  if echo "$generated_names" | grep -qw "$name_without_ext"; then
    # Ours — safe to overwrite
    return 0
  fi

  # User-created specialist — preserve
  if _file_exists "$file"; then
    log_info "Preserved user review specialist: ${basename}"
    return 1
  fi
  return 0
}

# --- .claude/rules/ ---
# workflow.md: backup + overwrite (we generate this)
# testing.md, security.md: skip if exists (already guarded in claude_md.sh)
# Any other .md: never touch (user's rules)
preserve_rule() {
  local file="$1"
  local basename="${file##*/}"

  case "$basename" in
    workflow.md|pipeline.md|session-protocol.md|invariants.md)
      # Generated rules — backup and overwrite
      if _file_exists "$file"; then
        _backup_file "$file"
        log_info "Updating ${basename} (backup saved)"
      fi
      return 0  # proceed
      ;;
    testing.md|security.md)
      if _file_exists "$file"; then
        return 1  # skip (already guarded)
      fi
      return 0
      ;;
    *)
      # Unknown rule — if file exists, it's user's (never touch)
      # If file doesn't exist, allow creation
      if _file_exists "$file"; then
        return 1  # skip — user's custom rule
      fi
      return 0  # proceed — new file
      ;;
  esac
}

# --- Summary of what was preserved ---
print_preserve_summary() {
  if [[ -n "$_PRESERVE_BACKUP_DIR" && -d "$_PRESERVE_BACKUP_DIR" ]]; then
    local backup_count
    backup_count=$(find "$_PRESERVE_BACKUP_DIR" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    if [[ "$backup_count" -gt 0 ]]; then
      echo ""
      log_info "Backups saved to: .aiframework/backups/"
      log_info "  ${backup_count} file(s) backed up before update"
      log_info "  To restore: cp .aiframework/backups/TIMESTAMP/FILE ./FILE"
    fi
  fi
}
