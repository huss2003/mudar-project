# Implementation Guide

> Build order for AI coding agents. Dependencies between components. Start at Phase 1 and proceed sequentially.

## Phase 1: Database Foundation (Week 1)

**Dependency root. Everything else depends on this.**

1. Set up Supabase project
2. Run `sql/schema.sql` to create all 18 tables
3. Run `sql/functions.sql` for scoring, change detection, maintenance functions
4. Run `sql/indexes.sql` for all indexes
5. Run `sql/rls.sql` for Row Level Security
6. Run `sql/seed.sql` to load test data
7. Create `v_top_leads` and `v_weekly_costs` views from `sql/views.sql`

**Verification:** `SELECT COUNT(*) FROM companies;` returns 8 rows from seed data.

## Phase 2: Pipeline Orchestration (Week 2-3)

**Depends on Phase 1.**

1. Create Make.com scenario: **Company Discovery** (Firecrawl -> Supabase)
   - Input: target URL list or industry keywords
   - Output: companies inserted into `companies` + `profiles`
2. Create Make.com scenario: **Normalization** (DeepSeek V4 Flash)
   - Input: raw company data
   - Output: structured, validated records (update `companies` row)
3. Create Make.com scenario: **Verification** (MiMo V2.5)
   - Input: normalized records
   - Output: evidence_claims + evidence_sources rows
4. Create Make.com scenario: **Feature Engineering** (DeepSeek V4 Flash)
   - Input: verified claims
   - Output: 40+ feature values (stored in evidence_claims metadata)

## Phase 3: Scoring Engine (Week 3-4)

**Depends on Phase 2.**

1. Deploy 8 parallel pillar-scoring agents (Make.com scenarios)
   - Each agent reads feature vector, writes pillar score to `lead_scores`
   - Trigger: all 8 run in parallel after feature engineering completes
2. Create Consensus agent (MiMo V2.5)
   - Input: 8 pillar scores
   - Output: weighted composite, confidence score
   - Updates `lead_scores.total_score` and `lead_scores.confidence_score`
3. Create Reflection agent (MiMo V2.5)
   - Reviews scores for consistency, flags contradictions
4. Create Change Detection function (hash-based, no LLM)
   - `compute_company_hash()` + `detect_changes()` + snapshot management

## Phase 4: Cost Gate & Enrichment (Week 4-5)

**Depends on Phase 3.**

1. Implement Cost Gate logic in Make.com
   - Check: total_score >= threshold? budget remaining?
   - Route: high-scoring companies -> enrichment, low -> cooldown
2. Create Make.com scenario: **Contact Enrichment**
   - Apollo.io -> Hunter.io -> Snov.io -> SMTP verification chain
   - Write results to `email_drafts` table
3. Create Make.com scenario: **LinkedIn Enrichment**
   - Write results to `linkedin_drafts` table

## Phase 5: Judge & Delivery (Week 5-6)

**Depends on Phase 4.**

1. Create Judge agent (Claude Sonnet 4)
   - Processes only top 20-30 leads
   - Output: approve/reject + ranking + evidence package
2. Create Strategy agent (MiMo V2.5)
   - Output: commercial strategy brief (property recommendations, talking points)
3. Create Outreach agent (DeepSeek V4 Flash)
   - Output: email draft <=120 words or LinkedIn message
4. Create Evidence Snapshot (at pipeline completion)
   - Write `evidence_snapshots` row with full bundle + hash

## Phase 6: Notifications & Exports (Week 6-7)

**Depends on Phase 5.**

1. Create Make.com scenario: **Telegram Notification**
   - Weekly summary of top leads
   - High-value lead alerts (total_score >= 500)
   - Pipeline failure alerts
2. Create Make.com scenario: **Weekly CSV Export**
   - Query v_top_leads
   - Format and deliver to broker
3. Create Make.com scenario: **Cooldown Management**
   - Run `expire_cooldowns()` at pipeline start
   - Update lead states based on time-based transitions

## Phase 7: Learning & Iteration (Ongoing)

1. Implement QA Agent (validates output quality)
2. Implement Learning Agent (analyzes broker feedback)
3. Set up weekly cost tracking via `cost_log` table
4. Create `v_weekly_costs` dashboard for budget monitoring
5. Tune scoring thresholds based on conversion data

## Key Dependencies Diagram

```
Phase 1 (DB) -> Phase 2 (Pipeline) -> Phase 3 (Scoring) -> Phase 4 (Gate+Enrich) -> Phase 5 (Judge+Delivery) -> Phase 6 (Notify+Export)
                                                                                                                      |
                                                                                                            Phase 7 (Learn) --+
```

## Critical Files By Phase

| Phase | Must Read | Must Write/Modify |
|-------|-----------|-------------------|
| 1 | `docs/database/*.md` | `sql/schema.sql`, `sql/functions.sql` |
| 2 | `docs/api/firecrawl.md`, `docs/scraping/*` | Make.com scenarios, `sql/views.sql` |
| 3 | `docs/ai/routing.md`, `docs/agents/*` | `sql/functions.sql` (scoring), Make.com scenarios |
| 4 | `docs/api/apollo.md`, `docs/api/hunter.md`, `docs/api/snov.md` | Make.com scenarios |
| 5 | `docs/ai/judge.md`, `docs/prompts/*` | `sql/seed.sql` (test data) |
| 6 | `docs/api/telegram.md`, `docs/exports/*` | Make.com scenarios |
| 7 | `docs/agents/qa-agent.md`, `docs/agents/learning-agent.md` | Prompts, Make.com scenarios |
