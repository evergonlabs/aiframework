"""Bash/shell script parser for the code indexer.

Extracts functions, source/dot imports, and exports from shell scripts
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
language: str = "bash"
extensions: list[str] = [".sh", ".bash"]

_Symbol = dict[str, Any]


def _extract_docstring(lines: list[str], func_line: int) -> str:
    """Collect the # comment block immediately before a function definition."""
    doc_lines: list[str] = []
    idx = func_line - 2  # 0-based index of line before the function
    while idx >= 0:
        stripped = lines[idx].strip()
        if stripped.startswith("#"):
            doc_lines.append(stripped.lstrip("# "))
            idx -= 1
        else:
            break
    doc_lines.reverse()
    return "\n".join(doc_lines)


_FUNC_KEYWORD = re.compile(r"^function\s+(\w+)")
_FUNC_PARENS = re.compile(r"^(\w+)\s*\(\)\s*\{")
_SOURCE_RE = re.compile(r"^\s*(?:source|\.)\s+[\"']?(.+?)[\"']?\s*$")


def parse(content: str, filepath: str) -> tuple[list[_Symbol], list[str], list[str]]:
    """Parse a bash/shell script and return (symbols, imports, exports)."""
    lines = content.splitlines()
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    for line_no, line in enumerate(lines, start=1):
        name: str | None = None
        signature: str = ""

        m = _FUNC_KEYWORD.match(line.strip())
        if m:
            name = m.group(1)
            signature = f"function {name}()"
        else:
            m = _FUNC_PARENS.match(line.strip())
            if m:
                name = m.group(1)
                signature = f"{name}()"

        if name:
            docstring = _extract_docstring(lines, line_no)
            visibility = "private" if name.startswith("_") else "public"
            symbols.append(
                {
                    "name": name,
                    "kind": "function",
                    "line": line_no,
                    "signature": signature,
                    "docstring": docstring,
                    "visibility": visibility,
                }
            )
            if visibility == "public":
                exports.append(name)
            continue

        m = _SOURCE_RE.match(line)
        if m:
            imports.append(m.group(1))

    return symbols, imports, exports


# Legacy dict-based interface for backward compatibility
def parse_bash(filepath: str, content: str) -> dict:
    """Legacy interface: returns dict with symbols/imports/exports."""
    symbols, imports, exports = parse(content, filepath)
    return {"symbols": symbols, "imports": imports, "exports": exports}
