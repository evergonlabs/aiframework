"""Tests for the wiki graph generator."""

import json
import os
import sys
import tempfile

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from lib.generators.wiki_graph import (
    file_to_slug,
    generate_wiki_graph,
    module_to_slug,
    verify_wiki_graph,
)


def test_file_to_slug():
    assert file_to_slug("lib/generators/vault.sh") == "lib-generators-vault-sh"
    assert file_to_slug("bin/aiframework") == "bin-aiframework"
    assert file_to_slug("lib/indexers/__init__.py") == "lib-indexers-init-py"
    assert file_to_slug(".githooks/pre-commit") == "githooks-pre-commit"
    assert file_to_slug("Makefile") == "Makefile"
    print("  PASS: file_to_slug")


def test_module_to_slug():
    assert module_to_slug("lib/generators") == "lib-generators"
    assert module_to_slug(".") == "root-module"
    assert module_to_slug("lib/indexers/parsers") == "lib-indexers-parsers"
    print("  PASS: module_to_slug")


def _make_fixture():
    """Create a minimal code-index.json for testing."""
    return {
        "_meta": {
            "total_files": 3,
            "total_symbols": 4,
            "total_edges": 2,
            "languages": {"python": 2, "bash": 1},
            "top_files": [
                ["src/main.py", 0.5],
                ["src/utils.py", 0.3],
                ["bin/cli", 0.2],
            ],
        },
        "files": {
            "src/main.py": {
                "language": "python",
                "size_bytes": 500,
                "lines": 50,
                "symbols": ["main", "run"],
                "imports": ["src.utils"],
                "exports": ["main"],
                "importance": 0.5,
            },
            "src/utils.py": {
                "language": "python",
                "size_bytes": 300,
                "lines": 30,
                "symbols": ["helper"],
                "imports": [],
                "exports": ["helper"],
                "importance": 0.3,
            },
            "bin/cli": {
                "language": "bash",
                "size_bytes": 200,
                "lines": 20,
                "symbols": ["usage"],
                "imports": ["src/main.py"],
                "exports": [],
                "importance": 0.2,
            },
        },
        "symbols": [
            {"name": "main", "kind": "function", "file": "src/main.py", "line": 10, "signature": "def main()", "docstring": "Entry point", "visibility": "public"},
            {"name": "run", "kind": "function", "file": "src/main.py", "line": 20, "signature": "def run()", "docstring": "", "visibility": "public"},
            {"name": "helper", "kind": "function", "file": "src/utils.py", "line": 5, "signature": "def helper()", "docstring": "Utility function", "visibility": "public"},
            {"name": "usage", "kind": "function", "file": "bin/cli", "line": 3, "signature": "usage()", "docstring": "", "visibility": "public"},
        ],
        "edges": [
            {"source": "src/main.py", "target": "src/utils.py", "type": "import", "symbols": ["helper"]},
            {"source": "bin/cli", "target": "src/main.py", "type": "import", "symbols": ["main"]},
        ],
        "modules": {
            "src": {
                "files": ["main.py", "utils.py"],
                "role": "source",
                "fan_in": 1,
                "fan_out": 0,
                "total_symbols": 3,
            },
            "bin": {
                "files": ["cli"],
                "role": "entrypoint",
                "fan_in": 0,
                "fan_out": 1,
                "total_symbols": 1,
            },
        },
    }


