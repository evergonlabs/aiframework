# Adding a Scanner

How to extend aiframework with a new scanner module.

## Scanner Architecture

Scanners are the first stage of the aiframework pipeline. Each scanner is a standalone bash script in `lib/scanners/` that:

1. Reads files from the target repository (via `$TARGET_DIR`)
2. Extracts structured facts (never guesses or assumes)
3. Appends its findings to the `$MANIFEST` variable as JSON (via `jq`)

Scanners are sourced (not executed) by `bin/aiframework`, which means they share the same shell environment and can read/write the `MANIFEST` variable directly.

### Existing Scanners

| Scanner | File | What It Discovers |
|---------|------|-------------------|
| Identity | `lib/scanners/identity.sh` | Project name, version, description |
| Stack | `lib/scanners/stack.sh` | Language, framework, monorepo detection |
| Commands | `lib/scanners/commands.sh` | Package manager, build/test/lint commands |
| Structure | `lib/scanners/structure.sh` | Directory tree, file counts, entry points |
| CI | `lib/scanners/ci.sh` | CI provider, workflows, deploy targets |
| Env | `lib/scanners/env.sh` | Environment variables from 6 sources |
| Quality | `lib/scanners/quality.sh` | Linters, formatters, type checkers, test frameworks |
| Domain | `lib/scanners/domain.sh` | Domain-specific concerns (auth, DB, API, AI, etc.) |
| User Context | `lib/scanners/user_context.sh` | Interactive questions for human context |
| Code Index | `lib/scanners/code_index.sh` | Files, symbols, imports, dependency graph |
| Archetype | `lib/scanners/archetype.sh` | Repo archetype detection (library, web-app, cli-tool, etc.) |
| Skill Suggest | `lib/scanners/skill_suggest.sh` | Suggests custom skills based on detected repo patterns |

## Creating a New Scanner

### Step 1: Create the Scanner File

Create a new file in `lib/scanners/`. Follow the naming convention: lowercase, descriptive, `.sh` extension.

```bash
#!/usr/bin/env bash
# Scanner: <Your Scanner Name>
# Discovers <what it discovers> from actual files

scan_your_scanner() {
  local some_field=""
  local another_field=""

  # --- Detect something ---
  # Always check if files exist before reading them
  if [[ -f "$TARGET_DIR/some-config.json" ]]; then
    some_field=$(jq -r '.key // empty' "$TARGET_DIR/some-config.json" 2>/dev/null)
  fi

  # --- Detect something else ---
  if [[ -d "$TARGET_DIR/some-directory" ]]; then
    another_field="true"
  fi

  # --- Append to manifest ---
  MANIFEST=$(echo "$MANIFEST" | jq \
    --arg field1 "$some_field" \
    --arg field2 "$another_field" \
    '. + {
      "your_scanner": {
        "some_field": $field1,
        "another_field": ($field2 == "true")
      }
    }')

  # Log what was found (respects --verbose flag)
  if [[ "$VERBOSE" == "true" ]]; then
    log_info "your_scanner: some_field=$some_field another_field=$another_field"
  fi

  log_ok "Your Scanner — detected"
}
```

### Required Function Signature

Every scanner must define exactly one function named `scan_<name>`. The function:

- Takes no arguments (reads from environment variables)
- Reads from `$TARGET_DIR` (the repo being scanned)
- Writes to `$MANIFEST` (the shared JSON accumulator)
- Uses `jq` to merge its output into the manifest
- Must not exit the shell on error (use `|| true` or conditionals)

### Available Environment Variables

These are set by `bin/aiframework` before your scanner runs:

| Variable | Description |
|----------|-------------|
| `$TARGET_DIR` | Absolute path to the repo being scanned |
| `$MANIFEST` | Current manifest JSON (read and write) |
| `$MANIFEST_PATH` | Where manifest.json will be written |
| `$OUTPUT_DIR` | Output directory (default: `$TARGET_DIR/.aiframework`) |
| `$VERBOSE` | `"true"` if `--verbose` flag was passed |
| `$NON_INTERACTIVE` | `"true"` if `--non-interactive` flag was passed |
| `$DRY_RUN` | `"true"` if `--dry-run` flag was passed |

### Available Helper Functions

These are defined in `bin/aiframework` and available to all scanners:

```bash
log_info "message"   # Blue [INFO] prefix
log_ok "message"     # Green [OK] prefix
log_warn "message"   # Yellow [WARN] prefix
log_error "message"  # Red [ERROR] prefix
log_step "message"   # Cyan [STEP] prefix, bold text
```

## Step 2: Add the Manifest Key via jq

