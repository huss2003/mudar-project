-- ============================================================================
-- Jasfo Lead Intelligence Platform — Index Definitions
-- Supabase PostgreSQL 16
-- ============================================================================
-- All indexes for query performance, covering indexes for key queries,
-- GIN indexes for full-text search, and partial indexes for active subsets.
-- ============================================================================

-- 1. PRIMARY KEY & UNIQUE INDEXES --------------------------------------------
-- (Most PKs use default gen_random_uuid + implicit unique index)

-- Unique domain lookup (already defined as UNIQUE constraint in schema)
CREATE INDEX IF NOT EXISTS idx_companies_domain ON companies (domain);

-- 2. FOREIGN KEY INDEXES ------------------------------------------------------
-- Every FK relationship needs an index for JOIN performance.

CREATE INDEX IF NOT EXISTS idx_profiles_company ON profiles (company_id);
CREATE INDEX IF NOT EXISTS idx_mutual_connections_company ON mutual_connections (company_id);
CREATE INDEX IF NOT EXISTS idx_posts_company ON posts (company_id);
CREATE INDEX IF NOT EXISTS idx_lead_scores_company ON lead_scores (company_id);
CREATE INDEX IF NOT EXISTS idx_decisions_company ON decisions (company_id);
CREATE INDEX IF NOT EXISTS idx_email_drafts_company ON email_drafts (company_id);
CREATE INDEX IF NOT EXISTS idx_email_drafts_decision ON email_drafts (decision_id);
CREATE INDEX IF NOT EXISTS idx_linkedin_drafts_company ON linkedin_drafts (company_id);
CREATE INDEX IF NOT EXISTS idx_linkedin_drafts_decision ON linkedin_drafts (decision_id);
CREATE INDEX IF NOT EXISTS idx_ipc_mandates_ipc ON ipc_mandates (ipc_id);
CREATE INDEX IF NOT EXISTS idx_ipc_mandates_company ON ipc_mandates (company_id);
CREATE INDEX IF NOT EXISTS idx_outreach_history_company ON outreach_history (company_id);
CREATE INDEX IF NOT EXISTS idx_outreach_history_decision ON outreach_history (decision_id);
CREATE INDEX IF NOT EXISTS idx_cost_log_company ON cost_log (company_id);
CREATE INDEX IF NOT EXISTS idx_evidence_claims_company ON evidence_claims (company_id);
CREATE INDEX IF NOT EXISTS idx_evidence_sources_claim ON evidence_sources (claim_id);
CREATE INDEX IF NOT EXISTS idx_evidence_snapshots_company ON evidence_snapshots (company_id);
CREATE INDEX IF NOT EXISTS idx_companies_snapshots_company ON companies_snapshots (company_id);
CREATE INDEX IF NOT EXISTS idx_lead_events_decision ON lead_events (decision_id);

-- 3. COMPOSITE INDEXES FOR FILTERING + SORTING -------------------------------

-- Latest score per company query pattern
CREATE INDEX IF NOT EXISTS idx_lead_scores_company_scored
    ON lead_scores (company_id, scored_at DESC);

-- Lead queue: state + priority sort
CREATE INDEX IF NOT EXISTS idx_decisions_state_priority
    ON decisions (state, priority_band ASC);

-- Cooldown expiry checks
CREATE INDEX IF NOT EXISTS idx_decisions_cooldown_state
    ON decisions (cooldown_until DESC NULLS LAST, state);

-- Top leaderboard queries
CREATE INDEX IF NOT EXISTS idx_lead_scores_total_scored
    ON lead_scores (total_score DESC, scored_at DESC);

-- Company created_at for time-range queries
CREATE INDEX IF NOT EXISTS idx_companies_created
    ON companies (created_at DESC);

-- Company industry filtering
CREATE INDEX IF NOT EXISTS idx_companies_industry
    ON companies (industry);

-- Snapshot hash comparison
CREATE INDEX IF NOT EXISTS idx_snapshots_company_hash
    ON companies_snapshots (company_id, sha256_hash);

-- Snapshot capture time for pruning queries
CREATE INDEX IF NOT EXISTS idx_snapshots_captured
    ON companies_snapshots (captured_at DESC);

