# Community Parsers

Drop custom language parser modules here. Each module must export:

```python
language: str           # e.g. "haskell"
extensions: list[str]   # e.g. [".hs"]

def parse(content: str, filepath: str) -> tuple[list, list, list]:
    """Return (symbols, imports, exports)."""
    ...
```

## Symbol dict format

Each symbol in the symbols list should be a dict with:

```python
{
    "name": "function_name",
    "kind": "function",      # function, method, class, type, interface, etc.
    "line": 42,
    "signature": "def function_name(args)",
    "docstring": "Brief description",
    "visibility": "public",  # public or private
}
```

## How it works

Parsers in `contrib/` are loaded automatically after built-in parsers.
If a contrib parser declares the same `language` as a built-in, the contrib
version takes precedence.
