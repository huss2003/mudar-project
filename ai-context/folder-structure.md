# Folder Structure

```
jasfo-docs/
  .github/                  GitHub Actions workflows and CI/CD
  ai-context/               AI agent context files (this pack)
  assets/                   Static assets: images, logos
  diagrams/                 Source diagram files (Draw.io, Excalidraw)
  docs/                     All MkDocs documentation source
    index.md                Documentation home
    vision/                 Business context, strategy, personas
    architecture/           14-layer pipeline, ADRs, design principles
    ai/                     Model routing, consensus, reflection, judge
    agents/                 All 21 agent specifications
    database/               Schema, tables, functions, views, indexes, RLS, triggers
    lead-engine/            Scoring, memory, cooldown, change detection, states
    evidence/               Engine, verification, explainability, snapshots
    prompts/                System prompts, developer prompts, JSON schemas
    api/                    Firecrawl, Apollo, Hunter, Snov, SMTP, Telegram, Supabase
    scraping/               Firecrawl + Apify strategy, source priority
    make/                   Make.com scenario specs, error handling, scheduling
    exports/                CSV, Excel, PDF, JSON export formats
    deployment/             Railway, Supabase setup, Cloudflare, monitoring
    testing/                Prompt eval, regression, golden datasets
    security/               Auth, data handling
    appendix/               Benchmarks, references
    faq.md
    glossary.md
    getting-started.md
  examples/                 Sample evidence packages, lead reports
  make/                     Make.com scenario JSON exports
  schemas/                  JSON Schema validation files
  scripts/                  Utility scripts (data loaders, validation, DB mgmt)
  sql/                      All SQL files
    schema.sql              Complete database schema (all 18 tables)
    functions.sql           Postgres functions (scoring, change detection, maintenance)
    views.sql               SQL views (v_top_leads, v_weekly_costs, etc.)
    indexes.sql             All indexes (FK, composite, GIN, partial, covering)
    rls.sql                 Row Level Security policies
    seed.sql                Development seed data
  mkdocs.yml                MkDocs configuration
  README.md                 Project overview
  CHANGELOG.md              Versioned changelog
  CONTRIBUTING.md           Contribution guidelines
  LICENSE
  requirements.txt          Python dependencies
```