def test_generate_and_verify():
    """Full integration test: generate pages, verify completeness."""
    fixture = _make_fixture()

    with tempfile.TemporaryDirectory() as tmpdir:
        # Write fixture
        code_index_path = os.path.join(tmpdir, "code-index.json")
        vault_root = os.path.join(tmpdir, "vault")
        os.makedirs(os.path.join(vault_root, "wiki", "entities"))
        os.makedirs(os.path.join(vault_root, "wiki", "concepts"))
        os.makedirs(os.path.join(vault_root, ".vault"))

        with open(code_index_path, "w") as f:
            json.dump(fixture, f)

        # Generate
        stats = generate_wiki_graph(code_index_path, vault_root, "2026-04-18")

        # Check stats
        assert stats["total_files"] == 3, f"Expected 3 files, got {stats['total_files']}"
        assert stats["total_edges"] == 2, f"Expected 2 edges, got {stats['total_edges']}"
        assert stats["total_pages"] > 0, "No pages generated"
        print(f"  Generated {stats['total_pages']} pages ({stats['pages_written']} written)")

        # Check file pages exist
        assert os.path.exists(os.path.join(vault_root, "wiki", "entities", "src-main-py.md"))
        assert os.path.exists(os.path.join(vault_root, "wiki", "entities", "src-utils-py.md"))
        assert os.path.exists(os.path.join(vault_root, "wiki", "entities", "bin-cli.md"))

        # Check module pages exist
        assert os.path.exists(os.path.join(vault_root, "wiki", "entities", "src.md"))
        assert os.path.exists(os.path.join(vault_root, "wiki", "entities", "bin.md"))

        # Check architecture page
        assert os.path.exists(os.path.join(vault_root, "wiki", "concepts", "architecture.md"))

        # Check index
        assert os.path.exists(os.path.join(vault_root, "wiki", "index.md"))

        # Check wikilinks — src/main.py should link to src/utils.py
        with open(os.path.join(vault_root, "wiki", "entities", "src-main-py.md")) as f:
            content = f.read()
        assert "[[src-utils-py" in content, "Missing outbound link: main.py -> utils.py"
        assert "[[bin-cli" in content, "Missing inbound link: cli -> main.py"

        # Check reverse link — src/utils.py should show main.py as dependent
        with open(os.path.join(vault_root, "wiki", "entities", "src-utils-py.md")) as f:
            content = f.read()
        assert "[[src-main-py" in content, "Missing inbound link on utils.py"

        # Verify completeness
        errors = verify_wiki_graph(code_index_path, vault_root)
        assert len(errors) == 0, f"Verification errors: {errors}"

        print("  PASS: generate_and_verify")


def test_incremental_update():
    """Second run should produce no writes when nothing changed."""
    fixture = _make_fixture()

    with tempfile.TemporaryDirectory() as tmpdir:
        code_index_path = os.path.join(tmpdir, "code-index.json")
        vault_root = os.path.join(tmpdir, "vault")
        os.makedirs(os.path.join(vault_root, "wiki", "entities"))
        os.makedirs(os.path.join(vault_root, "wiki", "concepts"))
        os.makedirs(os.path.join(vault_root, ".vault"))

        with open(code_index_path, "w") as f:
            json.dump(fixture, f)

        # First run
        generate_wiki_graph(code_index_path, vault_root, "2026-04-18")

        # Second run — should write nothing
        stats = generate_wiki_graph(code_index_path, vault_root, "2026-04-18")
        assert stats["pages_written"] == 0, f"Expected 0 writes on second run, got {stats['pages_written']}"
        assert stats["pages_unchanged"] == stats["total_pages"]

        print("  PASS: incremental_update")


def test_stale_page_archival():
    """Removed files should get archived, not deleted (HR-014)."""
    fixture = _make_fixture()

    with tempfile.TemporaryDirectory() as tmpdir:
        code_index_path = os.path.join(tmpdir, "code-index.json")
        vault_root = os.path.join(tmpdir, "vault")
        os.makedirs(os.path.join(vault_root, "wiki", "entities"))
        os.makedirs(os.path.join(vault_root, "wiki", "concepts"))
        os.makedirs(os.path.join(vault_root, ".vault"))

        with open(code_index_path, "w") as f:
            json.dump(fixture, f)

        # First run with 3 files
        generate_wiki_graph(code_index_path, vault_root, "2026-04-18")

        # Remove a file from the index
        del fixture["files"]["bin/cli"]
        fixture["symbols"] = [s for s in fixture["symbols"] if s["file"] != "bin/cli"]
        fixture["edges"] = [e for e in fixture["edges"] if e["source"] != "bin/cli"]
        del fixture["modules"]["bin"]
        fixture["_meta"]["total_files"] = 2

        with open(code_index_path, "w") as f:
            json.dump(fixture, f)

        # Second run — bin-cli.md should be archived not deleted
        stats = generate_wiki_graph(code_index_path, vault_root, "2026-04-18")
        assert stats["pages_archived"] > 0, "Expected archived pages"

        archived_page = os.path.join(vault_root, "wiki", "entities", "bin-cli.md")
        assert os.path.exists(archived_page), "Archived page should still exist (HR-014)"
        with open(archived_page) as f:
            content = f.read()
        assert "status: archived" in content, "Page should be marked as archived"

        print("  PASS: stale_page_archival")


if __name__ == "__main__":
    print("=== Wiki Graph Tests ===")
    test_file_to_slug()
    test_module_to_slug()
    test_generate_and_verify()
    test_incremental_update()
    test_stale_page_archival()
    print(f"\nAll {5} tests passed.")
