"""Main entry point for the code indexer.

Walks a repository, dispatches files to language-specific regex parsers,
builds a dependency graph, and writes a structured JSON index.

Usage:
    python3 -m lib.indexers.parse --target <dir> --output <path>
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from typing import Any

from . import __version__
from .graph import build_graph, compute_pagerank
from .registry import discover_parsers

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_EXCLUDED_DIRS: set[str] = {
    ".git",
    "node_modules",
    ".venv",
    "__pycache__",
    "target",
    "dist",
    "build",
    ".aiframework",
}

_MAX_FILE_SIZE = 512 * 1024  # 512 KB — covers large generated files like vault.sh

# Base extension-to-language mapping for languages without plugin parsers.
# Plugin parsers (from parsers/ and contrib/) contribute their own mappings
# via the registry and are merged in below.
_EXT_LANGUAGE_BASE: dict[str, str] = {
    ".java": "java",
    ".cs": "csharp",
    ".php": "php",
    ".kt": "kotlin",
    ".kts": "kotlin",
    ".swift": "swift",
    ".ex": "elixir",
    ".exs": "elixir",
}

# Discover plugin parsers and merge extension mappings.
_PLUGIN_PARSERS, _PLUGIN_EXT_LANGUAGE = discover_parsers()

_EXT_LANGUAGE: dict[str, str] = {**_EXT_LANGUAGE_BASE, **_PLUGIN_EXT_LANGUAGE}

# ---------------------------------------------------------------------------
# Language parsers — each returns (symbols, imports, exports)
# ---------------------------------------------------------------------------

_Symbol = dict[str, Any]


def _lang_bash(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    for m in re.finditer(
        r"^(?:function\s+)?(\w+)\s*\(\s*\)", text, re.MULTILINE
    ):
        name = m.group(1)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"{name}()",
                "docstring": "",
                "visibility": "public",
            }
        )
    for m in re.finditer(r"^\s*(?:source|\.)\s+[\"']?([^\s\"']+)", text, re.MULTILINE):
        imports.append(m.group(1))
    return symbols, imports, []


def _lang_python(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Functions
    for m in re.finditer(
        r"^([ \t]*)def\s+(\w+)\s*\(([^)]*)\)(?:\s*->\s*([^:]+))?:", text, re.MULTILINE
    ):
        indent, name, params, ret = m.group(1), m.group(2), m.group(3), m.group(4)
        line = text[: m.start()].count("\n") + 1
        sig = f"def {name}({params.strip()})"
        if ret:
            sig += f" -> {ret.strip()}"
        # Grab first line of docstring if present.
        doc = ""
        after = text[m.end() :]
        dm = re.match(r'\s*\n\s*(?:"""|\'\'\')(.+?)(?:"""|\'\'\'|$)', after, re.DOTALL)
        if dm:
            doc = dm.group(1).strip().split("\n")[0]
        vis = "private" if name.startswith("_") else "public"
        symbols.append(
            {
                "name": name,
                "kind": "method" if len(indent) > 0 else "function",
                "file": rel_path,
                "line": line,
                "signature": sig,
                "docstring": doc,
                "visibility": vis,
            }
        )
        if vis == "public" and len(indent) == 0:
            exports.append(name)

    # Classes
    for m in re.finditer(r"^class\s+(\w+)(?:\(([^)]*)\))?:", text, re.MULTILINE):
        name = m.group(1)
        bases = m.group(2) or ""
        line = text[: m.start()].count("\n") + 1
        sig = f"class {name}"
        if bases:
            sig += f"({bases.strip()})"
        doc = ""
        after = text[m.end() :]
        dm = re.match(r'\s*\n\s*(?:"""|\'\'\')(.+?)(?:"""|\'\'\'|$)', after, re.DOTALL)
        if dm:
            doc = dm.group(1).strip().split("\n")[0]
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "file": rel_path,
                "line": line,
                "signature": sig,
                "docstring": doc,
                "visibility": "public" if not name.startswith("_") else "private",
            }
        )
        if not name.startswith("_"):
            exports.append(name)

    # Imports
    for m in re.finditer(r"^\s*(?:from\s+([\w.]+)\s+)?import\s+([\w., ]+)", text, re.MULTILINE):
        mod = m.group(1)
        names = m.group(2)
        if mod:
            imports.append(mod)
        else:
            for part in names.split(","):
                imports.append(part.strip().split(" ")[0])

    return symbols, imports, exports


