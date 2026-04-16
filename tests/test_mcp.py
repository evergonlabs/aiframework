"""Tests for aiframework MCP server."""
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

# Add lib to path
ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(ROOT / "lib"))

from mcp.server import AifMcpServer


class TestMcpServer(unittest.TestCase):
    """Test the MCP server dispatch and handlers."""

    def setUp(self):
        """Create a temp project with manifest."""
        self.tmpdir = tempfile.mkdtemp()
        aif_dir = os.path.join(self.tmpdir, ".aiframework")
        os.makedirs(aif_dir)

        manifest = {
            "identity": {"name": "testapp", "short_name": "test", "version": "1.0.0"},
            "stack": {"language": "python", "framework": "fastapi"},
            "commands": {
                "build": "make build",
                "test": "pytest",
                "lint": "ruff check .",
            },
            "archetype": {"type": "api-service", "maturity": "active", "complexity": "moderate"},
            "domain": {
                "detected_domains": [
                    {"name": "api", "display": "API Layer", "paths": ["src/api/"]},
                    {"name": "auth", "display": "Authentication", "paths": ["src/auth/"]},
                ]
            },
            "structure": {
                "entry_points": ["src/main.py"],
                "directories": ["src", "tests"],
                "test_dirs": ["tests"],
                "test_pattern": "test_*.py",
            },
        }
        with open(os.path.join(aif_dir, "manifest.json"), "w") as f:
            json.dump(manifest, f)

        code_index = {
            "_meta": {"total_files": 3, "total_symbols": 5, "top_files": [["src/main.py", 0.5]]},
            "files": [{"path": "src/main.py"}, {"path": "src/api/route.py"}],
            "symbols": [
                {"name": "app", "file": "src/main.py", "type": "variable"},
                {"name": "handler", "file": "src/api/route.py", "type": "function"},
            ],
            "edges": [
                {"source": "src/api/route.py", "target": "src/main.py"},
            ],
            "modules": {},
        }
        with open(os.path.join(aif_dir, "code-index.json"), "w") as f:
            json.dump(code_index, f)

        self.orig_cwd = os.getcwd()
        os.chdir(self.tmpdir)

    def tearDown(self):
        os.chdir(self.orig_cwd)
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _dispatch(self, method, params=None, req_id=1):
        server = AifMcpServer()
        request = {"jsonrpc": "2.0", "method": method, "params": params or {}, "id": req_id}
        return server.dispatch(request)

    def test_initialize(self):
        resp = self._dispatch("initialize")
        self.assertEqual(resp["jsonrpc"], "2.0")
        result = resp["result"]
        self.assertIn("protocolVersion", result)
        self.assertIn("capabilities", result)
        self.assertEqual(result["serverInfo"]["name"], "aiframework")

    def test_resources_list(self):
        resp = self._dispatch("resources/list")
        resources = resp["result"]["resources"]
        uris = [r["uri"] for r in resources]
        self.assertIn("aiframework://manifest", uris)
        self.assertIn("aiframework://code-index", uris)
        self.assertIn("aiframework://invariants", uris)
        self.assertIn("aiframework://commands", uris)
        self.assertIn("aiframework://architecture", uris)

    def test_resources_read_manifest(self):
        resp = self._dispatch("resources/read", {"uri": "aiframework://manifest"})
        contents = resp["result"]["contents"]
        self.assertEqual(len(contents), 1)
        data = json.loads(contents[0]["text"])
        self.assertEqual(data["identity"]["name"], "testapp")

    def test_resources_read_commands(self):
        resp = self._dispatch("resources/read", {"uri": "aiframework://commands"})
        data = json.loads(resp["result"]["contents"][0]["text"])
        self.assertEqual(data["build"], "make build")
        self.assertEqual(data["test"], "pytest")

    def test_resources_read_invariants(self):
        resp = self._dispatch("resources/read", {"uri": "aiframework://invariants"})
        data = json.loads(resp["result"]["contents"][0]["text"])
        invs = data["invariants"]
        self.assertTrue(len(invs) >= 2)
        domains = [i["domain"] for i in invs]
        self.assertIn("api", domains)
        self.assertIn("auth", domains)

    def test_resources_read_architecture(self):
        resp = self._dispatch("resources/read", {"uri": "aiframework://architecture"})
        data = json.loads(resp["result"]["contents"][0]["text"])
        self.assertEqual(data["archetype"]["type"], "api-service")
        self.assertIn("api", data["domains"])

    def test_tools_list(self):
        resp = self._dispatch("tools/list")
        tools = resp["result"]["tools"]
        names = [t["name"] for t in tools]
        self.assertIn("analyze_file", names)
        self.assertIn("find_tests", names)
        self.assertIn("check_invariants", names)
        self.assertIn("refresh", names)

    def test_tool_analyze_file(self):
        resp = self._dispatch("tools/call", {"name": "analyze_file", "arguments": {"path": "src/api/route.py"}})
        data = json.loads(resp["result"]["content"][0]["text"])
        self.assertEqual(data["path"], "src/api/route.py")
        self.assertEqual(len(data["symbols"]), 1)
        self.assertIn("src/main.py", data["imports_from"])

    def test_tool_check_invariants(self):
        resp = self._dispatch("tools/call", {"name": "check_invariants", "arguments": {}})
        data = json.loads(resp["result"]["content"][0]["text"])
        self.assertTrue(len(data["invariants"]) >= 2)

    def test_unknown_method(self):
        resp = self._dispatch("nonexistent/method")
        self.assertIn("error", resp)
        self.assertEqual(resp["error"]["code"], -32601)

    def test_notification_no_response(self):
        server = AifMcpServer()
        request = {"jsonrpc": "2.0", "method": "initialized", "params": {}}
        resp = server.dispatch(request)
        self.assertIsNone(resp)


if __name__ == "__main__":
    unittest.main()
