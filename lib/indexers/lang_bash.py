"""Bash/shell script parser for the code indexer.

Extracts functions, source/dot imports, and exports from shell scripts
using regex-based pattern matching.
"""

from __future__ import annotations

import re


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


def parse_bash(filepath: str, content: str) -> dict:
    """Parse a bash/shell script and return symbols, imports, and exports.

    Args:
        filepath: Path to the file (used for context, not read).
        content: The full text content of the file.

    Returns:
        dict with keys ``symbols``, ``imports``, ``exports``.
    """
    lines = content.splitlines()
    symbols: list[dict] = []
    imports: list[str] = []
    exports: list[str] = []

    for line_no, line in enumerate(lines, start=1):
        # --- function detection ---
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

        # --- source / dot imports ---
        m = _SOURCE_RE.match(line)
        if m:
            imports.append(m.group(1))

    return {
        "symbols": symbols,
        "imports": imports,
        "exports": exports,
    }
