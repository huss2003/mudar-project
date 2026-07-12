-- =============================================================================
-- 002-full-migration.sql
-- Layer 0 — Autonomous Lead Acquisition System
-- Safe migration: all CREATEs use IF NOT EXISTS, all ALTERs use IF NOT EXISTS
-- Will NOT destroy existing data
-- =============================================================================

-- =============================================================================
-- Section 1: Layer 0 — Autonomous Lead Acquisition Tables
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1.1 ICP Profiles - defines Ideal Customer Profile
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS icp_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  industry TEXT[] NOT NULL,  -- multiple industries
  country TEXT[],
  employee_min INTEGER,
  employee_max INTEGER,
  revenue_min NUMERIC,
  revenue_max NUMERIC,
  business_types TEXT[],  -- distributor, manufacturer, etc
  decision_maker_roles TEXT[],  -- owner, ceo, cto, etc
  keywords TEXT[],  -- search keywords
  excluded_keywords TEXT[],  -- things to exclude
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.2 Discovery Sources - registry of available sources
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS discovery_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,  -- google_maps, tradeindia, indiamart, etc
  source_type TEXT NOT NULL,  -- search, directory, api, rss, scrape
  base_url TEXT,
  auth_type TEXT,  -- none, apikey, oauth
  rate_limit_rph INTEGER,  -- requests per hour
  priority INTEGER DEFAULT 50,  -- 0-100, higher = better
  expected_quality INTEGER DEFAULT 50,  -- 0-100
  cost_per_request NUMERIC(10,6) DEFAULT 0,
  failure_rate NUMERIC(5,2) DEFAULT 0,  -- 0-100
  coverage TEXT[],  -- countries, industries covered
  is_free BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  last_checked TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed discovery sources (safe insert - skips existing)
INSERT INTO discovery_sources (name, source_type, base_url, auth_type, rate_limit_rph, priority, expected_quality, coverage)
SELECT * FROM (VALUES
  ('google_maps', 'scrape', 'https://www.google.com/maps', 'firecrawl', 60, 90, 85, ARRAY['global']),
  ('google_search', 'search', 'https://www.google.com/search', 'firecrawl', 60, 85, 75, ARRAY['global']),
  ('bing_search', 'search', 'https://www.bing.com/search', 'none', 30, 60, 60, ARRAY['global']),
  ('github', 'api', 'https://api.github.com', 'none', 60, 70, 70, ARRAY['global']),
  ('tradeindia', 'directory', 'https://www.tradeindia.com', 'none', 30, 50, 50, ARRAY['India']),
  ('indiamart', 'directory', 'https://www.indiamart.com', 'none', 30, 65, 60, ARRAY['India']),
  ('justdial', 'directory', 'https://www.justdial.com', 'none', 30, 55, 55, ARRAY['India']),
  ('yellow_pages', 'directory', 'https://www.yellowpages.com', 'none', 30, 50, 50, ARRAY['US']),
  ('clutch', 'directory', 'https://clutch.co', 'none', 30, 75, 80, ARRAY['global']),
  ('goodfirms', 'directory', 'https://www.goodfirms.co', 'none', 30, 60, 60, ARRAY['global']),
  ('opencorporates', 'api', 'https://api.opencorporates.com', 'none', 30, 70, 80, ARRAY['global']),
  ('google_rss', 'rss', 'https://news.google.com/rss', 'none', 100, 50, 40, ARRAY['global']),
  ('internet_archive', 'api', 'https://archive.org/wayback', 'none', 360, 60, 70, ARRAY['global'])
) AS v(name, source_type, base_url, auth_type, rate_limit_rph, priority, expected_quality, coverage)
WHERE NOT EXISTS (SELECT 1 FROM discovery_sources WHERE name = v.name);

