"""Built-in language parsers for the code indexer.

Each parser module in this package exports:
    language: str       — canonical language name
    extensions: list    — file extensions this parser handles (e.g. [".py"])
    parse(content, filepath) -> (symbols, imports, exports)
"""
