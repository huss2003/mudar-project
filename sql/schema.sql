-- ============================================================================
-- Jasfo Lead Intelligence Platform — Complete Database Schema
-- Supabase PostgreSQL 16 | public schema
-- ============================================================================
-- This file defines every table in the Jasfo platform. All tables use uuid
-- primary keys (gen_random_uuid), timestamptz for timezone-safe timestamps,
-- and jsonb for flexible nested data. Foreign keys are explicitly named
-- for clear dependency tracking.
-- ============================================================================

-- 0. EXTENSIONS -------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 1. COMPANIES --------------------------------------------------------------

CREATE TABLE companies (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name        text        NOT NULL,
    domain              text        NOT NULL,
    industry            text,
    employee_range      text,
    revenue_range       text,
    headquarters_city   text,
    headquarters_country text       DEFAULT 'India',
    founded_year        integer,
    management_team     jsonb       DEFAULT '[]',
    tech_stack          jsonb       DEFAULT '[]',
    description         text,
    firecrawl_source_url text,
    discovered_at       timestamptz DEFAULT now(),
    created_at          timestamptz DEFAULT now(),
    updated_at          timestamptz DEFAULT now(),

    CONSTRAINT uq_companies_domain UNIQUE (domain),
    CONSTRAINT chk_companies_founded_year CHECK (
        founded_year IS NULL OR
        (founded_year >= 1800 AND founded_year <= EXTRACT(YEAR FROM now()))
    )
);

COMMENT ON TABLE companies IS 'Core company profile. Central entity — most other tables reference it.';
COMMENT ON COLUMN companies.management_team IS '[{"name": "str", "title": "str", "linkedin_url": "str"}]';
COMMENT ON COLUMN companies.tech_stack IS '[{"technology": "str", "category": "str"}]';
COMMENT ON COLUMN companies.employee_range IS 'e.g. "51-200", "1001-5000"';

-- 2. PROFILES ---------------------------------------------------------------

CREATE TABLE profiles (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    source_url          text,
    linkedin_url        text,
    crunchbase_url      text,
    glassdoor_url       text,
    twitter_url         text,
    facebook_url        text,
    github_url          text,
    angelList_url       text,
    founded_year_verified integer,
    employee_count_exact integer,
    revenue_exact       bigint,
    naics_code          text,
    sic_code            text,
    legal_name          text,
    duns_number         text,
    ein_number          text,
    raw_scrape_data     jsonb       DEFAULT '{}',
    last_scraped_at     timestamptz,
    scrape_attempts     integer     DEFAULT 0,
    scrape_status       text        DEFAULT 'pending',
    created_at          timestamptz DEFAULT now(),
    updated_at          timestamptz DEFAULT now(),

    CONSTRAINT uq_profiles_company UNIQUE (company_id),
    CONSTRAINT chk_profiles_scrape_status CHECK (
        scrape_status IN ('pending', 'in_progress', 'completed', 'failed', 'skipped')
    ),
    CONSTRAINT chk_profiles_scrape_attempts CHECK (
        scrape_attempts >= 0 AND scrape_attempts <= 10
    )
);

COMMENT ON TABLE profiles IS 'Extended company profile with scraped data from multiple sources.';

-- 3. MUTUAL CONNECTIONS -----------------------------------------------------

CREATE TABLE mutual_connections (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    broker_name         text,
    connection_name     text        NOT NULL,
    connection_title    text,
    connection_linkedin_url text,
    relationship_type   text        DEFAULT 'linkedin',
    connection_strength integer     DEFAULT 1,
    notes               text,
    created_at          timestamptz DEFAULT now(),
    updated_at          timestamptz DEFAULT now(),

    CONSTRAINT chk_mutual_connection_strength CHECK (
        connection_strength >= 1 AND connection_strength <= 5
    ),
    CONSTRAINT chk_mutual_relationship_type CHECK (
        relationship_type IN ('linkedin', 'email', 'phone', 'introduction', 'other')
    )
);

COMMENT ON TABLE mutual_connections IS 'Broker mutual connections to target company decision-makers.';

-- 4. POSTS ------------------------------------------------------------------

CREATE TABLE posts (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    post_url            text        NOT NULL,
    post_type           text        DEFAULT 'linkedin',
    posted_at           timestamptz,
    content_summary     text,
    engagement_count    integer     DEFAULT 0,
    sentiment           text        DEFAULT 'neutral',
    relevant_signals    jsonb       DEFAULT '{}',
    created_at          timestamptz DEFAULT now(),

    CONSTRAINT uq_posts_url UNIQUE (post_url),
    CONSTRAINT chk_posts_type CHECK (
        post_type IN ('linkedin', 'twitter', 'newsletter', 'blog', 'press_release', 'other')
    ),
    CONSTRAINT chk_posts_engagement CHECK (engagement_count >= 0),
    CONSTRAINT chk_posts_sentiment CHECK (
        sentiment IN ('positive', 'neutral', 'negative', 'mixed')
    )
);

