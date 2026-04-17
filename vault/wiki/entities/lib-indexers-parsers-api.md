---
title: "API Reference: lib/indexers/parsers"
type: entity
created: 2026-04-17
updated: 2026-04-17
status: current
tags:
  - type/entity
  - domain/bash
  - source-type/code-index
  - format/reference
confidence: medium
---

# API Reference: lib/indexers/parsers

> Function and class reference for `lib/indexers/parsers` (19 symbols).

## Symbols

| Name | Kind | File | Description |
|------|------|------|-------------|
| `_extract_doc_comment` | function | `lib/indexers/parsers/go.py` | Extract the /// doc-comment block immediately before *pos*. |
| `_extract_docstring` | function | `lib/indexers/parsers/bash.py` | Collect the # comment block immediately before a function definition. |
| `_extract_jsdoc` | function | `lib/indexers/parsers/typescript.py` | Extract the JSDoc comment (/** ... */) immediately before *pos*. |
| `_extract_rdoc_comment` | function | `lib/indexers/parsers/ruby.py` | Extract the # comment block immediately before *pos*. |
| `_find_parent_class` | function | `lib/indexers/parsers/python.py` | Find the class that contains an indented method definition. |
| `_first_doc_line` | function | `lib/indexers/parsers/python.py` | Extract the first line of a docstring following a def/class. |
| `parse` | function | `lib/indexers/parsers/bash.py` | Parse a bash/shell script and return (symbols, imports, exports). |
| `parse_bash` | function | `lib/indexers/parsers/bash.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_go` | function | `lib/indexers/parsers/go.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_python` | function | `lib/indexers/parsers/python.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_ruby` | function | `lib/indexers/parsers/ruby.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_rust` | function | `lib/indexers/parsers/rust.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_typescript` | function | `lib/indexers/parsers/typescript.py` | Legacy interface: returns dict with symbols/imports/exports. |

## Related

- [[lib-indexers-parsers]]
- [[architecture]]
- [[tech-stack]]
