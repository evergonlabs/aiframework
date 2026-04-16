"""TypeScript/JavaScript language parser for the code indexer.

Extracts functions, arrow functions, classes, interfaces, types, and imports
using regex-based parsing. Supports JSDoc comment extraction.

Standard parser interface:
    language: str
    extensions: list[str]
    parse(content: str, filepath: str) -> tuple[list, list, list]
"""

from __future__ import annotations

import re
from typing import Any

# --- Standard parser interface attributes ---
language: str = "typescript"
extensions: list[str] = [".ts", ".tsx", ".js", ".jsx"]

_Symbol = dict[str, Any]


def _extract_jsdoc(text: str, pos: int) -> str:
    """Extract the JSDoc comment (/** ... */) immediately before *pos*."""
    before = text[:pos].rstrip()
    m = re.search(r'/\*\*\s*(.*?)\s*\*/\s*$', before, re.DOTALL)
    if m:
        for line in m.group(1).splitlines():
            cleaned = re.sub(r'^\s*\*\s?', '', line).strip()
            if cleaned:
                return cleaned
    return ""


def parse(content: str, filepath: str) -> tuple[list[_Symbol], list[str], list[str]]:
    """Parse TypeScript/JavaScript source and return (symbols, imports, exports)."""
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Exported and non-exported functions
    for m in re.finditer(
        r'^(export\s+)?(default\s+)?(async\s+)?function\s+(\w+)\s*\(([^)]*)\)',
        content,
        re.MULTILINE,
    ):
        exported, _default, _async, name, params = (
            m.group(1), m.group(2), m.group(3), m.group(4), m.group(5),
        )
        line = content[: m.start()].count("\n") + 1
        doc = _extract_jsdoc(content, m.start())
        vis = "public" if exported else "private"
        symbols.append({
            "name": name,
            "kind": "function",
            "line": line,
            "signature": f"function {name}({params.strip()})",
            "docstring": doc,
            "visibility": vis,
        })
        if exported:
            exports.append(name)

    # Arrow / const functions
    for m in re.finditer(
        r'^(export\s+)?(const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\(',
        content,
        re.MULTILINE,
    ):
        exported, _kw, name = m.group(1), m.group(2), m.group(3)
        line = content[: m.start()].count("\n") + 1
        doc = _extract_jsdoc(content, m.start())
        vis = "public" if exported else "private"
        symbols.append({
            "name": name,
            "kind": "function",
            "line": line,
            "signature": f"const {name} = (...)",
            "docstring": doc,
            "visibility": vis,
        })
        if exported:
            exports.append(name)

    # Classes
    for m in re.finditer(
        r'^(export\s+)?(default\s+)?class\s+(\w+)',
        content,
        re.MULTILINE,
    ):
        exported, _default, name = m.group(1), m.group(2), m.group(3)
        line = content[: m.start()].count("\n") + 1
        doc = _extract_jsdoc(content, m.start())
        vis = "public" if exported else "private"
        symbols.append({
            "name": name,
            "kind": "class",
            "line": line,
            "signature": f"class {name}",
            "docstring": doc,
            "visibility": vis,
        })
        if exported:
            exports.append(name)

    # Interfaces and type aliases
    for m in re.finditer(
        r'^(export\s+)?(interface|type)\s+(\w+)',
        content,
        re.MULTILINE,
    ):
        exported, kind_kw, name = m.group(1), m.group(2), m.group(3)
        line = content[: m.start()].count("\n") + 1
        doc = _extract_jsdoc(content, m.start())
        vis = "public" if exported else "private"
        symbols.append({
            "name": name,
            "kind": kind_kw,
            "line": line,
            "signature": f"{kind_kw} {name}",
            "docstring": doc,
            "visibility": vis,
        })
        if exported:
            exports.append(name)

    # Imports
    for m in re.finditer(r"""import\s+.*?from\s+['"]([^'"]+)['"]""", content):
        imports.append(m.group(1))
    for m in re.finditer(r"""require\s*\(\s*['"]([^'"]+)['"]\s*\)""", content):
        imports.append(m.group(1))

    return symbols, imports, exports


# Legacy dict-based interface for backward compatibility
def parse_typescript(filepath: str, content: str) -> dict:
    """Legacy interface: returns dict with symbols/imports/exports."""
    symbols, imports, exports = parse(content, filepath)
    return {"symbols": symbols, "imports": imports, "exports": exports}
