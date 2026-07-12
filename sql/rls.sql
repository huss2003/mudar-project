-- ============================================================================
-- Jasfo Lead Intelligence Platform — Row Level Security Policies
-- Supabase PostgreSQL 16
-- ============================================================================
-- Currently configured for single-user operation with a design path toward
-- multi-user. All tables have RLS enabled but with permissive single-user
-- policies. Service role key bypasses RLS entirely.
-- ============================================================================

-- 0. ENABLE EXTENSION -------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. ENABLE RLS ON ALL TABLES -----------------------------------------------

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE mutual_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE linkedin_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipcs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ipc_mandates ENABLE ROW LEVEL SECURITY;
ALTER TABLE outreach_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE cost_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_events ENABLE ROW LEVEL SECURITY;

-- 2. SINGLE-USER POLICIES (CURRENT) ------------------------------------------
-- Permissive: any authenticated user can read/write everything.
-- This matches the single-broker architecture.

CREATE POLICY "single_user_full_access"
    ON companies
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON profiles
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON mutual_connections
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON posts
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON lead_scores
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON decisions
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON email_drafts
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON linkedin_drafts
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON ipcs
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON ipc_mandates
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON outreach_history
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON cost_log
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON audit_log
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON companies_snapshots
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON evidence_claims
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON evidence_sources
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON evidence_snapshots
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "single_user_full_access"
    ON lead_events
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 3. FUTURE MULTI-USER POLICIES (COMMENTED OUT) ------------------------------
-- Activate when adding user_id columns and multi-broker support.
-- These replace the single-user policies above.

-- 3.1 Broker manages own companies
-- CREATE POLICY "broker_manage_companies"
--     ON companies FOR ALL
--     USING (user_id = auth.uid());
--
-- CREATE POLICY "admin_read_companies"
--     ON companies FOR SELECT
--     USING (auth.jwt() ->> 'role' = 'admin');

-- 3.2 Broker manages own leads
-- CREATE POLICY "broker_manage_decisions"
--     ON decisions FOR ALL
--     USING (user_id = auth.uid());
--
-- CREATE POLICY "team_shared_watchlists"
--     ON decisions FOR SELECT
--     USING (
--         is_watchlisted = true
--         AND user_id IN (
--             SELECT team_member_id FROM broker_teams
--             WHERE broker_id = auth.uid()
--         )
--     );

-- 3.3 Broker manages own evidence
-- CREATE POLICY "broker_evidence_access"
--     ON evidence_claims FOR ALL
--     USING (user_id = auth.uid());
--
-- CREATE POLICY "cross_reference_sources"
--     ON evidence_sources FOR SELECT
--     USING (true);

-- 3.4 Broker manages own outreach
-- CREATE POLICY "broker_outreach"
--     ON outreach_history FOR ALL
--     USING (user_id = auth.uid());

-- 3.5 Admin read on all tables
-- CREATE POLICY "admin_read_leads"
--     ON decisions FOR SELECT
--     USING (auth.jwt() ->> 'role' = 'admin');
--
-- CREATE POLICY "admin_read_evidence"
--     ON evidence_claims FOR SELECT
--     USING (auth.jwt() ->> 'role' = 'admin');

-- ============================================================================
-- END OF RLS POLICIES
-- ============================================================================
