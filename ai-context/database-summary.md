# Database Summary

> Supabase PostgreSQL 16. All tables in `public` schema. Single-user design.

## Table Groups

| Prefix | Purpose | Tables |
|--------|---------|--------|
| `companies` | Core company data | `companies`, `profiles`, `mutual_connections`, `posts` |
| `lead_scores` | Scoring history | `lead_scores` |
| `decisions` | Lead lifecycle | `decisions`, `lead_events` |
| `email_drafts` / `linkedin_drafts` | Outreach drafts | `email_drafts`, `linkedin_drafts` |
| `ipcs` | Competitive intel | `ipcs`, `ipc_mandates` |
| `outreach_history` | Outreach audit | `outreach_history` |
| `cost_log` | Cost tracking | `cost_log` |
| `audit_log` | Change audit | `audit_log` |
| `companies_snapshots` | Change detection | `companies_snapshots` |
| `evidence` | Evidence engine | `evidence_claims`, `evidence_sources`, `evidence_snapshots` |

## Key Tables (18 total)

| Table | Est. Rows | Purpose |
|-------|-----------|---------|
| companies | 50,000 | Core company profiles |
| profiles | 50,000 | Extended scraped data per company |
| mutual_connections | 10,000 | Broker's LinkedIn connections to targets |
| posts | 100,000 | Social media posts from targets |
| lead_scores | 200,000 | Per-cycle 8-pillar scoring records |
| decisions | 5,000 | Lead state machine (one per qualified lead) |
| email_drafts | 10,000 | AI-generated email drafts |
| linkedin_drafts | 10,000 | AI-generated LinkedIn messages |
| ipcs | 500 | Institutional Property Consultants (competitors) |
| ipc_mandates | 2,000 | IPC-company mandate relationships |
| outreach_history | 50,000 | All broker outreach attempts |
| cost_log | 500,000 | Per-layer cost tracking |
| audit_log | 1,000,000 | Append-only change log |
| companies_snapshots | 200,000 | Weekly SHA-256 signal snapshots |
| lead_events | 100,000 | Lead state transition events |
| evidence_claims | 500,000 | Factual claims per company |
| evidence_sources | 1,000,000 | Source URLs backing claims |
| evidence_snapshots | 50,000 | Immutable evidence bundles per cycle |

## Key Relationships

- `companies` 1--N `lead_scores` (latest resolved by `DISTINCT ON (company_id) ORDER BY scored_at DESC`)
- `companies` 1--1 `decisions` (at most one active decision per company)
- `decisions` 1--N `lead_events` (state transitions)
- `companies` 1--N `evidence_claims` 1--N `evidence_sources`
- `companies` 1--1 `profiles`
- `companies` 1--N `email_drafts`, `linkedin_drafts`
- `companies` 1--N `companies_snapshots`
- `ipcs` 1--N `ipc_mandates` N--1 `companies`

## Naming Conventions

- Tables: snake_case plural
- Columns: snake_case singular
- Booleans: `is_` prefix
- Timestamps: `_at` suffix
- PKs: `id uuid DEFAULT gen_random_uuid()`
- FKs: match referenced PK name (e.g., `company_id`)
- Scores: integer 0-100 per pillar, 0-800 total
- JSONB: lowercase snake_case keys, DEFAULT '[]' for arrays, '{}' for objects

## Scoring Model (8 Pillars)

| Pillar | Type | Range | Description |
|--------|------|-------|-------------|
| growth_score | Leading | 0-100 | Headcount + revenue trajectory |
| space_need_score | Leading | 0-100 | Lease expiration, office listings |
| financial_health_score | Lagging | 0-100 | Funding, profitability |
| industry_trend_score | Lagging | 0-100 | Sector tailwinds |
| decision_maker_access_score | Leading | 0-100 | Contact findability |
| digital_footprint_score | Lagging | 0-100 | Website + social activity |
| funding_activity_score | Leading | 0-100 | Recent funding rounds |
| regulatory_exposure_score | Lagging | 0-100 | Compliance-driven moves |
| **total_score** | — | **0-800** | Sum of all 8 pillars |

## Lead States

`new` -> `qualified` -> `contacted` -> `meeting_booked` -> `deal` / `lost`
`qualified` -> `dormant` (90d no action) -> `archived` (365d no change)

## Index Strategy

- FK indexes on every foreign key
- Composite: `(state, priority_band)`, `(company_id, scored_at DESC)`, `(cooldown_until DESC NULLS LAST, state)`
- GIN: full-text search on companies (name + industry + description)
- Partial: active decisions, unverified claims, recent snapshots
- Covering: lead_scores for v_top_leads query