-- Evidence snapshot hash uniqueness
CREATE INDEX IF NOT EXISTS idx_ev_snapshots_hash
    ON evidence_snapshots (sha256_hash);

-- Event timeline per lead
CREATE INDEX IF NOT EXISTS idx_lead_events_decision_occurred
    ON lead_events (decision_id, occurred_at DESC);

-- Event type filtering
CREATE INDEX IF NOT EXISTS idx_lead_events_type
    ON lead_events (event_type);

-- Event time-range queries
CREATE INDEX IF NOT EXISTS idx_lead_events_occurred
    ON lead_events (occurred_at DESC);

-- Audit log queries
CREATE INDEX IF NOT EXISTS idx_audit_log_table
    ON audit_log (table_name);

CREATE INDEX IF NOT EXISTS idx_audit_log_record
    ON audit_log (record_id);

CREATE INDEX IF NOT EXISTS idx_audit_log_changed
    ON audit_log (changed_at DESC);

-- Cost log queries
CREATE INDEX IF NOT EXISTS idx_cost_log_layer
    ON cost_log (layer_id);

CREATE INDEX IF NOT EXISTS idx_cost_log_recorded
    ON cost_log (recorded_at DESC);

-- Outreach performance queries
CREATE INDEX IF NOT EXISTS idx_outreach_sent
    ON outreach_history (sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_outreach_channel_status
    ON outreach_history (channel, status);

-- 4. GIN INDEXES FOR FULL-TEXT SEARCH ----------------------------------------

-- Company full-text search across name, industry, and description
CREATE INDEX IF NOT EXISTS idx_companies_fts
    ON companies
    USING GIN (
        to_tsvector('english',
            COALESCE(company_name, '') || ' ' ||
            COALESCE(industry, '') || ' ' ||
            COALESCE(description, '')
        )
    );

-- JSONB indexes for companies (if path queries become frequent)
CREATE INDEX IF NOT EXISTS idx_companies_management_team
    ON companies USING GIN (management_team);

CREATE INDEX IF NOT EXISTS idx_companies_tech_stack
    ON companies USING GIN (tech_stack);

-- JSONB indexes for posts
CREATE INDEX IF NOT EXISTS idx_posts_relevant_signals
    ON posts USING GIN (relevant_signals);

-- 5. PARTIAL INDEXES FOR ACTIVE SUBSETS --------------------------------------

-- Active decisions (excludes terminal states)
CREATE INDEX IF NOT EXISTS idx_decisions_active
    ON decisions (priority_band)
    WHERE state NOT IN ('lost', 'archived');

-- Unverified claims that need attention
CREATE INDEX IF NOT EXISTS idx_evidence_claims_unverified
    ON evidence_claims (created_at)
    WHERE is_verified = false;

-- Recent snapshots (last 90 days)
CREATE INDEX IF NOT EXISTS idx_snapshots_recent
    ON companies_snapshots (company_id)
    WHERE captured_at > now() - interval '90 days';

-- High-value leads (total_score >= 500)
CREATE INDEX IF NOT EXISTS idx_lead_scores_high_value
    ON lead_scores (company_id, scored_at DESC)
    WHERE total_score >= 500;

-- Active IPCs only
CREATE INDEX IF NOT EXISTS idx_ipcs_active
    ON ipcs (ipc_name)
    WHERE is_active = true;

-- Active mandates only
CREATE INDEX IF NOT EXISTS idx_ipc_mandates_active
    ON ipc_mandates (ipc_id, company_id)
    WHERE mandate_status = 'active';

-- 6. COVERING INDEXES FOR KEY QUERIES ----------------------------------------

-- Covering index for v_top_leads latest-score lookup
CREATE INDEX IF NOT EXISTS idx_lead_scores_latest_covering
    ON lead_scores (company_id, scored_at DESC)
    INCLUDE (total_score, growth_score, space_need_score,
             financial_health_score, confidence_score);

-- Covering index for v_stale_profiles
CREATE INDEX IF NOT EXISTS idx_lead_scores_stale_covering
    ON lead_scores (company_id, scored_at DESC)
    INCLUDE (total_score, score_version);

-- ============================================================================
-- END OF INDEXES
-- ============================================================================
