"""Python source parser for the code indexer.

Extracts functions, classes, methods, imports, and exports from Python files
using regex-based pattern matching.

Standard parser interface:
    language: str
    extensions: list[str]
    parse(content: str, filepath: str) -> tuple[list, list, list]
"""

from __future__ import annotations

import re
from typing import Any

# --- Standard parser interface attributes ---
language: str = "python"
extensions: list[str] = [".py"]

_Symbol = dict[str, Any]

_FUNC_RE = re.compile(
    r"^([ \t]*)def\s+(\w+)\s*\(([^)]*)\)(?:\s*->\s*([^:]+))?:", re.MULTILINE
)
_CLASS_RE = re.compile(r"^class\s+(\w+)(\([^)]*\))?:", re.MULTILINE)
_IMPORT_RE = re.compile(r"^\s*import\s+(.+)", re.MULTILINE)
_FROM_IMPORT_RE = re.compile(r"^\s*from\s+(\S+)\s+import", re.MULTILINE)
_ALL_RE = re.compile(r"^__all__\s*=\s*\[([^\]]*)\]", re.MULTILINE | re.DOTALL)
_DOCSTRING_RE = re.compile(r'\s*\n\s*(?:"""|\'\'\')\s*(.+?)(?:"""|\'\'\'|$)', re.DOTALL)


def _first_doc_line(text_after_def: str) -> str:
    """Extract the first line of a docstring following a def/class."""
    m = _DOCSTRING_RE.match(text_after_def)
    if m:
        return m.group(1).strip().split("\n")[0]
    return ""


def _find_parent_class(content: str, func_start: int) -> str | None:
    """Find the class that contains an indented method definition."""
    before = content[:func_start]
    best: str | None = None
    for m in _CLASS_RE.finditer(before):
        best = m.group(1)
    return best


def parse(content: str, filepath: str) -> tuple[list[_Symbol], list[str], list[str]]:
    """Parse a Python file and return (symbols, imports, exports)."""
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # --- Detect __all__ for explicit exports ---
    explicit_all: list[str] | None = None
    m_all = _ALL_RE.search(content)
    if m_all:
        raw = m_all.group(1)
        explicit_all = re.findall(r"['\"](\w+)['\"]", raw)

    # --- Functions and methods ---
    for m in _FUNC_RE.finditer(content):
        indent, name, params, ret = m.group(1), m.group(2), m.group(3), m.group(4)
        line = content[: m.start()].count("\n") + 1
        sig = f"def {name}({params.strip()})"
        if ret:
            sig += f" -> {ret.strip()}"
        docstring = _first_doc_line(content[m.end():])
        visibility = "private" if name.startswith("_") else "public"

        is_method = len(indent) > 0
        entry: dict = {
            "name": name,
            "kind": "method" if is_method else "function",
            "line": line,
            "signature": sig,
            "docstring": docstring,
            "visibility": visibility,
        }
        if is_method:
            parent = _find_parent_class(content, m.start())
            if parent:
                entry["parent"] = parent

        symbols.append(entry)

    # --- Classes ---
    for m in _CLASS_RE.finditer(content):
        name = m.group(1)
        bases = m.group(2) or ""
        line = content[: m.start()].count("\n") + 1
        sig = f"class {name}{bases}" if bases else f"class {name}"
        docstring = _first_doc_line(content[m.end():])
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "line": line,
                "signature": sig,
                "docstring": docstring,
                "visibility": "public" if not name.startswith("_") else "private",
            }
        )

    # --- Imports ---
    for m in _FROM_IMPORT_RE.finditer(content):
        imports.append(m.group(1))
    for m in _IMPORT_RE.finditer(content):
        raw = m.group(1)
        if raw.strip().startswith("from "):
            continue
        for part in raw.split(","):
            mod = part.strip().split(" ")[0]
            if mod:
                imports.append(mod)

    # --- Exports ---
    if explicit_all is not None:
        exports = list(explicit_all)
    else:
        for sym in symbols:
            if sym["visibility"] == "public" and sym["kind"] in ("function", "class"):
                exports.append(sym["name"])

    return symbols, imports, exports


# Legacy dict-based interface for backward compatibility
def parse_python(filepath: str, content: str) -> dict:
    """Legacy interface: returns dict with symbols/imports/exports."""
    symbols, imports, exports = parse(content, filepath)
    return {"symbols": symbols, "imports": imports, "exports": exports}