-- ---------------------------------------------------------------------------
-- 1.3 Planner Runs - each discovery cycle
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS planner_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  icp_id UUID REFERENCES icp_profiles(id),
  status TEXT DEFAULT 'planning',  -- planning, executing, completed, failed
  source_plan JSONB,  -- which sources to use, in order
  query_plan JSONB,  -- which queries to execute
  companies_found INTEGER DEFAULT 0,
  companies_accepted INTEGER DEFAULT 0,
  companies_rejected INTEGER DEFAULT 0,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  cost_cents NUMERIC(10,4) DEFAULT 0
);

-- ---------------------------------------------------------------------------
-- 1.4 Planner Decisions - every AI planner decision
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS planner_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  planner_run_id UUID REFERENCES planner_runs(id),
  iteration INTEGER NOT NULL,
  action TEXT NOT NULL,  -- SELECT_SOURCE, GENERATE_QUERIES, SEARCH, NORMALIZE, VALIDATE, CONTINUE, REJECT
  source_used TEXT,
  query_used TEXT,
  result_summary TEXT,
  companies_found INTEGER,
  confidence_before NUMERIC(5,2),
  confidence_after NUMERIC(5,2),
  tokens_used INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.5 Search Queries - all generated queries
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS search_queries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  planner_run_id UUID REFERENCES planner_runs(id),
  query_text TEXT NOT NULL,
  source TEXT NOT NULL,
  intent TEXT,  -- industry, location, keyword, synonym
  results_count INTEGER,
  quality_score NUMERIC(5,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.6 Raw Companies - discovered but not yet normalized
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  planner_run_id UUID REFERENCES planner_runs(id),
  source TEXT NOT NULL,
  query_used TEXT,
  company_name TEXT NOT NULL,
  website TEXT,
  address TEXT,
  phone TEXT,
  industry TEXT,
  description TEXT,
  category TEXT,
  raw_data JSONB,  -- full source response
  discovered_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_source ON raw_companies(source);

-- ---------------------------------------------------------------------------
-- 1.7 Normalized Companies - after domain normalization
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS normalized_companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  raw_company_id UUID REFERENCES raw_companies(id),
  planner_run_id UUID REFERENCES planner_runs(id),
  company_name TEXT NOT NULL,
  normalized_name TEXT NOT NULL,  -- lowercased, stripped legal suffixes
  domain TEXT UNIQUE,  -- canonical domain
  original_url TEXT,
  address TEXT,
  phone TEXT,
  industry TEXT,
  description TEXT,
  validation_status TEXT DEFAULT 'pending',  -- pending, valid, invalid, duplicate
  validation_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_norm_domain ON normalized_companies(domain);
CREATE INDEX IF NOT EXISTS idx_norm_name ON normalized_companies(normalized_name);

-- ---------------------------------------------------------------------------
-- 1.8 Duplicate Matches
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS duplicate_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_a_id UUID REFERENCES normalized_companies(id),
  company_b_id UUID REFERENCES normalized_companies(id),
  similarity_score NUMERIC(5,2),  -- 0-100
  match_type TEXT,  -- exact_domain, fuzzy_name, same_phone, same_address
  resolved BOOLEAN DEFAULT false,
  resolved_company_id UUID,  -- which survives
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.9 Domain Validation Results
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS domain_validation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  normalized_company_id UUID REFERENCES normalized_companies(id),
  domain TEXT NOT NULL,
  has_dns BOOLEAN,
  has_website BOOLEAN,
  http_status INTEGER,
  has_https BOOLEAN,
  title TEXT,
  description TEXT,
  domain_age_days INTEGER,
  registrar TEXT,
  is_parked BOOLEAN,
  is_social_media BOOLEAN,
  is_marketplace BOOLEAN,
  quality_score INTEGER,  -- 0-100
  checked_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.10 Initial Qualification Scores
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS initial_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  normalized_company_id UUID REFERENCES normalized_companies(id),
  criteria_scores JSONB,  -- { "website_exists": 100, "has_https": 100, ... }
  composite_score INTEGER,  -- 0-100
  confidence NUMERIC(5,2),
  passed_threshold BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.11 Source Statistics - learning system
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS source_statistics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_name TEXT NOT NULL,
  planner_run_id UUID REFERENCES planner_runs(id),
  queries_executed INTEGER DEFAULT 0,
  companies_found INTEGER DEFAULT 0,
  companies_accepted INTEGER DEFAULT 0,
  companies_rejected INTEGER DEFAULT 0,
  duplicate_rate NUMERIC(5,2),
  avg_quality_score NUMERIC(5,2),
  avg_confidence NUMERIC(5,2),
  total_cost_cents NUMERIC(10,4) DEFAULT 0,
  latency_seconds INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.12 Score Signal Groups - explainable scoring
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS signal_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  default_weight NUMERIC(5,2) NOT NULL,  -- 0-100
  is_active BOOLEAN DEFAULT true
);

