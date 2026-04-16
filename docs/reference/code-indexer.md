# Code Indexer — Reference

## Overview

The code indexer (`lib/indexers/`) creates a deterministic, structured index of any repository. It extracts files, symbols (functions, classes, types), import relationships (edges), and module groupings — all without API calls.

## Entry Points

### CLI

```bash
# Via aiframework
./bin/aiframework index --target /path/to/repo

# Direct Python
python3 -m lib.indexers.parse --target /path/to/repo --output code-index.json
```

### Python API

```python
from lib.indexers.parse import index_repo

result = index_repo("/path/to/repo", "/path/to/output.json")
# result is the full index dict
```

## Output Schema

Output is written to `.aiframework/code-index.json`.

### `_meta`

| Field | Type | Description |
|-------|------|-------------|
| `generated_at` | string | ISO-8601 timestamp |
| `indexer_version` | string | Indexer version (currently "1.0.0") |
| `target_dir` | string | Absolute path to indexed repo |
| `total_files` | int | Number of source files indexed |
| `total_symbols` | int | Total symbols extracted |
| `total_edges` | int | Total import edges resolved |
| `languages` | object | `{language: file_count}` |
| `elapsed_ms` | int | Indexing time in milliseconds |

### `files`

Dict keyed by relative path. Each entry:

| Field | Type | Description |
|-------|------|-------------|
| `language` | string | Detected language |
| `size_bytes` | int | File size |
| `lines` | int | Line count |
| `symbols` | string[] | Symbol names in this file |
| `imports` | string[] | Import paths |
| `exports` | string[] | Exported symbol names |

### `symbols`

Array of symbol objects:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Symbol name |
| `kind` | string | `function`, `class`, `method`, `type` |
| `file` | string | Relative file path |
| `line` | int | Line number |
| `signature` | string | Full signature |
| `docstring` | string | First line of docstring (if available) |
| `visibility` | string | `public` or `private` |

### `edges`

Array of import-relationship objects:

| Field | Type | Description |
|-------|------|-------------|
| `source` | string | Importing file path |
| `target` | string | Imported file path |
| `type` | string | `import` |
| `symbols` | string[] | Imported symbol names |

### `modules`

Dict keyed by directory path. Each entry:

| Field | Type | Description |
|-------|------|-------------|
| `files` | string[] | File names in this module |
| `role` | string | Heuristic role (discovery, generation, verification, etc.) |
| `fan_in` | int | Number of other modules importing from this one |
| `fan_out` | int | Number of other modules this one imports from |
| `total_symbols` | int | Total symbols across all files |
| `circular_deps` | string[] | Modules with circular dependencies (if any) |

## Language Support

> **Note:** The Python indexer provides full symbol extraction for 7 languages (listed below). The language registry (`lib/data/languages.json`) supports 20 languages for detection via marker files.

### Extension Mapping

| Extension | Language |
|-----------|----------|
| `.sh`, `.bash` | bash |
| `.py` | python |
| `.ts`, `.tsx` | typescript |
| `.js`, `.jsx` | javascript |
| `.go` | go |
| `.rs` | rust |
| `.rb` | ruby |

### Excluded Directories

`.git`, `node_modules`, `.venv`, `__pycache__`, `target/`, `dist/`, `build/`, `.aiframework`

### File Size Limit

Files larger than 100KB are counted (language, size, lines) but not symbol-parsed.

## Dependency Graph

The graph builder (`graph.py`) resolves imports to actual file paths:

- **Python**: Handles relative imports (`.`, `..`, `...`) and dot-separated module paths
- **Go**: Skips domain-like imports (e.g., `github.com/...`) to avoid false resolution
- **TypeScript/JavaScript**: Resolves `import...from` and `require()` paths
- **Bash**: Resolves `source` and `.` commands (when paths don't contain variables)

### Module Roles

Directories are assigned heuristic roles:

| Directory name | Role |
|---------------|------|
| scanners | discovery |
| generators | generation |
| validators | verification |
| enhancers | enhancement |
| tests, spec | testing |
| utils, helpers | utility |
| bin, cmd, cli | entrypoint |
| tools, scripts | tooling |
| models, schemas | data-model |
| routes, handlers | routing |

## Downstream Consumers

### CLAUDE.md Generator

When `code-index.json` exists, `claude_md.sh` adds:
- **Module Map** table with role, file count, key symbols, dependencies
- **Architecture Hot Spots** showing highest fan-in and most complex modules

### Vault Generator

When `code-index.json` exists, `vault.sh` auto-populates:
- Module entity pages for modules with 3+ files
- Architecture concept page with module dependency graph
- API reference pages for modules with 10+ symbols
- Enhanced tech-stack data with per-language symbol counts

### Enhance Agents

The code analyzer agent reads `code-index.json` to identify:
- Missing test coverage
- Circular dependencies
- God modules (high fan-in + high symbol count)
- Orphan files (no imports in or out)

## Bash Fallback

When `python3` is unavailable, `code_index.sh` falls back to a bash-only implementation that produces a minimal index with file-level data (path, language, lines, size) but no symbols, edges, or modules.
