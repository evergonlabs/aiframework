"""TypeScript/JavaScript parser — backward compatibility stub.

The parser implementation has moved to ``lib.indexers.parsers.typescript``.
This module re-exports the public API for backward compatibility.
"""

from lib.indexers.parsers.typescript import parse_typescript, parse  # noqa: F401

__all__ = ["parse_typescript", "parse"]
