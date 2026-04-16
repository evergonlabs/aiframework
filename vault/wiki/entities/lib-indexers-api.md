---
title: "API Reference: lib/indexers"
type: entity
created: 2026-04-16
updated: 2026-04-16
status: current
tags:
  - type/entity
  - domain/bash
  - source-type/code-index
  - format/reference
confidence: medium
---

# API Reference: lib/indexers

> Function and class reference for `lib/indexers` (34 symbols).

## Symbols

| Name | Kind | File | Description |
|------|------|------|-------------|
| `_adapt` | function | `lib/indexers/parse.py` | Adapt standalone parser dict result to inline tuple format. |
| `_extract_doc_comment` | function | `lib/indexers/lang_go.py` | Extract the // comment block immediately before *pos*. |
| `_extract_docstring` | function | `lib/indexers/lang_bash.py` | Collect the # comment block immediately before a function definition. |
| `_extract_jsdoc` | function | `lib/indexers/lang_typescript.py` | Extract the JSDoc comment (/** ... */) immediately before *pos*. |
| `_extract_rdoc_comment` | function | `lib/indexers/lang_ruby.py` | Extract the # comment block immediately before *pos*. |
| `_find_parent_class` | function | `lib/indexers/lang_python.py` | Find the class that contains an indented method definition. |
| `_first_doc_line` | function | `lib/indexers/lang_python.py` | Extract the first line of a docstring following a def/class. |
| `_lang_bash` | function | `lib/indexers/parse.py` | — |
| `_lang_csharp` | function | `lib/indexers/parse.py` | — |
| `_lang_elixir` | function | `lib/indexers/parse.py` | — |
| `_lang_go` | function | `lib/indexers/parse.py` | — |
| `_lang_java` | function | `lib/indexers/parse.py` | — |
| `_lang_kotlin` | function | `lib/indexers/parse.py` | — |
| `_lang_php` | function | `lib/indexers/parse.py` | — |
| `_lang_python` | function | `lib/indexers/parse.py` | — |
| `_lang_ruby` | function | `lib/indexers/parse.py` | — |
| `_lang_rust` | function | `lib/indexers/parse.py` | — |
| `_lang_swift` | function | `lib/indexers/parse.py` | — |
| `_lang_typescript` | function | `lib/indexers/parse.py` | — |
| `_parse_file` | function | `lib/indexers/parse.py` | Parse a single file and return its file-entry dict plus symbols list. |
| `_resolve_import_to_file` | function | `lib/indexers/graph.py` | Best-effort resolve an import string to a known relative file path. |
| `_role_for_directory` | function | `lib/indexers/graph.py` | Assign a heuristic role based on the directory name. |
| `_try_import_standalone` | function | `lib/indexers/parse.py` | Import standalone parsers if available, return dict of adapters. |
| `build_graph` | function | `lib/indexers/graph.py` | Build dependency edges and module groupings from parsed file data. |
| `compute_pagerank` | function | `lib/indexers/graph.py` | Compute PageRank scores for files based on import edges. |
| `index_repo` | function | `lib/indexers/parse.py` | Index a repository and optionally write the result to a JSON file. |
| `main` | function | `lib/indexers/parse.py` | — |
| `parse_bash` | function | `lib/indexers/lang_bash.py` | Parse a bash/shell script and return symbols, imports, and exports. |
| `parse_go` | function | `lib/indexers/lang_go.py` | Parse Go source and return symbols, imports, exports. |
| `parse_python` | function | `lib/indexers/lang_python.py` | Parse a Python file and return symbols, imports, and exports. |
| `parse_ruby` | function | `lib/indexers/lang_ruby.py` | Parse Ruby source and return symbols, imports, exports. |
| `parse_rust` | function | `lib/indexers/lang_rust.py` | Parse Rust source and return symbols, imports, exports. |
| `parse_typescript` | function | `lib/indexers/lang_typescript.py` | Parse TypeScript/JavaScript source and return symbols, imports, exports. |

## Related

- [[lib-indexers]]
- [[architecture]]
- [[tech-stack]]
