# Coding Rules

> Mandatory rules extracted from all project docs. Violations cause CI failures, incorrect data, or budget overruns.

## 1. Never Invent APIs or DB Fields

- Do NOT call an API endpoint that does not exist in the docs.
- Do NOT add columns to SQL tables without checking `sql/schema.sql` first.
- Do NOT invent JSONB keys. Every key must match the schema.
- If you need a new field, check all related docs first, then add with IF NOT EXISTS.

## 2. Always Verify Before Trusting

- After reading a doc, verify your understanding against the actual schemas/files.
- After writing SQL, verify column names and types against schema.md.
- After adding an agent, verify its prompt matches the system-prompt patterns.

## 3. Evidence-First Output

- Every claim in generated output must have a confidence score (0-100).
- Every claim must cite a source URL.
- If data is unavailable, mark it as "Not Found" with confidence 0, never hallucinate.

## 4. Cost Awareness

- DeepSeek V4 Flash for 70% of tasks ($0.20/1M tokens).
- MiMo V2.5 for 20% ($0.75/1M tokens).
- Claude Sonnet 4 for 10% — Judge layer ONLY ($8/1M tokens).
- Always ask: "Can a cheaper model do this?" before using a premium model.

## 5. Test-First Development

- Write tests before implementation for any new function or agent.
- For SQL: write SELECT queries that validate the function works before creating it.
- For agents: test with sample prompts before deploying to pipeline.
- Run existing tests before committing to ensure no regression.

## 6. Idempotent SQL

- All CREATE statements use IF NOT EXISTS.
- All migrations must be safe to run multiple times.
- Never use DROP unless explicitly called for.
- Use CREATE OR REPLACE for functions and views.

## 7. Lazy-First (Don't Overbuild)

- Single-user: no user_id fields, no team tables, no multi-tenant.
- If a feature is not needed for the current 10K/week scale, defer it.
- Do not add indexes until there is evidence of slow queries.
- "Build the simplest version that works."

## 8. No Hallucinated Data

- Never invent company data, scores, or claims.
- Never guess email addresses or phone numbers.
- Never assume funding rounds or employee counts.
- If a field has no data, mark it null, skip it, or note "insufficient data."

## 9. Follow Naming Conventions

- Tables: snake_case plural (`companies`, `evidence_sources`)
- Columns: snake_case singular (`company_name`, `founded_year`)
- Booleans: is_ prefix (`is_verified`, `is_watchlisted`)
- Timestamps: _at suffix (`created_at`, `updated_at`)
- Foreign keys: match referenced PK name (`company_id` references `companies.id`)

## 10. Commit Checklist

Before every commit:
- [ ] All tests pass
- [ ] No hallucinated fields/APIs
- [ ] SQL is idempotent (IF NOT EXISTS)
- [ ] Evidence verified (sources exist, URLs resolve)
- [ ] Cost model appropriate (cheapest capable model)
- [ ] ADR updated if architectural decision changed
