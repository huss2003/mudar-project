-- ============================================================================
-- Jasfo Lead Intelligence Platform — Seed Data
-- Supabase PostgreSQL 16
-- ============================================================================
-- Sample data for development and testing. Includes IPC competitors (CBRE,
-- JLL, Cushman), sample companies, a broker profile, and test scenarios.
-- All UUIDs are static for reproducibility. Use in dev/staging only.
-- ============================================================================

-- 0. HELPER: avoid duplicate inserts if re-running --------------------------

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM companies LIMIT 1) THEN
        RAISE NOTICE 'Database already seeded. Skipping.';
        RETURN;
    END IF;
END $$;

-- 1. COMPANIES ---------------------------------------------------------------

INSERT INTO companies (id, company_name, domain, industry, employee_range, revenue_range, headquarters_city, founded_year, description) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'TechNova Solutions',    'technova.in',        'Information Technology', '201-500',   '$50M-$100M',  'Pune',         2015, 'Enterprise SaaS platform for supply chain optimization.'),
    ('a0000000-0000-0000-0000-000000000002', 'GreenBuild Innovations', 'greenbuild.tech',     'Construction Technology', '51-200',    '$10M-$50M',   'Mumbai',       2018, 'Sustainable building materials marketplace.'),
    ('a0000000-0000-0000-0000-000000000003', 'FinLeap India',          'finleap.in',         'Financial Services',     '501-1000',  '$100M-$500M', 'Bangalore',    2010, 'Digital lending and credit infrastructure platform.'),
    ('a0000000-0000-0000-0000-000000000004', 'MediSync Health',        'medisync.health',    'Healthcare Technology',  '201-500',   '$50M-$100M',  'Hyderabad',    2017, 'Hospital management and patient data platform.'),
    ('a0000000-0000-0000-0000-000000000005', 'CloudBase Systems',      'cloudbase.io',       'Cloud Infrastructure',   '1001-5000', '$500M+',      'Bangalore',    2008, 'Cloud hosting and DevOps platform for enterprises.'),
    ('a0000000-0000-0000-0000-000000000006', 'Astra Robotics',         'astrarobotics.in',   'Robotics & Automation',  '51-200',    '$10M-$50M',   'Chennai',      2019, 'Industrial robotics and warehouse automation.'),
    ('a0000000-0000-0000-0000-000000000007', 'Vayu Energy',            'vayuenergy.com',     'Clean Energy',           '201-500',   '$50M-$100M',  'Delhi',        2013, 'Solar and wind energy infrastructure developer.'),
    ('a0000000-0000-0000-0000-000000000008', 'DigiEdu Learning',       'digiedu.in',         'EdTech',                 '51-200',    '$10M-$50M',   'Pune',         2020, 'Online learning platform for K-12 and vocational skills.');

-- 2. PROFILES ----------------------------------------------------------------

INSERT INTO profiles (company_id, linkedin_url, crunchbase_url, naics_code, scrape_status) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'https://linkedin.com/company/technova', 'https://crunchbase.com/organization/technova', '541511', 'completed'),
    ('a0000000-0000-0000-0000-000000000002', 'https://linkedin.com/company/greenbuild', NULL, '236220', 'completed'),
    ('a0000000-0000-0000-0000-000000000003', 'https://linkedin.com/company/finleap', 'https://crunchbase.com/organization/finleap', '522390', 'completed'),
    ('a0000000-0000-0000-0000-000000000005', 'https://linkedin.com/company/cloudbase', 'https://crunchbase.com/organization/cloudbase', '518210', 'completed');

-- 3. MUTUAL CONNECTIONS ------------------------------------------------------

INSERT INTO mutual_connections (company_id, connection_name, connection_title, relationship_type, connection_strength) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Rajesh Patel', 'VP Engineering at TechNova', 'linkedin', 3),
    ('a0000000-0000-0000-0000-000000000003', 'Anita Desai',  'CFO at FinLeap India',       'linkedin', 4),
    ('a0000000-0000-0000-0000-000000000005', 'Vikram Singh', 'CTO at CloudBase Systems',    'introduction', 5);

