-- ============================================================================
-- Jasfo Lead Intelligence Platform — View Definitions
-- Supabase PostgreSQL 16
-- ============================================================================
-- Materialized and non-materialized views that simplify common query patterns.
-- ============================================================================

-- 1. V_TOP_LEADS -------------------------------------------------------------
-- Broker-facing view of the highest-priority leads ready for action.

CREATE OR REPLACE VIEW v_top_leads AS
SELECT
    c.id AS company_id,
    c.company_name,
    c.domain,
    c.industry,
    c.headquarters_city,
    c.employee_range,
    c.revenue_range,
    ls.total_score,
    ls.growth_score,
    ls.space_need_score,
    ls.financial_health_score,
    ls.confidence_score,
    d.state,
    d.priority_band,
    d.entered_state_at,
    d.is_watchlisted,
    COUNT(ec.id) AS evidence_claim_count,
    COUNT(es.id) FILTER (WHERE es.reliability_tier <= 2) AS high_quality_source_count
FROM companies c
JOIN LATERAL (
    SELECT * FROM lead_scores ls
    WHERE ls.company_id = c.id
    ORDER BY ls.scored_at DESC
    LIMIT 1
) ls ON true
JOIN decisions d ON d.company_id = c.id
LEFT JOIN evidence_claims ec ON ec.company_id = c.id
LEFT JOIN evidence_sources es ON es.claim_id = ec.id
WHERE d.state NOT IN ('lost', 'archived')
  AND (d.cooldown_until IS NULL OR d.cooldown_until < now())
GROUP BY c.id, ls.total_score, ls.growth_score, ls.space_need_score,
         ls.financial_health_score, ls.confidence_score,
         d.state, d.priority_band, d.entered_state_at, d.is_watchlisted
ORDER BY ls.total_score DESC, ls.confidence_score DESC;

COMMENT ON VIEW v_top_leads IS 'Highest-priority leads with latest scores and evidence metrics.';

-- 2. V_WEEKLY_COSTS ----------------------------------------------------------
-- Cost tracking view for budget monitoring.

CREATE OR REPLACE VIEW v_weekly_costs AS
SELECT
    date_trunc('week', cl.recorded_at) AS week_start,
    cl.layer_id AS pipeline_layer,
    cl.model_used,
    cl.source_type,
    COUNT(*) AS operation_count,
    SUM(cl.cost_cents) AS total_cost_cents,
    SUM(cl.tokens_used) AS total_tokens,
    ROUND(SUM(cl.cost_cents) / 100.0, 2) AS total_cost_usd
FROM cost_log cl
GROUP BY week_start, cl.layer_id, cl.model_used, cl.source_type
ORDER BY week_start DESC, total_cost_cents DESC;

COMMENT ON VIEW v_weekly_costs IS 'Weekly cost aggregation per pipeline layer, model, and source.';

-- 3. V_STALE_PROFILES --------------------------------------------------------
-- Identifies companies whose profiles have not been re-scored on time.

CREATE OR REPLACE VIEW v_stale_profiles AS
SELECT
    c.id AS company_id,
    c.company_name,
    c.domain,
    c.industry,
    ls_last.scored_at AS last_scored_at,
    ls_last.total_score AS last_total_score,
    ls_last.score_version AS last_score_version,
    d.state,
    d.cooldown_until,
    CASE
        WHEN ls_last.scored_at IS NULL THEN 'never_scored'
        WHEN ls_last.scored_at < now() - interval '14 days' AND d.is_watchlisted THEN 'stale_watchlisted'
        WHEN ls_last.scored_at < now() - interval '90 days' AND d.state = 'dormant' THEN 'stale_dormant'
        WHEN ls_last.scored_at < now() - interval '7 days' AND d.state IN ('new', 'qualified') THEN 'stale_active'
        ELSE 'current'
    END AS staleness_category
FROM companies c
LEFT JOIN LATERAL (
    SELECT * FROM lead_scores ls
    WHERE ls.company_id = c.id
    ORDER BY ls.scored_at DESC
    LIMIT 1
) ls_last ON true
LEFT JOIN decisions d ON d.company_id = c.id
WHERE ls_last.scored_at IS NULL
   OR ls_last.scored_at < now() - interval '7 days'
ORDER BY ls_last.scored_at ASC NULLS FIRST;

COMMENT ON VIEW v_stale_profiles IS 'Companies needing re-scoring, categorized by staleness.';

-- 4. V_DM_COVERAGE -----------------------------------------------------------
-- Decision-maker coverage: which companies have verified contacts.

