#!/usr/bin/env bash
# Generator: CI Workflow
# Creates GitHub Actions CI based on manifest

generate_ci() {
  local m="$MANIFEST"

  local ci_provider
  ci_provider=$(echo "$m" | jq -r '.ci.provider // "none"')

  # Check if CI already covers lint+test+build
  local coverage
  coverage=$(echo "$m" | jq -r '.ci.coverage | length' 2>/dev/null || echo "0")

  if [[ "$ci_provider" != "none" && "$coverage" -ge 3 ]]; then
    log_info "CI already covers lint+test+build — skipping ci.yml creation"
    return 0
  fi

  # Preserve existing CI workflow even if coverage is incomplete
  if ! preserve_ci "$TARGET_DIR/.github/workflows/ci.yml"; then
    return 0
  fi

  local lang
  lang=$(echo "$m" | jq -r '.stack.language')
  local name
  name=$(echo "$m" | jq -r '.identity.name')
  local pkg
  pkg=$(echo "$m" | jq -r '.commands.package_manager // "npm"')
  local install
  install=$(echo "$m" | jq -r '.commands.install // "npm install"')
  local build
  build=$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')
  local lint
  lint=$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')
  local typecheck
  typecheck=$(echo "$m" | jq -r '.commands.typecheck // "NOT_CONFIGURED"')
  local test_cmd
  test_cmd=$(echo "$m" | jq -r '.commands.test // "NOT_CONFIGURED"')
  local lock
  lock=$(echo "$m" | jq -r '.commands.lock_file // ""')
  local node_ver
  node_ver=$(echo "$m" | jq -r '.stack.node_version // "20"')
  local py_ver
  py_ver=$(echo "$m" | jq -r '.stack.python_version // "3.12"')

  # Source dirs for path triggers
  local src_dirs
  src_dirs=$(echo "$m" | jq -r '.structure.source_dirs | join("/**\n") + "/**"' 2>/dev/null || echo "src/**")

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create .github/workflows/ci.yml"
    return 0
  fi

  mkdir -p "$TARGET_DIR/.github/workflows"
  local out="$TARGET_DIR/.github/workflows/ci.yml"

  case "$lang" in
    typescript|javascript)
      # Build path triggers from source_dirs
      local ts_path_entries=""
      while IFS= read -r sdir; do
        ts_path_entries+="      - '${sdir}/**'
"
      done < <(echo "$m" | jq -r '.structure.source_dirs[]?' 2>/dev/null)
      # Fallback to src/** if no source_dirs found
      if [[ -z "$ts_path_entries" ]]; then
        ts_path_entries="      - 'src/**'
"
      fi

      cat > "$out" << CIYML
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
    paths:
${ts_path_entries}      - 'package.json'
$([ -n "$lock" ] && echo "      - '${lock}'" || true)
      - '.github/workflows/ci.yml'

concurrency:
  group: ci-\${{ github.ref }}
  cancel-in-progress: true

jobs:
CIYML

      if [[ "$build" != "NOT_CONFIGURED" ]]; then
        cat >> "$out" << JOB
  build:
    name: Build
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '${node_ver}'
          cache: ${pkg}
      - run: ${install}
      - run: ${build}

JOB
      fi

      if [[ "$lint" != "NOT_CONFIGURED" ]]; then
        cat >> "$out" << JOB
  lint:
    name: Lint
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '${node_ver}'
          cache: ${pkg}
      - run: ${install}
      - run: ${lint}

JOB
      fi

      if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then
        cat >> "$out" << JOB
  test:
    name: Test
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '${node_ver}'
          cache: ${pkg}
      - run: ${install}
      - run: ${test_cmd}
JOB
      fi
      ;;

    python)
      cat > "$out" << CIYML
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'pyproject.toml'
      - '.github/workflows/ci.yml'

concurrency:
  group: ci-\${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    name: Lint + Type Check + Test
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '${py_ver}'
      - run: ${install}
$([ "$lint" != "NOT_CONFIGURED" ] && echo "      - name: Lint\n        run: ${lint}" || true)
$([ "$typecheck" != "NOT_CONFIGURED" ] && echo "      - name: Type check\n        run: ${typecheck}" || true)
$([ "$test_cmd" != "NOT_CONFIGURED" ] && echo "      - name: Test\n        run: ${test_cmd}" || true)
CIYML

      if [[ -f "$TARGET_DIR/Dockerfile" ]]; then
        cat >> "$out" << JOB

  build:
    name: Docker Build
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t ${name} .
JOB
      fi
      ;;

    rust)
      cat > "$out" << CIYML
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-\${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    name: Check + Clippy + Test
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          components: clippy, rustfmt
      - uses: Swatinem/rust-cache@v2
      - name: Format check
        run: cargo fmt --all -- --check
      - name: Clippy
        run: cargo clippy --workspace -- -D warnings
      - name: Test
        run: cargo test --workspace
      - name: Build
        run: cargo build --workspace
CIYML
      ;;

    go)
      cat > "$out" << CIYML
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-\${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    name: Vet + Lint + Test
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - name: Vet
        run: go vet ./...
      - name: Test
        run: go test ./...
      - name: Build
        run: go build ./...
CIYML
      ;;

    ruby)
      local ruby_ver
      ruby_ver=$(echo "$m" | jq -r '.stack.ruby_version // "3.2"')
      local rubocop_configured
      rubocop_configured=$(echo "$m" | jq -r '.quality.linter.tool // ""')
      local rspec_configured
      rspec_configured=$(echo "$m" | jq -r '.quality.test_framework.tool // ""')

      cat > "$out" << CIYML
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-\${{ github.ref }}
  cancel-in-progress: true

jobs:
  quality:
    name: Lint + Test
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '${ruby_ver}'
          bundler-cache: true
      - run: bundle install
CIYML

      if [[ "$rubocop_configured" == *"rubocop"* || -f "$TARGET_DIR/.rubocop.yml" ]]; then
        cat >> "$out" << 'JOB'
      - name: Lint (RuboCop)
        run: bundle exec rubocop
JOB
      fi

      if [[ "$rspec_configured" == *"rspec"* || -d "$TARGET_DIR/spec" ]]; then
        cat >> "$out" << 'JOB'
      - name: Test (RSpec)
        run: bundle exec rspec
JOB
      fi
      ;;

    bash|shell)
      cat > "$out" << 'CIYML'
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  shellcheck:
    name: ShellCheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install ShellCheck
        run: sudo apt-get install -y shellcheck
      - name: Run ShellCheck
        run: find . -name "*.sh" -not -path "*/.git/*" -not -path "*/vault/*" | xargs shellcheck
      - name: Vault integrity check
        if: hashFiles('vault/.vault/scripts/vault-tools.sh') != ''
        run: bash vault/.vault/scripts/vault-tools.sh lint --report || true
CIYML
      ;;

    *)
      # Fallback: if .sh files exist in the project, generate a shellcheck CI
      if find "$TARGET_DIR" -name "*.sh" -not -path "*/.git/*" | head -1 | grep -q .; then
        lang="bash"
        cat > "$out" << 'CIYML'
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  shellcheck:
    name: ShellCheck
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install ShellCheck
        run: sudo apt-get install -y shellcheck
      - name: Run ShellCheck
        run: find . -name "*.sh" -not -path "*/.git/*" -not -path "*/vault/*" | xargs shellcheck
CIYML
      else
        log_warn "No CI template for language: $lang"
        return 0
      fi
      ;;
  esac

  log_ok "Created .github/workflows/ci.yml (${lang})"
}
