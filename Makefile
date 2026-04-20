PREFIX ?= /usr/local

.PHONY: build install uninstall test lint check dist

build:
	cd rust && cargo build --release

install: build
	mkdir -p $(PREFIX)/bin
	cp rust/target/release/aiframework $(PREFIX)/bin/aiframework
	@echo "Installed aiframework to $(PREFIX)/bin/aiframework"

uninstall:
	rm -f $(PREFIX)/bin/aiframework
	@echo "Removed aiframework from $(PREFIX)/bin/"

test:
	cd rust && cargo test

lint:
	cd rust && cargo clippy --quiet 2>/dev/null || cargo check --quiet

check: lint test
	cd rust && ./target/release/aiframework index --target .. --summary

dist: build
	@VERSION=$$(cat VERSION | tr -d '[:space:]'); \
	mkdir -p dist; \
	cp rust/target/release/aiframework dist/aiframework-$${VERSION}; \
	tar czf dist/aiframework-$${VERSION}.tar.gz -C dist aiframework-$${VERSION}; \
	rm dist/aiframework-$${VERSION}; \
	echo "Built dist/aiframework-$${VERSION}.tar.gz"; \
	ls -lh dist/aiframework-$${VERSION}.tar.gz
