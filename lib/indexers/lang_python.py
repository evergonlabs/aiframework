"""Python source parser — backward compatibility stub.

The parser implementation has moved to ``lib.indexers.parsers.python``.
This module re-exports the public API for backward compatibility.
"""

from lib.indexers.parsers.python import parse_python, parse  # noqa: F401

__all__ = ["parse_python", "parse"]
