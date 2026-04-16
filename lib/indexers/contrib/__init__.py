"""Community-contributed language parsers.

Drop parser modules here following the standard interface:

    language: str           — canonical language name
    extensions: list[str]   — file extensions handled
    parse(content: str, filepath: str) -> tuple[list, list, list]

Parsers in this directory are loaded after built-in parsers and can
override them by declaring the same language name.
"""
