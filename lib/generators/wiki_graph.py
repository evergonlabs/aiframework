"""Dense wiki graph generator — transforms code-index.json into interconnected vault pages.

Every source file gets its own entity page. Every dependency edge becomes a bidirectional
wikilink. Module summary pages aggregate their files. The result is a navigable knowledge
graph that Claude Code can traverse to understand any part of the codebase.

Usage (called from vault.sh):
    python3 -m lib.generators.wiki_graph --code-index PATH --vault-root PATH [--verify]

Can also be imported:
    from lib.generators.wiki_graph import generate_wiki_graph
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from typing import Any


# ---------------------------------------------------------------------------
# Slug generation
# ---------------------------------------------------------------------------

def file_to_slug(path: str) -> str:
    """Convert a file path to a wiki-safe slug.

    Examples:
        lib/generators/vault.sh  -> lib-generators-vault-sh
        bin/aiframework          -> bin-aiframework
        lib/indexers/__init__.py  -> lib-indexers-init-py
        .githooks/pre-commit     -> githooks-pre-commit
    """
    slug = path.replace("/", "-").replace(".", "-").replace("_", "-")
    # Strip leading dashes
    slug = slug.lstrip("-")
    # Collapse multiple dashes
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug


def module_to_slug(path: str) -> str:
    """Convert a module directory path to a wiki-safe slug.

    Examples:
        lib/generators -> lib-generators
        .              -> root-module
    """
    if path == ".":
        return "root-module"
    slug = path.replace("/", "-").replace(".", "-").replace("_", "-")
    slug = slug.lstrip("-")
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug


# ---------------------------------------------------------------------------
# Data loading and lookup tables
# ---------------------------------------------------------------------------

def _build_lookups(code_index: dict) -> dict:
    """Build all lookup tables from the code index."""
    files = code_index.get("files", {})
    symbols = code_index.get("symbols", [])
    edges = code_index.get("edges", [])
    modules = code_index.get("modules", {})
    meta = code_index.get("_meta", {})

    # file -> list of symbol dicts
    file_symbols: dict[str, list[dict]] = {}
    for sym in symbols:
        f = sym.get("file", "")
        if f not in file_symbols:
            file_symbols[f] = []
        file_symbols[f].append(sym)

    # Sort symbols by line number within each file
    for f in file_symbols:
        file_symbols[f].sort(key=lambda s: s.get("line", 0))

    # file -> outbound edges (this file imports X)
    file_outbound: dict[str, list[dict]] = {}
    # file -> inbound edges (X imports this file)
    file_inbound: dict[str, list[dict]] = {}
    for edge in edges:
        src = edge.get("source", "")
        tgt = edge.get("target", "")
        if src not in file_outbound:
            file_outbound[src] = []
        file_outbound[src].append(edge)
        if tgt not in file_inbound:
            file_inbound[tgt] = []
        file_inbound[tgt].append(edge)

    # module -> list of file paths
    module_files: dict[str, list[str]] = {}
    for mod_path, mod_data in modules.items():
        filenames = mod_data.get("files", [])
        # Reconstruct full paths
        if mod_path == ".":
            full_paths = [fn for fn in filenames if fn in files]
        else:
            full_paths = [f"{mod_path}/{fn}" for fn in filenames if f"{mod_path}/{fn}" in files]
        module_files[mod_path] = sorted(full_paths)

    # file -> module path
    file_module: dict[str, str] = {}
    for mod_path, fpaths in module_files.items():
        for fp in fpaths:
            file_module[fp] = mod_path

    # pagerank scores from _meta.top_files
    pagerank: dict[str, float] = {}
    for entry in meta.get("top_files", []):
        if isinstance(entry, list) and len(entry) == 2:
            pagerank[entry[0]] = entry[1]

    return {
        "files": files,
        "symbols": symbols,
        "edges": edges,
        "modules": modules,
        "meta": meta,
        "file_symbols": file_symbols,
        "file_outbound": file_outbound,
        "file_inbound": file_inbound,
        "module_files": module_files,
        "file_module": file_module,
        "pagerank": pagerank,
    }


# ---------------------------------------------------------------------------
# Page renderers
# ---------------------------------------------------------------------------

def _render_file_page(
    filepath: str,
    file_data: dict,
    lookups: dict,
    today: str,
) -> str:
    """Render a wiki entity page for a single source file."""
    basename = os.path.basename(filepath)
    language = file_data.get("language", "unknown")
    lines = file_data.get("lines", 0)
    size_bytes = file_data.get("size_bytes", 0)
    importance = lookups["pagerank"].get(filepath, 0)

    syms = lookups["file_symbols"].get(filepath, [])
    outbound = lookups["file_outbound"].get(filepath, [])
    inbound = lookups["file_inbound"].get(filepath, [])
    mod_path = lookups["file_module"].get(filepath, ".")
    mod_slug = module_to_slug(mod_path)

    # Domain tag
    domain_tag = f"domain/{language}" if language != "unknown" else "domain/general"

    # --- Build symbols table (cap at 25, overflow note) ---
    sym_lines = []
    max_syms = 25
    for sym in syms[:max_syms]:
        name = sym.get("name", "?")
        kind = sym.get("kind", "symbol")
        line = sym.get("line", "—")
        vis = sym.get("visibility", "public")
        doc = (sym.get("docstring") or "—")[:60]
        if doc and doc != "—" and len(sym.get("docstring", "")) > 60:
            doc += "..."
        sym_lines.append(f"| `{name}` | {kind} | {line} | {vis} | {doc} |")

    overflow_note = ""
    if len(syms) > max_syms:
        overflow_note = f"\n> Showing {max_syms} of {len(syms)} symbols.\n"

    symbols_section = ""
    if sym_lines:
        symbols_section = f"""## Symbols ({len(syms)})