CREATE OR REPLACE VIEW v_dm_coverage AS
SELECT
    c.id AS company_id,
    c.company_name,
    c.domain,
    d.state,
    d.priority_band,
    COUNT(DISTINCT ed.id) AS email_draft_count,
    COUNT(DISTINCT ld.id) AS linkedin_draft_count,
    COUNT(DISTINCT mc.id) AS mutual_connection_count,
    COUNT(DISTINCT oh.id) AS outreach_count,
    CASE
        WHEN COUNT(DISTINCT ed.id) > 0 THEN 'email_ready'
        WHEN COUNT(DISTINCT ld.id) > 0 THEN 'linkedin_ready'
        WHEN COUNT(DISTINCT mc.id) > 0 THEN 'intro_available'
        ELSE 'no_coverage'
    END AS coverage_status
FROM companies c
JOIN decisions d ON d.company_id = c.id
LEFT JOIN email_drafts ed ON ed.company_id = c.id
LEFT JOIN linkedin_drafts ld ON ld.company_id = c.id
LEFT JOIN mutual_connections mc ON mc.company_id = c.id
LEFT JOIN outreach_history oh ON oh.company_id = c.id
WHERE d.state IN ('qualified', 'contacted', 'meeting_booked')
GROUP BY c.id, d.state, d.priority_band
ORDER BY d.priority_band ASC, coverage_status ASC;

COMMENT ON VIEW v_dm_coverage IS 'Decision-maker contact coverage per qualified lead.';

-- 5. V_OUTREACH_PERFORMANCE --------------------------------------------------
-- Outreach effectiveness metrics by channel and time.

CREATE OR REPLACE VIEW v_outreach_performance AS
SELECT
    date_trunc('week', oh.sent_at) AS week_start,
    oh.channel,
    oh.status,
    COUNT(*) AS send_count,
    COUNT(*) FILTER (WHERE oh.response_at IS NOT NULL) AS response_count,
    COUNT(*) FILTER (WHERE oh.response_type = 'positive') AS positive_count,
    COUNT(*) FILTER (WHERE oh.response_type = 'meeting_booked') AS meeting_count,
    ROUND(
        COUNT(*) FILTER (WHERE oh.response_at IS NOT NULL) * 100.0 / NULLIF(COUNT(*), 0),
        1
    ) AS response_rate_pct,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (oh.response_at - oh.sent_at)) / 86400.0)
        FILTER (WHERE oh.response_at IS NOT NULL),
        1
    ) AS avg_response_days
FROM outreach_history oh
GROUP BY week_start, oh.channel, oh.status
ORDER BY week_start DESC, send_count DESC;

COMMENT ON VIEW v_outreach_performance IS 'Outreach effectiveness metrics by channel and week.';

-- 6. V_IPC_INTELLIGENCE ------------------------------------------------------
-- IPC competitive intelligence summary.

CREATE OR REPLACE VIEW v_ipc_intelligence AS
SELECT
    i.id AS ipc_id,
    i.ipc_name,
    i.ipc_type,
    i.headquarters_city,
    i.services_offered,
    i.coverage_cities,
    COUNT(im.id) AS active_mandate_count,
    COUNT(im.id) FILTER (WHERE im.mandate_status = 'active') AS active_mandates,
    COUNT(DISTINCT im.company_id) AS unique_client_count
FROM ipcs i
LEFT JOIN ipc_mandates im ON im.ipc_id = i.id
GROUP BY i.id, i.ipc_name, i.ipc_type, i.headquarters_city,
         i.services_offered, i.coverage_cities
ORDER BY active_mandate_count DESC;

COMMENT ON VIEW v_ipc_intelligence IS 'IPC competitive intelligence with mandate counts.';

-- 7. V_COOLDOWN_STATUS -------------------------------------------------------
-- Cooldown status for all companies with active decisions.

CREATE OR REPLACE VIEW v_cooldown_status AS
SELECT
    c.id AS company_id,
    c.company_name,
    c.domain,
    d.state,
    d.priority_band,
    d.cooldown_until,
    d.entered_state_at,
    CASE
        WHEN d.cooldown_until IS NULL THEN 'active'
        WHEN d.cooldown_until > now() THEN
            'in_cooldown (' || EXTRACT(DAY FROM (d.cooldown_until - now()))::text || 'd remaining)'
        ELSE 'expired'
    END AS cooldown_status,
    CASE
        WHEN d.cooldown_until IS NULL THEN NULL
        WHEN d.cooldown_until > now() THEN
            EXTRACT(EPOCH FROM (d.cooldown_until - now())) / 86400.0
        ELSE 0
    END AS cooldown_days_remaining
FROM decisions d
JOIN companies c ON c.id = d.company_id
WHERE d.state NOT IN ('archived')
ORDER BY d.cooldown_until ASC NULLS FIRST;

COMMENT ON VIEW v_cooldown_status IS 'Cooldown status for all non-archived decisions.';

-- ============================================================================
-- END OF VIEWS
-- ============================================================================
