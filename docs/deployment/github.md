# GitHub Setup

GitHub serves as the source of truth for the Jasfo Lead Intelligence Platform codebase, hosting the monorepo, orchestrating CI/CD pipelines via GitHub Actions, managing encrypted secrets for environment-specific configuration, and enforcing branch protection rules. The repository follows a structured branching strategy aligned with the platform's staging and production environments.

## Repository Structure

The monorepo contains all application code, infrastructure definitions, and documentation organized into a flat directory structure:

```
jasfo-lead-intelligence/
  src/
    api/           — FastAPI application source
    workers/       — Background task processors
    scoring/       — Scoring engine and prompt templates
    database/      — Database access layer and models
    utils/         — Shared utilities and helpers
  supabase/
    migrations/    — Database migration files
    seed/          — Seed data for development
    functions/     — Supabase Edge Functions
  tests/
    unit/          — Unit test suite
    integration/   — Integration test suite
    prompts/       — Prompt evaluation tests
  docs/            — Documentation
    deployment/
    testing/
    roadmap/
    architecture/
  .github/
    workflows/     — GitHub Actions workflow definitions
    CODEOWNERS     — Code ownership assignments
  Dockerfile       — Production container definition
  docker-compose.yml  — Local development environment
  Makefile         — Common task automation
  pyproject.toml   — Python project configuration
  requirements.txt — Python dependencies
```

## Branch Strategy

```mermaid
gitGraph
    commit id: "initial"
    branch develop
    commit id: "feature start"
    branch feature/scoring-engine
    commit id: "WIP scoring"
    commit id: "tests added"
    checkout develop
    merge feature/scoring-engine id: "PR #42"
    branch staging
    commit id: "staging deploy"
    checkout main
    merge staging id: "release v1.2"
    commit id: "tag v1.2"
```

The repository uses a three-tier branch strategy:

| Branch | Purpose | Protection |
|---|---|---|
| `main` | Production-ready code; deploys to Railway production | Requires PR review; status checks pass; no direct pushes |
| `staging` | Pre-production validation; deploys to Railway staging | Requires PR review; status checks pass |
| `feature/*` | Feature development branches | None; ephemeral |

**Workflow**: Developers create feature branches from `develop` (or `main` for hotfixes). Once the feature is complete and tests pass, a pull request is opened against the parent branch. After review and CI passing, the PR is squash-merged. The `main` branch is periodically merged into `staging` for pre-release validation, and `staging` is merged into `main` for production releases.

## GitHub Actions CI/CD

Three primary workflows automate the platform's build, test, and deployment lifecycle:

### 1. Pull Request Validation (`pr-validation.yml`)

Triggers on all PRs against `main` and `staging`. Validates code quality and functionality:

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install ruff
      - run: ruff check src/ tests/

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
    steps:
      - uses: actions/checkout@v4
      - run: pip install -r requirements-dev.txt
      - run: pytest tests/unit/
      - run: pytest tests/integration/ --db-url postgresql://postgres:test@localhost:5432/postgres
```

### 2. Staging Deployment (`deploy-staging.yml`)

Triggers on merge to `staging`. Deploys to the Railway staging environment after running the full test suite:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
      - run: supabase link --project-ref ${{ secrets.SUPABASE_STAGING_REF }}
      - run: supabase db push --linked
      - uses: railway/cli-action@v1
        with:
          railwayToken: ${{ secrets.RAILWAY_STAGING_TOKEN }}
      - run: railway up --service jasfo-api
      - run: railway run --service jasfo-worker "python -m src.workers.validate"
```

### 3. Production Deployment (`deploy-production.yml`)

Triggers on merge to `main`. Deploys to production after validation on staging:

```yaml
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Manual approval gate — deployment pending"
        # Production deployment requires manual approval via GitHub Environments

  deploy:
    needs: validate
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - run: supabase db push --linked
      - uses: railway/cli-action@v1
        with:
          railwayToken: ${{ secrets.RAILWAY_PRODUCTION_TOKEN }}
      - run: railway up --service jasfo-api
      - run: railway up --service jasfo-worker
      - run: railway run --service jasfo-cron "python -m src.cron.validate_run"
```

## Secret Management

All sensitive configuration values are stored as GitHub Encrypted Secrets, organized by environment:

| Secret Name | Environment | Purpose |
|---|---|---|
| `SUPABASE_PRODUCTION_URL` | Production | Production database connection |
| `SUPABASE_STAGING_URL` | Staging | Staging database connection |
| `RAILWAY_PRODUCTION_TOKEN` | Production | Railway deploy token |
| `FIRECRAWL_API_KEY` | Both | Web scraping API key |
| `OPENAI_API_KEY` | Both | OpenAI API access |
| `TELEGRAM_BOT_TOKEN` | Both | Notification bot token |

Secrets are referenced in workflows via `${{ secrets.SECRET_NAME }}`. Repository admins manage secrets through the GitHub UI under Settings > Secrets and variables > Actions. No secrets are ever committed to the repository or exposed in build logs.

## Branch Protection Rules

The `main` branch enforces the following protection rules:

- **Require pull request review** — at least one approved review before merging
- **Dismiss stale reviews** — when new commits are pushed
- **Require status checks** — all CI checks must pass (lint, test, build)
- **Require branches to be up to date** — before merging
- **Do not allow bypassing** — above settings apply even to admins
- **Restrict deletions** — protected branches cannot be deleted

## Release Tagging

Releases follow semantic versioning with tags created by the deployment workflow:

```
v1.0.0    — Initial production release
v1.1.0    — Added 8-pillar scoring
v1.2.0    — Telegram notifications
v1.2.1    — Hotfix: scoring timeout bug
```

Tags are created automatically during the production deployment workflow and pushed to the repository. Release notes are generated from the commit log using `git log --oneline <previous-tag>..HEAD`.
