# Appendix: Coding Standards

> Mandatory standards for all code written in the Jasfo platform. AI coding agents must follow these rules. Violations can cause data corruption, budget overruns, or pipeline failures.

---

## Language: TypeScript

All custom code must be written in **TypeScript**, not JavaScript. This applies to: Railway-hosted services (SMTP verification, export generation, webhook handlers), Supabase Edge Functions, and any custom scripts outside Make.com. TypeScript is required for its type safety, which prevents the class of bugs most likely to corrupt lead data or cause silent pipeline failures. Every function must have explicit parameter and return types. The `strict: true` flag must be enabled in `tsconfig.json`. The `any` type is forbidden except in generic utility functions that perform JSON parsing with Zod validation immediately after. Runtime type checking via Zod is preferred over type assertions. All TypeScript code must pass `tsc --noEmit` before merging. The target is ES2022, module resolution is NodeNext.

---

## Validation: Zod

Every external input (API request, webhook payload, Make.com webhook body, AI model output, database write) must be validated with a **Zod schema** before use. This is non-negotiable: any unvalidated input is a potential source of data corruption. Schemas are defined in dedicated files under `schemas/` and imported where needed. Examples: `CompanyProfileSchema`, `LeadScoreSchema`, `EvidenceClaimSchema`, `PipelineConfigSchema`. Parsing follows the pattern `schema.parse(data)` for guaranteed valid data or `schema.safeParse(data)` when handling expected failures. Error messages from failed parses are logged to the audit log. Zod schemas also serve as the single source of truth for TypeScript types — infer types with `z.infer<typeof MySchema>` rather than writing duplicate interfaces. AI agent output is validated with Zod before being written to the database; invalid output triggers a retry with the same model rather than proceeding with corrupt data.

---

## Supabase SDK Patterns

All database access must use the **`@supabase/supabase-js`** client. Raw SQL queries via `supabase.rpc()` calling stored functions are preferred over inline SQL strings. The client is configured with `db: { schema: 'public' }`. All queries use TypeScript generics with inferred row types: `supabase.from('companies').select('*')` returns `Company[]`. Mutations use the standard insert/update/upsert/delete methods. The `supabaseAdmin` client (service role key) is used for pipeline operations; it is stored in Railway secrets and never exposed to client-side code. The `supabaseAnon` client (anon key) is used only for public-facing API endpoints with Row-Level Security. Real-time subscriptions use `supabase.channel()` with the `pg_notify` PostgreSQL extension. File storage uses `supabase.storage.from('exports')` for signed URL generation with configurable expiry. All Supabase calls must have `.then()` or `await` error handling; unhandled promise rejections trigger Telegram alerts.

---

## REST API Conventions

All REST endpoints follow consistent patterns. Base path is `/api/v1`. Resources are plural kebab-case: `/api/v1/lead-scores`. Standard CRUD maps to POST (create), GET (read), PATCH (update), DELETE (delete). List endpoints support `offset` and `limit` for pagination (default limit: 100, max: 1000). All responses use the envelope format: `{ "data": ..., "total": number, "offset": number, "limit": number }` for collections, or `{ "data": ... }` for single resources. Error responses are `{ "error": { "code": "ERROR_CODE", "message": "Human-readable description", "details": {} } }`. HTTP status codes follow standard conventions: 200 for success, 201 for creation, 400 for validation errors, 404 for missing resources, 429 for rate limiting, 500 for server errors. Authentication uses `Authorization: Bearer <api_key>` header. API keys are stored in Supabase Vault (`vault.decrypted_secrets`). All endpoints are stateless; no session state is maintained on the server.

---

## JSON Schema Usage

All JSON structures that cross system boundaries must have a corresponding **JSON Schema** in the `schemas/` directory. This includes: Make.com webhook payloads, AI agent output specifications, API request/response bodies, export file formats (CSV column definitions, Excel sheet structures), and Telegram message payloads. JSON Schema files use the `.schema.json` extension and follow draft-07. Each schema defines `type`, `properties`, `required`, and `additionalProperties: false`. Schemas are referenced by URI in Zod validation error messages to provide full traceability. When a schema changes, all consumers must be updated in the same pull request. The schema directory mirrors the database structure: `schemas/companies/`, `schemas/leads/`, `schemas/evidence/`, `schemas/pipeline/`.

---

## Never Invent APIs

Do **not** call an API endpoint that does not exist in the documented API surface. The complete list of approved APIs is maintained in `docs/api/` and `ai-context/api-summary.md`. Before writing any HTTP request, verify the endpoint URL, method, headers, and payload against the API documentation. If the documentation does not list the endpoint you need, you must either: (a) find an alternative approach using documented endpoints, or (b) file an issue to add the endpoint to the documentation before implementing. This rule applies to Firecrawl, Apollo, Hunter, Snov, OpenRouter, Telegram, and Supabase APIs. Violations cause unrecoverable pipeline failures at runtime.

---

## Never Invent DB Fields

Do **not** add columns, tables, or JSONB keys that do not exist in the documented schema. The canonical schema is in `sql/schema.sql`. Before writing any SQL or inserting any JSONB data, verify the table structure, column names, data types, constraints, and defaults against `sql/schema.sql`. If you need a new field: (1) check all related documents to confirm no existing field covers the need, (2) add the field to `sql/schema.sql` using `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, (3) update the Zod schema in `schemas/`, (4) update the relevant documentation, (5) update any views in `sql/views.sql`. Never skip step 1. Never add a column without IF NOT EXISTS — all migrations must be idempotent.

---

## Everything Documented First

No code is written before its documentation exists. For a new feature: (1) write the specification in the relevant `docs/` directory, (2) add or update the schema file in `schemas/`, (3) update the AI context pack in `ai-context/`, (4) write the code, (5) update the ADR if the decision changes architecture. For a new database field: (1) update `sql/schema.sql` with a comment, (2) update the Zod schema, (3) update the database summary in `ai-context/`, (4) write migrations. This documentation-first approach ensures that AI agents and human contributors always have an accurate source of truth. Commits that introduce undocumented features will be rejected in review.

---

## Testing Requirements

All TypeScript code must have accompanying tests. Test files are colocated with source files using the `.test.ts` extension. Tests use Vitest as the test runner. Database functions are tested by running `SELECT` queries before and after execution. AI agent prompts are tested with sample inputs and expected outputs saved as test fixtures. Make.com scenarios are tested in the Make.com editor before deployment to the live pipeline. PRs without tests for new functionality will not be merged.

---

## Error Handling

Every `await` call must be wrapped in try/catch or handled with `.catch()`. Pipeline errors must be logged to the `audit_log` table with severity level, layer number, company ID (if applicable), error message, and stack trace. Transient errors (network timeouts, rate limits, 5xx responses) must be retried with exponential backoff (base delay: 1s, max delay: 60s, max retries: 3). Permanent errors (400, 401, 403, 404, 422) must not be retried — they indicate a configuration or data issue that requires human intervention. Unhandled exceptions in Railway services must trigger a Telegram alert to the broker.

---

## Cost-Conscious Coding

Every function that calls an AI model must log its token usage and cost to the `cost_log` table. Before adding a new AI call, evaluate whether a cheaper model can produce acceptable results. The default model is DeepSeek V4 Flash. MiMo V2.5 is used only when DeepSeek confidence is insufficient. Claude Sonnet 4 is used only in the Judge layer. Never hardcode model names — use environment variables or configuration constants. If a feature requires an expensive API call, it must be gated behind a score threshold check (the Cost Gate pattern). Budget overruns are prevented by design, not detected after the fact.
