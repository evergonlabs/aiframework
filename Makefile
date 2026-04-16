PREFIX ?= /usr/local

.PHONY: install uninstall lint test check

install:
	@mkdir -p $(PREFIX)/bin
	@ln -sf $(CURDIR)/bin/aiframework $(PREFIX)/bin/aiframework
	@echo "Installed aiframework to $(PREFIX)/bin/aiframework"

uninstall:
	@rm -f $(PREFIX)/bin/aiframework
	@echo "Removed aiframework from $(PREFIX)/bin/aiframework"

lint:
	@echo "Checking bash syntax..."
	@find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n
	@echo "Checking Python syntax..."
	@find . -name '*.py' -not -path '*/__pycache__/*' | xargs python3 -m py_compile
	@echo "All checks passed."

test:
	@echo "Running Python tests..."
	@python3 tests/test_indexer.py
	@echo "Running validator tests..."
	@bash tests/test_validators.sh
	@echo "Running integration tests..."
	@bash tests/test_e2e.sh
	@echo "All tests passed."

check: lint test
	@echo "Running code indexer smoke test..."
	@python3 -m lib.indexers.parse --target . --output /tmp/aiframework-check.json
	@echo "All checks passed."