| Name | Kind | Line | Visibility | Description |
|------|------|------|------------|-------------|
{chr(10).join(sym_lines)}
{overflow_note}"""
    else:
        symbols_section = "## Symbols\n\n*No symbols extracted (config/script file).*\n"

    # --- Build imports section (deduplicated) ---
    imports_lines = []
    seen_targets: set[str] = set()
    for edge in sorted(outbound, key=lambda e: e["target"]):
        tgt = edge["target"]
        if tgt in seen_targets:
            continue
        seen_targets.add(tgt)
        tgt_slug = file_to_slug(tgt)
        tgt_basename = os.path.basename(tgt)
        edge_syms = edge.get("symbols", [])
        sym_note = f" — `{'`, `'.join(edge_syms)}`" if edge_syms and edge_syms != ["sh"] else ""
        imports_lines.append(f"- [[{tgt_slug}|{tgt_basename}]] (`{tgt}`){sym_note}")

    imports_section = ""
    if imports_lines:
        imports_section = f"""## Imports ({len(imports_lines)})

{chr(10).join(imports_lines)}
"""
    else:
        imports_section = "## Imports\n\n*No internal imports detected.*\n"

    # --- Build imported-by section (deduplicated) ---
    inbound_lines = []
    seen_sources: set[str] = set()
    for edge in sorted(inbound, key=lambda e: e["source"]):
        src = edge["source"]
        if src in seen_sources:
            continue
        seen_sources.add(src)
        src_slug = file_to_slug(src)
        src_basename = os.path.basename(src)
        inbound_lines.append(f"- [[{src_slug}|{src_basename}]] (`{src}`)")

    inbound_section = ""
    if inbound_lines:
        inbound_section = f"""## Imported By ({len(inbound_lines)})

{chr(10).join(inbound_lines)}
"""
    else:
        inbound_section = "## Imported By\n\n*No internal dependents detected.*\n"

    # --- Assemble page ---
    importance_str = f"{importance:.4f}" if importance > 0 else "—"

    # Use full path for title to ensure uniqueness (HR-006)
    page_title = filepath.replace("/", " / ")

    page = f"""---
