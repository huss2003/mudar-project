-- ============================================================================
-- Jasfo v2 — Evidence-Based Extraction & Autonomous Planning Schema
-- Supabase PostgreSQL 16 | public schema
-- ============================================================================
-- Migration: 001-schema.sql
-- This migration introduces the v2 data model centered on:
--   • Evidence-based extraction with confidence scoring
--   • Multi-model verification and agreement tracking
--   • Autonomous planner decision logging
--   • Source caching with ETag/hash deduplication
--   • Comprehensive observability for cost, latency, and hallucination tracking
-- ============================================================================

-- 0. EXTENSIONS --------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. UPDATED_AT TRIGGER HELPER ------------------------------------------------
-- Reusable trigger function that sets updated_at = NOW() on row modification.

CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_set_updated_at() IS
  'Sets updated_at to NOW() on every row UPDATE. Attach via: CREATE TRIGGER ... EXECUTE FUNCTION trigger_set_updated_at()';

-- 2. COMPANIES (v2) ----------------------------------------------------------
-- Core company registry with deduplication support. Replaces the v1 companies
-- table with a canonical-domain key and array-based name variant tracking.

CREATE TABLE IF NOT EXISTS companies (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_domain   TEXT        UNIQUE NOT NULL,
  registered_names  TEXT[]      NOT NULL,    -- all known name variants ('Google', 'Google LLC', 'Alphabet Inc')
  normalized_name   TEXT        NOT NULL,    -- cleaned, de‑branded canonical name for fuzzy matching
  status            TEXT        DEFAULT 'active',  -- active | merged | duplicate
  merged_into       UUID        REFERENCES companies(id) ON DELETE SET NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT chk_companies_status CHECK (
    status IN ('active', 'merged', 'duplicate')
  )
);

COMMENT ON TABLE companies IS
  'Core company registry — v2. Uses canonical_domain as the dedup key.';
COMMENT ON COLUMN companies.canonical_domain IS
  'Primary domain (lowercase, no www). Used as the external deduplication identifier.';
COMMENT ON COLUMN companies.registered_names IS
  'All known legal/trading name variants for this entity.';
COMMENT ON COLUMN companies.normalized_name IS
  'Cleaned, lowercase, stopword‑stripped name for fuzzy matching against other records.';

CREATE INDEX IF NOT EXISTS idx_companies_domain
  ON companies (canonical_domain);

CREATE INDEX IF NOT EXISTS idx_companies_status
  ON companies (status)
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_companies_normalized_name
  ON companies (normalized_name);

-- updated_at trigger
CREATE TRIGGER trg_companies_updated_at
  BEFORE UPDATE ON companies
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- 3. EVIDENCE_STORE ----------------------------------------------------------
-- Every extracted piece of information is stored as an evidence envelope.
-- Supports field‑level extraction tracking, confidence scoring, source
-- provenance, and active/inactive lifecycle (superseded extractions).

CREATE TABLE IF NOT EXISTS evidence_store (
  id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  field_path        TEXT            NOT NULL,      -- e.g. company.employee_count, products.0.name
  value             JSONB,                         -- the actual extracted value (integer, string, array, …)
  confidence        NUMERIC(5,2)    NOT NULL CHECK (confidence >= 0 AND confidence <= 100),
  source            TEXT            NOT NULL,      -- website | github | crtsh | whois | news | linkedin | …
  evidence          TEXT,                           -- verbatim text from the source proving the value
  source_url        TEXT,
  extracted_by      TEXT            NOT NULL,      -- rule_engine | deepseek | mimo | planner
  model_used        TEXT,                           -- deepseek‑v4‑flash | mimo‑v2.5 | regex | …
  prompt_version    TEXT,
  retrieved_at      TIMESTAMPTZ     DEFAULT NOW(),
  is_active         BOOLEAN         DEFAULT TRUE,  -- FALSE if superseded by a newer extraction
  UNIQUE (company_id, field_path, extracted_by, retrieved_at)
);