-- 4. POSTS -------------------------------------------------------------------

INSERT INTO posts (company_id, post_url, post_type, posted_at, content_summary, engagement_count, sentiment) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'https://linkedin.com/company/technova/posts/1', 'linkedin', now() - interval '3 days',  'Announced new warehouse management product', 245, 'positive'),
    ('a0000000-0000-0000-0000-000000000003', 'https://linkedin.com/company/finleap/posts/1', 'press_release', now() - interval '7 days', 'Raised $30M Series C led by Sequoia', 512, 'positive'),
    ('a0000000-0000-0000-0000-000000000005', 'https://linkedin.com/company/cloudbase/posts/1', 'linkedin', now() - interval '1 day', 'Opened new office in Hyderabad', 189, 'positive');

-- 5. LEAD SCORES -------------------------------------------------------------

INSERT INTO lead_scores (company_id, growth_score, space_need_score, financial_health_score, industry_trend_score, decision_maker_access_score, digital_footprint_score, funding_activity_score, regulatory_exposure_score, total_score, confidence_score) VALUES
    ('a0000000-0000-0000-0000-000000000001', 78, 65, 82, 74, 55, 80, 45, 30, 509, 78),
    ('a0000000-0000-0000-0000-000000000003', 90, 72, 85, 80, 60, 75, 90, 55, 607, 85),
    ('a0000000-0000-0000-0000-000000000005', 85, 45, 95, 82, 70, 95, 40, 50, 562, 90),
    ('a0000000-0000-0000-0000-000000000002', 60, 80, 45, 65, 40, 50, 70, 35, 445, 55);

-- 6. DECISIONS ---------------------------------------------------------------

INSERT INTO decisions (company_id, state, priority_band, is_watchlisted) VALUES
    ('a0000000-0000-0000-0000-000000000003', 'qualified', 1, false),
    ('a0000000-0000-0000-0000-000000000001', 'qualified', 2, false),
    ('a0000000-0000-0000-0000-000000000005', 'new',       3, true),
    ('a0000000-0000-0000-0000-000000000002', 'new',       4, false);

-- 7. EMAIL DRAFTS ------------------------------------------------------------

INSERT INTO email_drafts (company_id, recipient_name, recipient_email, recipient_title, subject, body_text, tone, status) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'Priya Sharma', 'priya@technova.in', 'CEO', 'Exploring Office Space Options for TechNova',
     'Hi Priya, I noticed TechNova has been growing rapidly. Are you currently exploring new office space options in Pune? I specialize in helping tech companies find the right space for their teams. Happy to share some options.', 'consultative', 'draft'),
    ('a0000000-0000-0000-0000-000000000003', 'Anita Desai', 'anita@finleap.in', 'CFO', 'Office Expansion Planning for FinLeap',
     'Hi Anita, with FinLeap recent $30M Series C, I imagine you are planning for growth. I would love to discuss how we can help with your office space strategy in Bangalore.', 'professional', 'draft');

-- 8. LINKEDIN DRAFTS ---------------------------------------------------------

INSERT INTO linkedin_drafts (company_id, recipient_name, recipient_linkedin_url, recipient_title, message_text, message_type, status) VALUES
    ('a0000000-0000-0000-0000-000000000005', 'Vikram Singh', 'https://linkedin.com/in/vikramsingh', 'CTO', 'Hi Vikram, congratulations on CloudBase new Hyderabad office! Always happy to connect with fellow tech leaders.', 'connection_request', 'draft');

-- 9. IPCS (Institutional Property Consultants) -------------------------------

