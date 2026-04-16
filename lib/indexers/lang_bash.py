"""Bash/shell script parser — backward compatibility stub.

The parser implementation has moved to ``lib.indexers.parsers.bash``.
This module re-exports the public API for backward compatibility.
"""

from lib.indexers.parsers.bash import parse_bash, parse  # noqa: F401

__all__ = ["parse_bash", "parse"]