COMMENT ON TABLE evidence_store IS
  'Every extracted piece of information, stored as a versioned evidence envelope.';
COMMENT ON COLUMN evidence_store.field_path IS
  'Dot‑notation path into the company data model, e.g. company.employee_count or products.0.name';
COMMENT ON COLUMN evidence_store.value IS
  'The actual extracted value normalised to JSONB (integer, text, array, object).';
COMMENT ON COLUMN evidence_store.confidence IS
  '0‑100 confidence that this extraction is correct.';
COMMENT ON COLUMN evidence_store.evidence IS
  'Verbatim excerpt from the source that proves the value.';
COMMENT ON COLUMN evidence_store.is_active IS
  'TRUE = current; FALSE = this row was superseded by a later extraction of the same field.';

CREATE INDEX IF NOT EXISTS idx_evidence_company
  ON evidence_store (company_id);

CREATE INDEX IF NOT EXISTS idx_evidence_field
  ON evidence_store (field_path);

CREATE INDEX IF NOT EXISTS idx_evidence_active
  ON evidence_store (company_id, is_active)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_evidence_company_field_active
  ON evidence_store (company_id, field_path)
  WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_evidence_source
  ON evidence_store (source);

CREATE INDEX IF NOT EXISTS idx_evidence_retrieved
  ON evidence_store (retrieved_at DESC);

-- 4. EXTRACTION_RUNS ---------------------------------------------------------
-- Tracks each extraction attempt with cost, latency, and multi‑model
-- agreement metadata.

CREATE TABLE IF NOT EXISTS extraction_runs (
  id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  extractor_type    TEXT            NOT NULL,      -- facts | products | technology | hiring | growth | decision_makers | financial | contact
  model_used        TEXT,
  prompt_version    TEXT,
  input_tokens      INTEGER,
  output_tokens     INTEGER,
  latency_ms        INTEGER,
  cost_cents        NUMERIC(10,4),
  status            TEXT            DEFAULT 'pending',  -- pending | success | failed | retry
  error_message     TEXT,
  agreement_score   NUMERIC(5,2),                      -- 0‑100, multi‑model agreement
  created_at        TIMESTAMPTZ     DEFAULT NOW()
);

COMMENT ON TABLE extraction_runs IS
  'Every extraction attempt — used for cost tracking, latency analysis, and model comparison.';
COMMENT ON COLUMN extraction_runs.agreement_score IS
  '0‑100 agreement between multiple models that extracted this field. NULL if only one model ran.';

CREATE INDEX IF NOT EXISTS idx_extraction_runs_company
  ON extraction_runs (company_id);

CREATE INDEX IF NOT EXISTS idx_extraction_runs_status
  ON extraction_runs (status);

