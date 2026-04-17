"""Tests for the code indexer."""
import json
import os
import tempfile
import unittest

# Add repo root to path
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from lib.indexers.parse import index_repo, _parse_file
from lib.indexers.graph import build_graph


class TestIndexRepo(unittest.TestCase):
    def test_indexes_this_repo(self):
        """Smoke test: index the aiframework repo itself."""
        result = index_repo(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        self.assertGreater(result["_meta"]["total_files"], 30)
        self.assertGreater(result["_meta"]["total_symbols"], 50)
        self.assertIn("bash", result["_meta"]["languages"])
        self.assertIn("python", result["_meta"]["languages"])
        self.assertGreater(len(result["modules"]), 5)

    def test_output_schema_complete(self):
        """Verify all required top-level keys present."""
        result = index_repo(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        for key in ("_meta", "files", "symbols", "edges", "modules"):
            self.assertIn(key, result)

    def test_empty_directory(self):
        """Indexing an empty directory produces empty results."""
        with tempfile.TemporaryDirectory() as d:
            result = index_repo(d)
            self.assertEqual(result["_meta"]["total_files"], 0)
            self.assertEqual(result["_meta"]["total_symbols"], 0)


class TestParsers(unittest.TestCase):
    def test_python_parser(self):
        """Python parser detects functions and classes."""
        with tempfile.NamedTemporaryFile(suffix=".py", mode="w", delete=False) as f:
            f.write('def hello(name: str) -> str:\n    """Greet someone."""\n    return f"hi {name}"\n\nclass Greeter:\n    pass\n')
            f.flush()
            result = _parse_file(f.name, "test.py", "python")
        os.unlink(f.name)
        self.assertGreaterEqual(len(result["symbols"]), 2)
        names = [s["name"] for s in result["symbols"]]
        self.assertIn("hello", names)
        self.assertIn("Greeter", names)

    def test_bash_parser(self):
        """Bash parser detects functions."""
        with tempfile.NamedTemporaryFile(suffix=".sh", mode="w", delete=False) as f:
            f.write('#!/bin/bash\nmy_func() {\n  echo "hi"\n}\n')
            f.flush()
            result = _parse_file(f.name, "test.sh", "bash")
        os.unlink(f.name)
        names = [s["name"] for s in result["symbols"]]
        self.assertIn("my_func", names)

    def test_binary_file_skipped(self):
        """Binary files produce empty results."""
        with tempfile.NamedTemporaryFile(suffix=".py", mode="wb", delete=False) as f:
            f.write(b'\x00\x01\x02\x03binary content\x00')
            f.flush()
            result = _parse_file(f.name, "binary.py", "python")
        os.unlink(f.name)
        self.assertEqual(len(result["symbols"]), 0)

    def test_large_file_skipped(self):
        """Files > 512KB get file-level only, no symbols."""
        with tempfile.NamedTemporaryFile(suffix=".py", mode="w", delete=False) as f:
            f.write("x = 1\n" * 20000)  # > 100KB
            f.flush()
            result = _parse_file(f.name, "large.py", "python")
        os.unlink(f.name)
        self.assertEqual(len(result["symbols"]), 0)
        self.assertGreater(result["file_entry"]["size_bytes"], 0)


class TestGraph(unittest.TestCase):
    def test_build_graph_empty(self):
        """Empty files dict produces empty graph."""
        edges, modules = build_graph({})
        self.assertEqual(edges, [])
        self.assertEqual(modules, {})

    def test_module_grouping(self):
        """Files in same directory are grouped into a module."""
        files = {
            "lib/a.py": {"language": "python", "symbols": ["x"], "imports": [], "exports": ["x"], "size_bytes": 100, "lines": 10},
            "lib/b.py": {"language": "python", "symbols": ["y"], "imports": [], "exports": ["y"], "size_bytes": 100, "lines": 10},
        }
        edges, modules = build_graph(files)
        self.assertIn("lib", modules)
        self.assertEqual(len(modules["lib"]["files"]), 2)


class TestNewParsers(unittest.TestCase):
    """Tests for newly added language parsers."""

    def _parse(self, code, ext, lang):
        with tempfile.NamedTemporaryFile(suffix=ext, mode="w", delete=False) as f:
            f.write(code)
            f.flush()
            result = _parse_file(f.name, f"test{ext}", lang)
        os.unlink(f.name)
        return result

    def test_java_parser(self):
        code = 'public class Hello {\n  public void greet(String name) {}\n}\n'
        r = self._parse(code, ".java", "java")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("Hello", names)
        self.assertIn("greet", names)

    def test_csharp_parser(self):
        code = 'public class Service {\n  public void Run() {}\n}\n'
        r = self._parse(code, ".cs", "csharp")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("Service", names)

    def test_php_parser(self):
        code = '<?php\nclass Controller {\n  public function index() {}\n}\n'
        r = self._parse(code, ".php", "php")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("Controller", names)

    def test_kotlin_parser(self):
        code = 'data class User(val name: String)\nfun main() {}\n'
        r = self._parse(code, ".kt", "kotlin")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("User", names)
        self.assertIn("main", names)

    def test_swift_parser(self):
        code = 'struct Point {\n  var x: Int\n}\nfunc distance() -> Double { return 0 }\n'
        r = self._parse(code, ".swift", "swift")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("Point", names)
        self.assertIn("distance", names)

    def test_elixir_parser(self):
        code = 'defmodule MyApp do\n  def hello do\n    :world\n  end\nend\n'
        r = self._parse(code, ".ex", "elixir")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("MyApp", names)
        self.assertIn("hello", names)

    def test_typescript_parser(self):
        code = 'export function greet(name: string): void {}\nexport class Greeter {}\n'
        r = self._parse(code, ".ts", "typescript")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("greet", names)
        self.assertIn("Greeter", names)

    def test_go_parser(self):
        code = 'package main\nfunc Hello(name string) string { return "" }\ntype Server struct {}\n'
        r = self._parse(code, ".go", "go")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("Hello", names)
        self.assertIn("Server", names)

    def test_rust_parser(self):
        code = 'pub fn process(data: &str) -> Result<(), Error> {}\npub struct Config {}\n'
        r = self._parse(code, ".rs", "rust")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("process", names)
        self.assertIn("Config", names)

    def test_ruby_parser(self):
        code = "class Greeter\n  def greet(name)\n    puts name\n  end\nend\n"
        r = self._parse(code, ".rb", "ruby")
        names = [s["name"] for s in r["symbols"]]
        self.assertIn("Greeter", names)
        self.assertIn("greet", names)


class TestEdgeCases(unittest.TestCase):
    """Edge case tests."""

    def test_empty_file(self):
        with tempfile.NamedTemporaryFile(suffix=".py", mode="w", delete=False) as f:
            f.write("")
            f.flush()
            result = _parse_file(f.name, "empty.py", "python")
        os.unlink(f.name)
        self.assertEqual(len(result["symbols"]), 0)

    def test_unknown_language(self):
        with tempfile.NamedTemporaryFile(suffix=".xyz", mode="w", delete=False) as f:
            f.write("hello world")
            f.flush()
            result = _parse_file(f.name, "test.xyz", "unknown")
        os.unlink(f.name)
        self.assertEqual(len(result["symbols"]), 0)


if __name__ == '__main__':
    unittest.main()
