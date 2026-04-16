"""Ruby language parser — backward compatibility stub.

The parser implementation has moved to ``lib.indexers.parsers.ruby``.
This module re-exports the public API for backward compatibility.
"""

from lib.indexers.parsers.ruby import parse_ruby, parse  # noqa: F401

__all__ = ["parse_ruby", "parse"]