CREATE INDEX IF NOT EXISTS idx_extraction_runs_company_created
  ON extraction_runs (company_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_extraction_runs_type
  ON extraction_runs (extractor_type);

-- 5. PLANNER_DECISIONS -------------------------------------------------------
-- Every decision made by the AI planner: which search action to take, which
-- source was queried, and whether confidence improved.

CREATE TABLE IF NOT EXISTS planner_decisions (
  id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  iteration         INTEGER         NOT NULL,
  action            TEXT            NOT NULL,  -- SEARCH_WEBSITE | SEARCH_GITHUB | SEARCH_NEWS | SEARCH_WHOIS | SEARCH_CRTSH | SEARCH_ARCHIVE | CONTINUE | REJECT
  source_queried    TEXT,                       -- which source was actually queried
  result_summary    TEXT,
  confidence_before NUMERIC(5,2),
  confidence_after  NUMERIC(5,2),
  fields_improved   TEXT[],                     -- which fields got better
  tokens_used       INTEGER,
  created_at        TIMESTAMPTZ     DEFAULT NOW()
);

COMMENT ON TABLE planner_decisions IS
  'Audit trail of every AI planner decision — what it chose, why, and whether it helped.';
COMMENT ON COLUMN planner_decisions.action IS
  'The planner action taken. SEARCH_* actions query a source; CONTINUE moves to scoring; REJECT abandons the company.';
COMMENT ON COLUMN planner_decisions.fields_improved IS
  'Array of field_path values whose confidence increased after this action.';

CREATE INDEX IF NOT EXISTS idx_planner_company
  ON planner_decisions (company_id);

CREATE INDEX IF NOT EXISTS idx_planner_company_iteration
  ON planner_decisions (company_id, iteration);

CREATE INDEX IF NOT EXISTS idx_planner_action
  ON planner_decisions (action);

CREATE INDEX IF NOT EXISTS idx_planner_created
  ON planner_decisions (created_at DESC);

-- 6. SOURCE_CACHE ------------------------------------------------------------
-- Hash‑based caching with ETag/Last‑Modified support to avoid re‑fetching
-- unchanged sources.

CREATE TABLE IF NOT EXISTS source_cache (
  id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  source_type       TEXT            NOT NULL,   -- website | github | whois | crtsh | news | linkedin | …
  url               TEXT            NOT NULL,
  page_hash         TEXT,                       -- SHA‑256 hash of the content
  etag              TEXT,
  last_modified     TEXT,
  content_text      TEXT,                       -- extracted readable text
  content_raw       JSONB,                      -- raw response if JSON
  http_status       INTEGER,
  retrieved_at      TIMESTAMPTZ     DEFAULT NOW(),
  expires_at        TIMESTAMPTZ,
  UNIQUE (company_id, source_type, url)
);

COMMENT ON TABLE source_cache IS
  'Cache of fetched source content with ETag, hash dedup, and TTL expiry.';

CREATE INDEX IF NOT EXISTS idx_cache_company
  ON source_cache (company_id);

CREATE INDEX IF NOT EXISTS idx_cache_expiry
  ON source_cache (expires_at)
  WHERE expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cache_source_type
  ON source_cache (source_type);

CREATE INDEX IF NOT EXISTS idx_cache_hash
  ON source_cache (page_hash)
  WHERE page_hash IS NOT NULL;

-- 7. SCORE_CARDS_V2 -----------------------------------------------------------
-- Single scoring result with evidence‑backed pillars. Replaces the v1
-- lead_scores table with a composite score and hallucination tracking.

CREATE TABLE IF NOT EXISTS score_cards_v2 (
  id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id          UUID            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  run_id              TEXT            NOT NULL,
  move_intent         INTEGER         CHECK (move_intent >= 0 AND move_intent <= 100),
  growth              INTEGER         CHECK (growth >= 0 AND growth <= 100),
  financial           INTEGER         CHECK (financial >= 0 AND financial <= 100),
  company_fit         INTEGER         CHECK (company_fit >= 0 AND company_fit <= 100),
  decision_access     INTEGER         CHECK (decision_access >= 0 AND decision_access <= 100),
  network             INTEGER         CHECK (network >= 0 AND network <= 100),
  timing              INTEGER         CHECK (timing >= 0 AND timing <= 100),
  evidence_quality    INTEGER         CHECK (evidence_quality >= 0 AND evidence_quality <= 100),
  overall             INTEGER         CHECK (overall >= 0 AND overall <= 100),
  composite_score     INTEGER         GENERATED ALWAYS AS (
    (move_intent * 0.35 + growth * 0.15 + financial * 0.12 + company_fit * 0.10 +
     decision_access * 0.10 + network * 0.08 + timing * 0.05 + evidence_quality * 0.05)::int
  ) STORED,
  confidence          TEXT,                         -- high | medium | low
  reasoning           TEXT,                         -- AI reasoning for the scores
  verification_model  TEXT,                         -- which model performed the verification pass
  agreement_score     NUMERIC(5,2),                 -- 0‑100 multi‑model agreement
  hallucination_flags TEXT[],                       -- any hallucinations detected during this scoring
  created_at          TIMESTAMPTZ     DEFAULT NOW()
);

COMMENT ON TABLE score_cards_v2 IS
  'Single scoring result with evidence‑backed pillar scores and a computed composite.';
COMMENT ON COLUMN score_cards_v2.composite_score IS
  'Weighted average: move_intent 35% + growth 15% + financial 12% + company_fit 10% + decision_access 10% + network 8% + timing 5% + evidence_quality 5%.';
COMMENT ON COLUMN score_cards_v2.hallucination_flags IS
  'List of hallucination categories detected during this scoring run, if any.';

CREATE INDEX IF NOT EXISTS idx_scorecard_company
  ON score_cards_v2 (company_id);

CREATE INDEX IF NOT EXISTS idx_scorecard_run
  ON score_cards_v2 (run_id);

CREATE INDEX IF NOT EXISTS idx_scorecard_company_created
  ON score_cards_v2 (company_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_scorecard_overall
  ON score_cards_v2 (overall DESC);

-- 8. SCENARIO_QUEUE (v2) -----------------------------------------------------
-- Work queue for the processing pipeline. The v2 migration adds planner
-- fields for autonomous decision tracking.

CREATE TABLE IF NOT EXISTS scenario_queue (
  id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id              TEXT,
  company_name        TEXT,
  company_domain      TEXT,
  industry            TEXT,
  headquarters_city   TEXT,
  headquarters_country TEXT,
  source              TEXT,
  scenario_step       TEXT            DEFAULT 'discovery',
  next_step           TEXT,
  status              TEXT            DEFAULT 'pending',
  created_at          TIMESTAMPTZ     DEFAULT NOW(),
  updated_at          TIMESTAMPTZ     DEFAULT NOW()
);

COMMENT ON TABLE scenario_queue IS
  'Processing pipeline work queue. Each row represents a company moving through discovery → AI analysis → scoring → export.';

-- v2 planner columns
ALTER TABLE scenario_queue
  ADD COLUMN IF NOT EXISTS company_id          UUID    REFERENCES companies(id),
  ADD COLUMN IF NOT EXISTS planner_iteration   INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS planner_state       JSONB,           -- current planner state (actions taken, confidence levels, …)
  ADD COLUMN IF NOT EXISTS evidence_summary    JSONB;           -- summary of evidence collected so far

CREATE INDEX IF NOT EXISTS idx_scenario_queue_status
  ON scenario_queue (status);

CREATE INDEX IF NOT EXISTS idx_scenario_queue_step
  ON scenario_queue (scenario_step);

CREATE INDEX IF NOT EXISTS idx_scenario_queue_company
  ON scenario_queue (company_id)
  WHERE company_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_scenario_queue_run
  ON scenario_queue (run_id);

-- updated_at trigger
CREATE TRIGGER trg_scenario_queue_updated_at
  BEFORE UPDATE ON scenario_queue
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- 9. VALIDATION_LOG ----------------------------------------------------------
-- Every validation attempt — schema, regex, type, or range checks — recorded
-- with pass/fail and retry tracking.

CREATE TABLE IF NOT EXISTS validation_log (
  id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  extraction_run_id   UUID            NOT NULL REFERENCES extraction_runs(id) ON DELETE CASCADE,
  field_path          TEXT,
  validator_type      TEXT,            -- schema | regex | type_check | range_check
  passed              BOOLEAN,
  error_message       TEXT,
  retry_count         INTEGER         DEFAULT 0,
  created_at          TIMESTAMPTZ     DEFAULT NOW()
);

COMMENT ON TABLE validation_log IS
  'Every validation attempt recorded with pass/fail status and retry count.';

CREATE INDEX IF NOT EXISTS idx_validation_run
  ON validation_log (extraction_run_id);

CREATE INDEX IF NOT EXISTS idx_validation_passed
  ON validation_log (extraction_run_id, passed);

CREATE INDEX IF NOT EXISTS idx_validation_type
  ON validation_log (validator_type);

-- 10. OBSERVABILITY_EVENTS ---------------------------------------------------
-- Granular observability tracking for extraction, scoring, planner, cache,
-- validation, and hallucination events.

CREATE TABLE IF NOT EXISTS observability_events (
  id                    UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id                TEXT            NOT NULL,
  company_id            UUID            REFERENCES companies(id) ON DELETE SET NULL,
  event_type            TEXT            NOT NULL,   -- extraction | scoring | planner | cache | validation | hallucination
  model_used            TEXT,
  prompt_version        TEXT,
  latency_ms            INTEGER,
  tokens_used           INTEGER,
  cost_cents            NUMERIC(10,4),
  confidence            NUMERIC(5,2),
  evidence_count        INTEGER,
  cache_hit             BOOLEAN,
  search_source         TEXT,
  planner_action        TEXT,
  validation_failures   INTEGER,
  hallucination_detected BOOLEAN,
  metadata              JSONB,
  created_at            TIMESTAMPTZ     DEFAULT NOW()
);

COMMENT ON TABLE observability_events IS
  'Granular observability events for cost, latency, confidence, cache, and hallucination tracking.';

CREATE INDEX IF NOT EXISTS idx_observability_run
  ON observability_events (run_id);

CREATE INDEX IF NOT EXISTS idx_observability_company
  ON observability_events (company_id);

CREATE INDEX IF NOT EXISTS idx_observability_type
  ON observability_events (event_type);

CREATE INDEX IF NOT EXISTS idx_observability_created
  ON observability_events (created_at);

CREATE INDEX IF NOT EXISTS idx_observability_run_type
  ON observability_events (run_id, event_type);

-- 11. COMPANY_DUPLICATES -----------------------------------------------------
-- Tracks duplicate resolution with similarity scores and match types.

CREATE TABLE IF NOT EXISTS company_duplicates (
  id                    UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id            UUID            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  duplicate_company_id  UUID            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  similarity_score      NUMERIC(5,2),              -- 0‑100 similarity score
  match_type            TEXT,                       -- exact_domain | fuzzy_name | same_normalized
  resolved              BOOLEAN         DEFAULT FALSE,
  created_at            TIMESTAMPTZ     DEFAULT NOW(),

  CONSTRAINT uq_company_duplicate_pair UNIQUE (company_id, duplicate_company_id),
  CONSTRAINT chk_no_self_duplicate CHECK (company_id <> duplicate_company_id)
);

COMMENT ON TABLE company_duplicates IS
  'Duplicate company pairs with similarity scoring and resolution status.';

CREATE INDEX IF NOT EXISTS idx_duplicates_company
  ON company_duplicates (company_id);

CREATE INDEX IF NOT EXISTS idx_duplicates_unresolved
  ON company_duplicates (company_id, duplicate_company_id)
  WHERE resolved = FALSE;

CREATE INDEX IF NOT EXISTS idx_duplicates_match_type
  ON company_duplicates (match_type);

-- 12. RULE_ENGINE_RESULTS ----------------------------------------------------
-- Pre‑AI deterministic extraction results from regex‑based and structured‑
-- data rule engines.

CREATE TABLE IF NOT EXISTS rule_engine_results (
  id                UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id        UUID            NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  extractor         TEXT            NOT NULL,   -- email | phone | address | social | schema_org | meta
  results           JSONB           NOT NULL,   -- array of extracted items
  source_url        TEXT,
  created_at        TIMESTAMPTZ     DEFAULT NOW()
);

COMMENT ON TABLE rule_engine_results IS
  'Deterministic extraction results from the pre‑AI rule engine (regex, schema.org, meta tags, …).';

CREATE INDEX IF NOT EXISTS idx_rule_engine_company
  ON rule_engine_results (company_id);

CREATE INDEX IF NOT EXISTS idx_rule_engine_extractor
  ON rule_engine_results (extractor);

-- ============================================================================
-- END OF V2 SCHEMA
-- ============================================================================