title: "{page_title}"
type: entity
created: "{today}"
updated: "{today}"
status: current
tags:
  - type/entity
  - scope/file
  - {domain_tag}
  - source-type/code-index
confidence: medium
---

# {basename}

> `{filepath}` — {language}, {lines} lines

| Property | Value |
|----------|-------|
| Path | `{filepath}` |
| Language | {language} |
| Lines | {lines} |
| Size | {size_bytes} bytes |
| Symbols | {len(syms)} |
| PageRank | {importance_str} |

{symbols_section}
{imports_section}
{inbound_section}
## Module

- [[{mod_slug}|{mod_path}]]

## Related

- [[architecture]]
"""
    return page.strip() + "\n"


def _render_module_page(
    mod_path: str,
    mod_data: dict,
    lookups: dict,
    today: str,
) -> str:
    """Render a wiki summary page for a module (directory)."""
    mod_slug = module_to_slug(mod_path)
    role = mod_data.get("role", "general")
    fan_in = mod_data.get("fan_in", 0)
    fan_out = mod_data.get("fan_out", 0)
    total_symbols = mod_data.get("total_symbols", 0)
    file_paths = lookups["module_files"].get(mod_path, [])

    # Primary language
    lang_counts: dict[str, int] = {}
    for fp in file_paths:
        lang = lookups["files"].get(fp, {}).get("language", "unknown")
        lang_counts[lang] = lang_counts.get(lang, 0) + 1
    primary_lang = max(lang_counts, key=lang_counts.get) if lang_counts else "unknown"
    domain_tag = f"domain/{primary_lang}" if primary_lang != "unknown" else "domain/general"

    # File table
    file_rows = []
    for fp in file_paths:
        fdata = lookups["files"].get(fp, {})
        fslug = file_to_slug(fp)
        fname = os.path.basename(fp)
        sym_count = len(lookups["file_symbols"].get(fp, []))
        imp = lookups["pagerank"].get(fp, 0)
        imp_str = f"{imp:.4f}" if imp > 0 else "—"
        file_rows.append(f"| [[{fslug}|{fname}]] | {sym_count} | {imp_str} |")

    files_section = f"""## Files ({len(file_paths)})

| File | Symbols | PageRank |
|------|---------|----------|
{chr(10).join(file_rows)}
"""

    # Module-level outbound deps (aggregate file edges to unique target modules)
    out_modules: dict[str, int] = {}
    for fp in file_paths:
        for edge in lookups["file_outbound"].get(fp, []):
            tgt_mod = lookups["file_module"].get(edge["target"], ".")
            if tgt_mod != mod_path:
                out_modules[tgt_mod] = out_modules.get(tgt_mod, 0) + 1

    out_lines = []
    for tmod in sorted(out_modules.keys()):
        tslug = module_to_slug(tmod)
        out_lines.append(f"- [[{tslug}|{tmod}]] ({out_modules[tmod]} edges)")

    deps_section = ""
    if out_lines:
        deps_section = f"""## Dependencies ({len(out_lines)} modules)

{chr(10).join(out_lines)}
"""
    else:
        deps_section = "## Dependencies\n\n*No outbound module dependencies.*\n"

    # Module-level inbound deps
    in_modules: dict[str, int] = {}
    for fp in file_paths:
        for edge in lookups["file_inbound"].get(fp, []):
            src_mod = lookups["file_module"].get(edge["source"], ".")
            if src_mod != mod_path:
                in_modules[src_mod] = in_modules.get(src_mod, 0) + 1

    in_lines = []
    for smod in sorted(in_modules.keys()):
        sslug = module_to_slug(smod)
        in_lines.append(f"- [[{sslug}|{smod}]] ({in_modules[smod]} edges)")

    dependents_section = ""
    if in_lines:
        dependents_section = f"""## Dependents ({len(in_lines)} modules)

{chr(10).join(in_lines)}
"""
    else:
        dependents_section = "## Dependents\n\n*No inbound module dependents.*\n"

    # Circular deps
    circular = mod_data.get("circular_deps", [])
    circular_section = ""
    if circular:
        circ_lines = [f"- [[{module_to_slug(c)}|{c}]]" for c in circular]
        circular_section = f"""## Circular Dependencies

