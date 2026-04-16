# Adding a Domain

How to add a new domain detection to aiframework.

## What is a Domain?

Domains represent application concerns like "authentication", "payments", "search", or "caching". When aiframework detects a domain, it generates domain-specific review checklists and CLAUDE.md guidance.

## Step 1: Add to the Registry

Edit `lib/data/domains.json` and add your domain entry inside the `"domains"` object. The key is your domain's machine-readable identifier (kebab-case):

```json
{
  "domains": {
    "your-domain": {
      "display": "Your Domain",
      "file_patterns": ["**/your-pattern/**", "src/your-domain/**"],
      "dependency_markers": {
        "python": ["your-python-lib"],
        "typescript": ["your-ts-lib"],
        "javascript": ["your-js-lib"]
      },
      "invariants": [
        {
          "id": "YD-1",
          "rule": "Description of a rule to enforce",
          "severity": "high"
        }
      ],
      "security_concerns": [
        "concern-one",
        "concern-two"
      ]
    }
  }
}
```

Fields:
- **key**: Machine-readable identifier (kebab-case), used as the domain name
- **display**: Human-readable name shown in CLAUDE.md
- **file_patterns**: Glob patterns that indicate this domain
- **dependency_markers**: Per-language maps of package names (supports python, typescript, javascript, ruby, go, rust, java, csharp, php, elixir)
- **invariants**: Array of rule objects with `id`, `rule`, and `severity` (critical/high/medium)
- **security_concerns**: Array of security concern identifiers

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
