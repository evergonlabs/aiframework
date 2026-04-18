# Getting Started with aiframework

A step-by-step tutorial for first-time users.

## Prerequisites

Before you begin, make sure you have the following installed:

| Tool | Minimum Version | Check Command | Purpose |
|------|----------------|---------------|---------|
| `bash` | 3.2+ (4.0+ recommended) | `bash --version` | Core runtime (all scanners and generators are bash) |
| `jq` | 1.6+ | `jq --version` | JSON processing for manifest creation and reading |
| `git` | 2.0+ | `git --version` | Repo analysis (branch, remote, log parsing) |
| `python3` | 3.10+ | `python3 --version` | Code indexer (symbol extraction, dependency graphing) |

> **Why Python 3.10+?** The code indexer uses `match/case` syntax introduced in Python 3.10. All versions 3.10 through 3.13+ are supported.

**Optional but recommended:**

| Tool | Purpose | Install |
|------|---------|---------|
| `shellcheck` | Lints generated shell hooks and CI scripts | `brew install shellcheck` / `apt install shellcheck` |
| `node` / `npm` | Runtime session intelligence (sheal) | `brew install node` / `apt install nodejs` |

### Installing dependencies by platform

<details>
<summary><b>macOS</b></summary>

```bash
# All at once via Homebrew
brew install bash jq python@3.12 shellcheck

# Verify
bash --version && jq --version && python3 --version && git --version
```

macOS ships with bash 3.2 and git. The installer checks these automatically.

</details>

<details>
<summary><b>Linux (Ubuntu/Debian)</b></summary>

```bash
sudo apt update && sudo apt install -y bash jq python3 git shellcheck

# Verify
bash --version && jq --version && python3 --version && git --version
```

</details>

<details>
<summary><b>Linux (Fedora/RHEL)</b></summary>

```bash
sudo dnf install -y bash jq python3 git ShellCheck
```

</details>

<details>
<summary><b>Windows (Git Bash / MSYS2)</b></summary>

