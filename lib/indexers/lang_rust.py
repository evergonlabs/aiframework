"""Rust language parser for the code indexer.

Extracts functions (sync/async), structs, enums, traits, and use-imports
using regex-based parsing. Visibility: ``pub`` prefix = public, otherwise private.
Doc comments (``///``) are captured.
"""

from __future__ import annotations

import re
from typing import Any

_Symbol = dict[str, Any]


def _extract_doc_comment(text: str, pos: int) -> str:
    """Extract the /// doc-comment block immediately before *pos*."""
    before = text[:pos].rstrip()
    doc_lines: list[str] = []
    for line in reversed(before.splitlines()):
        stripped = line.strip()
        if stripped.startswith("///"):
            doc_lines.append(stripped.lstrip("/").strip())
        else:
            break
    if doc_lines:
        return doc_lines[-1]  # first logical line (reversed)
    return ""


def parse_rust(filepath: str, content: str) -> dict[str, Any]:
    """Parse Rust source and return symbols, imports, exports."""
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Functions: pub (async) fn name(params)
    for m in re.finditer(
        r'^(pub(?:\([^)]*\))?\s+)?(async\s+)?fn\s+(\w+)\s*\(([^)]*)\)',
        content,
        re.MULTILINE,
    ):
        pub, _async, name, params = m.group(1), m.group(2), m.group(3), m.group(4)
        line = content[: m.start()].count("\n") + 1
        vis = "public" if pub else "private"
        prefix = "async fn" if _async else "fn"
        doc = _extract_doc_comment(content, m.start())
        symbols.append({
            "name": name,
            "kind": "function",
            "line": line,
            "signature": f"{prefix} {name}({params.strip()})",
            "docstring": doc,
            "visibility": vis,
        })
        if vis == "public":
            exports.append(name)

    # Structs, enums, traits
    for m in re.finditer(
        r'^(pub(?:\([^)]*\))?\s+)?(struct|enum|trait)\s+(\w+)',
        content,
        re.MULTILINE,
    ):
        pub, kind_kw, name = m.group(1), m.group(2), m.group(3)
        line = content[: m.start()].count("\n") + 1
        vis = "public" if pub else "private"
        doc = _extract_doc_comment(content, m.start())
        symbols.append({
            "name": name,
            "kind": kind_kw,
            "line": line,
            "signature": f"{kind_kw} {name}",
            "docstring": doc,
            "visibility": vis,
        })
        if vis == "public":
            exports.append(name)

    # Imports: use path::to::module;
    for m in re.finditer(r'^\s*use\s+(.+?);', content, re.MULTILINE):
        imports.append(m.group(1).strip())

    return {"symbols": symbols, "imports": imports, "exports": exports}
