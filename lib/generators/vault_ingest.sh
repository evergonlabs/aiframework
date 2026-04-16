#!/usr/bin/env bash
# Vault Auto-Ingest — deposits key project documents and creates source summaries

vault_auto_ingest() {
  local target_dir="$1"
  local vault_root="$2"
  local today
  today=$(date +%Y-%m-%d)

  [[ -d "$vault_root" ]] || return 0

  mkdir -p "$vault_root/raw" "$vault_root/wiki/sources"

  local ingested=0

  # Ingest key documents into raw/
  local docs_to_ingest=(
    "README.md"
    "CONTRIBUTING.md"
    "ARCHITECTURE.md"
    "docs/architecture.md"
    "docs/README.md"
  )

  for doc in "${docs_to_ingest[@]}"; do
    local src="$target_dir/$doc"
    [[ -f "$src" ]] || continue

    local slug
    slug=$(echo "$doc" | tr '/' '-' | sed 's/\.md$//')
    local raw_dest="$vault_root/raw/${slug}.md"
    local source_dest="$vault_root/wiki/sources/${slug}.md"

    # Copy to raw/ (immutable deposit)
    if [[ ! -f "$raw_dest" ]]; then
      cp "$src" "$raw_dest"
      ((ingested++))

      # Create source summary in wiki/sources/
      local title
      title=$(head -1 "$src" | sed 's/^#\+ *//')
      [[ -z "$title" ]] && title="$doc"
      local line_count
      line_count=$(wc -l < "$src" | tr -d ' ')
      local word_count
      word_count=$(wc -w < "$src" | tr -d ' ')

      cat > "$source_dest" << SOURCEEOF
---
title: "Source: ${title}"
type: source
created: ${today}
updated: ${today}
status: current
tags:
  - type/source
  - source-type/documentation
  - lifecycle/active
source_path: "raw/${slug}.md"
original_path: "${doc}"
confidence: high
---

# ${title}

**Source:** \`${doc}\` (${line_count} lines, ${word_count} words)
**Deposited:** ${today}

## Summary

*Auto-ingested from project root. See [[raw/${slug}]] for full content.*

## Key Topics

$(grep -E '^##+ ' "$src" 2>/dev/null | head -10 | sed 's/^#\+/•/' || echo "• (no sections detected)")

## Related

- [[project-overview]]
- [[tech-stack]]
SOURCEEOF
    fi
  done

  # Ingest manifest as a source
  local manifest_path="$target_dir/.aiframework/manifest.json"
  if [[ -f "$manifest_path" && ! -f "$vault_root/raw/manifest.md" ]]; then
    # Create a markdown summary of the manifest
    local name
    name=$(jq -r '.identity.name // "unknown"' "$manifest_path")
    local lang
    lang=$(jq -r '.stack.language // "unknown"' "$manifest_path")
    local fw
    fw=$(jq -r '.stack.framework // "none"' "$manifest_path")
    local files
    files=$(jq -r '.structure.total_files // 0' "$manifest_path")

    cat > "$vault_root/raw/manifest.md" << MANEOF
# Manifest Summary: ${name}

- **Language**: ${lang}
- **Framework**: ${fw}
- **Total files**: ${files}
- **Generated**: ${today}

Full manifest at: \`.aiframework/manifest.json\`
MANEOF

    cat > "$vault_root/wiki/sources/manifest.md" << MANSRCEOF
---
title: "Source: Project Manifest"
type: source
created: ${today}
updated: ${today}
status: current
tags:
  - type/source
  - source-type/manifest
  - lifecycle/active
source_path: "raw/manifest.md"
confidence: high
---

# Project Manifest

Auto-generated analysis of **${name}** (${lang}/${fw}, ${files} files).

## Related

- [[project-overview]]
- [[tech-stack]]
MANSRCEOF
    ((ingested++))
  fi

  # Update index.md with new source pages
  if [[ "$ingested" -gt 0 && -f "$vault_root/wiki/index.md" ]]; then
    # Append source entries if not already present
    for doc in "${docs_to_ingest[@]}"; do
      local slug
      slug=$(echo "$doc" | tr '/' '-' | sed 's/\.md$//')
      if [[ -f "$vault_root/wiki/sources/${slug}.md" ]] && ! grep -q "sources/${slug}.md" "$vault_root/wiki/index.md" 2>/dev/null; then
        # Insert before ## Conventions using temp file
        local tmp
        tmp=$(mktemp)
        awk -v entry="| ${slug} | wiki/sources/${slug}.md | source | ${today} | current | type/source |" \
          '/^## Conventions/{print entry}1' "$vault_root/wiki/index.md" > "$tmp"
        mv "$tmp" "$vault_root/wiki/index.md"
      fi
    done

    # Same for manifest
    if [[ -f "$vault_root/wiki/sources/manifest.md" ]] && ! grep -q "sources/manifest.md" "$vault_root/wiki/index.md" 2>/dev/null; then
      local tmp
      tmp=$(mktemp)
      awk -v entry="| manifest | wiki/sources/manifest.md | source | ${today} | current | source-type/manifest |" \
        '/^## Conventions/{print entry}1' "$vault_root/wiki/index.md" > "$tmp"
      mv "$tmp" "$vault_root/wiki/index.md"
    fi
  fi

  # Log
  if [[ "$ingested" -gt 0 && -f "$vault_root/wiki/log.md" ]]; then
    echo "| ${today} | ingest | Auto-ingested ${ingested} source documents into raw/ and wiki/sources/ |" >> "$vault_root/wiki/log.md"
  fi

  [[ "$VERBOSE" == true ]] && log_info "Vault: ingested ${ingested} source documents"
}
