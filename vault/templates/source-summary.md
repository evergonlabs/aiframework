---
title: "{{SOURCE_TITLE}}"
type: source
created: "{{DATE}}"
updated: "{{DATE}}"
status: draft
sources:
  - "raw/{{RAW_FILENAME}}"
related:
  - "{{RELATED_SLUG}}"
tags:
  - type/source
  - source-type/{{SOURCE_TYPE}}
  - domain/{{DOMAIN}}
owner: "{{OWNER}}"
confidence: medium
---

# {{SOURCE_TITLE}}

> Summary of [[{{RAW_FILENAME}}]] ingested on {{DATE}}.

## Key Points

1. {{POINT_1}}
2. {{POINT_2}}
3. {{POINT_3}}

## Detailed Summary

{{SUMMARY_BODY}}

## Relevance

- **Why this matters**: {{RELEVANCE}}
- **Related concepts**: [[{{CONCEPT_1}}]], [[{{CONCEPT_2}}]]
- **Confidence**: medium (single source, not yet cross-referenced)

## Source Metadata

| Field | Value |
|-------|-------|
| Source type | {{SOURCE_TYPE}} |
| Author | {{AUTHOR}} |
| Date | {{SOURCE_DATE}} |
| Length | {{LENGTH}} |
| Location | raw/{{RAW_FILENAME}} |
