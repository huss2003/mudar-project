# Index Strategy

> Performance-focused index design for the Jasfo Postgres database. All indexes are created with `CONCURRENTLY` to avoid blocking writes during weekly pipeline execution.

## Index Categories

### 1. Key Lookup Indexes

Every foreign key relationship has a corresponding index. These are the most frequently hit indexes — every JOIN in the pipeline depends on them.

| Index Name | Table | Columns | Type | Why |
|------------|-------|---------|------|-----|
| `idx_companies_domain` | companies | `domain` | `UNIQUE BTREE` | Enforce domain uniqueness; O(1) lookup |
| `idx_scores_company_scored` | companies_scores | `(company_id, scored_at DESC)` | `BTREE` | Latest-score-per-company query |
| `idx_snapshots_company_hash` | companies_snapshots | `(company_id, sha256_hash)` | `BTREE` | Change detection JOIN |
| `idx_claims_company` | evidence_claims | `company_id` | `BTREE` | Evidence lookup per company |
| `idx_sources_claim` | evidence_sources | `claim_id` | `BTREE` | Sources per claim |
| `idx_events_lead` | leads_events | `lead_id` | `BTREE` | Event history per lead |
| `idx_ev_snapshots_company` | evidence_snapshots | `company_id` | `BTREE` | Evidence bundle lookup |

Without these indexes, every JOIN would trigger a sequential scan. On `evidence_sources` (projected 1M rows), an unindexed JOIN on `claim_id` would scan the entire table every time.

### 2. Full-Text Search

The platform supports searching companies by name, industry, and description. Postgres full-text search with a `GIN` index provides fast token-based matching without an external search service.

```sql
CREATE INDEX idx_companies_fts ON companies
  USING GIN (
    to_tsvector('english', coalesce(company_name, '') || ' ' ||
                coalesce(industry, '') || ' ' ||
                coalesce(description, ''))
  );
```

Search queries use the `ts_query` function:

```sql
SELECT id, company_name, domain, industry
FROM companies
WHERE to_tsvector('english',
    coalesce(company_name, '') || ' ' ||
    coalesce(industry, '') || ' ' ||
    coalesce(description, ''))
  @@ plainto_tsquery('english', 'enterprise software pune');
```

The GIN index handles stemming (e.g., "technologies" matches "technology"), stop word removal, and ranking via `ts_rank()`. This is sufficient for the single-broker workload — if full-text search needs to scale later, the platform can migrate to Supabase's full-text search wrapper or pgvector for semantic search.

### 3. Composite Indexes for Filtering + Sorting

The most common query pattern in the lead engine is: "find leads in state X, ordered by priority, with active cooldown." These queries need composite indexes that cover both the WHERE filter and the ORDER BY.

| Index Name | Columns | Covers |
|------------|---------|--------|
| `idx_leads_state_priority` | `(state, priority_band ASC)` | Lead queue queries |
| `idx_leads_cooldown_state` | `(cooldown_until DESC NULLS LAST, state)` | Cooldown expiry checks |
| `idx_scores_total_scored` | `(total_score DESC, scored_at DESC)` | Top-leaderboard queries |
| `idx_events_lead_occurred` | `(lead_id, occurred_at DESC)` | Event timeline queries |

The `idx_leads_state_priority` index is the most performance-critical. It powers the primary broker view: "show me all leads in 'qualified' state, sorted by priority band." Postgres can satisfy both the WHERE clause and the ORDER BY from a single index scan, avoiding an explicit sort.

### 4. Partial Indexes for Active Subsets

Most queries operate on a subset of rows — active leads, unverified claims, pending cooldowns. Partial indexes shrink the index size by only including matching rows.

```sql
CREATE INDEX idx_leads_active ON leads (priority_band)
  WHERE state NOT IN ('lost', 'archived');

CREATE INDEX idx_claims_unverified ON evidence_claims (created_at)
  WHERE is_verified = false;

CREATE INDEX idx_snapshots_recent ON companies_snapshots (company_id)
  WHERE captured_at > now() - interval '90 days';
```

The partial index on `leads` reduces index size from ~200 KB to ~40 KB because 80% of lead records are in terminal states (lost/archived) and never queried.

### 5. Avoiding Over-Indexing

Not every column gets an index. The following columns are intentionally unindexed:

- **`evidence_sources.extracted_content`** — Full-text content stored for audit. Queried by claim_id JOIN, never by content search.
- **`companies.management_team`** and **`tech_stack`** — JSONB columns accessed via path operators, not filters. If JSONB path queries become frequent, a `GIN` index on the column can be added.
- **`leads_events.metadata`** — Arbitrary JSONB payload. Indexed only if specific metadata keys become filter targets.

## Maintenance

Postgres index maintenance is handled through weekly `ANALYZE` runs scheduled via `pg_cron`:

```sql
SELECT cron.schedule('weekly-analyze', '0 2 * * 0',
  'ANALYZE;'
);
```

The `autovacuum` daemon handles index bloat reclamation on actively mutated tables (`companies_scores`, `leads_events`). Table-specific autovacuum tuning:

```sql
ALTER TABLE leads_events SET (autovacuum_vacuum_scale_factor = 0.01);
ALTER TABLE audit_log SET (autovacuum_vacuum_scale_factor = 0.01);
```

These high-write tables get more aggressive vacuum to prevent index bloat from degrading query performance over the 50-week projected data accumulation.
