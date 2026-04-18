---
title: "API Reference: lib/indexers (legacy)"
type: entity
created: 2026-04-17
updated: 2026-04-17
status: archived
tags:
  - type/entity
  - domain/bash
  - source-type/code-index
  - format/reference
confidence: medium
---

# API Reference: lib/indexers

> Function and class reference for `lib/indexers` (42 symbols).

## Symbols

| Name | Kind | File | Description |
|------|------|------|-------------|
| `_detect_shebang_language` | function | `lib/indexers/parse.py` | Read the first line of a file and detect language from shebang. |
| `_extract_doc_comment` | function | `lib/indexers/parsers/go.py` | Extract the // comment block immediately before *pos*. |
| `_extract_docstring` | function | `lib/indexers/parsers/bash.py` | Collect the # comment block immediately before a function definition. |
| `_extract_jsdoc` | function | `lib/indexers/parsers/typescript.py` | Extract the JSDoc comment (/** ... */) immediately before *pos*. |
| `_extract_rdoc_comment` | function | `lib/indexers/parsers/ruby.py` | Extract the # comment block immediately before *pos*. |
| `_find_parent_class` | function | `lib/indexers/parsers/python.py` | Find the class that contains an indented method definition. |
| `_first_doc_line` | function | `lib/indexers/parsers/python.py` | Extract the first line of a docstring following a def/class. |
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
| `_load_parsers_from_package` | function | `lib/indexers/registry.py` | Load all parser modules from a package. |
| `_normalize_bash_import` | function | `lib/indexers/parsers/bash.py` | Normalize a bash source/dot import path to a relative file path. |
| `_parse_file` | function | `lib/indexers/parse.py` | Parse a single file and return its file-entry dict plus symbols list. |
| `_resolve_import_to_file` | function | `lib/indexers/graph.py` | Best-effort resolve an import string to a known relative file path. |
| `_role_for_directory` | function | `lib/indexers/graph.py` | Assign a heuristic role based on the directory name. |
| `build_graph` | function | `lib/indexers/graph.py` | Build dependency edges and module groupings from parsed file data. |
| `compute_pagerank` | function | `lib/indexers/graph.py` | Compute PageRank scores for files based on import edges. |
| `discover_parsers` | function | `lib/indexers/registry.py` | Discover all available parsers from built-in and contrib packages. |
| `index_repo` | function | `lib/indexers/parse.py` | Index a repository and optionally write the result to a JSON file. |
| `main` | function | `lib/indexers/parse.py` | — |
| `parse` | function | `lib/indexers/parsers/bash.py` | Parse a bash/shell script and return (symbols, imports, exports). |
| `parse_bash` | function | `lib/indexers/parsers/bash.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_go` | function | `lib/indexers/parsers/go.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_python` | function | `lib/indexers/parsers/python.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_ruby` | function | `lib/indexers/parsers/ruby.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_rust` | function | `lib/indexers/parsers/rust.py` | Legacy interface: returns dict with symbols/imports/exports. |
| `parse_typescript` | function | `lib/indexers/parsers/typescript.py` | Legacy interface: returns dict with symbols/imports/exports. |

## Related

- [[lib-indexers]]
- [[architecture]]
- [[tech-stack]]