Your scanner appends a new top-level key to `$MANIFEST`. Use `jq` for all JSON manipulation:

```bash
# Simple key-value pairs
MANIFEST=$(echo "$MANIFEST" | jq \
  --arg val "$my_value" \
  '. + { "my_scanner": { "detected": $val } }')

# Arrays
MANIFEST=$(echo "$MANIFEST" | jq \
  --argjson items "$json_array" \
  '. + { "my_scanner": { "items": $items } }')

# Booleans (jq requires --argjson for non-string types)
MANIFEST=$(echo "$MANIFEST" | jq \
  --argjson enabled "$( [[ "$found" == "true" ]] && echo true || echo false )" \
  '. + { "my_scanner": { "enabled": $enabled } }')
```

**Rules for manifest data:**

- Every value must come from reading an actual file. Never hardcode assumptions.
- Use `// empty` or `// "unknown"` as jq fallbacks for missing fields.
- Suppress stderr with `2>/dev/null` on all file-reading commands.
- Prefer structured JSON over flat strings.

## Step 3: Register in bin/aiframework

Open `bin/aiframework` and add your scanner in two places.

**Source the file** (with the other scanner sources in `bin/aiframework`):

```bash
source "$LIB_DIR/scanners/your_scanner.sh"
```

**Call the function** in `cmd_discover()` (update the step counter):

```bash
log_step "13/13 Your Scanner"
scan_your_scanner
```

Remember to update the step numbering for all existing steps and add yours as the new last step (there are currently 12 scanners, so a new one would be 13/13).

## Step 4: Test Your Scanner

### Manual Testing

```bash
# Run discovery with verbose output
./bin/aiframework discover --target /path/to/test-repo --verbose

# Check the manifest for your scanner's output
jq '.your_scanner' /path/to/test-repo/.aiframework/manifest.json
```

### Verify Determinism

Run discovery twice on the same repo and diff the results:

```bash
./bin/aiframework discover --target /path/to/repo --non-interactive
cp /path/to/repo/.aiframework/manifest.json /tmp/manifest1.json

./bin/aiframework discover --target /path/to/repo --non-interactive
cp /path/to/repo/.aiframework/manifest.json /tmp/manifest2.json

# Should only differ in _meta.generated_at timestamp
diff <(jq 'del(._meta.generated_at)' /tmp/manifest1.json) \
     <(jq 'del(._meta.generated_at)' /tmp/manifest2.json)
```

### Lint Your Scanner

```bash
shellcheck lib/scanners/your_scanner.sh
bash -n lib/scanners/your_scanner.sh
```

## Step 5: Feed Downstream (Optional)

If you want generators or validators to consume your scanner's data, you will need to update the relevant downstream modules:

| To update... | Edit... |
|-------------|---------|
| CLAUDE.md output | `lib/generators/claude_md.sh` |
| Git hooks | `lib/generators/hooks.sh` |
| CI workflow | `lib/generators/ci.sh` |
| Vault wiki pages | `lib/generators/vault.sh` |
| Verification checks | `lib/validators/` |

Each generator reads from the `$MANIFEST` variable, so accessing your scanner's data is straightforward:

```bash
local my_value
my_value=$(echo "$MANIFEST" | jq -r '.your_scanner.some_field // "default"')
```

## Example: A Minimal Scanner

Here is a complete minimal scanner that detects whether a repo uses Docker:

```bash
#!/usr/bin/env bash
# Scanner: Docker Detection
# Discovers Dockerfile presence and compose configuration

scan_docker() {
  local has_dockerfile="false"
  local has_compose="false"
  local base_image=""

  if [[ -f "$TARGET_DIR/Dockerfile" ]]; then
    has_dockerfile="true"
    base_image=$(grep -m1 '^FROM' "$TARGET_DIR/Dockerfile" | awk '{print $2}' 2>/dev/null || true)
  fi

  if [[ -f "$TARGET_DIR/docker-compose.yml" ]] || [[ -f "$TARGET_DIR/docker-compose.yaml" ]]; then
    has_compose="true"
  fi

  MANIFEST=$(echo "$MANIFEST" | jq \
    --argjson dockerfile "$( [[ "$has_dockerfile" == "true" ]] && echo true || echo false )" \
    --argjson compose "$( [[ "$has_compose" == "true" ]] && echo true || echo false )" \
    --arg base "$base_image" \
    '. + {
      "docker": {
        "has_dockerfile": $dockerfile,
        "has_compose": $compose,
        "base_image": $base
      }
    }')

  log_ok "Docker — dockerfile=$has_dockerfile compose=$has_compose"
}
```
