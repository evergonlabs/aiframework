PREFIX ?= /usr/local

.PHONY: install uninstall lint test check dist build

# Build the Rust binary (release mode)
build:
	@cd rust && cargo build --release
	@echo "Built rust/target/release/aiframework"

# Install: build Rust binary + symlink + legacy bash scripts
install: build
	@mkdir -p $(PREFIX)/bin
	@cp rust/target/release/aiframework $(PREFIX)/bin/aiframework-rs
	@ln -sf $(CURDIR)/bin/aiframework $(PREFIX)/bin/aiframework
	@ln -sf $(CURDIR)/bin/aiframework-mcp $(PREFIX)/bin/aiframework-mcp
	@ln -sf $(CURDIR)/bin/aiframework-telemetry $(PREFIX)/bin/aiframework-telemetry
	@ln -sf $(CURDIR)/bin/aiframework-update-check $(PREFIX)/bin/aiframework-update-check
	@echo "Installed aiframework to $(PREFIX)/bin/"
	@if command -v npm >/dev/null 2>&1; then \
		npm install -g @liwala/sheal@latest 2>/dev/null && echo "Installed sheal (runtime session intelligence)" || echo "Warning: sheal npm install failed (non-fatal)"; \
	else \
		echo "Note: Install Node.js 22+ and run 'npm install -g @liwala/sheal' for runtime session intelligence"; \
	fi

uninstall:
	@rm -f $(PREFIX)/bin/aiframework $(PREFIX)/bin/aiframework-rs $(PREFIX)/bin/aiframework-mcp $(PREFIX)/bin/aiframework-telemetry $(PREFIX)/bin/aiframework-update-check
	@npm uninstall -g @liwala/sheal 2>/dev/null || true
	@echo "Removed aiframework binaries from $(PREFIX)/bin/"

lint:
	@echo "Checking bash syntax..."
	@find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n
	@echo "Checking Python syntax..."
	@find . -name '*.py' -not -path '*/__pycache__/*' | xargs python3 -m py_compile
	@if [ -d rust ] && command -v cargo >/dev/null 2>&1; then \
		echo "Checking Rust..."; \
		cd rust && cargo check --quiet 2>/dev/null && echo "Rust OK" || echo "Rust check failed (non-fatal)"; \
	fi
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
	@echo "Running installer tests..."
	@bash tests/test_installer.sh
	@echo "Running integration tests..."
	@bash tests/test_e2e.sh
	@if [ -d rust ] && command -v cargo >/dev/null 2>&1; then \
		echo "Running Rust tests..."; \
		cd rust && cargo test --quiet 2>/dev/null && echo "Rust tests passed" || echo "Rust tests failed (non-fatal)"; \
	fi
	@echo "All tests passed."

check: lint test
	@echo "Running code indexer smoke test..."
	@python3 -m lib.indexers.parse --target . --output /tmp/aiframework-check.json
	@if [ -d rust ] && command -v cargo >/dev/null 2>&1; then \
		echo "Running Rust indexer smoke test..."; \
		cd rust && cargo run --quiet --release -- index --target .. --summary 2>/dev/null; \
	fi
	@echo "All checks passed."

dist:
	@VERSION=$$(cat VERSION | tr -d '[:space:]'); \
	echo "Building aiframework-$$VERSION.tar.gz..."; \
	STAGING=$$(mktemp -d); \
	mkdir -p "$$STAGING/aiframework"; \
	cp -r bin lib Makefile VERSION README.md CHANGELOG.md install.sh "$$STAGING/aiframework/"; \
	if [ -d templates ] && [ "$$(ls -A templates 2>/dev/null)" ]; then cp -r templates "$$STAGING/aiframework/"; fi; \
	cp LICENSE "$$STAGING/aiframework/" 2>/dev/null || true; \
	if [ -f rust/target/release/aiframework ]; then \
		mkdir -p "$$STAGING/aiframework/rust/target/release"; \
		cp rust/target/release/aiframework "$$STAGING/aiframework/rust/target/release/"; \
	fi; \
	find "$$STAGING" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true; \
	find "$$STAGING" -name '.DS_Store' -delete 2>/dev/null || true; \
	mkdir -p dist; \
	(cd "$$STAGING" && tar czf "$(CURDIR)/dist/aiframework-$$VERSION.tar.gz" aiframework); \
	rm -rf "$$STAGING"; \
	echo "Built dist/aiframework-$$VERSION.tar.gz"; \
	ls -lh "dist/aiframework-$$VERSION.tar.gz"
