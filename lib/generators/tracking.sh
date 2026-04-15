#!/usr/bin/env bash
# Generator: Tracking Files
# Creates CHANGELOG.md, VERSION, STATUS.md

generate_tracking() {
  local m="$MANIFEST"
  local name=$(echo "$m" | jq -r '.identity.name')
  local short=$(echo "$m" | jq -r '.identity.short_name')
  local version=$(echo "$m" | jq -r '.identity.version // "0.1.0"')
  local today=$(date +%Y-%m-%d)

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create CHANGELOG.md, VERSION, STATUS.md"
    return 0
  fi

  # --- CHANGELOG.md ---
  cat > "$TARGET_DIR/CHANGELOG.md" << CHANGELOG
# Changelog

All notable changes to ${name} are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Automation pipeline (12 layers) via aiframework
- CLAUDE.md for Claude Code integration
- Git hooks (pre-commit + pre-push quality gates)
- Custom Claude Code skills (/${short}-review, /${short}-ship)
- Documentation scaffold (Diataxis structure)
- CI workflow for quality gates

## [${version}] — ${today}
### Added
- Initial project setup
CHANGELOG

  log_ok "Created CHANGELOG.md"

  # --- VERSION ---
  echo "$version" > "$TARGET_DIR/VERSION"
  log_ok "Created VERSION (${version})"

  # --- STATUS.md ---
  cat > "$TARGET_DIR/STATUS.md" << STATUS
# Current Sprint — Status Tracker

## Current Phase: Automation setup

## Progress
| Phase | Description | Status | Date |
|-------|-------------|--------|------|
| 1 | Repo discovery (manifest.json) | Done | ${today} |
| 2 | CLAUDE.md generated | Done | ${today} |
| 3 | Git hooks (pre-commit + pre-push) | Done | ${today} |
| 4 | CI workflow created | Done | ${today} |
| 5 | Custom skills created | Done | ${today} |
| 6 | Review specialists created | Done | ${today} |
| 7 | Documentation scaffold | Done | ${today} |
| 8 | Tracking files (changelog, version) | Done | ${today} |

## Audit Findings Log
| # | Date | Finding | Root Cause | Fix Applied |
|---|------|---------|-----------|-------------|

*Last updated: ${today}*
STATUS

  log_ok "Created STATUS.md"
}
