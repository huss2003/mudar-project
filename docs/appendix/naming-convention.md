# Appendix: Naming Conventions

> Consistent naming across the stack prevents bugs, reduces cognitive load, and enables reliable code generation by AI agents. These conventions are mandatory for all contributors, including AI coding agents.

---

## Database Tables

All table names use **snake_case plural** nouns. A table represents a collection of entities, so the name must be plural. Examples: `companies`, `profiles`, `lead_scores`, `evidence_claims`, `evidence_sources`, `decisions`, `lead_events`, `email_drafts`, `linkedin_drafts`, `ipcs`, `ipc_mandates`, `outreach_history`, `cost_log`, `audit_log`, `companies_snapshots`. Join tables combine both plural table names: `ipc_mandates` (not `ipc_mandate`). Tables that store historical or snapshot data use the base table name plus a plural descriptor: `companies_snapshots`, `lead_events`. System tables (log, audit) use singular: `cost_log`, `audit_log` — because they represent a single log concept even though they store many rows. Every table has an `id` column as `uuid DEFAULT gen_random_uuid()` primary key.

---

## Database Columns

All column names use **snake_case singular**. Boolean columns use the `is_` prefix: `is_verified`, `is_watchlisted`, `is_catch_all`, `is_active`. Timestamp columns use the `_at` suffix: `created_at`, `updated_at`, `scored_at`, `cooldown_until`. Date-only columns use the `_date` suffix: `founded_date`, `last_active_date`. Foreign key columns match the referenced table's primary key name: `company_id` references `companies.id`, `decision_id` references `decisions.id`. JSONB columns use lowercase snake_case keys internally. Score columns are integers (`total_score integer`), confidence values are decimals (`confidence numeric(4,3)`). Enum-like string columns use valid values from application-level constants documented in the schema files.

---

## Database Functions

All custom PostgreSQL functions use **snake_case** with a **verb_noun** pattern. Functions that get data start with `get_`: `get_top_leads`, `get_company_scores`, `get_pending_decisions`. Functions that create data start with `insert_` or `create_`: `create_decision`, `insert_evidence_claim`. Functions that update start with `update_`: `update_cooldown_state`, `update_lead_score`. Functions that delete start with `delete_` or `archive_`: `archive_stale_leads`. Utility functions describe their action: `calculate_weighted_score`, `detect_significant_change`. All functions are idempotent — created with `CREATE OR REPLACE FUNCTION` — and include a comment documenting their purpose, parameters, and return type.

---

## Database Views

All views use the **`v_` prefix** followed by a descriptive snake_case name. The prefix distinguishes views from tables in `\d` listings and SQL queries. Examples: `v_top_leads`, `v_active_decisions`, `v_company_summary`, `v_pipeline_stats`, `v_recent_scores`, `v_broker_worklist`. Views that join multiple tables describe the combination: `v_company_with_scores`, `v_lead_with_events`. Views used for export or reporting use the `v_report_` prefix: `v_report_weekly_leads`, `v_report_cost_summary`. Views are created with `CREATE OR REPLACE VIEW` and include a column list comment for documentation.

---

## API Endpoints

All REST API endpoints follow the pattern **`/{resource}`** for collections and **`/{resource}/{id}`** for individual resources. Resources use plural kebab-case: `/api/companies`, `/api/lead-scores`, `/api/evidence-claims`, `/api/decisions`. Query parameters use camelCase: `?companyId=uuid&scoredAfter=ISO8601`. Pagination uses `offset` and `limit` as query parameters. Responses follow a consistent envelope: `{ "data": [...], "total": integer, "offset": integer, "limit": integer }`. Error responses use `{ "error": { "code": string, "message": string, "details": object? } }`. The API base path is `/api/v1` with versioning in the URL. Endpoints that trigger pipeline operations use verbs: `/api/v1/pipeline/run`, `/api/v1/pipeline/status`, `/api/v1/leads/export`. All endpoints return JSON, accept JSON bodies, and require the `Authorization: Bearer <key>` header.

---

## Make.com Scenarios

Make.com scenario names follow the pattern **`{Layer#} - {Verb} {Noun}`**. The layer number prefix keeps scenarios sorted in the Make.com interface and maps directly to the 14-layer architecture. Examples: `01 - Collect Companies`, `02 - Normalize Data`, `03 - Verify Claims`, `04 - Engineer Features`, `05 - Run Growth Agent`, `10 - Run Consensus`, `12 - Detect Changes`, `13 - Enforce Cost Gate`, `14 - Run Judge`, `15 - Export Leads`. Sub-scenarios (error handling, retries) use a suffix: `03 - Verify Claims [Error Handler]`, `10 - Run Consensus [Fallback]`. Module labels within scenarios are lowercase with underscores: `get_companies`, `normalize_record`, `save_to_db`. Webhook names are kebab-case: `jasfo-pipeline-trigger`, `jasfo-cost-gate-callback`.

---

## File Names

All documentation, configuration, and script files use **kebab-case**. This is consistent with markdown conventions and avoids cross-platform casing issues. Examples: `glossary.md`, `naming-convention.md`, `coding-standards.md`, `adr-001.md`, `architecture-summary.md`, `project-summary.md`, `database-summary.md`. SQL migration files use a timestamp prefix with description: `2025-01-15-initial-schema.sql`, `2025-02-01-add-evidence-tables.sql`. Script files use kebab-case with appropriate extension: `export-leads.js`, `verify-email.js`, `run-pipeline.sh`. Directory names are also kebab-case: `docs/appendix/`, `ai-context/`, `sql/migrations/`, `make/scenarios/`.

---

## JSON Fields

All JSONB field keys and API JSON payload fields use **camelCase**. This follows JavaScript/TypeScript conventions and is the standard for JSON APIs. Examples: `companyName`, `totalScore`, `pillarScores`, `evidenceUrls`, `cooldownUntil`, `moveProbability`, `isVerified`, `confidenceScore`, `sourceUrl`, `extractedAt`. Nested objects follow the same convention: `{ "decisionMaker": { "fullName": string, "emailAddress": string, "confidence": number } }`. Arrays are plural camelCase: `leadScores[]`, `evidenceClaims[]`, `decisionMakers[]`. Timestamp values use ISO 8601 format as strings. Score values are integers or decimals; never strings. Every JSON object in a response or stored JSONB column should match its documented schema in the `schemas/` directory. AI agent output schemas are validated against these JSON conventions using Zod before being persisted to the database.

---

## Quick Reference Table

| Context | Convention | Example |
|---------|-----------|---------|
| Database table | snake_case plural | `evidence_claims` |
| Database column | snake_case singular | `is_verified` |
| Boolean column | `is_` prefix | `is_watchlisted` |
| Timestamp column | `_at` suffix | `created_at` |
| FK column | match PK name | `company_id` |
| Function | snake_case, verb_noun | `get_top_leads` |
| View | `v_` prefix | `v_top_leads` |
| API endpoint | plural kebab-case | `/api/lead-scores` |
| API param | camelCase | `?companyId=` |
| Make scenario | `{#} - Verb Noun` | `03 - Verify Claims` |
| Markdown file | kebab-case | `naming-convention.md` |
| JSON key | camelCase | `totalScore` |
| Env variable | UPPER_SNAKE | `FIRECRAWL_API_KEY` |