COMMENT ON TABLE posts IS 'Social media posts and public content from target companies.';

-- 5. LEAD SCORES ------------------------------------------------------------

CREATE TABLE lead_scores (
    id                          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id                  uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    growth_score                integer,
    space_need_score            integer,
    financial_health_score      integer,
    industry_trend_score        integer,
    decision_maker_access_score integer,
    digital_footprint_score     integer,
    funding_activity_score      integer,
    regulatory_exposure_score   integer,
    total_score                 integer,
    confidence_score            integer     DEFAULT 0,
    score_version               text        DEFAULT 'v1',
    scored_at                   timestamptz DEFAULT now(),
    created_at                  timestamptz DEFAULT now(),

    CONSTRAINT chk_growth_score CHECK (growth_score IS NULL OR (growth_score >= 0 AND growth_score <= 100)),
    CONSTRAINT chk_space_need_score CHECK (space_need_score IS NULL OR (space_need_score >= 0 AND space_need_score <= 100)),
    CONSTRAINT chk_financial_health_score CHECK (financial_health_score IS NULL OR (financial_health_score >= 0 AND financial_health_score <= 100)),
    CONSTRAINT chk_industry_trend_score CHECK (industry_trend_score IS NULL OR (industry_trend_score >= 0 AND industry_trend_score <= 100)),
    CONSTRAINT chk_decision_maker_access_score CHECK (decision_maker_access_score IS NULL OR (decision_maker_access_score >= 0 AND decision_maker_access_score <= 100)),
    CONSTRAINT chk_digital_footprint_score CHECK (digital_footprint_score IS NULL OR (digital_footprint_score >= 0 AND digital_footprint_score <= 100)),
    CONSTRAINT chk_funding_activity_score CHECK (funding_activity_score IS NULL OR (funding_activity_score IS NULL OR (funding_activity_score >= 0 AND funding_activity_score <= 100))),
    CONSTRAINT chk_regulatory_exposure_score CHECK (regulatory_exposure_score IS NULL OR (regulatory_exposure_score >= 0 AND regulatory_exposure_score <= 100)),
    CONSTRAINT chk_total_score CHECK (total_score IS NULL OR (total_score >= 0 AND total_score <= 800)),
    CONSTRAINT chk_confidence_score CHECK (confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 100))
);

COMMENT ON TABLE lead_scores IS 'Per-cycle scoring records. Each weekly pipeline run inserts new scores.';

-- 6. DECISIONS --------------------------------------------------------------

CREATE TABLE decisions (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    state               text        NOT NULL DEFAULT 'new',
    priority_band       integer     DEFAULT 3,
    entered_state_at    timestamptz DEFAULT now(),
    cooldown_until      timestamptz,
    is_watchlisted      boolean     DEFAULT false,
    decision_notes      text,
    created_at          timestamptz DEFAULT now(),
    updated_at          timestamptz DEFAULT now(),

    CONSTRAINT uq_decisions_company UNIQUE (company_id),
    CONSTRAINT chk_decisions_state CHECK (
        state IN ('new', 'qualified', 'contacted', 'meeting_booked', 'deal', 'lost', 'dormant', 'archived')
    ),
    CONSTRAINT chk_decisions_priority CHECK (
        priority_band >= 1 AND priority_band <= 5
    )
);

COMMENT ON TABLE decisions IS 'Lead decision state machine. One row per qualified lead.';
COMMENT ON COLUMN decisions.priority_band IS '1=Critical, 2=Hot, 3=Warm, 4=Cool, 5=Cold';

-- 7. EMAIL DRAFTS -----------------------------------------------------------

CREATE TABLE email_drafts (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    decision_id         uuid        REFERENCES decisions(id) ON DELETE SET NULL,
    recipient_name      text        NOT NULL,
    recipient_email     text        NOT NULL,
    recipient_title     text,
    subject             text        NOT NULL,
    body_text           text        NOT NULL,
    tone                text        DEFAULT 'professional',
    word_count          integer,
    status              text        DEFAULT 'draft',
    sent_at             timestamptz,
    opened_at           timestamptz,
    replied_at          timestamptz,
    created_at          timestamptz DEFAULT now(),
    updated_at          timestamptz DEFAULT now(),

    CONSTRAINT chk_email_status CHECK (
        status IN ('draft', 'reviewed', 'sent', 'opened', 'replied', 'bounced', 'failed')
    ),
    CONSTRAINT chk_email_tone CHECK (
        tone IN ('professional', 'warm', 'direct', 'consultative', 'follow_up')
    )
);