{chr(10).join(circ_lines)}
"""

    page = f"""---
title: "Module: {mod_path}"
type: entity
created: "{today}"
updated: "{today}"
status: current
tags:
  - type/entity
  - scope/module
  - {domain_tag}
  - source-type/code-index
confidence: medium
---

# Module: {mod_path}

> {role} — {len(file_paths)} files, {total_symbols} symbols

| Property | Value |
|----------|-------|
| Path | `{mod_path}` |
| Role | {role} |
| Files | {len(file_paths)} |
| Symbols | {total_symbols} |
| Fan-in | {fan_in} |
| Fan-out | {fan_out} |

{files_section}
{deps_section}
{dependents_section}
{circular_section}
## Related

- [[architecture]]
"""
    return page.strip() + "\n"


def _render_architecture_page(
    lookups: dict,
    today: str,
) -> str:
    """Render the architecture concept page with module graph and file-level links."""
    modules = lookups["modules"]
    meta = lookups["meta"]
    primary_lang = "unknown"
    langs = meta.get("languages", {})
    if langs:
        primary_lang = max(langs, key=langs.get)
    domain_tag = f"domain/{primary_lang}" if primary_lang != "unknown" else "domain/general"

    # Module graph table
    rows = []
    for mod_path in sorted(modules.keys()):
        mod_data = modules[mod_path]
        mslug = module_to_slug(mod_path)
        role = mod_data.get("role", "general")
        fan_in = mod_data.get("fan_in", 0)
        fan_out = mod_data.get("fan_out", 0)
        file_count = len(lookups["module_files"].get(mod_path, []))
        rows.append(f"| [[{mslug}|{mod_path}]] | {role} | {file_count} | {fan_in} | {fan_out} |")

    # Top files by pagerank
    top_files = meta.get("top_files", [])[:15]
    top_rows = []
    for entry in top_files:
        if isinstance(entry, list) and len(entry) == 2:
            fp, score = entry
            fslug = file_to_slug(fp)
            fname = os.path.basename(fp)
            top_rows.append(f"| [[{fslug}|{fname}]] | `{fp}` | {score:.4f} |")

    # Entry points (modules with fan_in=0 and fan_out>0)
    entry_points = []
    for mod_path, mod_data in sorted(modules.items()):
        if mod_data.get("fan_in", 0) == 0 and mod_data.get("fan_out", 0) > 0:
            mslug = module_to_slug(mod_path)
            entry_points.append(f"- [[{mslug}|{mod_path}]]")

    entry_section = ""
    if entry_points:
        entry_section = f"""## Entry Points (fan-in = 0)

{chr(10).join(entry_points)}
"""
    else:
        entry_section = "## Entry Points\n\n*All modules have inbound dependencies.*\n"

    page = f"""---
title: "Architecture — Module Graph"
type: concept
created: "{today}"
updated: "{today}"
status: current
tags:
  - type/concept
  - type/architecture
  - {domain_tag}
  - source-type/code-index
confidence: medium
---

# Architecture — Module Graph

> Auto-generated from code index. {meta.get('total_files', 0)} files, {meta.get('total_symbols', 0)} symbols, {meta.get('total_edges', 0)} edges.

## Modules

| Module | Role | Files | Fan-in | Fan-out |
|--------|------|-------|--------|---------|
{chr(10).join(rows)}

## Most Important Files (by PageRank)

| File | Path | Score |
|------|------|-------|
{chr(10).join(top_rows)}

{entry_section}
## Related