INSERT INTO ipcs (id, ipc_name, ipc_type, headquarters_city, website, services_offered, coverage_cities, notes) VALUES
    ('b0000000-0000-0000-0000-000000000001', 'CBRE Group',           'full_service', 'Mumbai',   'https://www.cbre.co.in',
     '["tenant_representation", "property_management", "valuation", "investment_sales", "project_management"]',
     '["Mumbai", "Delhi", "Bangalore", "Pune", "Hyderabad", "Chennai"]',
     'Global leader. Strong in office leasing across all major Indian markets.'),
    ('b0000000-0000-0000-0000-000000000002', 'JLL (Jones Lang LaSalle)', 'full_service', 'Mumbai', 'https://www.jll.co.in',
     '["tenant_representation", "landlord_representation", "facility_management", "investment_advisory", "project_management"]',
     '["Mumbai", "Delhi", "Bangalore", "Pune", "Hyderabad", "Chennai", "Kolkata"]',
     'Strong occupier services and facility management practice.'),
    ('b0000000-0000-0000-0000-000000000003', 'Cushman & Wakefield',   'full_service', 'Mumbai',   'https://www.cushmanwakefield.com/en/india',
     '["tenant_representation", "landlord_representation", "valuation", "investment_sales", "research"]',
     '["Mumbai", "Delhi", "Bangalore", "Pune", "Hyderabad"]',
     'Strong research and advisory practice. Key competitor in Pune market.'),
    ('b0000000-0000-0000-0000-000000000004', 'Colliers International', 'full_service', 'Mumbai', 'https://www.colliers.com/en-in',
     '["tenant_representation", "property_management", "valuation", "investment_sales", "project_management"]',
     '["Mumbai", "Delhi", "Bangalore", "Pune"]',
     'Growing presence in Indian market.'),
    ('b0000000-0000-0000-0000-000000000005', 'Knight Frank India',     'full_service', 'Mumbai',   'https://www.knightfrank.co.in',
     '["tenant_representation", "valuation", "investment_sales", "research", "property_management"]',
     '["Mumbai", "Delhi", "Bangalore", "Pune", "Hyderabad", "Chennai"]',
     'Strong residential and commercial research division.');

-- 10. IPC MANDATES -----------------------------------------------------------

INSERT INTO ipc_mandates (ipc_id, company_id, mandate_type, mandate_status, notes) VALUES
    ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'tenant_rep', 'active', 'CBRE representing FinLeap for Bangalore office search'),
    ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000005', 'tenant_rep', 'active', 'JLL handling CloudBase Hyderabad expansion'),
    ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'tenant_rep', 'lost',   'Cushman pitched TechNova but lost to boutique firm');

-- 11. OUTREACH HISTORY -------------------------------------------------------

INSERT INTO outreach_history (company_id, channel, recipient_name, recipient_contact, message_preview, status, sent_at, response_at, response_type) VALUES
    ('a0000000-0000-0000-0000-000000000001', 'email', 'Priya Sharma', 'priya@technova.in', 'Exploring office space options for TechNova', 'sent', now() - interval '5 days', NULL, NULL),
    ('a0000000-0000-0000-0000-000000000003', 'linkedin', 'Anita Desai', 'https://linkedin.com/in/anitadesai', 'Congratulations on the Series C funding', 'replied', now() - interval '2 days', now() - interval '1 day', 'positive');

-- 12. COST LOG ---------------------------------------------------------------

INSERT INTO cost_log (company_id, pipeline_run_id, layer_id, model_used, cost_cents, tokens_used, source_type) VALUES
    (NULL, 'run-001', 'layer_1', 'firecrawl',   0,     0,    'scrape'),
    (NULL, 'run-001', 'layer_2', 'deepseek',    5,     1500, 'ai_inference'),
    (NULL, 'run-001', 'layer_3', 'mimo',        15,    3200, 'ai_inference'),
    (NULL, 'run-001', 'layer_4', 'deepseek',    3,     800,  'ai_inference'),
    (NULL, 'run-001', 'layer_5', 'deepseek',    12,    4000, 'ai_inference'),
    (NULL, 'run-001', 'cost_gate', NULL,         0,     0,    'internal');