COMMENT ON TABLE email_drafts IS 'AI-generated email drafts for broker outreach.';

-- 8. LINKEDIN DRAFTS --------------------------------------------------------

CREATE TABLE linkedin_drafts (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    decision_id         uuid        REFERENCES decisions(id) ON DELETE SET NULL,
    recipient_name      text        NOT NULL,
    recipient_linkedin_url text,
    recipient_title     text,
    message_text        text        NOT NULL,
    connection_note     text,
    message_type        text        DEFAULT 'connection_request',
    status              text        DEFAULT 'draft',
    sent_at             timestamptz,
    replied_at          timestamptz,
    created_at          timestamptz DEFAULT now(),
    updated_at          timestamptz DEFAULT now(),

    CONSTRAINT chk_linkedin_message_type CHECK (
        message_type IN ('connection_request', 'inmail', 'follow_up', 'introduction')
    ),
    CONSTRAINT chk_linkedin_status CHECK (
        status IN ('draft', 'reviewed', 'sent', 'accepted', 'replied', 'declined', 'failed')
    )
);

COMMENT ON TABLE linkedin_drafts IS 'AI-generated LinkedIn messages for broker outreach.';

-- 9. IPCS (Institutional Property Consultants) ------------------------------

CREATE TABLE ipcs (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    ipc_name            text        NOT NULL,
    ipc_type            text        NOT NULL DEFAULT 'full_service',
    headquarters_city   text,
    headquarters_country text       DEFAULT 'India',
    website             text,
    services_offered    jsonb       DEFAULT '[]',
    coverage_cities     jsonb       DEFAULT '[]',
    key_contacts        jsonb       DEFAULT '[]',
    market_share        text,
    annual_revenue      text,
    notes               text,
    is_active           boolean     DEFAULT true,
    created_at          timestamptz DEFAULT now(),
    updated_at          timestamptz DEFAULT now(),

    CONSTRAINT uq_ipcs_name UNIQUE (ipc_name),
    CONSTRAINT chk_ipc_type CHECK (
        ipc_type IN ('full_service', 'boutique', 'specialist', 'advisory', 'occupier_rep')
    )
);

COMMENT ON TABLE ipcs IS 'Institutional Property Consultants tracked as competitive intelligence.';

-- 10. IPC MANDATES ----------------------------------------------------------

CREATE TABLE ipc_mandates (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    ipc_id              uuid        NOT NULL REFERENCES ipcs(id) ON DELETE CASCADE,
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    mandate_type        text        NOT NULL DEFAULT 'tenant_rep',
    mandate_status      text        DEFAULT 'active',
    mandate_value       text,
    start_date          date,
    end_date            date,
    notes               text,
    discovered_at       timestamptz DEFAULT now(),
    created_at          timestamptz DEFAULT now(),
    updated_at          timestamptz DEFAULT now(),

    CONSTRAINT uq_ipc_mandate UNIQUE (ipc_id, company_id, mandate_type),
    CONSTRAINT chk_mandate_type CHECK (
        mandate_type IN ('tenant_rep', 'landlord_rep', 'advisory', 'valuation', 'project_management')
    ),
    CONSTRAINT chk_mandate_status CHECK (
        mandate_status IN ('active', 'completed', 'lost', 'pending')
    )
);

COMMENT ON TABLE ipc_mandates IS 'Track which IPC has a mandate with which company.';

-- 11. OUTREACH HISTORY ------------------------------------------------------

CREATE TABLE outreach_history (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    decision_id         uuid        REFERENCES decisions(id) ON DELETE SET NULL,
    channel             text        NOT NULL,
    recipient_name      text,
    recipient_contact   text,
    message_preview     text,
    status              text        DEFAULT 'sent',
    sent_at             timestamptz DEFAULT now(),
    response_at         timestamptz,
    response_type       text,
    notes               text,
    created_at          timestamptz DEFAULT now(),

    CONSTRAINT chk_outreach_channel CHECK (
        channel IN ('email', 'linkedin', 'phone', 'introduction', 'event', 'other')
    ),
    CONSTRAINT chk_outreach_status CHECK (
        status IN ('draft', 'sent', 'delivered', 'opened', 'replied', 'bounced', 'failed', 'scheduled')
    ),
    CONSTRAINT chk_outreach_response CHECK (
        response_type IN ('positive', 'neutral', 'negative', 'no_response', 'meeting_booked')
    )
);

COMMENT ON TABLE outreach_history IS 'Audit trail of all broker outreach attempts.';

-- 12. COST LOG --------------------------------------------------------------

