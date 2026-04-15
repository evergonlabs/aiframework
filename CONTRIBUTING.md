# Contributing to aiframework

## Branch Naming
- `feat/description` — new feature
- `fix/description` — bug fix
- `refactor/description` — code restructuring
- `chore/description` — maintenance
- `docs/description` — documentation only

## Commit Messages (Conventional Commits)
- `feat: add user authentication`
- `fix: resolve timeout on large requests`
- `refactor: extract calculation to separate module`

## Pull Request Process
1. Branch from `main`
2. Run lint + test + build locally (pre-push hook enforces this)
3. Create PR with description: What, Why, How, Testing
4. Wait for CI to pass
5. Request review

## Code Style
- Linter: `find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs shellcheck`
- Formatted by: not configured

## Testing

No test framework is configured yet. Testing is done via:

1. **Syntax check**: `find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs bash -n`
2. **Lint**: `find . -name '*.sh' -not -path '*/.git/*' -not -path '*/vault/*' | xargs shellcheck`
3. **CI**: GitHub Actions runs quality checks on all PRs
