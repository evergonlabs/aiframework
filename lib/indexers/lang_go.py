"""Go language parser — backward compatibility stub.

The parser implementation has moved to ``lib.indexers.parsers.go``.
This module re-exports the public API for backward compatibility.
"""

from lib.indexers.parsers.go import parse_go, parse  # noqa: F401

__all__ = ["parse_go", "parse"]
