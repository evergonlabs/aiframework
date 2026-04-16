"""Dynamic parser registry for the code indexer.

Discovers parser modules from both the built-in ``parsers/`` package and
the community ``contrib/`` package.  Each parser module must export:

    language: str           — canonical language name (e.g. "python")
    extensions: list[str]   — file extensions handled (e.g. [".py"])
    parse(content: str, filepath: str) -> tuple[list, list, list]

Usage:
    from lib.indexers.registry import discover_parsers
    parsers, ext_map = discover_parsers()
    # parsers: {"python": <parse function>, ...}
    # ext_map: {".py": "python", ".sh": "bash", ...}
"""

from __future__ import annotations

import importlib
import logging
import pkgutil
from typing import Any, Callable

logger = logging.getLogger(__name__)

_ParserFn = Callable[[str, str], tuple[list, list, list]]


def _load_parsers_from_package(package_name: str) -> list[tuple[str, list[str], _ParserFn]]:
    """Load all parser modules from a package.

    Returns list of (language, extensions, parse_fn) tuples.
    """
    results: list[tuple[str, list[str], _ParserFn]] = []
    try:
        package = importlib.import_module(package_name)
    except ImportError:
        logger.debug("Parser package %s not found, skipping", package_name)
        return results

    if not hasattr(package, "__path__"):
        return results

    for _importer, module_name, _is_pkg in pkgutil.iter_modules(package.__path__):
        if module_name.startswith("_"):
            continue
        try:
            mod = importlib.import_module(f"{package_name}.{module_name}")
        except ImportError as exc:
            logger.warning("Failed to import parser %s.%s: %s", package_name, module_name, exc)
            continue

        # Validate standard interface
        lang = getattr(mod, "language", None)
        exts = getattr(mod, "extensions", None)
        parse_fn = getattr(mod, "parse", None)

        if not lang or not exts or not callable(parse_fn):
            logger.debug(
                "Skipping %s.%s — missing language/extensions/parse",
                package_name, module_name,
            )
            continue

        results.append((lang, exts, parse_fn))

    return results


def discover_parsers() -> tuple[dict[str, _ParserFn], dict[str, str]]:
    """Discover all available parsers from built-in and contrib packages.

    Returns:
        (parsers, ext_language) where:
        - parsers maps language name -> parse function
        - ext_language maps file extension -> language name
    """
    parsers: dict[str, _ParserFn] = {}
    ext_language: dict[str, str] = {}

    # Load built-in parsers first
    for lang, exts, parse_fn in _load_parsers_from_package("lib.indexers.parsers"):
        parsers[lang] = parse_fn
        for ext in exts:
            ext_language[ext] = lang

    # Load contrib parsers (can override built-in)
    for lang, exts, parse_fn in _load_parsers_from_package("lib.indexers.contrib"):
        parsers[lang] = parse_fn
        for ext in exts:
            ext_language[ext] = lang

    return parsers, ext_language