def _lang_typescript(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Functions (export/async variants)
    for m in re.finditer(
        r"^(export\s+)?(?:default\s+)?(?:async\s+)?function\s+(\w+)\s*\(([^)]*)\)",
        text,
        re.MULTILINE,
    ):
        exported, name, params = m.group(1), m.group(2), m.group(3)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"function {name}({params.strip()})",
                "docstring": "",
                "visibility": "public" if exported else "private",
            }
        )
        if exported:
            exports.append(name)

    # Arrow / const functions
    for m in re.finditer(
        r"^(export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\(",
        text,
        re.MULTILINE,
    ):
        exported, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"const {name} = (...)",
                "docstring": "",
                "visibility": "public" if exported else "private",
            }
        )
        if exported:
            exports.append(name)

    # Classes
    for m in re.finditer(
        r"^(export\s+)?class\s+(\w+)", text, re.MULTILINE
    ):
        exported, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "file": rel_path,
                "line": line,
                "signature": f"class {name}",
                "docstring": "",
                "visibility": "public" if exported else "private",
            }
        )
        if exported:
            exports.append(name)

    # Interfaces / types
    for m in re.finditer(
        r"^(export\s+)?(?:interface|type)\s+(\w+)", text, re.MULTILINE
    ):
        exported, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "type",
                "file": rel_path,
                "line": line,
                "signature": f"type {name}",
                "docstring": "",
                "visibility": "public" if exported else "private",
            }
        )
        if exported:
            exports.append(name)

    # Imports
    for m in re.finditer(
        r"""(?:import|require)\s*\(?['"]([^'"]+)['"]""", text
    ):
        imports.append(m.group(1))

    return symbols, imports, exports


