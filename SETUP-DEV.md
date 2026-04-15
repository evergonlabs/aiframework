# Developer Setup — aiframework

## Prerequisites

- Check project configuration for required tools

## Setup Steps

### Step 1: Clone
```bash
git clone https://github.com/evergonlabs/aiframework
cd aiframework
```

### Step 2: Install dependencies
```bash
NOT_CONFIGURED
```

### Step 3: Activate git hooks
```bash
git config core.hooksPath .githooks
```

### Step 4: Environment variables
```bash
cp .env.example .env
# Edit .env with your values — ask team lead for credentials
```

### Step 5: Verify everything works
```bash



```

### Step 6: Install Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

### Step 7: Install gstack (optional)
```bash
git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup --no-prefix
```

### Step 8: Read key docs
| Order | File | Time |
|:-----:|------|:----:|
| 1 | `CLAUDE.md` | 10 min |
| 2 | `docs/README.md` | 2 min |