- [[tech-stack]]
- [[project-overview]]
"""
    return page.strip() + "\n"


def _render_index(
    all_pages: dict[str, str],
    vault_root: str,
    today: str,
) -> str:
    """Render index.md from all generated pages."""
    # Also scan for existing pages not generated by us (concepts, sources, etc.)
    existing_pages: dict[str, dict] = {}
    for dirpath, _dirnames, filenames in os.walk(os.path.join(vault_root, "wiki")):
        for fn in filenames:
            if not fn.endswith(".md"):
                continue
            if fn in ("index.md", "log.md"):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, vault_root)
            slug = fn[:-3]  # strip .md
            # Read frontmatter for type and tags
            page_type = "entity"
            status = "current"
            try:
                with open(full, "r") as f:
                    content = f.read(2000)
                if content.startswith("---"):
                    fm_end = content.find("---", 3)
                    if fm_end > 0:
                        fm = content[3:fm_end]
                        for line in fm.split("\n"):
                            if line.startswith("type:"):
                                page_type = line.split(":", 1)[1].strip().strip('"')
                            elif line.startswith("status:"):
                                status = line.split(":", 1)[1].strip().strip('"')
            except (OSError, ValueError):
                pass
            existing_pages[slug] = {
                "path": rel,
                "type": page_type,
                "status": status,
            }

    # Merge generated pages into existing
    for slug, _content in all_pages.items():
        rel_path = _page_rel_path(slug, all_pages, vault_root)
        existing_pages[slug] = {
            "path": rel_path,
            "type": "entity",
            "status": "current",
        }

    # Build index table sorted by slug
    rows = []
    for slug in sorted(existing_pages.keys()):
        info = existing_pages[slug]
        rows.append(f"| {slug} | {info['path']} | {info['type']} | {today} | {info['status']} |")

    page = f"""---
title: "Vault Index"
type: index
created: "{today}"
updated: "{today}"
status: current
tags:
  - type/index
  - lifecycle/permanent
confidence: high
---

# Vault Index

> Master registry of all vault pages. {len(existing_pages)} pages indexed.

