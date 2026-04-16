"""Ruby language parser for the code indexer.

Extracts methods, classes, modules, and require/require_relative imports
using regex-based parsing. Tracks ``private`` keyword to determine visibility.
RDoc-style ``#`` comment blocks before definitions are captured.

Standard parser interface:
    language: str
    extensions: list[str]
    parse(content: str, filepath: str) -> tuple[list, list, list]
"""

from __future__ import annotations

import re
from typing import Any

# --- Standard parser interface attributes ---
language: str = "ruby"
extensions: list[str] = [".rb"]

_Symbol = dict[str, Any]


def _extract_rdoc_comment(text: str, pos: int) -> str:
    """Extract the # comment block immediately before *pos*."""
    before = text[:pos].rstrip()
    doc_lines: list[str] = []
    for line in reversed(before.splitlines()):
        stripped = line.strip()
        if stripped.startswith("#"):
            doc_lines.append(stripped.lstrip("#").strip())
        else:
            break
    if doc_lines:
        return doc_lines[-1]  # first logical line (reversed)
    return ""


def parse(content: str, filepath: str) -> tuple[list[_Symbol], list[str], list[str]]:
    """Parse Ruby source and return (symbols, imports, exports)."""
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Track lines where `private` appears
    private_lines: list[int] = []
    for m in re.finditer(r'^\s*private\s*$', content, re.MULTILINE):
        private_lines.append(content[: m.start()].count("\n") + 1)

    # Methods
    for m in re.finditer(
        r'^\s*def\s+(self\.)?(\w+[?!=]?)\s*(\([^)]*\))?',
        content,
        re.MULTILINE,
    ):
        _class_method, name, params = m.group(1), m.group(2), m.group(3) or "()"
        line = content[: m.start()].count("\n") + 1
        vis = "public"
        for pl in private_lines:
            if pl < line:
                vis = "private"
        if name.startswith("_"):
            vis = "private"
        doc = _extract_rdoc_comment(content, m.start())
        symbols.append({
            "name": name,
            "kind": "method",
            "line": line,
            "signature": f"def {name}{params}",
            "docstring": doc,
            "visibility": vis,
        })
        if vis == "public":
            exports.append(name)

    # Classes and modules
    for m in re.finditer(
        r'^\s*(class|module)\s+(\w+)',
        content,
        re.MULTILINE,
    ):
        kind_kw, name = m.group(1), m.group(2)
        line = content[: m.start()].count("\n") + 1
        doc = _extract_rdoc_comment(content, m.start())
        symbols.append({
            "name": name,
            "kind": kind_kw,
            "line": line,
            "signature": f"{kind_kw} {name}",
            "docstring": doc,
            "visibility": "public",
        })
        exports.append(name)

    # Imports
    for m in re.finditer(
        r"""^\s*require(?:_relative)?\s+['"]([^'"]+)['"]""",
        content,
        re.MULTILINE,
    ):
        imports.append(m.group(1))

    return symbols, imports, exports


# Legacy dict-based interface for backward compatibility
def parse_ruby(filepath: str, content: str) -> dict:
    """Legacy interface: returns dict with symbols/imports/exports."""
    symbols, imports, exports = parse(content, filepath)
    return {"symbols": symbols, "imports": imports, "exports": exports}
