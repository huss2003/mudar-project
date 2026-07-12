# Views

> Materialized and non-materialized views that simplify common query patterns. Views are created via `supabase/migrations/` and rebuilt during deployment.

---

## `v_top_leads`

**Purpose**: Broker-facing view of the highest-priority leads ready for action. Filters out leads in terminal states, excludes companies in cooldown, and sorts by total score descending.

```sql
CREATE VIEW v_top_leads AS
SELECT
    c.id AS company_id,
    c.company_name,
    c.domain,
    c.industry,
    c.headquarters_city,
    c.employee_range,
    c.revenue_range,
    cs.total_score,
    cs.growth_score,
    cs.space_need_score,
    cs.financial_health_score,
    cs.confidence_score,
    l.state,
    l.priority_band,
    l.entered_state_at,
    l.is_watchlisted,
    COUNT(ec.id) AS evidence_claim_count,
    COUNT(es.id) FILTER (WHERE es.reliability_tier <= 2) AS high_quality_source_count
FROM companies c
JOIN LATERAL (
    SELECT * FROM companies_scores cs
    WHERE cs.company_id = c.id
    ORDER BY cs.scored_at DESC
    LIMIT 1
) cs ON true
JOIN leads l ON l.company_id = c.id
LEFT JOIN evidence_claims ec ON ec.company_id = c.id
LEFT JOIN evidence_sources es ON es.claim_id = ec.id
WHERE l.state NOT IN ('lost', 'archived')
  AND (l.cooldown_until IS NULL OR l.cooldown_until < now())
GROUP BY c.id, cs.total_score, cs.growth_score, cs.space_need_score,
         cs.financial_health_score, cs.confidence_score,
         l.state, l.priority_band, l.entered_state_at, l.is_watchlisted
ORDER BY cs.total_score DESC, cs.confidence_score DESC;
```

**Usage**: This is the primary view consumed by the weekly export scenario. It returns 20–40 rows per query, each with full company context plus evidence quality metrics. The `LATERAL` join ensures only the latest score per company is used, even if multiple scoring cycles have run.

**Columns exposed**: `company_id`, `company_name`, `domain`, `industry`, `city`, `employees`, `revenue`, `total_score`, `growth_score`, `space_need_score`, `financial_health_score`, `confidence_score`, `state`, `priority_band`, `entered_state_at`, `is_watchlisted`, `evidence_claim_count`, `high_quality_source_count`.

---

## `v_weekly_costs`

**Purpose**: Cost tracking view for budget monitoring. Aggregates per-pipeline-run costs by layer, model, and source type.

```sql
CREATE VIEW v_weekly_costs AS
SELECT
    date_trunc('week', occurred_at) AS week_start,
    CASE
        WHEN event_type LIKE 'layer_%' THEN split_part(event_type, '_', 2) || '_' || split_part(event_type, '_', 3)
        ELSE 'other'
    END AS pipeline_layer,
    metadata->>'model' AS model_used,
    metadata->>'source_type' AS source_type,
    COUNT(*) AS operation_count,
    SUM((metadata->>'cost_cents')::integer) AS total_cost_cents,
    SUM((metadata->>'tokens')::integer) AS total_tokens
FROM leads_events
WHERE event_type LIKE 'layer_%'
   OR event_type = 'cost_gate_check'
GROUP BY week_start, pipeline_layer, model_used, source_type
ORDER BY week_start DESC, total_cost_cents DESC;
```

**Usage**: Consumed by the weekly cost report sent to Telegram. Aggregates cost data from `leads_events.metadata` where pipeline layers record their per-company spend. The `cost_cents` field is recorded in integer cents to avoid floating-point precision issues.

**Important**: This view depends on pipeline layers writing cost data to `leads_events.metadata` with the correct schema. If a layer fails to record its cost, it will be missing from the aggregation. The `total_tokens` column provides a secondary check — a layer with tokens but no cost indicates a recording error.

---

## `v_stale_profiles`

**Purpose**: Identifies companies whose profiles have not been re-scored within the expected cadence. Used by the maintenance scheduler to trigger re-processing.

```sql
CREATE VIEW v_stale_profiles AS
SELECT
    c.id AS company_id,
    c.company_name,
    c.domain,
    c.industry,
    cs_last.scored_at AS last_scored_at,
    cs_last.total_score AS last_total_score,
    cs_last.score_version AS last_score_version,
    l.state,
    l.cooldown_until,
    CASE
        WHEN cs_last.scored_at IS NULL THEN 'never_scored'
        WHEN cs_last.scored_at < now() - interval '14 days' AND l.state = 'watchlisted' THEN 'stale_watchlisted'
        WHEN cs_last.scored_at < now() - interval '90 days' AND l.state = 'dormant' THEN 'stale_dormant'
        WHEN cs_last.scored_at < now() - interval '7 days' AND l.state IN ('new', 'qualified') THEN 'stale_active'
        ELSE 'current'
    END AS staleness_category
FROM companies c
LEFT JOIN LATERAL (
    SELECT * FROM companies_scores cs
    WHERE cs.company_id = c.id
    ORDER BY cs.scored_at DESC
    LIMIT 1
) cs_last ON true
LEFT JOIN leads l ON l.company_id = c.id
WHERE cs_last.scored_at IS NULL
   OR cs_last.scored_at < now() - interval '7 days'
ORDER BY cs_last.scored_at ASC NULLS FIRST;
```

**Usage**: Runs as part of the Sunday maintenance window. Companies in `stale_active` or `stale_watchlisted` categories are queued for re-processing. Companies that have `never_scored` indicate a data pipeline failure — they were discovered but never completed the scoring layer. The view provides three staleness categories with different thresholds, enabling targeted re-processing: active leads are refreshed weekly, watchlist leads biweekly, and dormant leads quarterly.

**Output categories**:

| Category | Threshold | Action |
|----------|-----------|--------|
| `never_scored` | No score record exists | Investigate pipeline failure |
| `stale_watchlisted` | >14 days since last score | Re-run change detection |
| `stale_dormant` | >90 days since last score | Full re-score |
| `stale_active` | >7 days since last score | Expedite re-score |
| `current` | Within threshold | No action |
