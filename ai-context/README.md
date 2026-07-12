# AI Context Pack

> **What this is:** A dense set of markdown files optimized for AI coding agent context windows. Each file covers one aspect of the Jasfo platform. AI agents should read relevant files before implementing, debugging, or modifying the platform.

## How to Use

1. **New to the project?** Start with `project-summary.md` + `architecture-summary.md` + `folder-structure.md`.
2. **Writing code?** Read `coding-rules.md` + `coding-checklist.md` + `database-summary.md`.
3. **Writing SQL?** Read `database-summary.md` + check `sql/schema.sql` for exact column definitions.
4. **Modifying agents?** Read `agent-summary.md` + `prompt-summary.md`.
5. **Integrating APIs?** Read `api-summary.md`.
6. **Planning implementation?** Read `implementation-guide.md`.

## File Index

| File | Purpose | When to Read |
|------|---------|--------------|
| `project-summary.md` | What Jasfo does, tech stack, status | First time, context refresh |
| `architecture-summary.md` | 14-layer pipeline, data flow, key decisions | Before any architectural work |
| `coding-rules.md` | Mandatory rules: verify, don't hallucinate, test first | Before writing ANY code |
| `folder-structure.md` | Every directory and key file | Navigation, finding files |
| `database-summary.md` | Tables, relationships, patterns | Writing SQL, queries |
| `api-summary.md` | All external APIs, auth, rate limits | API integrations |
| `agent-summary.md` | All 21 agents, models, costs | Agent development |
| `prompt-summary.md` | Prompt templates, patterns, validation | Prompt engineering |
| `implementation-guide.md` | Build order, dependencies, milestones | Planning work |
| `coding-checklist.md` | Pre-commit verification | Before every commit |

## Conventions

- All monetary values: **USD cents** in DB, **USD dollars** in reports.
- All timestamps: **ISO 8601 UTC** (`timestamptz`).
- All scores: **0-100 integer** per pillar, **0-800** total.
- All JSONB arrays: **lowercase snake_case** keys.
- All SQL: **IF NOT EXISTS**, idempotent, no destructive operations.
