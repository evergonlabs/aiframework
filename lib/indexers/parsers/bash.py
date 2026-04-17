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


def _normalize_bash_import(raw: str) -> str | None:
    """Normalize a bash source/dot import path to a relative file path.

    Strips shell variable prefixes ($VAR/, ${VAR}/, $(...)) and leading ./,
    returning a clean relative path suitable for graph resolution.
    Returns None if the path cannot be meaningfully parsed.
    """
    path = raw.strip()

    # Remove surrounding quotes
    path = path.strip("\"'")

    # Skip command substitutions like $(dirname $0)/...
    if "$(" in path and ")" in path:
        # Try to extract just the path portion after the closing paren
        idx = path.rfind(")")
        remainder = path[idx + 1:].lstrip("/")
        if remainder and not remainder.startswith("$"):
            path = remainder
        else:
            return None

    # Strip shell variable prefixes: ${VAR}/, $VAR/
    # e.g. "${ROOT_DIR}/lib/scanners/stack.sh" -> "lib/scanners/stack.sh"
    # e.g. "$LIB_DIR/generators/preserve.sh" -> "generators/preserve.sh"
    path = re.sub(r'\$\{[^}]+\}/', '', path)
    path = re.sub(r'\$[A-Za-z_][A-Za-z_0-9]*/', '', path)

    # Strip leading ./
    path = re.sub(r'^\./', '', path)

    # Strip leading /
    path = path.lstrip('/')

    # If nothing left, or still has unresolved variables, skip
    if not path or '$' in path:
        return None

    # Must look like a plausible file path (contains at least one path char)
    if not re.match(r'^[\w./_-]+$', path):
        return None

    return path


_FUNC_KEYWORD = re.compile(r"^function\s+(\w+)")
_FUNC_PARENS = re.compile(r"^(\w+)\s*\(\)\s*\{")
_SOURCE_RE = re.compile(r"^\s*(?:source|\.)\s+(.+)$")


def parse(content: str, filepath: str) -> tuple[list[_Symbol], list[str], list[str]]:
    """Parse a bash/shell script and return (symbols, imports, exports)."""
    lines = content.splitlines()
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    for line_no, line in enumerate(lines, start=1):
        stripped = line.strip()

        # Skip comments
        if stripped.startswith("#"):
            continue

        name: str | None = None
        signature: str = ""

        m = _FUNC_KEYWORD.match(stripped)
        if m:
            name = m.group(1)
            signature = f"function {name}()"
        else:
            m = _FUNC_PARENS.match(stripped)
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
                    "file": filepath,
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
            raw_path = m.group(1).strip()
            # Remove inline comments
            raw_path = re.sub(r'\s*#.*$', '', raw_path)
            normalized = _normalize_bash_import(raw_path)
            if normalized:
                imports.append(normalized)

    return symbols, imports, exports


# Legacy dict-based interface for backward compatibility
def parse_bash(filepath: str, content: str) -> dict:
    """Legacy interface: returns dict with symbols/imports/exports."""
    symbols, imports, exports = parse(content, filepath)
    return {"symbols": symbols, "imports": imports, "exports": exports}