INSERT INTO signal_groups (name, description, default_weight)
SELECT * FROM (VALUES
  ('business_legitimacy', 'Domain age, HTTPS, official email, registration', 15),
  ('digital_presence', 'Website quality, SEO, tech stack, social activity', 10),
  ('growth_indicators', 'Hiring, new locations, funding, press releases', 15),
  ('pain_indicators', 'Outdated tech, missing security, no analytics', 5),
  ('buying_intent', 'Expansion, migration, tech replacement', 20),
  ('tech_compatibility', 'Framework, cloud, CRM, language match', 10),
  ('evidence_quality', 'Source reliability, independent confirmations', 15),
  ('freshness', 'Recent activity, news, commits, updates', 10)
) AS v(name, description, default_weight)
WHERE NOT EXISTS (SELECT 1 FROM signal_groups WHERE name = v.name);

-- ---------------------------------------------------------------------------
-- 1.13 Scoring Weights (evolveable)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scoring_weights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  signal_group_id UUID REFERENCES signal_groups(id),
  industry TEXT,
  country TEXT,
  company_size TEXT,
  weight NUMERIC(5,2) NOT NULL,
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.14 Scoring Outcomes - track actual results
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS scoring_outcomes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID,
  score_data JSONB,  -- full score breakdown
  outcome TEXT,  -- meeting, proposal, won, lost
  outcome_value NUMERIC,  -- revenue if won
  sales_feedback TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------------------------------------------------------------------------
-- 1.15 Observability Events
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS observability_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id TEXT,
  company_id UUID,
  event_type TEXT NOT NULL,  -- discovery, extraction, scoring, planner, cache, validation
  source TEXT,
  model_used TEXT,
  latency_ms INTEGER,
  tokens_used INTEGER,
  cost_cents NUMERIC(10,4),
  confidence NUMERIC(5,2),
  cache_hit BOOLEAN,
  metadata JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_obs_run ON observability_events(run_id);
CREATE INDEX IF NOT EXISTS idx_obs_type ON observability_events(event_type);
CREATE INDEX IF NOT EXISTS idx_obs_created ON observability_events(created_at);

-- =============================================================================
-- Section 2: Functions & Triggers
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 2.1 Trigger function for updated_at
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 2.2 Apply triggers to tables with updated_at column
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY['icp_profiles'])
  LOOP
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = tbl) THEN
      IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'set_' || tbl || '_updated_at') THEN
        EXECUTE format('CREATE TRIGGER set_%s_updated_at BEFORE UPDATE ON %s FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at()', tbl, tbl);
      END IF;
    END IF;
  END LOOP;
END;
$$;

-- =============================================================================
-- Section 3: Existing Table Migrations
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 3.1 Add Layer 0 columns to existing scenario_queue
-- ---------------------------------------------------------------------------
ALTER TABLE scenario_queue ADD COLUMN IF NOT EXISTS icp_id UUID;
ALTER TABLE scenario_queue ADD COLUMN IF NOT EXISTS acquisition_source TEXT;
ALTER TABLE scenario_queue ADD COLUMN IF NOT EXISTS initial_score INTEGER;
ALTER TABLE scenario_queue ADD COLUMN IF NOT EXISTS initial_confidence NUMERIC(5,2);
