#!/usr/bin/env python3
"""
aiframework MCP Server

Exposes project manifest, code index, invariants, and commands as MCP
resources and tools for AI agents that support the Model Context Protocol.

JSON-RPC 2.0 over stdin/stdout.
"""

import json
import os
import sys
from pathlib import Path

# Protocol version
MCP_VERSION = "2024-11-05"
SERVER_NAME = "aiframework"
SERVER_VERSION = "1.2.0"


def _find_project_root():
    """Walk up from cwd to find .aiframework/manifest.json."""
    p = Path.cwd()
    while p != p.parent:
        if (p / ".aiframework" / "manifest.json").exists():
            return p
        p = p.parent
    return Path.cwd()


def _load_json(path):
    """Load JSON file, return None on failure."""
    try:
        with open(path, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


class AifMcpServer:
    def __init__(self):
        self.root = _find_project_root()
        self.aif_dir = self.root / ".aiframework"
        self._manifest = None
        self._code_index = None

    @property
    def manifest(self):
        if self._manifest is None:
            self._manifest = _load_json(self.aif_dir / "manifest.json") or {}
        return self._manifest

    @property
    def code_index(self):
        if self._code_index is None:
            self._code_index = _load_json(self.aif_dir / "code-index.json") or {}
        return self._code_index

    # ── Capabilities ─────────────────────────────────────────────

    def handle_initialize(self, params):
        return {
            "protocolVersion": MCP_VERSION,
            "capabilities": {
                "resources": {"listChanged": False},
                "tools": {},
            },
            "serverInfo": {
                "name": SERVER_NAME,
                "version": SERVER_VERSION,
            },
        }

    def handle_initialized(self, params):
        return None  # notification, no response needed

    # ── Resources ────────────────────────────────────────────────

    def handle_resources_list(self, params):
        resources = [
            {
                "uri": "aiframework://manifest",
                "name": "Project Manifest",
                "description": "Full project analysis manifest (stack, commands, domains, archetype)",
                "mimeType": "application/json",
            },
            {
                "uri": "aiframework://code-index",
                "name": "Code Index",
                "description": "Indexed symbols, modules, edges, and file rankings",
                "mimeType": "application/json",
            },
            {
                "uri": "aiframework://invariants",
                "name": "Project Invariants",
                "description": "Rules that must never be violated",
                "mimeType": "application/json",
            },
            {
                "uri": "aiframework://commands",
                "name": "Project Commands",
                "description": "Build, test, lint, and dev commands",
                "mimeType": "application/json",
            },
            {
                "uri": "aiframework://architecture",
                "name": "Architecture Summary",
                "description": "Archetype, domains, entry points, key locations",
                "mimeType": "application/json",
            },
        ]
        return {"resources": resources}

    def handle_resources_read(self, params):
        uri = params.get("uri", "")

        if uri == "aiframework://manifest":
            content = json.dumps(self.manifest, indent=2)
        elif uri == "aiframework://code-index":
            content = json.dumps(self.code_index, indent=2)
        elif uri == "aiframework://invariants":
            invariants = self._extract_invariants()
            content = json.dumps(invariants, indent=2)
        elif uri == "aiframework://commands":
            cmds = self.manifest.get("commands", {})
            content = json.dumps(cmds, indent=2)
        elif uri == "aiframework://architecture":
            arch = self._extract_architecture()
            content = json.dumps(arch, indent=2)
        else:
            return {"contents": [{"uri": uri, "text": "Unknown resource"}]}

        return {"contents": [{"uri": uri, "mimeType": "application/json", "text": content}]}

    # ── Tools ────────────────────────────────────────────────────

    def handle_tools_list(self, params):
        tools = [
            {
                "name": "analyze_file",
                "description": "Get symbols, imports, and dependencies for a file path",
                "inputSchema": {
                    "type": "object",
                    "properties": {"path": {"type": "string", "description": "File path relative to project root"}},
                    "required": ["path"],
                },
            },
            {
                "name": "find_tests",
                "description": "Find test files related to a source file",
                "inputSchema": {
                    "type": "object",
                    "properties": {"path": {"type": "string", "description": "Source file path"}},
                    "required": ["path"],
                },
            },
            {
                "name": "check_invariants",
                "description": "List all project invariants that must be maintained",
                "inputSchema": {"type": "object", "properties": {}},
            },
            {
                "name": "refresh",
                "description": "Re-run aiframework discover + generate to update project context",
                "inputSchema": {"type": "object", "properties": {}},
            },
        ]
        return {"tools": tools}

    def handle_tools_call(self, params):
        name = params.get("name", "")
        args = params.get("arguments", {})

        if name == "analyze_file":
            result = self._tool_analyze_file(args.get("path", ""))
        elif name == "find_tests":
            result = self._tool_find_tests(args.get("path", ""))
        elif name == "check_invariants":
            result = self._tool_check_invariants()
        elif name == "refresh":
            result = self._tool_refresh()
        else:
            result = {"error": f"Unknown tool: {name}"}

        return {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]}

    # ── Tool implementations ─────────────────────────────────────

    def _tool_analyze_file(self, path):
        idx = self.code_index
        symbols = [s for s in idx.get("symbols", []) if s.get("file") == path]
        edges_out = [e for e in idx.get("edges", []) if e.get("source") == path]
        edges_in = [e for e in idx.get("edges", []) if e.get("target") == path]
        return {
            "path": path,
            "symbols": symbols,
            "imports_from": [e["target"] for e in edges_out],
            "imported_by": [e["source"] for e in edges_in],
        }

    def _tool_find_tests(self, path):
        test_pattern = self.manifest.get("structure", {}).get("test_pattern", "")
        test_dirs = self.manifest.get("structure", {}).get("test_dirs", [])
        stem = Path(path).stem

        candidates = []
        for td in test_dirs:
            test_dir = self.root / td
            if test_dir.exists():
                for f in test_dir.rglob(f"*{stem}*"):
                    if f.is_file():
                        candidates.append(str(f.relative_to(self.root)))

        # Also check for co-located tests
        src = self.root / path
        if src.exists():
            parent = src.parent
            for f in parent.glob(f"*test*{stem}*"):
                rel = str(f.relative_to(self.root))
                if rel not in candidates:
                    candidates.append(rel)

        return {"source": path, "test_files": candidates, "test_pattern": test_pattern}

    def _tool_check_invariants(self):
        return self._extract_invariants()

    def _tool_refresh(self):
        import subprocess

        try:
            result = subprocess.run(
                ["aiframework", "refresh", "--target", str(self.root)],
                capture_output=True,
                text=True,
                timeout=60,
            )
            return {"success": result.returncode == 0, "output": result.stdout[-500:] if result.stdout else ""}
        except (FileNotFoundError, subprocess.TimeoutExpired) as e:
            return {"success": False, "error": str(e)}

    # ── Helpers ──────────────────────────────────────────────────

    def _extract_invariants(self):
        domains = self.manifest.get("domain", {}).get("detected_domains", [])
        invariants = []
        for i, d in enumerate(domains, 1):
            name = d.get("name", "")
            inv_map = {
                "auth": "Auth guards on all protected endpoints",
                "database": f"Database access through {d.get('orm', 'ORM')} only",
                "api": "Input validation on all API endpoints",
                "ai": "LLM trust boundary — validate all AI output",
                "sandbox": "Sandbox isolation for code execution",
            }
            if name in inv_map:
                invariants.append({"id": f"INV-{i}", "rule": inv_map[name], "domain": name})

        if not invariants:
            invariants.append({"id": "INV-1", "rule": "No secrets in source code", "domain": "general"})

        return {"invariants": invariants}

    def _extract_architecture(self):
        m = self.manifest
        return {
            "archetype": m.get("archetype", {}),
            "domains": [d.get("name") for d in m.get("domain", {}).get("detected_domains", [])],
            "entry_points": m.get("structure", {}).get("entry_points", []),
            "directories": m.get("structure", {}).get("directories", []),
            "stack": m.get("stack", {}),
        }

    # ── JSON-RPC dispatch ────────────────────────────────────────

    def dispatch(self, request):
        method = request.get("method", "")
        params = request.get("params", {})
        req_id = request.get("id")

        handlers = {
            "initialize": self.handle_initialize,
            "initialized": self.handle_initialized,
            "resources/list": self.handle_resources_list,
            "resources/read": self.handle_resources_read,
            "tools/list": self.handle_tools_list,
            "tools/call": self.handle_tools_call,
        }

        handler = handlers.get(method)
        if handler is None:
            if req_id is not None:
                return {"jsonrpc": "2.0", "id": req_id, "error": {"code": -32601, "message": f"Method not found: {method}"}}
            return None  # notification for unknown method

        result = handler(params)

        if req_id is not None and result is not None:
            return {"jsonrpc": "2.0", "id": req_id, "result": result}
        elif req_id is not None:
            return {"jsonrpc": "2.0", "id": req_id, "result": {}}
        return None  # notification response

    def run(self):
        """Main loop: read JSON-RPC from stdin, write to stdout."""
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue

            try:
                request = json.loads(line)
            except json.JSONDecodeError:
                error_resp = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Parse error"}}
                sys.stdout.write(json.dumps(error_resp) + "\n")
                sys.stdout.flush()
                continue

            response = self.dispatch(request)
            if response is not None:
                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()


def main():
    server = AifMcpServer()
    server.run()


if __name__ == "__main__":
    main()
