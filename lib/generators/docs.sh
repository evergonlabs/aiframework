#!/usr/bin/env bash
# Generator: Documentation Scaffold
# Creates docs/ structure, SETUP-DEV.md, CONTRIBUTING.md

generate_docs() {
  local m="$MANIFEST"
  local name
  name=$(echo "$m" | jq -r '.identity.name')
  local short
  short=$(echo "$m" | jq -r '.identity.short_name')
  local lang
  lang=$(echo "$m" | jq -r '.stack.language')
  local gh_url
  gh_url=$(echo "$m" | jq -r '.commands.github_url // "https://github.com/org/repo"')
  local install
  install=$(echo "$m" | jq -r '.commands.install // "NOT_CONFIGURED"')
  local lint
  lint=$(echo "$m" | jq -r '.commands.lint // "NOT_CONFIGURED"')
  local test_cmd
  test_cmd=$(echo "$m" | jq -r '.commands.test // "NOT_CONFIGURED"')
  local build
  build=$(echo "$m" | jq -r '.commands.build // "NOT_CONFIGURED"')
  local format_cmd
  format_cmd=$(echo "$m" | jq -r '.commands.format // "NOT_CONFIGURED"')
  local node_ver
  node_ver=$(echo "$m" | jq -r '.stack.node_version // "20"')
  local py_ver
  py_ver=$(echo "$m" | jq -r '.stack.python_version // "3.12"')

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] Would create docs/, SETUP-DEV.md, CONTRIBUTING.md"
    return 0
  fi

  # --- docs/ scaffold ---
  mkdir -p "$TARGET_DIR/docs/"{onboarding,guides,reference,explanation,decisions}

  if ! preserve_doc "$TARGET_DIR/docs/README.md"; then
    log_ok "Preserved existing docs/README.md"
  else
    cat > "$TARGET_DIR/docs/README.md" << DOCSMD
# ${name} — Documentation

## Structure (Diataxis)

