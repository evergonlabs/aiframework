# Adding a Domain

How to add a new domain detection to aiframework.

## What is a Domain?

Domains represent application concerns like "authentication", "payments", "search", or "caching". When aiframework detects a domain, it generates domain-specific review checklists and CLAUDE.md guidance.

## Step 1: Add to the Registry

Edit `lib/data/domains.json` and add your domain entry:

```json
{
  "name": "your-domain",
  "display": "Your Domain",
  "signals": {
    "files": ["**/your-pattern/**", "src/your-domain/**"],
    "dependencies": ["your-lib", "another-lib"],
    "keywords": ["your_keyword"]
  }
}
```

Fields:
- **name**: Machine-readable identifier (kebab-case)
- **display**: Human-readable name shown in CLAUDE.md
- **signals.files**: Glob patterns that indicate this domain
- **signals.dependencies**: Package names in package.json, pyproject.toml, etc.
- **signals.keywords**: Code patterns to grep for

## Step 2: Create a Review Specialist

Create `tools/review-specialists/your-domain.md`:

```markdown
# Your Domain Review Checklist

- [ ] Check 1: Description of what to verify
- [ ] Check 2: Another verification point
- [ ] Check 3: Security consideration
```

The review specialist is loaded by the `/aif-review` skill when files matching the domain's trigger paths are changed.

## Step 3: Test

Run aiframework against a project that uses your domain:

```bash
./bin/aiframework discover --target /path/to/project-with-domain --verbose
```

Check the manifest output:
```bash
jq '.domain.detected_domains' .aiframework/manifest.json
```

Your domain should appear in the list. Then run the full pipeline:

```bash
./bin/aiframework run --target /path/to/project --non-interactive
```

Verify:
- The domain appears in the generated CLAUDE.md under "Domains"
- The review specialist is copied to the target project
- The doc-sync matrix references your domain's key files

## How Detection Works

The domain scanner (`lib/scanners/domain.sh`) reads `lib/data/domains.json` at runtime. For each domain:

1. Check if any signal files exist (glob match)
2. Check if any signal dependencies appear in the project's dependency manifest
3. Check if any signal keywords appear in source files
4. If any signal matches, the domain is detected

No code changes needed — just edit the JSON registry.
