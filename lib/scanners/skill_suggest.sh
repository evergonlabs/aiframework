#!/usr/bin/env bash
# Scanner: Skill Suggestions
# Analyzes the target repo for patterns that could benefit from custom skills.
# Outputs suggestions — never auto-creates skills without user approval.
#
# Security: This scanner only reads local files. No web requests.
# All suggestions are presented in the report for user review.

scan_skill_suggestions() {
  local suggestions="[]"

  # --- Deploy scripts ---
  if [[ -f "$TARGET_DIR/deploy.sh" || -f "$TARGET_DIR/scripts/deploy.sh" || -f "$TARGET_DIR/bin/deploy" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "deploy",
      "reason": "Deploy script detected",
      "description": "Wrap your deploy script in a skill with pre-deploy checks (lint, test, build) and post-deploy verification",
      "trigger_files": ["deploy.sh", "scripts/deploy.sh", "bin/deploy"]
    }]')
  fi

  # --- Database migrations ---
  if [[ -d "$TARGET_DIR/migrations" || -d "$TARGET_DIR/db/migrate" || -d "$TARGET_DIR/prisma/migrations" || -d "$TARGET_DIR/alembic" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "migrate",
      "reason": "Database migrations detected",
      "description": "Create a migration skill that runs migrations safely with rollback verification",
      "trigger_files": ["migrations/", "db/migrate/", "prisma/migrations/", "alembic/"]
    }]')
  fi

  # --- Seed / fixture data ---
  if [[ -f "$TARGET_DIR/prisma/seed.ts" || -f "$TARGET_DIR/db/seeds.rb" || -d "$TARGET_DIR/fixtures" || -f "$TARGET_DIR/seed.py" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "seed",
      "reason": "Database seed/fixture files detected",
      "description": "Create a seed skill that populates test data safely without affecting production",
      "trigger_files": ["prisma/seed.ts", "db/seeds.rb", "fixtures/", "seed.py"]
    }]')
  fi

  # --- Docker / container orchestration ---
  if [[ -f "$TARGET_DIR/docker-compose.yml" || -f "$TARGET_DIR/compose.yml" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "infra",
      "reason": "Docker Compose detected",
      "description": "Create an infra skill that starts/stops local services, checks health, and resets state",
      "trigger_files": ["docker-compose.yml", "compose.yml"]
    }]')
  fi

  # --- API documentation generation ---
  if [[ -f "$TARGET_DIR/openapi.yaml" || -f "$TARGET_DIR/openapi.json" || -f "$TARGET_DIR/swagger.json" || -f "$TARGET_DIR/swagger.yaml" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "api-docs",
      "reason": "OpenAPI/Swagger spec detected",
      "description": "Create an API docs skill that validates the spec, generates client SDKs, and checks endpoint coverage",
      "trigger_files": ["openapi.yaml", "openapi.json", "swagger.json"]
    }]')
  fi

  # --- Storybook / component docs ---
  if [[ -d "$TARGET_DIR/.storybook" || -f "$TARGET_DIR/.storybook/main.ts" || -f "$TARGET_DIR/.storybook/main.js" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "storybook",
      "reason": "Storybook configuration detected",
      "description": "Create a storybook skill that builds stories, checks for missing stories on new components, and runs visual regression",
      "trigger_files": [".storybook/"]
    }]')
  fi

  # --- Terraform / Infrastructure as Code ---
  if [[ -d "$TARGET_DIR/terraform" || -f "$TARGET_DIR/main.tf" || -d "$TARGET_DIR/infra" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "plan-infra",
      "reason": "Terraform/IaC files detected",
      "description": "Create an infrastructure planning skill that runs terraform plan, validates changes, and requires approval before apply",
      "trigger_files": ["terraform/", "main.tf", "infra/"]
    }]')
  fi

  # --- Monorepo package management ---
  local is_mono
  is_mono=$(echo "$MANIFEST" | jq -r '.stack.is_monorepo // false' 2>/dev/null)
  if [[ "$is_mono" == "true" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "affected",
      "reason": "Monorepo structure detected",
      "description": "Create a skill that detects affected packages from changes and runs only their tests/builds (like nx affected or turbo)",
      "trigger_files": ["packages/", "apps/", "libs/"]
    }]')
  fi

  # --- E2E / integration test runner ---
  if [[ -d "$TARGET_DIR/e2e" || -d "$TARGET_DIR/cypress" || -d "$TARGET_DIR/playwright" || -f "$TARGET_DIR/playwright.config.ts" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "e2e",
      "reason": "E2E test framework detected",
      "description": "Create an E2E testing skill that runs browser tests, captures screenshots on failure, and reports results",
      "trigger_files": ["e2e/", "cypress/", "playwright/"]
    }]')
  fi

  # --- Documentation site ---
  if [[ -f "$TARGET_DIR/docusaurus.config.js" || -f "$TARGET_DIR/mkdocs.yml" || -f "$TARGET_DIR/docs/.vitepress/config.ts" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "docs-build",
      "reason": "Documentation site generator detected",
      "description": "Create a docs skill that builds the documentation site, checks for broken links, and previews locally",
      "trigger_files": ["docusaurus.config.js", "mkdocs.yml", "docs/.vitepress/"]
    }]')
  fi

  # --- Benchmarks ---
  if [[ -d "$TARGET_DIR/bench" || -d "$TARGET_DIR/benchmarks" || -f "$TARGET_DIR/bench.ts" ]]; then
    suggestions=$(echo "$suggestions" | jq '. + [{
      "name": "benchmark",
      "reason": "Benchmark files detected",
      "description": "Create a benchmark skill that runs performance tests and compares against previous baselines",
      "trigger_files": ["bench/", "benchmarks/"]
    }]')
  fi

  # Store suggestions in manifest
  local suggestion_count
  suggestion_count=$(echo "$suggestions" | jq 'length')

  MANIFEST=$(echo "$MANIFEST" | jq --argjson s "$suggestions" '. + {"skill_suggestions": $s}')

  if [[ "$suggestion_count" -gt 0 ]]; then
    log_ok "Found $suggestion_count skill suggestion(s)"
  fi
}