1. Install [Git for Windows](https://git-scm.com/download/win) (includes bash and git)
2. Install [Python 3.12+](https://python.org/downloads/) (check "Add to PATH" during install)
3. Install jq: `choco install jq` or `scoop install jq` or [download manually](https://jqlang.github.io/jq/download/)

```bash
# Verify (in Git Bash)
bash --version && jq --version && python --version && git --version
```

> **Note:** On Windows, `python` (not `python3`) is detected automatically by the installer.

</details>

<details>
<summary><b>WSL (Windows Subsystem for Linux)</b></summary>

WSL is auto-detected and treated as Linux. Follow the Ubuntu/Debian instructions above.

</details>

## Installation

**Recommended: one-line install** (works on macOS, Linux, WSL, Windows Git Bash):

```bash
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh
```

The installer will:
1. Detect your platform (macOS / Linux / WSL / Windows)
2. Check all dependencies and tell you exactly what's missing
3. Clone aiframework to `~/.aiframework-src/`
4. Create symlinks (or copies on Windows) in `~/.local/bin/`
5. Add `~/.local/bin` to your PATH if needed
6. Optionally install sheal via npm

**Alternative install methods:**

```bash
# Homebrew (macOS/Linux)
brew tap evergonlabs/tap && brew install aiframework

# Manual (any platform)
git clone https://github.com/evergonlabs/aiframework.git && cd aiframework && make install

# From release tarball (replace VERSION with latest from Releases page)
VERSION=$(curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/VERSION | tr -d '[:space:]')
curl -LO "https://github.com/evergonlabs/aiframework/releases/download/v${VERSION}/aiframework-${VERSION}.tar.gz"
tar xzf "aiframework-${VERSION}.tar.gz" && cd aiframework && make install
```

**Verify it works:**

```bash
aiframework --version    # prints the installed version
aiframework --help       # show all commands
```

There is no build step. aiframework is a set of bash scripts that run directly.

## Running on Your First Repo

Point aiframework at any git repository and run the full pipeline:

```bash
# Full pipeline: discover + generate + verify
./bin/aiframework run --target /path/to/your-project
```

This runs three stages in sequence:

1. **Discover** -- scans the repo, produces `.aiframework/manifest.json`
2. **Generate** -- reads manifest, writes CLAUDE.md + vault + hooks + CI + docs
3. **Verify** -- runs 46+ checks to ensure generated files are consistent

Then run `/aif-ready` in Claude Code to enhance with framework-specific knowledge -- no API key needed.

You will see a confirmation prompt after discovery showing what was detected:

```
Analysis Summary
  Project: my-app
  Language: typescript
  Framework: next
  Domains: 3
  ...
Proceed with generation? [Y/n]
```

### Running Individual Steps

You can also run stages independently:

```bash
# Discover only (produces manifest.json)
./bin/aiframework discover --target /path/to/your-project

# Generate only (requires existing manifest)
./bin/aiframework generate --manifest /path/to/your-project/.aiframework/manifest.json

# Verify only
./bin/aiframework verify --target /path/to/your-project

# Index only (produces code-index.json without full discovery)
./bin/aiframework index --target /path/to/your-project
```

### Useful Flags

```bash
# Skip the interactive user-context questions
./bin/aiframework run --target /path/to/project --non-interactive

# Skip code indexing (faster, but no symbol data in vault)
./bin/aiframework run --target /path/to/project --no-index

# See detailed scanner output
./bin/aiframework run --target /path/to/project --verbose
```

## Understanding the Output

After a successful run, your target repo will contain these new files:

### Core Files

| File | What It Does |
|------|-------------|
| `CLAUDE.md` | The primary source of truth for Claude Code. Contains project identity, commands, invariants, pipeline stages, and skill routing. |
| `.aiframework/manifest.json` | Raw scan results. Every value comes from reading actual files -- nothing invented. |
| `.aiframework/code-index.json` | Structured code index: files, symbols, imports, dependency edges, module groupings. |

### Git Hooks

| File | What It Does |
|------|-------------|
| `.githooks/pre-commit` | Runs type checking or linting before each commit. |
| `.githooks/pre-push` | Full quality gate: lint + test + build + invariant checks. |

### CI / CD

| File | What It Does |
|------|-------------|
| `.github/workflows/ci.yml` | GitHub Actions workflow tailored to your detected language and framework. |

### Skills and Review

| File | What It Does |
|------|-------------|
| `.claude/skills/<project>-review/SKILL.md` | Project-specific code review skill for Claude Code. |
| `.claude/skills/<project>-ship/SKILL.md` | Shipping workflow skill (verify, review, docs, changelog, commit). |
| `tools/review-specialists/*.md` | Domain-specific review checklists (database, auth, API, AI, etc.). |
| `tools/learnings/<project>-learnings.jsonl` | Structured storage for session learnings. |

### Documentation

| File | What It Does |
|------|-------------|
| `docs/` | Diataxis documentation scaffold (tutorials, guides, reference, explanation, decisions). |
| `CHANGELOG.md` | Release changelog in Keep a Changelog format. |
| `VERSION` | Semantic version file. |
| `STATUS.md` | Sprint tracker for multi-phase work. |
| `SETUP-DEV.md` | Developer onboarding guide (8 steps). |
| `CONTRIBUTING.md` | Contributor guidelines. |

### Knowledge Vault

| Directory | What It Does |
|-----------|-------------|
| `vault/raw/` | Immutable source documents (human-owned). |
| `vault/wiki/` | Agent-generated knowledge: concepts, entities, module pages. |
| `vault/memory/` | Operational state: decisions, notes, session status. |
| `vault/.vault/` | Vault infrastructure: rules, schemas, scripts, hooks. |

### Understanding the Generated `.claude/` Directory

After generation, your project will have:

```
.claude/
├── rules/
│   ├── workflow.md    # Development process rules (always loaded)
│   ├── testing.md     # Testing conventions (loaded for test files)
│   └── security.md    # Security rules (loaded for auth/api files)
├── settings.json      # Permissions (Read, Glob, Grep, WebSearch pre-approved)
└── skills/
    ├── <project>-review/SKILL.md  # Code review with invariant checks
    └── <project>-ship/SKILL.md    # Shipping workflow
```

Claude Code automatically reads these files:
- **`rules/`**: Loaded based on file path matching (path-scoped)
- **`settings.json`**: Enforced permissions and hooks
- **`skills/`**: Available via `/skill-name` slash commands

## Next Steps

1. **Open your project in Claude Code.** It will automatically read the generated `CLAUDE.md` and have full project context.

2. **Customize CLAUDE.md.** The generated file is a starting point. Add project-specific invariants, env vars, and workflow notes as you work.

3. **Enhance with Claude Code.** Run `/aif-ready` in Claude Code to research your stack and fill gaps that heuristic scanning cannot catch -- no API key needed. Use `/aif-enhance` for targeted deep-dives after that.

4. **Use the vault.** Drop source documents in `vault/raw/`, then use Claude Code to process them into wiki pages. Run `vault/.vault/scripts/vault-tools.sh doctor` to check vault health.

5. **Extend with custom scanners.** See the [Adding a Scanner](../guides/adding-a-scanner.md) guide.

## Updating

```bash
aiframework update
```

This auto-detects how you installed (git clone, Homebrew, or tarball) and updates accordingly. It also refreshes all your bootstrapped projects.

## Uninstalling

```bash
# If installed via curl|sh or manual
curl -fsSL https://raw.githubusercontent.com/evergonlabs/aiframework/main/install.sh | sh -s -- --uninstall

# If installed via Homebrew
brew uninstall aiframework && brew untap evergonlabs/tap

# If installed via make
cd ~/aiframework && make uninstall
```

## Troubleshooting

### `jq: command not found`

aiframework requires `jq` for all JSON processing. Install it:

| Platform | Command |
|:---------|:--------|
| macOS | `brew install jq` |
| Ubuntu/Debian | `sudo apt install jq` |
| Fedora/RHEL | `sudo dnf install jq` |
| Windows | `choco install jq` or `scoop install jq` |

### `shellcheck: command not found`

ShellCheck is optional but recommended. Without it, the generated pre-push hook will skip shell linting.

| Platform | Command |
|:---------|:--------|
| macOS | `brew install shellcheck` |
| Ubuntu/Debian | `sudo apt install shellcheck` |
| Fedora/RHEL | `sudo dnf install ShellCheck` |

The tool gracefully degrades -- if ShellCheck is missing, hooks detect this and skip the lint step rather than failing.

### `python3: command not found` or wrong version

Python 3.10+ is required for the code indexer. If unavailable, use `--no-index` to skip indexing:

```bash
aiframework run --target /path/to/project --no-index
```

To install Python:

| Platform | Command |
|:---------|:--------|
| macOS | `brew install python@3.12` |
| Ubuntu/Debian | `sudo apt install python3` |
| Fedora/RHEL | `sudo dnf install python3` |
| Windows | Download from [python.org](https://python.org/downloads/) (check "Add to PATH") |

> **Windows users:** The installer detects `python` (not `python3`) automatically. Both work.

### `Target directory does not exist`

Make sure you pass an absolute path or a path relative to your current working directory:

```bash
# Absolute path (preferred)
aiframework run --target /Users/me/projects/my-app

# Relative path
aiframework run --target ../my-app

# Windows (Git Bash)
aiframework run --target /c/Users/me/projects/my-app
```

### Manifest is empty or missing fields

This usually means `jq` failed silently. Run with `--verbose` to see detailed scanner output:

```bash
aiframework discover --target /path/to/project --verbose
```

### Verification fails after generation

Run `aiframework verify --target /path/to/project` to see which checks failed. Common causes:

- A hook references a command that does not exist on your system.
- CI workflow references a language/framework that the scanner detected incorrectly.
- A generated file was manually edited and now drifts from the manifest.

Re-running `discover` + `generate` will regenerate files from the current repo state.

### Symlinks don't work on Windows

Windows requires admin privileges to create symlinks. The installer detects this and copies files instead. The trade-off: after `aiframework update`, you need to re-run the installer to refresh the copies (unlike symlinks which auto-resolve).
