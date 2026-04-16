"""Go language parser for the code indexer.

Extracts functions (with receiver detection), types (struct/interface),
and imports using regex-based parsing. Visibility follows Go convention:
uppercase first letter = public, lowercase = private.

Standard parser interface:
    language: str
    extensions: list[str]
    parse(content: str, filepath: str) -> tuple[list, list, list]
"""

from __future__ import annotations

import re
from typing import Any

# --- Standard parser interface attributes ---
language: str = "go"
extensions: list[str] = [".go"]

_Symbol = dict[str, Any]


def _extract_doc_comment(text: str, pos: int) -> str:
    """Extract the // comment block immediately before *pos*."""
    before = text[:pos].rstrip()
    doc_lines: list[str] = []
    for line in reversed(before.splitlines()):
        stripped = line.strip()
        if stripped.startswith("//"):
            doc_lines.append(stripped.lstrip("/").strip())
        else:
            break
    if doc_lines:
        return doc_lines[-1]  # first logical line (reversed)
    return ""


def parse(content: str, filepath: str) -> tuple[list[_Symbol], list[str], list[str]]:
    """Parse Go source and return (symbols, imports, exports)."""
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Functions and methods
    for m in re.finditer(
        r'^func\s+(\([^)]*\)\s+)?(\w+)\s*\(([^)]*)\)',
        content,
        re.MULTILINE,
    ):
        receiver, name, params = m.group(1), m.group(2), m.group(3)
        line = content[: m.start()].count("\n") + 1
        vis = "public" if name[0].isupper() else "private"
        kind = "method" if receiver else "function"
        sig = f"func {name}({params.strip()})"
        if receiver:
            sig = f"func {receiver.strip()} {name}({params.strip()})"
        doc = _extract_doc_comment(content, m.start())
        symbols.append({
            "name": name,
            "kind": kind,
            "line": line,
            "signature": sig,
            "docstring": doc,
            "visibility": vis,
        })
        if vis == "public":
            exports.append(name)

    # Type declarations
    for m in re.finditer(
        r'^type\s+(\w+)\s+(struct|interface)',
        content,
        re.MULTILINE,
    ):
        name, type_kw = m.group(1), m.group(2)
        line = content[: m.start()].count("\n") + 1
        vis = "public" if name[0].isupper() else "private"
        doc = _extract_doc_comment(content, m.start())
        symbols.append({
            "name": name,
            "kind": type_kw,
            "line": line,
            "signature": f"type {name} {type_kw}",
            "docstring": doc,
            "visibility": vis,
        })
        if vis == "public":
            exports.append(name)

    # Imports
    for m in re.finditer(r'import\s*\((.*?)\)', content, re.DOTALL):
        for im in re.finditer(r'"([^"]+)"', m.group(1)):
            imports.append(im.group(1))
    for m in re.finditer(r'^import\s+"([^"]+)"', content, re.MULTILINE):
        imports.append(m.group(1))

    return symbols, imports, exports


# Legacy dict-based interface for backward compatibility
def parse_go(filepath: str, content: str) -> dict:
    """Legacy interface: returns dict with symbols/imports/exports."""
    symbols, imports, exports = parse(content, filepath)
    return {"symbols": symbols, "imports": imports, "exports": exports}
