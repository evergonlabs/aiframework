"""Dependency graph builder — edges, modules, and circular dependency detection."""

from __future__ import annotations

import os
import re
from collections import defaultdict
from typing import Any


# Heuristic role assignment based on directory name keywords.
_ROLE_MAP: dict[str, str] = {
    "scanners": "discovery",
    "scanner": "discovery",
    "generators": "generation",
    "generator": "generation",
    "validators": "verification",
    "validator": "verification",
    "enhancers": "enhancement",
    "enhancer": "enhancement",
    "tests": "testing",
    "test": "testing",
    "spec": "testing",
    "specs": "testing",
    "utils": "utility",
    "util": "utility",
    "helpers": "utility",
    "lib": "library",
    "src": "source",
    "bin": "entrypoint",
    "cmd": "entrypoint",
    "cli": "entrypoint",
    "tools": "tooling",
    "scripts": "tooling",
    "docs": "documentation",
    "config": "configuration",
    "models": "data-model",
    "schemas": "data-model",
    "routes": "routing",
    "handlers": "routing",
    "middleware": "middleware",
    "services": "service",
    "api": "api",
}


def _resolve_import_to_file(
    import_path: str,
    known_files: set[str],
) -> str | None:
    """Best-effort resolve an import string to a known relative file path."""
    # Convert dot-separated imports to path candidates.
    candidates: list[str] = []

    # Python-style: "lib.scanners.stack" -> "lib/scanners/stack.py"
    # Skip dot-to-slash conversion for Go-style domain imports (e.g. "github.com/...")
    if "://" in import_path or re.match(r"^[a-zA-Z0-9-]+\.[a-z]{2,}", import_path):
        as_path = import_path
    else:
        as_path = import_path.replace(".", "/")
    candidates.append(as_path + ".py")
    candidates.append(as_path + "/index.ts")
    candidates.append(as_path + "/index.js")
    candidates.append(as_path + "/mod.rs")
    candidates.append(as_path + ".ts")
    candidates.append(as_path + ".tsx")
    candidates.append(as_path + ".js")
    candidates.append(as_path + ".jsx")
    candidates.append(as_path + ".go")
    candidates.append(as_path + ".rs")
    candidates.append(as_path + ".rb")
    candidates.append(as_path + ".sh")
    candidates.append(as_path + "/__init__.py")

    # Also try the raw import_path in case it already looks like a path.
    if "/" in import_path:
        candidates.insert(0, import_path)

    for candidate in candidates:
        if candidate in known_files:
            return candidate

    return None


def _role_for_directory(dir_name: str) -> str:
    """Assign a heuristic role based on the directory name."""
    lower = dir_name.lower()
    return _ROLE_MAP.get(lower, "general")


def build_graph(
    files_data: dict[str, dict[str, Any]],
    target_dir: str,
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]]]:
    """Build dependency edges and module groupings from parsed file data.

    Returns:
        (edges, modules) where edges is a list of import-edge dicts and
        modules is a dict keyed by directory path.
    """
    known_files: set[str] = set(files_data.keys())
    edges: list[dict[str, Any]] = []

    # Track per-module incoming / outgoing edges.
    module_fan_in: dict[str, int] = defaultdict(int)
    module_fan_out: dict[str, int] = defaultdict(int)

    # Track edges for circular-dependency detection (module-level).
    module_edges: dict[str, set[str]] = defaultdict(set)

    for source_file, fdata in files_data.items():
        source_dir = os.path.dirname(source_file) or "."
        for imp in fdata.get("imports", []):
            # Handle Python relative imports (leading dots)
            effective_imp = imp
            if imp.startswith("."):
                # Strip leading dots and resolve relative to source dir
                dots = len(imp) - len(imp.lstrip("."))
                base = source_dir
                for _ in range(dots - 1):
                    base = os.path.dirname(base) or "."
                remainder = imp.lstrip(".")
                if remainder:
                    effective_imp = base + "/" + remainder.replace(".", "/")
                else:
                    effective_imp = base + "/__init__"
            resolved = _resolve_import_to_file(effective_imp, known_files)
            if resolved is None:
                continue
            target_dir_mod = os.path.dirname(resolved) or "."
            symbols_imported = [imp.rsplit(".", 1)[-1]] if "." in imp else [imp]
            edges.append(
                {
                    "source": source_file,
                    "target": resolved,
                    "type": "import",
                    "symbols": symbols_imported,
                }
            )
            if source_dir != target_dir_mod:
                module_fan_out[source_dir] += 1
                module_fan_in[target_dir_mod] += 1
                module_edges[source_dir].add(target_dir_mod)

    # --- Build modules dict ---------------------------------------------------
    modules: dict[str, dict[str, Any]] = {}
    dir_files: dict[str, list[str]] = defaultdict(list)
    dir_symbols: dict[str, int] = defaultdict(int)

    for rel_path, fdata in files_data.items():
        parent = os.path.dirname(rel_path) or "."
        dir_files[parent].append(os.path.basename(rel_path))
        dir_symbols[parent] += len(fdata.get("symbols", []))

    # Detect circular dependencies at module level (simple DFS).
    circular_deps: dict[str, list[str]] = defaultdict(list)
    for mod_a, targets in module_edges.items():
        for mod_b in targets:
            if mod_a in module_edges.get(mod_b, set()):
                if mod_b not in circular_deps[mod_a]:
                    circular_deps[mod_a].append(mod_b)

    for dir_path, file_list in dir_files.items():
        last_part = os.path.basename(dir_path) if dir_path != "." else "root"
        entry: dict[str, Any] = {
            "files": sorted(file_list),
            "role": _role_for_directory(last_part),
            "fan_in": module_fan_in.get(dir_path, 0),
            "fan_out": module_fan_out.get(dir_path, 0),
            "total_symbols": dir_symbols.get(dir_path, 0),
        }
        if dir_path in circular_deps:
            entry["circular_deps"] = circular_deps[dir_path]
        modules[dir_path] = entry

    return edges, modules


def compute_pagerank(
    edges: list[dict],
    files_data: dict[str, dict],
    damping: float = 0.85,
    iterations: int = 20,
) -> dict[str, float]:
    """Compute PageRank scores for files based on import edges.

    Files that are imported by many other files get higher scores.
    This identifies the most architecturally important files.
    """
    # Build adjacency: importing_file -> imported_file
    all_files = set(files_data.keys())
    outlinks: dict[str, set[str]] = {f: set() for f in all_files}
    inlinks: dict[str, set[str]] = {f: set() for f in all_files}

    for edge in edges:
        src, tgt = edge["source"], edge["target"]
        if src in all_files and tgt in all_files:
            outlinks[src].add(tgt)
            inlinks[tgt].add(src)

    # Initialize uniform
    n = len(all_files)
    if n == 0:
        return {}
    rank = {f: 1.0 / n for f in all_files}

    # Iterate
    for _ in range(iterations):
        new_rank = {}
        for f in all_files:
            incoming = sum(
                rank[src] / max(len(outlinks[src]), 1)
                for src in inlinks[f]
            )
            new_rank[f] = (1 - damping) / n + damping * incoming
        rank = new_rank

    return rank
