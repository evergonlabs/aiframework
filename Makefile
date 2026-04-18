PREFIX ?= /usr/local

.PHONY: install uninstall lint test check

install:
	@mkdir -p $(PREFIX)/bin
	@ln -sf $(CURDIR)/bin/aiframework $(PREFIX)/bin/aiframework
	@ln -sf $(CURDIR)/bin/aiframework-mcp $(PREFIX)/bin/aiframework-mcp
	@echo "Installed aiframework + aiframework-mcp to $(PREFIX)/bin/"
	@if command -v npm >/dev/null 2>&1; then \
		npm install -g @liwala/sheal@latest 2>/dev/null && echo "Installed sheal (runtime session intelligence)" || echo "Warning: sheal npm install failed (non-fatal)"; \
	else \
		echo "Note: Install Node.js 22+ and run 'npm install -g @liwala/sheal' for runtime session intelligence"; \
	fi

uninstall:
	@rm -f $(PREFIX)/bin/aiframework $(PREFIX)/bin/aiframework-mcp
	@npm uninstall -g @liwala/sheal 2>/dev/null || true
	@echo "Removed aiframework + aiframework-mcp + sheal from $(PREFIX)/bin/"

lint:
	@echo "Checking bash syntax..."
	@find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n
	@echo "Checking Python syntax..."
	@find . -name '*.py' -not -path '*/__pycache__/*' | xargs python3 -m py_compile
	@echo "All checks passed."

test:
	@echo "Running Python tests..."
	@python3 tests/test_indexer.py
	@echo "Running MCP tests..."
	@python3 tests/test_mcp.py
	@echo "Running wiki graph tests..."
	@python3 tests/test_wiki_graph.py
	@echo "Running validator tests..."
	@bash tests/test_validators.sh
	@echo "Running sheal integration tests..."
	@bash tests/test_sheal.sh
	@echo "Running integration tests..."
	@bash tests/test_e2e.sh
	@echo "All tests passed."

check: lint test
	@echo "Running code indexer smoke test..."
	@python3 -m lib.indexers.parse --target . --output /tmp/aiframework-check.json
	@echo "All checks passed."
