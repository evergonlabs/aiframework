---
name: aif-ingest
description: Ingest a document into the vault knowledge base
---

# Vault Ingest

When the user provides a document to ingest (URL, file path, or pasted content):

1. Save the raw content to `vault/raw/<slug>.md`
2. Create a source summary at `vault/wiki/sources/<slug>.md` with:
   - YAML frontmatter (title, type: source, date, tags)
   - One-paragraph summary
   - Key topics/sections
   - Wikilinks to related concept pages
3. Update existing concept/entity pages that the new source relates to
4. Add entry to `vault/wiki/index.md`
5. Log to `vault/wiki/log.md`
6. Report: "Ingested <title>. Updated N existing pages."

## Rules
- NEVER modify files in `vault/raw/` after creation (immutable)
- ALWAYS add YAML frontmatter to wiki pages
- ALWAYS update the index
- ALWAYS log the operation
- Use approved tags from `vault/.vault/rules/tags.md`
