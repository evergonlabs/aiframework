"""TypeScript/JavaScript language parser for the code indexer.

Extracts functions, arrow functions, classes, interfaces, types, and imports
using regex-based parsing. Supports JSDoc comment extraction.
"""

from __future__ import annotations

import re
from typing import Any

_Symbol = dict[str, Any]


def _extract_jsdoc(text: str, pos: int) -> str:
    """Extract the JSDoc comment (/** ... */) immediately before *pos*."""
    before = text[:pos].rstrip()
    m = re.search(r'/\*\*\s*(.*?)\s*\*/\s*$', before, re.DOTALL)
    if m:
        # Return the first non-empty line of the doc block.
        for line in m.group(1).splitlines():
            cleaned = re.sub(r'^\s*\*\s?', '', line).strip()
            if cleaned:
                return cleaned
    return ""


def parse_typescript(filepath: str, content: str) -> dict[str, Any]:
    """Parse TypeScript/JavaScript source and return symbols, imports, exports."""
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    lines = content.split("\n")

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

    # Arrow / const functions: export const foo = (...) => ...
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

    # Classes (exported and non-exported)
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
            "kind": kind_kw,  # "interface" or "type"
            "line": line,
            "signature": f"{kind_kw} {name}",
            "docstring": doc,
            "visibility": vis,
        })
        if exported:
            exports.append(name)

    # Imports: import ... from "module"  /  require("module")
    for m in re.finditer(r"""import\s+.*?from\s+['"]([^'"]+)['"]""", content):
        imports.append(m.group(1))
    for m in re.finditer(r"""require\s*\(\s*['"]([^'"]+)['"]\s*\)""", content):
        imports.append(m.group(1))

    return {"symbols": symbols, "imports": imports, "exports": exports}
