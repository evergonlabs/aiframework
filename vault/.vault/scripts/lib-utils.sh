#!/usr/bin/env bash
# lib-utils.sh — Shared utility functions for vault tooling
# Source this file; do not execute directly.

# ── Colors ──
readonly _RED='\033[0;31m'
readonly _GREEN='\033[0;32m'
readonly _YELLOW='\033[1;33m'
readonly _BLUE='\033[0;34m'
readonly _BOLD='\033[1m'
readonly _NC='\033[0m'

# ── Path Resolution ──
# Resolve VAULT_ROOT from any script location inside .vault/scripts/
resolve_vault_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
  # Navigate from .vault/scripts/ up to vault/
  echo "$(cd "$script_dir/../.." && pwd)"
}

# ── Frontmatter Extraction ──
# Extract YAML frontmatter from a markdown file.
# Usage: extract_frontmatter /path/to/file.md
# Returns the frontmatter block (without --- delimiters) on stdout.
extract_frontmatter() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo ""
    return 1
  fi
  # Read between first and second --- lines
  awk 'BEGIN{found=0} /^---$/{found++; next} found==1{print} found>=2{exit}' "$file"
}

# Check if a file has valid YAML frontmatter (starts with ---)
has_frontmatter() {
  local file="$1"
  [[ -f "$file" ]] && head -1 "$file" | grep -q '^---$'
}

# Extract a specific frontmatter field value.
# Usage: get_frontmatter_field /path/to/file.md "title"
get_frontmatter_field() {
  local file="$1"
  local field="$2"
  extract_frontmatter "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" | sed 's/^["'"'"']//; s/["'"'"']$//'
}

# Extract all tags from frontmatter as newline-separated list.
# Handles both block-style (  - tag) and inline-style (tags: [a, b, c]).
get_frontmatter_tags() {
  local file="$1"
  local fm
  fm=$(extract_frontmatter "$file")

  # Check for inline tags: tags: [a, b, c]
  local inline
  inline=$(echo "$fm" | grep '^tags:.*\[' | sed 's/^tags:[[:space:]]*\[//; s/\][[:space:]]*//' | tr ',' '\n')
  if [[ -n "$inline" ]]; then
    echo "$inline" | while IFS= read -r tag; do
      tag=$(echo "$tag" | xargs | sed 's/^["'"'"']//;s/["'"'"']$//')
      [[ -n "$tag" ]] && echo "$tag"
    done
    return
  fi

  # Block-style tags
  echo "$fm" | awk '/^tags:/{found=1; next} found && /^  - /{gsub(/^  - /,""); print} found && !/^  - /&&!/^$/{exit}'
}

# ── Wikilink Parsing ──
# Extract all [[wikilinks]] from a file.
# Usage: extract_wikilinks /path/to/file.md
extract_wikilinks() {
  local file="$1"
  grep -oE '\[\[[a-zA-Z0-9/_-]+\]\]' "$file" 2>/dev/null | sed 's/\[\[//g; s/\]\]//g' | sort -u
}

# Count wikilinks in a file.
count_wikilinks() {
  local file="$1"
  extract_wikilinks "$file" | wc -l | tr -d ' '
}

# ── Tag Validation ──
# Load approved tags from tags.md into a newline-separated list.
# Usage: load_approved_tags /path/to/vault
load_approved_tags() {
  local vault_root="$1"
  local tags_file="$vault_root/.vault/rules/tags.md"
  if [[ ! -f "$tags_file" ]]; then
    echo ""
    return 1
  fi
  grep -oE '  - [a-z]+/[a-z0-9-]+' "$tags_file" | sed 's/^  - //' | sort -u
}

# Validate a single tag against the approved list.
# Usage: validate_tag "domain/auth" "$approved_tags"
# Returns 0 if valid, 1 if invalid.
validate_tag() {
  local tag="$1"
  local approved="$2"
  echo "$approved" | grep -qxF "$tag"
}

# Validate tag format (HR-009: prefix/value, lowercase alphanumeric with hyphens).
validate_tag_format() {
  local tag="$1"
  [[ "$tag" =~ ^[a-z]+/[a-z0-9-]+$ ]]
}

# ── File Utilities ──
# Count lines in a file.
count_lines() {
  local file="$1"
  wc -l < "$file" | tr -d ' '
}

# Get file age in days.
file_age_days() {
  local file="$1"
  local now_epoch
  now_epoch=$(date +%s)
  local file_epoch
  # macOS uses stat -f, Linux uses stat -c
  file_epoch=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo "$now_epoch")
  echo $(( (now_epoch - file_epoch) / 86400 ))
}

# Check if a file is a markdown file.
is_markdown() {
  [[ "$1" == *.md ]]
}

# Check if a file is a JSON file.
is_json() {
  [[ "$1" == *.json ]]
}

# Get relative path from vault root.
rel_path() {
  local file="$1"
  local vault_root="$2"
  echo "${file#"$vault_root"/}"
}

# ── Index Utilities ──
# Check if a file path appears in the index.
is_indexed() {
  local file_rel_path="$1"
  local index_file="$2"
  grep -qF "$file_rel_path" "$index_file" 2>/dev/null
}

# ── Logging ──
log_pass() { echo -e "${_GREEN}[PASS]${_NC} $*"; }
log_fail() { echo -e "${_RED}[FAIL]${_NC} $*"; }
log_warn() { echo -e "${_YELLOW}[WARN]${_NC} $*"; }
log_info() { echo -e "${_BLUE}[INFO]${_NC} $*"; }