| Slug | Path | Type | Updated | Status |
|------|------|------|---------|--------|
{chr(10).join(rows)}
"""
    return page.strip() + "\n"


def _page_rel_path(slug: str, all_pages: dict, vault_root: str) -> str:
    """Determine the relative path within vault for a given slug."""
    # Module pages and file pages go to entities/
    # Architecture goes to concepts/
    if slug == "architecture":
        return "wiki/concepts/architecture.md"
    return f"wiki/entities/{slug}.md"


# ---------------------------------------------------------------------------
# Incremental update via content hashing
# ---------------------------------------------------------------------------

def _content_hash(content: str) -> str:
    return hashlib.md5(content.encode("utf-8")).hexdigest()


def _load_hashes(vault_root: str) -> dict[str, str]:
    hash_file = os.path.join(vault_root, ".vault", ".wiki-hashes.json")
    if os.path.exists(hash_file):
        try:
            with open(hash_file, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            pass
    return {}


def _save_hashes(vault_root: str, hashes: dict[str, str]) -> None:
    hash_file = os.path.join(vault_root, ".vault", ".wiki-hashes.json")
    os.makedirs(os.path.dirname(hash_file), exist_ok=True)
    with open(hash_file, "w") as f:
        json.dump(hashes, f, indent=2, sort_keys=True)


# ---------------------------------------------------------------------------
# Core generator
# ---------------------------------------------------------------------------

def generate_wiki_graph(
    code_index_path: str,
    vault_root: str,
    today: str | None = None,
) -> dict[str, int]:
    """Generate the full wiki graph from a code index.

    Returns stats dict: {pages_written, pages_unchanged, pages_archived, total_pages}
    """
    if today is None:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    with open(code_index_path, "r") as f:
        code_index = json.load(f)

    lookups = _build_lookups(code_index)
    old_hashes = _load_hashes(vault_root)
    new_hashes: dict[str, str] = {}
    all_pages: dict[str, str] = {}  # slug -> content

    stats = {
        "pages_written": 0,
        "pages_unchanged": 0,
        "pages_archived": 0,
        "total_pages": 0,
        "total_files": len(lookups["files"]),
        "total_edges": len(lookups["edges"]),
        "total_symbols": len(lookups["symbols"]),
    }

    # Ensure directories exist
    os.makedirs(os.path.join(vault_root, "wiki", "entities"), exist_ok=True)
    os.makedirs(os.path.join(vault_root, "wiki", "concepts"), exist_ok=True)

    # --- 1. File entity pages ---
    for filepath in sorted(lookups["files"].keys()):
        file_data = lookups["files"][filepath]
        slug = file_to_slug(filepath)
        content = _render_file_page(filepath, file_data, lookups, today)
        all_pages[slug] = content

    # --- 2. Module summary pages ---
    for mod_path in sorted(lookups["modules"].keys()):
        mod_data = lookups["modules"][mod_path]
        slug = module_to_slug(mod_path)
        content = _render_module_page(mod_path, mod_data, lookups, today)
        all_pages[slug] = content

    # --- 3. Architecture concept page ---
    arch_content = _render_architecture_page(lookups, today)
    all_pages["architecture"] = arch_content

    # --- 4. Write pages with incremental hashing ---
    for slug, content in sorted(all_pages.items()):
        h = _content_hash(content)
        new_hashes[slug] = h

        rel_path = _page_rel_path(slug, all_pages, vault_root)
        full_path = os.path.join(vault_root, rel_path)

        if old_hashes.get(slug) == h and os.path.exists(full_path):
            stats["pages_unchanged"] += 1
        else:
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, "w") as f:
                f.write(content)
            stats["pages_written"] += 1

        stats["total_pages"] += 1

    # --- 5. Archive stale pages (pages in old hashes but not in new) ---
    for old_slug in sorted(old_hashes.keys()):
        if old_slug not in new_hashes:
            old_rel = f"wiki/entities/{old_slug}.md"
            old_path = os.path.join(vault_root, old_rel)
            if os.path.exists(old_path):
                # Mark as archived in frontmatter (HR-014: no deletion)
                try:
                    with open(old_path, "r") as f:
                        old_content = f.read()
                    if "status: current" in old_content:
                        old_content = old_content.replace(
                            "status: current", "status: archived"
                        )
                        with open(old_path, "w") as f:
                            f.write(old_content)
                        stats["pages_archived"] += 1
                except OSError:
                    pass

    # --- 6. Rebuild index.md ---
    index_content = _render_index(all_pages, vault_root, today)
    index_path = os.path.join(vault_root, "wiki", "index.md")
    with open(index_path, "w") as f:
        f.write(index_content)

    # --- 7. Save hashes ---
    _save_hashes(vault_root, new_hashes)

    return stats


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

def verify_wiki_graph(
    code_index_path: str,
    vault_root: str,
) -> list[str]:
    """Verify that the wiki graph is complete and correct.

    Returns a list of error strings. Empty list means everything is correct.
    """
    errors: list[str] = []
    warnings: list[str] = []

    with open(code_index_path, "r") as f:
        code_index = json.load(f)

    lookups = _build_lookups(code_index)

    # 1. Every file in code-index has a corresponding page
    for filepath in lookups["files"]:
        slug = file_to_slug(filepath)
        page_path = os.path.join(vault_root, "wiki", "entities", f"{slug}.md")
        if not os.path.exists(page_path):
            errors.append(f"MISSING FILE PAGE: {filepath} -> {page_path}")

    # 2. Every module has a summary page
    for mod_path in lookups["modules"]:
        slug = module_to_slug(mod_path)
        page_path = os.path.join(vault_root, "wiki", "entities", f"{slug}.md")
        if not os.path.exists(page_path):
            errors.append(f"MISSING MODULE PAGE: {mod_path} -> {page_path}")

    # 3. Every edge appears as wikilinks on both sides
    for edge in lookups["edges"]:
        src = edge["source"]
        tgt = edge["target"]
        src_slug = file_to_slug(src)
        tgt_slug = file_to_slug(tgt)

        src_page = os.path.join(vault_root, "wiki", "entities", f"{src_slug}.md")
        tgt_page = os.path.join(vault_root, "wiki", "entities", f"{tgt_slug}.md")

        if os.path.exists(src_page):
            with open(src_page, "r") as f:
                src_content = f.read()
            if f"[[{tgt_slug}" not in src_content:
                errors.append(f"MISSING OUTBOUND LINK: {src} -> {tgt}")

        if os.path.exists(tgt_page):
            with open(tgt_page, "r") as f:
                tgt_content = f.read()
            if f"[[{src_slug}" not in tgt_content:
                errors.append(f"MISSING INBOUND LINK: {tgt} <- {src}")

    # 4. All pages in index.md
    index_path = os.path.join(vault_root, "wiki", "index.md")
    if os.path.exists(index_path):
        with open(index_path, "r") as f:
            index_content = f.read()
        for dirpath, _dirnames, filenames in os.walk(os.path.join(vault_root, "wiki")):
            for fn in filenames:
                if not fn.endswith(".md") or fn in ("index.md", "log.md"):
                    continue
                slug = fn[:-3]
                if slug not in index_content:
                    errors.append(f"ORPHAN PAGE (not in index): {slug}")
    else:
        errors.append("MISSING: index.md does not exist")

    # 5. No page exceeds line limits
    for dirpath, _dirnames, filenames in os.walk(os.path.join(vault_root, "wiki")):
        for fn in filenames:
            if not fn.endswith(".md"):
                continue
            full = os.path.join(dirpath, fn)
            try:
                with open(full, "r") as f:
                    line_count = sum(1 for _ in f)
                if line_count > 400:
                    errors.append(f"OVER 400 LINES (HR-004 block): {fn} ({line_count} lines)")
                elif line_count > 200:
                    warnings.append(f"OVER 200 LINES (HR-004 warn): {fn} ({line_count} lines)")
            except OSError:
                pass

    # 6. Architecture page exists
    arch_path = os.path.join(vault_root, "wiki", "concepts", "architecture.md")
    if not os.path.exists(arch_path):
        errors.append("MISSING: architecture.md concept page")

    # Print warnings
    for w in warnings:
        print(f"  WARN: {w}", file=sys.stderr)

    return errors


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate dense wiki graph from code-index.json"
    )
    parser.add_argument("--code-index", required=True, help="Path to code-index.json")
    parser.add_argument("--vault-root", required=True, help="Path to vault/ directory")
    parser.add_argument("--verify", action="store_true", help="Verify completeness after generation")
    parser.add_argument("--verify-only", action="store_true", help="Only verify, don't generate")
    parser.add_argument("--today", default=None, help="Override date (YYYY-MM-DD)")
    args = parser.parse_args()

    if not os.path.exists(args.code_index):
        print(f"Error: code index not found at {args.code_index}", file=sys.stderr)
        sys.exit(1)

    if args.verify_only:
        errors = verify_wiki_graph(args.code_index, args.vault_root)
        if errors:
            print(f"VERIFICATION FAILED — {len(errors)} error(s):", file=sys.stderr)
            for e in errors:
                print(f"  {e}", file=sys.stderr)
            sys.exit(1)
        else:
            print("VERIFICATION PASSED — wiki graph is complete and correct.")
            sys.exit(0)

    stats = generate_wiki_graph(args.code_index, args.vault_root, args.today)
    print(
        f"Wiki graph: {stats['pages_written']} written, "
        f"{stats['pages_unchanged']} unchanged, "
        f"{stats['pages_archived']} archived, "
        f"{stats['total_pages']} total "
        f"({stats['total_files']} files, {stats['total_edges']} edges, "
        f"{stats['total_symbols']} symbols)"
    )

    if args.verify:
        errors = verify_wiki_graph(args.code_index, args.vault_root)
        if errors:
            print(f"\nVERIFICATION FAILED — {len(errors)} error(s):", file=sys.stderr)
            for e in errors:
                print(f"  {e}", file=sys.stderr)
            sys.exit(1)
        else:
            print("VERIFICATION PASSED — wiki graph is complete and correct.")


if __name__ == "__main__":
    main()