| Category | Directory | Purpose |
|----------|-----------|---------|
| Tutorials | \`onboarding/\` | Learning-oriented, step-by-step |
| How-to Guides | \`guides/\` | Task-oriented instructions |
| Reference | \`reference/\` | Precise technical descriptions |
| Explanation | \`explanation/\` | Conceptual discussions |
| Decisions | \`decisions/\` | Architecture Decision Records |
DOCSMD

    log_ok "Created docs/ scaffold (Diataxis structure)"
  fi

  # --- SETUP-DEV.md ---
  local prerequisites=""
  case "$lang" in
    typescript|javascript)
      prerequisites="- **Node.js** ${node_ver}+: \`node --version\` (install via [nvm](https://github.com/nvm-sh/nvm))
- **Package manager**: $(echo "$m" | jq -r '.commands.package_manager // "npm"')"
      ;;
    python)
      prerequisites="- **Python** ${py_ver}+: \`python --version\` (install via [pyenv](https://github.com/pyenv/pyenv))
- **Package manager**: $(echo "$m" | jq -r '.commands.package_manager // "pip"')"
      ;;
    rust)
      prerequisites="- **Rust** (stable): \`rustc --version\` (install via [rustup](https://rustup.rs/))"
      ;;
    go)
      prerequisites="- **Go** 1.21+: \`go version\` (install via [official site](https://go.dev/dl/))"
      ;;
    *)
      prerequisites="- Check project configuration for required tools"
      ;;
  esac

  if ! preserve_doc "$TARGET_DIR/SETUP-DEV.md"; then
    true  # skip — preserved
  else
    cat > "$TARGET_DIR/SETUP-DEV.md" << SETUPMD
# Developer Setup — ${name}

## Prerequisites

${prerequisites}

## Setup Steps

### Step 1: Clone
\`\`\`bash
git clone ${gh_url}
cd ${name}
\`\`\`

### Step 2: Install dependencies
\`\`\`bash
${install}
\`\`\`

### Step 3: Activate git hooks
\`\`\`bash
git config core.hooksPath .githooks
\`\`\`

### Step 4: Environment variables
\`\`\`bash
cp .env.example .env
# Edit .env with your values — ask team lead for credentials
\`\`\`

### Step 5: Verify everything works
\`\`\`bash
$([ "$lint" != "NOT_CONFIGURED" ] && echo "$lint" || true)
$([ "$test_cmd" != "NOT_CONFIGURED" ] && echo "$test_cmd" || true)
$([ "$build" != "NOT_CONFIGURED" ] && echo "$build" || true)
\`\`\`

### Step 6: Install Claude Code
\`\`\`bash
npm install -g @anthropic-ai/claude-code
\`\`\`

### Step 7: Install gstack (optional)
\`\`\`bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup --no-prefix
\`\`\`

### Step 8: Read key docs
| Order | File | Time |
|:-----:|------|:----:|
| 1 | \`CLAUDE.md\` | 10 min |
| 2 | \`docs/README.md\` | 2 min |
SETUPMD

    log_ok "Created SETUP-DEV.md"
  fi

  # --- CONTRIBUTING.md ---
  if ! preserve_doc "$TARGET_DIR/CONTRIBUTING.md"; then
    true  # skip — preserved
  else
    cat > "$TARGET_DIR/CONTRIBUTING.md" << CONTRIBMD
# Contributing to ${name}

## Branch Naming
- \`feat/description\` — new feature
- \`fix/description\` — bug fix
- \`refactor/description\` — code restructuring
- \`chore/description\` — maintenance
- \`docs/description\` — documentation only

## Commit Messages (Conventional Commits)
- \`feat: add user authentication\`
- \`fix: resolve timeout on large requests\`
- \`refactor: extract calculation to separate module\`

## Pull Request Process
1. Branch from \`main\`
2. Run lint + test + build locally (pre-push hook enforces this)
3. Create PR with description: What, Why, How, Testing
4. Wait for CI to pass
5. Request review

## Code Style
CONTRIBMD

    # Language-aware code style and testing sections
    if [[ "$lint" != "NOT_CONFIGURED" ]]; then
      echo "- Linter: \`${lint}\`" >> "$TARGET_DIR/CONTRIBUTING.md"
    else
      echo "- Enforced by linter: $(echo "$m" | jq -r '.quality.linter.tool // "not configured"')" >> "$TARGET_DIR/CONTRIBUTING.md"
    fi
    if [[ "$format_cmd" != "NOT_CONFIGURED" ]]; then
      echo "- Formatter: \`${format_cmd}\`" >> "$TARGET_DIR/CONTRIBUTING.md"
    else
      echo "- Formatted by: $(echo "$m" | jq -r '.quality.formatter.tool // "not configured"')" >> "$TARGET_DIR/CONTRIBUTING.md"
    fi

    echo "" >> "$TARGET_DIR/CONTRIBUTING.md"
    echo "## Testing" >> "$TARGET_DIR/CONTRIBUTING.md"

    if [[ "$test_cmd" != "NOT_CONFIGURED" ]]; then
      echo "- Framework: $(echo "$m" | jq -r '.quality.test_framework.tool // "not configured"')" >> "$TARGET_DIR/CONTRIBUTING.md"
      echo "- Run: \`${test_cmd}\`" >> "$TARGET_DIR/CONTRIBUTING.md"
      echo "- Write tests for all new functionality" >> "$TARGET_DIR/CONTRIBUTING.md"
    else
      local typecheck_cmd_val
      typecheck_cmd_val=$(echo "$m" | jq -r '.commands.typecheck // "NOT_CONFIGURED"')
      echo "" >> "$TARGET_DIR/CONTRIBUTING.md"
      echo "No test framework is configured yet. Testing is done via:" >> "$TARGET_DIR/CONTRIBUTING.md"
      echo "" >> "$TARGET_DIR/CONTRIBUTING.md"
      if [[ "$typecheck_cmd_val" != "NOT_CONFIGURED" ]]; then
        echo "1. **Syntax check**: \`${typecheck_cmd_val}\`" >> "$TARGET_DIR/CONTRIBUTING.md"
      fi
      if [[ "$lint" != "NOT_CONFIGURED" ]]; then
        echo "2. **Lint**: \`${lint}\`" >> "$TARGET_DIR/CONTRIBUTING.md"
      fi
      echo "3. **CI**: GitHub Actions runs quality checks on all PRs" >> "$TARGET_DIR/CONTRIBUTING.md"
    fi

    log_ok "Created CONTRIBUTING.md"
  fi

  # --- docs/LESSONS_LEARNED.md ---
  local lessons_file="$TARGET_DIR/docs/LESSONS_LEARNED.md"
  if ! preserve_doc "$lessons_file"; then
    cat > "$lessons_file" << 'LESSONSMD'
# Lessons Learned

> Hard-won operational patterns. Criteria for inclusion:
> (a) broadly reusable across many tasks, (b) easy to violate without a reminder,
> (c) costly when forgotten, (d) not already in CLAUDE.md Invariants.

## Common Mistakes

*Add recurring agent mistakes here as they're discovered. Examples:*
*- Editing the wrong config file (staging vs production)*
*- Forgetting to update the sidebar after adding a page*
*- Not running the full test suite before marking done*

## Operational Patterns

*Add patterns that emerge from repeated sessions. Use `/aif-learn` to capture.*
LESSONSMD
    log_ok "Created docs/LESSONS_LEARNED.md"
  fi
}