def _lang_go(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    for m in re.finditer(r"^func\s+(?:\(\w+\s+\*?\w+\)\s+)?(\w+)\s*\(([^)]*)\)", text, re.MULTILINE):
        name, params = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if name[0].isupper() else "private"
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"func {name}({params.strip()})",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    for m in re.finditer(r"^type\s+(\w+)\s+(?:struct|interface)", text, re.MULTILINE):
        name = m.group(1)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if name[0].isupper() else "private"
        symbols.append(
            {
                "name": name,
                "kind": "type",
                "file": rel_path,
                "line": line,
                "signature": f"type {name}",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    for m in re.finditer(r'"([^"]+)"', text):
        candidate = m.group(1)
        if "/" in candidate and not candidate.startswith("http"):
            imports.append(candidate)

    return symbols, imports, exports


def _lang_rust(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    for m in re.finditer(r"^(pub(?:\([^)]*\))?\s+)?fn\s+(\w+)\s*\(([^)]*)\)", text, re.MULTILINE):
        pub, name, params = m.group(1), m.group(2), m.group(3)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if pub else "private"
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"fn {name}({params.strip()})",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    for m in re.finditer(r"^(pub\s+)?(?:struct|enum|trait)\s+(\w+)", text, re.MULTILINE):
        pub, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if pub else "private"
        symbols.append(
            {
                "name": name,
                "kind": "type",
                "file": rel_path,
                "line": line,
                "signature": f"type {name}",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    for m in re.finditer(r"^\s*use\s+([\w:]+)", text, re.MULTILINE):
        imports.append(m.group(1))

    return symbols, imports, exports


def _lang_ruby(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    for m in re.finditer(r"^\s*def\s+(self\.)?(\w+[?!=]?)\s*(\([^)]*\))?", text, re.MULTILINE):
        class_method, name, params = m.group(1), m.group(2), m.group(3) or "()"
        line = text[: m.start()].count("\n") + 1
        vis = "private" if name.startswith("_") else "public"
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"def {name}{params}",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    for m in re.finditer(r"^\s*class\s+(\w+)", text, re.MULTILINE):
        name = m.group(1)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "file": rel_path,
                "line": line,
                "signature": f"class {name}",
                "docstring": "",
                "visibility": "public",
            }
        )
        exports.append(name)

    for m in re.finditer(r"^\s*(?:require|require_relative|load)\s+['\"]([^'\"]+)", text, re.MULTILINE):
        imports.append(m.group(1))

    return symbols, imports, exports


def _lang_java(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []
    lines = text.split("\n")

    # Classes
    for m in re.finditer(
        r"^(public\s+)?(abstract\s+)?class\s+(\w+)", text, re.MULTILINE
    ):
        name = m.group(3)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if m.group(1) else "package"
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "file": rel_path,
                "line": line,
                "signature": f"class {name}",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    # Interfaces
    for m in re.finditer(
        r"^(public\s+)?interface\s+(\w+)", text, re.MULTILINE
    ):
        name = m.group(2)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if m.group(1) else "package"
        symbols.append(
            {
                "name": name,
                "kind": "interface",
                "file": rel_path,
                "line": line,
                "signature": f"interface {name}",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    # Methods (with annotation as docstring)
    for m in re.finditer(
        r"^\s+(public|protected|private)\s+.*?\s+(\w+)\s*\(", text, re.MULTILINE
    ):
        vis_kw, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        # Look for annotation on preceding line
        doc = ""
        line_idx = line - 2  # zero-based index of line before
        if line_idx >= 0 and line_idx < len(lines):
            ann = re.search(r"@(\w+)", lines[line_idx])
            if ann:
                doc = f"@{ann.group(1)}"
        symbols.append(
            {
                "name": name,
                "kind": "method",
                "file": rel_path,
                "line": line,
                "signature": f"{name}()",
                "docstring": doc,
                "visibility": vis_kw,
            }
        )

    # Imports
    for m in re.finditer(r"^import\s+([\w.]+);", text, re.MULTILINE):
        imports.append(m.group(1))

    return symbols, imports, exports


def _lang_csharp(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Classes
    for m in re.finditer(
        r"^(public|internal)\s+(abstract\s+)?class\s+(\w+)", text, re.MULTILINE
    ):
        vis_kw, name = m.group(1), m.group(3)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "file": rel_path,
                "line": line,
                "signature": f"class {name}",
                "docstring": "",
                "visibility": vis_kw,
            }
        )
        if vis_kw == "public":
            exports.append(name)

    # Interfaces
    for m in re.finditer(
        r"^(public|internal)\s+interface\s+(\w+)", text, re.MULTILINE
    ):
        vis_kw, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "interface",
                "file": rel_path,
                "line": line,
                "signature": f"interface {name}",
                "docstring": "",
                "visibility": vis_kw,
            }
        )
        if vis_kw == "public":
            exports.append(name)

    # Methods
    for m in re.finditer(
        r"^\s+(public|protected|private|internal)\s+.*?\s+(\w+)\s*\(", text, re.MULTILINE
    ):
        vis_kw, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "method",
                "file": rel_path,
                "line": line,
                "signature": f"{name}()",
                "docstring": "",
                "visibility": vis_kw,
            }
        )

    # Imports
    for m in re.finditer(r"^using\s+([\w.]+);", text, re.MULTILINE):
        imports.append(m.group(1))

    return symbols, imports, exports


def _lang_php(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Namespaces (captured as an export)
    for m in re.finditer(r"^namespace\s+([\w\\]+);", text, re.MULTILINE):
        exports.append(m.group(1))

    # Classes
    for m in re.finditer(r"^class\s+(\w+)", text, re.MULTILINE):
        name = m.group(1)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "file": rel_path,
                "line": line,
                "signature": f"class {name}",
                "docstring": "",
                "visibility": "public",
            }
        )
        exports.append(name)

    # Functions / methods
    for m in re.finditer(
        r"^(public|protected|private)?\s*function\s+(\w+)", text, re.MULTILINE
    ):
        vis_kw, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        vis = vis_kw if vis_kw else "public"
        symbols.append(
            {
                "name": name,
                "kind": "function" if vis_kw is None else "method",
                "file": rel_path,
                "line": line,
                "signature": f"function {name}()",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    # Imports: use statements
    for m in re.finditer(r"^use\s+([\w\\]+);", text, re.MULTILINE):
        imports.append(m.group(1))

    # Imports: require / require_once
    for m in re.finditer(r"^require(?:_once)?\s+", text, re.MULTILINE):
        line_end = text.find("\n", m.start())
        snippet = text[m.start() : line_end if line_end != -1 else len(text)]
        sm = re.search(r"""['"]([^'"]+)['"]""", snippet)
        if sm:
            imports.append(sm.group(1))

    return symbols, imports, exports


def _lang_kotlin(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Classes (including data classes)
    for m in re.finditer(r"^(data\s+)?class\s+(\w+)", text, re.MULTILINE):
        name = m.group(2)
        line = text[: m.start()].count("\n") + 1
        kind = "class"
        sig = f"data class {name}" if m.group(1) else f"class {name}"
        symbols.append(
            {
                "name": name,
                "kind": kind,
                "file": rel_path,
                "line": line,
                "signature": sig,
                "docstring": "",
                "visibility": "public",
            }
        )
        exports.append(name)

    # Objects
    for m in re.finditer(r"^object\s+(\w+)", text, re.MULTILINE):
        name = m.group(1)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "file": rel_path,
                "line": line,
                "signature": f"object {name}",
                "docstring": "",
                "visibility": "public",
            }
        )
        exports.append(name)

    # Functions (including suspend)
    for m in re.finditer(r"^(fun|suspend\s+fun)\s+(\w+)", text, re.MULTILINE):
        prefix, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"{prefix} {name}()",
                "docstring": "",
                "visibility": "public",
            }
        )
        exports.append(name)

    # Imports
    for m in re.finditer(r"^import\s+([\w.]+)", text, re.MULTILINE):
        imports.append(m.group(1))

    return symbols, imports, exports


def _lang_swift(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Structs / Classes / Protocols / Enums
    for m in re.finditer(
        r"^(public\s+)?(struct|class|protocol|enum)\s+(\w+)", text, re.MULTILINE
    ):
        pub, kind_kw, name = m.group(1), m.group(2), m.group(3)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if pub else "internal"
        kind_map = {"struct": "type", "class": "class", "protocol": "interface", "enum": "type"}
        symbols.append(
            {
                "name": name,
                "kind": kind_map.get(kind_kw, "type"),
                "file": rel_path,
                "line": line,
                "signature": f"{kind_kw} {name}",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    # Functions
    for m in re.finditer(
        r"^(public\s+)?(func|static\s+func)\s+(\w+)", text, re.MULTILINE
    ):
        pub, prefix, name = m.group(1), m.group(2), m.group(3)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if pub else "internal"
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"{prefix} {name}()",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    # Imports
    for m in re.finditer(r"^import\s+(\w+)", text, re.MULTILINE):
        imports.append(m.group(1))

    return symbols, imports, exports


def _lang_elixir(text: str, rel_path: str) -> tuple[list[_Symbol], list[str], list[str]]:
    symbols: list[_Symbol] = []
    imports: list[str] = []
    exports: list[str] = []

    # Modules
    for m in re.finditer(r"^defmodule\s+([\w.]+)", text, re.MULTILINE):
        name = m.group(1)
        line = text[: m.start()].count("\n") + 1
        symbols.append(
            {
                "name": name,
                "kind": "class",
                "file": rel_path,
                "line": line,
                "signature": f"defmodule {name}",
                "docstring": "",
                "visibility": "public",
            }
        )
        exports.append(name)

    # Public functions (def) and private functions (defp)
    for m in re.finditer(r"^\s+(def|defp)\s+(\w+)", text, re.MULTILINE):
        kind_kw, name = m.group(1), m.group(2)
        line = text[: m.start()].count("\n") + 1
        vis = "public" if kind_kw == "def" else "private"
        symbols.append(
            {
                "name": name,
                "kind": "function",
                "file": rel_path,
                "line": line,
                "signature": f"{kind_kw} {name}()",
                "docstring": "",
                "visibility": vis,
            }
        )
        if vis == "public":
            exports.append(name)

    # Imports: import, alias, use
    for m in re.finditer(r"^(?:import|alias|use)\s+([\w.]+)", text, re.MULTILINE):
        imports.append(m.group(1))

    return symbols, imports, exports


# ---------------------------------------------------------------------------
# Dispatcher — combines plugin parsers with inline fallbacks
# ---------------------------------------------------------------------------

# Inline parsers for languages that don't yet have standalone plugin modules.
_INLINE_PARSERS: dict[str, Any] = {
    "java": _lang_java,
    "csharp": _lang_csharp,
    "php": _lang_php,
    "kotlin": _lang_kotlin,
    "swift": _lang_swift,
    "elixir": _lang_elixir,
}

# Merge: plugin parsers take priority, inline parsers fill the gaps.
# JavaScript reuses the typescript parser (handled by extensions in the
# typescript parser module: [".ts", ".tsx", ".js", ".jsx"]).
_PARSERS: dict[str, Any] = {**_INLINE_PARSERS, **_PLUGIN_PARSERS}

# Alias: JavaScript files use the TypeScript parser.
if "typescript" in _PARSERS and "javascript" not in _PARSERS:
    _PARSERS["javascript"] = _PARSERS["typescript"]


def _parse_file(
    abs_path: str,
    rel_path: str,
    language: str,
) -> dict[str, Any]:
    """Parse a single file and return its file-entry dict plus symbols list."""
    size = os.path.getsize(abs_path)

    if size > _MAX_FILE_SIZE:
        return {
            "file_entry": {
                "language": language,
                "size_bytes": size,
                "lines": 0,
                "symbols": [],
                "imports": [],
                "exports": [],
            },
            "symbols": [],
        }

    try:
        with open(abs_path, "r", encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        return {
            "file_entry": {
                "language": language,
                "size_bytes": size,
                "lines": 0,
                "symbols": [],
                "imports": [],
                "exports": [],
            },
            "symbols": [],
        }

    # Detect binary files (null bytes indicate non-text content).
    if "\0" in text:
        return {
            "file_entry": {
                "language": language,
                "size_bytes": size,
                "lines": 0,
                "symbols": [],
                "imports": [],
                "exports": [],
            },
            "symbols": [],
        }

    line_count = text.count("\n") + (1 if text and not text.endswith("\n") else 0)

    parser = _PARSERS.get(language)
    if parser is None:
        return {
            "file_entry": {
                "language": language,
                "size_bytes": size,
                "lines": line_count,
                "symbols": [],
                "imports": [],
                "exports": [],
            },
            "symbols": [],
        }

    symbols, imports, exports = parser(text, rel_path)

    return {
        "file_entry": {
            "language": language,
            "size_bytes": size,
            "lines": line_count,
            "symbols": [s["name"] for s in symbols],
            "imports": imports,
            "exports": exports,
        },
        "symbols": symbols,
    }


# ---------------------------------------------------------------------------
# Shebang detection for extensionless scripts
# ---------------------------------------------------------------------------

_SHEBANG_LANGUAGE: dict[str, str] = {
    "bash": "bash",
    "sh": "bash",
    "zsh": "bash",
    "python": "python",
    "python3": "python",
    "node": "javascript",
    "ruby": "ruby",
    "perl": "perl",
}


def _detect_shebang_language(abs_path: str) -> str | None:
    """Read the first line of a file and detect language from shebang.

    Supports both direct shebangs (#!/bin/bash) and env shebangs
    (#!/usr/bin/env bash).  Returns the language string or None.
    """
    try:
        with open(abs_path, "r", encoding="utf-8", errors="replace") as fh:
            first_line = fh.readline(256)
    except OSError:
        return None

    if not first_line.startswith("#!"):
        return None

    shebang = first_line[2:].strip()
    # #!/usr/bin/env bash  ->  "bash"
    # #!/bin/bash          ->  "bash"
    parts = shebang.split()
    if not parts:
        return None

    if parts[0].endswith("/env") and len(parts) > 1:
        interpreter = parts[1]
    else:
        interpreter = os.path.basename(parts[0])

    return _SHEBANG_LANGUAGE.get(interpreter)


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------


def index_repo(target_dir: str, output_path: str | None = None) -> dict[str, Any]:
    """Index a repository and optionally write the result to a JSON file.

    Args:
        target_dir: Absolute path to the repository root.
        output_path: If provided, write the index JSON here.

    Returns:
        The complete index dictionary.
    """
    t0 = time.monotonic()
    target_dir = os.path.abspath(target_dir)

    # Collect files.
    tasks: list[tuple[str, str, str]] = []  # (abs, rel, lang)
    for dirpath, dirnames, filenames in os.walk(target_dir):
        # Prune excluded directories in-place.
        dirnames[:] = [
            d for d in dirnames if d not in _EXCLUDED_DIRS
        ]
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            lang = _EXT_LANGUAGE.get(ext)
            if lang is None:
                # Try extensionless files — check for bash shebang
                if ext == "":
                    abs_path = os.path.join(dirpath, fname)
                    lang = _detect_shebang_language(abs_path)
                if lang is None:
                    continue
            abs_path = os.path.join(dirpath, fname)
            rel_path = os.path.relpath(abs_path, target_dir)
            tasks.append((abs_path, rel_path, lang))

    # Parse in parallel.
    files_data: dict[str, dict[str, Any]] = {}
    all_symbols: list[dict[str, Any]] = []
    lang_counts: dict[str, int] = {}

    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = {
            pool.submit(_parse_file, abs_p, rel_p, lang): rel_p
            for abs_p, rel_p, lang in tasks
        }
        for future in as_completed(futures):
            rel_p = futures[future]
            try:
                result = future.result()
            except Exception as exc:
                # Don't let one bad file crash the entire index.
                import logging
                logging.warning("indexer: failed to parse %s: %s", rel_p, exc)
                continue
            files_data[rel_p] = result["file_entry"]
            all_symbols.extend(result["symbols"])
            lang = result["file_entry"]["language"]
            lang_counts[lang] = lang_counts.get(lang, 0) + 1

    # Build graph.
    edges, modules = build_graph(files_data, target_dir)

    # Compute PageRank importance scores.
    pagerank = compute_pagerank(edges, files_data)
    for path, score in pagerank.items():
        if path in files_data:
            files_data[path]["importance"] = round(score * 1000, 2)

    elapsed_ms = int((time.monotonic() - t0) * 1000)

    index: dict[str, Any] = {
        "_meta": {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "indexer_version": __version__,
            "target_dir": target_dir,
            "total_files": len(files_data),
            "total_symbols": len(all_symbols),
            "total_edges": len(edges),
            "languages": lang_counts,
            "elapsed_ms": elapsed_ms,
            "top_files": sorted(pagerank.items(), key=lambda x: -x[1])[:20],
        },
        "files": dict(sorted(files_data.items())),
        "symbols": all_symbols,
        "edges": edges,
        "modules": dict(sorted(modules.items())),
    }

    if output_path is not None:
        out_dir = os.path.dirname(output_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as fh:
            json.dump(index, fh, indent=2)

    return index


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Index a repository into a structured JSON file."
    )
    parser.add_argument(
        "--target",
        required=True,
        help="Path to the repository to index.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output path for the JSON index (default: <target>/.aiframework/code-index.json).",
    )
    args = parser.parse_args()

    target = os.path.abspath(args.target)
    output = args.output or os.path.join(target, ".aiframework", "code-index.json")

    result = index_repo(target, output)

    meta = result["_meta"]
    print(
        f"Indexed {meta['total_files']} files, "
        f"{meta['total_symbols']} symbols, "
        f"{meta['total_edges']} edges "
        f"in {meta['elapsed_ms']}ms → {output}"
    )


if __name__ == "__main__":
    main()