CREATE TABLE cost_log (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        REFERENCES companies(id) ON DELETE SET NULL,
    pipeline_run_id     text,
    layer_id            text        NOT NULL,
    model_used          text,
    cost_cents          integer     NOT NULL DEFAULT 0,
    tokens_used         integer     DEFAULT 0,
    source_type         text,
    operation_count     integer     DEFAULT 1,
    metadata            jsonb       DEFAULT '{}',
    recorded_at         timestamptz DEFAULT now(),

    CONSTRAINT chk_cost_cents CHECK (cost_cents >= 0),
    CONSTRAINT chk_cost_tokens CHECK (tokens_used >= 0)
);

COMMENT ON TABLE cost_log IS 'Per-layer, per-company cost tracking for budget monitoring.';

-- 13. AUDIT LOG -------------------------------------------------------------

CREATE TABLE audit_log (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name          text        NOT NULL,
    record_id           text        NOT NULL,
    operation           text        NOT NULL,
    old_data            jsonb,
    new_data            jsonb,
    changed_by          text        DEFAULT 'system',
    changed_at          timestamptz DEFAULT now(),

    CONSTRAINT chk_audit_operation CHECK (
        operation IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
    )
);

COMMENT ON TABLE audit_log IS 'Append-only log of all data changes across tracked tables.';

-- 14. COMPANIES SNAPSHOTS (change detection) --------------------------------

CREATE TABLE companies_snapshots (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    sha256_hash         text        NOT NULL,
    snapshot_data       jsonb       NOT NULL,
    captured_at         timestamptz DEFAULT now()
);

COMMENT ON TABLE companies_snapshots IS 'Weekly SHA-256 snapshots of company signals for change detection.';

-- 15. EVIDENCE CLAIMS -------------------------------------------------------

CREATE TABLE evidence_claims (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    claim_text          text        NOT NULL,
    claim_category      text        NOT NULL,
    confidence_score    integer     DEFAULT 0,
    source_count        integer     DEFAULT 0,
    is_verified         boolean     DEFAULT false,
    created_at          timestamptz DEFAULT now(),

    CONSTRAINT chk_claim_confidence CHECK (confidence_score >= 0 AND confidence_score <= 100),
    CONSTRAINT chk_claim_source_count CHECK (source_count >= 0),
    CONSTRAINT chk_claim_category CHECK (
        claim_category IN ('growth', 'space', 'financial', 'team', 'technology',
                           'funding', 'regulatory', 'product', 'market', 'other')
    )
);

COMMENT ON TABLE evidence_claims IS 'Individual factual claims extracted by AI agents.';

-- 16. EVIDENCE SOURCES ------------------------------------------------------

CREATE TABLE evidence_sources (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id            uuid        NOT NULL REFERENCES evidence_claims(id) ON DELETE CASCADE,
    source_url          text        NOT NULL,
    source_type         text        NOT NULL,
    reliability_tier    integer     DEFAULT 3,
    extracted_content   text,
    captured_at         timestamptz DEFAULT now(),

    CONSTRAINT chk_source_reliability CHECK (reliability_tier >= 1 AND reliability_tier <= 5),
    CONSTRAINT chk_source_type CHECK (
        source_type IN ('website', 'news', 'linkedin', 'crunchbase', 'twitter',
                        'blog', 'press_release', 'government', 'financial', 'other')
    )
);

COMMENT ON TABLE evidence_sources IS 'Source URLs backing each evidence claim.';

-- 17. EVIDENCE SNAPSHOTS ----------------------------------------------------

CREATE TABLE evidence_snapshots (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          uuid        NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    bundle              jsonb       NOT NULL,
    sha256_hash         text        NOT NULL,
    captured_at         timestamptz DEFAULT now()
);

COMMENT ON TABLE evidence_snapshots IS 'Immutable timestamped bundles of all evidence per scoring cycle.';

-- 18. LEAD EVENTS -----------------------------------------------------------

CREATE TABLE lead_events (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    decision_id         uuid        NOT NULL REFERENCES decisions(id) ON DELETE CASCADE,
    event_type          text        NOT NULL,
    old_state           text,
    new_state           text,
    metadata            jsonb       DEFAULT '{}',
    occurred_at         timestamptz DEFAULT now(),

    CONSTRAINT chk_event_type CHECK (
        event_type IN ('state_changed', 'contacted', 'meeting_booked', 'note_added',
                       'cooldown_expired', 'change_detected', 'score_updated',
                       'watchlist_added', 'watchlist_removed', 'cost_gate_check',
                       'layer_1', 'layer_2', 'layer_3', 'layer_4', 'layer_5')
    )
);

COMMENT ON TABLE lead_events IS 'Immutable event log for lead state transitions and pipeline events.';

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
