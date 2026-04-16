"""Rust language parser — backward compatibility stub.

The parser implementation has moved to ``lib.indexers.parsers.rust``.
This module re-exports the public API for backward compatibility.
"""

from lib.indexers.parsers.rust import parse_rust, parse  # noqa: F401

__all__ = ["parse_rust", "parse"]