-- 13. LEAD EVENTS ------------------------------------------------------------

INSERT INTO lead_events (decision_id, event_type, old_state, new_state, metadata) VALUES
    ((SELECT id FROM decisions WHERE company_id = 'a0000000-0000-0000-0000-000000000003'), 'state_changed', 'new', 'qualified',
     '{"trigger": "scoring_complete", "total_score": 607, "confidence": 85}'),
    ((SELECT id FROM decisions WHERE company_id = 'a0000000-0000-0000-0000-000000000001'), 'state_changed', 'new', 'qualified',
     '{"trigger": "scoring_complete", "total_score": 509, "confidence": 78}'),
    ((SELECT id FROM decisions WHERE company_id = 'a0000000-0000-0000-0000-000000000003'), 'contacted', 'qualified', 'contacted',
     '{"channel": "linkedin", "contacted_by": "broker"}');

-- 14. EVIDENCE CLAIMS & SOURCES ----------------------------------------------

INSERT INTO evidence_claims (company_id, claim_text, claim_category, confidence_score, source_count, is_verified) VALUES
    ('a0000000-0000-0000-0000-000000000003', 'FinLeap raised $30M Series C in July 2026', 'funding', 95, 2, true),
    ('a0000000-0000-0000-0000-000000000001', 'TechNova hired 150+ employees in Q2 2026', 'growth', 80, 1, false),
    ('a0000000-0000-0000-0000-000000000005', 'CloudBase opened new Hyderabad office in July 2026', 'space', 90, 2, true);

INSERT INTO evidence_sources (claim_id, source_url, source_type, reliability_tier) VALUES
    ((SELECT id FROM evidence_claims WHERE claim_text LIKE '%$30M Series C%'), 'https://techcrunch.com/2026/07/finleap-series-c', 'news', 1),
    ((SELECT id FROM evidence_claims WHERE claim_text LIKE '%$30M Series C%'), 'https://crunchbase.com/organization/finleap', 'crunchbase', 1),
    ((SELECT id FROM evidence_claims WHERE claim_text LIKE '%Hyderabad office%'), 'https://linkedin.com/company/cloudbase/posts/1', 'linkedin', 2),
    ((SELECT id FROM evidence_claims WHERE claim_text LIKE '%Hyderabad office%'), 'https://cloudbase.io/blog/new-hyderabad-office', 'blog', 2);

-- 15. COMPANIES SNAPSHOTS ----------------------------------------------------

INSERT INTO companies_snapshots (company_id, sha256_hash, snapshot_data)
SELECT
    c.id,
    encode(hmac(
        coalesce(c.employee_range, '') ||
        coalesce(c.revenue_range, '') ||
        coalesce(c.description, '') ||
        coalesce(c.tech_stack::text, '') ||
        coalesce(c.management_team::text, ''),
        c.id::text, 'SHA256'
    ), 'hex'),
    jsonb_build_object(
        'employee_range', c.employee_range,
        'revenue_range', c.revenue_range,
        'description', c.description,
        'tech_stack', c.tech_stack,
        'management_team', c.management_team,
        'industry', c.industry
    )
FROM companies c;

-- 16. EVIDENCE SNAPSHOTS -----------------------------------------------------

INSERT INTO evidence_snapshots (company_id, bundle, sha256_hash)
SELECT
    ec.company_id,
    jsonb_build_object(
        'scored_at', now(),
        'claim_count', COUNT(DISTINCT ec.id),
        'source_count', COUNT(DISTINCT es.id),
        'claims', jsonb_agg(DISTINCT ec.claim_text)
    ),
    encode(hmac(now()::text, ec.company_id::text, 'SHA256'), 'hex')
FROM evidence_claims ec
LEFT JOIN evidence_sources es ON es.claim_id = ec.id
GROUP BY ec.company_id;

-- ============================================================================
-- END OF SEED DATA
-- ============================================================================
