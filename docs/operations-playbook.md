---
title: Jasfo Operations Playbook
description: Complete operational workflow, tool usage, and cost breakdown
---

# Jasfo — Operations Playbook

## Platform Stack

| Tool | Role | Plan | Cost/Month |
|------|------|------|------------|
| **n8n Cloud** | Workflow orchestration | Starter ($24) | 2,500 executions |
| **Supabase** | Database + REST API | Free | 500 MB, 50K rows |
| **OpenCode GO** | AI model provider | $10/month | $60 monthly value |
| **Firecrawl** | Web scraping engine | Hobby ($19) | 5,000 credits |
| **Telegram** | Output delivery | Free | Unlimited |
| **GitHub** | Code/docs versioning | Free | Unlimited |
| **Make.com** (backup) | Alternative orchestrator | Free trial | 1,000 ops |
| **Total** | | | **~$53/month** |

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                  MONDAY 1:00 AM UTC                       │
│                                                          │
│  1. Weekly Master ── Loads company_queue ── enqueues     │
│       ↓                                                 │
│  2. Discovery Processor (cron */30min)                   │
│     Picks 25 pending → Firecrawl scrapes → marks ai_ready│
│       ↓                                                 │
│  3. AI Processor (cron */30min)                          │
│     Picks 20 → OpenCode GO (DeepSeek/MiMo) → marks      │
│                            scoring_ready                  │
│       ↓                                                 │
│  4. Scoring Processor (cron */30min)                     │
│     Picks 12 → 8 pillar scores × OpenCode GO → marks    │
│                            export_ready                  │
│       ↓                                                 │
│  5. Export Processor (cron */30min)                      │
│     Picks 30 → Telegram report + Google Sheets → marks   │
│                            done                          │
└──────────────────────────────────────────────────────────┘
```

**Total wall time:** ~12 hours (Mon 1AM → 1PM)
**Lead quality:** First strong lead at ~2:30AM

---

## Pipeline State Machine

Each company moves through status fields in `scenario_queue`:

```
STATUS          NEXT_STEP        MEANING
─────────────────────────────────────────────────
pending         discovery        Awaiting scrape
completed       ai_ready         Scraped, ready for AI
completed       scoring_ready    Entities extracted
completed       export_ready     Scored, ready to deliver
done            —                Report delivered
```

---

# Workflow 1: Weekly Master

**Trigger:** Cron `0 1 * * 1` (Monday 1AM UTC)
**File:** `workflows/n8n/jasfo-weekly-master.json`

### Nodes

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Schedule Trigger | scheduleTrigger | Cron `0 1 * * 1` |
| 2 | Load Companies | HTTP GET | Supabase REST: `company_queue?status=eq.pending` |
| 3 | Validate & Enqueue | Code | JS: validates name≥2, generates run_id, emits items |
| 4 | Is Company? | IF | Routes: meta→Telegram, companies→Insert |
| 5 | Insert to Queue | HTTP POST | Supabase REST: inserts `scenario_queue` rows |
| 6 | Telegram Notification | HTTP POST | Telegram Bot API: sends run summary |

### API Calls
| API | Endpoint | Count |
|-----|----------|-------|
| Supabase GET | `/rest/v1/company_queue` | 1 |
| Supabase POST | `/rest/v1/scenario_queue` | 1 (batch 250) |
| Telegram POST | `/sendMessage` | 1 |

### Usage
- **n8n executions:** 1/month
- **Supabase reads:** ~1 row scanned
- **Supabase writes:** 250 rows inserted

---

# Workflow 2: Discovery Processor

**Trigger:** Cron `0,30 0-23 * * 1` (Monday, every 30min)
**File:** `workflows/n8n/jasfo-discovery-processor.json`

### Nodes

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Schedule Trigger | scheduleTrigger | Cron every 30min Mon |
| 2 | Load Pending Items | HTTP GET | Supabase: `scenario_queue?status=eq.pending&scenario_step=eq.discovery&limit=25` |
| 3 | Items Found? | IF | Skip if queue empty (0 executions) |
| 4 | Batch Processor | splitInBatches | batchSize:1 — process 25 companies |
| 5 | Check Cache | HTTP GET | Supabase: `scrape_cache?company_domain=eq.{domain}` |
| 6 | Cache Hit? | IF | Skip scrape if cached |
| 7 | Firecrawl Crawl | HTTP POST | `api.firecrawl.dev/v1/crawl` |
| 8 | Firecrawl Scrape | HTTP POST | `api.firecrawl.dev/v1/scrape` |
| 9 | Merge Scraped Data | Code | JS: combines crawl + scrape results |
| 10 | Insert Cache | HTTP POST | Supabase: insert `scrape_cache` |
| 11 | Update Queue | HTTP PATCH | Supabase: `status=completed`, `next_step=ai_ready` |

### API Calls (per run with data)

| API | Count | Notes |
|-----|-------|-------|
| Supabase GET (queue) | 1 | Loads 25 pending |
| Supabase GET (cache) | 25 | 1 per company |
| Firecrawl POST (crawl) | 25 | 1 per company |
| Firecrawl POST (scrape) | 25 | 1 per company/about |
| Supabase POST (cache) | 25 | Cache result |
| Supabase PATCH (queue) | 25 | Mark completed |

### Usage Metrics

| Metric | Per Run | Per Week |
|--------|---------|----------|
| n8n executions | 48 | 48 (only ~10 with data) |
| Firecrawl crawl credits | 25 | 250 |
| Firecrawl scrape credits | 25 | 250 |
| Total Firecrawl credits | 50 | **500** |
| Supabase reads | 26 | 260 |
| Supabase writes | 50 | 500 |

---

# Workflow 3: AI Processor

**Trigger:** Cron `0,30 0-23 * * 1-2` (Mon-Tue, every 30min)
**File:** `workflows/n8n/jasfo-ai-processor.json`

### Nodes

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Schedule Trigger | scheduleTrigger | Cron every 30min Mon-Tue |
| 2 | Load Items | HTTP GET | Supabase: `scenario_queue?next_step=eq.ai_ready&limit=20` |
| 3 | Split In Batches | splitInBatches | batchSize:1 |
| 4 | Load Scrape Cache | HTTP GET | Supabase: load cached scrape data |
| 5 | Build AI Prompt | Code | JS: token estimation, model selection |
| 6 | Call OpenCode GO | HTTP POST | `opencode.ai/zen/go/v1/chat/completions` (DeepSeek or MiMo) |
| 7 | Parse And Validate | Code | JS: JSON.parse + schema validation |
| 8 | Insert AI Extraction | HTTP POST | Supabase: insert `ai_extractions` |
| 9 | Update Queue | HTTP PATCH | Supabase: `next_step=scoring_ready` |

### Model Routing Logic

```
IF estimatedTokens < 100K → USE DeepSeek V4 Flash ($0.14M input)
ELSE                      → USE MiMo V2.5 ($0.14/M input)
                            (longer content path)
IF API fails (429/503)    → FALLBACK to MiMo V2.5
IF JSON parse fails       → CALL DeepSeek V4 Flash repair prompt
```

**Cache hit advantage:** If a company was already discovered in a previous week, the scrape_cache returns data. The AI prompt is built from cached data with O(200) tokens — only ~50 tokens per request for cache verification. This means ~90% prompt caching on OpenCode GO, reducing costs by ~70% on repeat runs.

### API Calls (per run with data)

| API | Count | Notes |
|-----|-------|-------|
| Supabase GET (queue) | 1 | Loads 20 |
| Supabase GET (cache) | 20 | 1 per company |
| OpenCode GO POST | 20-22 | DeepSeek primary, MiMo fallback |
| Supabase POST (extraction) | 20 | 1 per company |
| Supabase PATCH (queue) | 20 | 1 per company |

### Usage Metrics

| Metric | Per Run | Per Week |
|--------|---------|----------|
| n8n executions | 96 | ~13 with data |
| OpenCode GO calls | ~20 | ~250 |
| OpenCode GO tokens | ~20K input × 20 = 400K | ~5M |
| OpenCode GO cost | ~$0.056 | ~$0.70 |
| Supabase reads | 21 | 260 |
| Supabase writes | 40 | 500 |

---

# Workflow 4: Scoring Processor

**Trigger:** Cron `0,30 0-23 * * 1-2` (Mon-Tue, every 30min)
**File:** `workflows/n8n/jasfo-scoring-processor.json`

### Nodes

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Schedule Trigger | scheduleTrigger | Cron every 30min Mon-Tue |
| 2 | Load Items | HTTP GET | Supabase: `scenario_queue?next_step=eq.scoring_ready&limit=12` |
| 3 | Split In Batches | splitInBatches | batchSize:1 |
| 4 | Load AI Extraction | HTTP GET | Supabase: load extraction data |
| 5-12 | Score Pillars (×8) | HTTP POST ×8 | Sequential OpenCode GO calls, 1 per pillar |
| 13 | Calculate Composite | Code | JS: weighted sum of 8 pillars |
| 14 | MiMo Reflection | HTTP POST | OpenCode GO: MiMo V2.5 verification |
| 15 | Insert Score Card | HTTP POST | Supabase: insert `score_cards` |
| 16 | Update Queue | HTTP PATCH | Supabase: `next_step=export_ready` |

### Pillar Weighting

| Pillar | Weight | Scoring Model |
|--------|--------|--------------|
| Move Intent | 35% | DeepSeek V4 Flash |
| Growth Signal | 15% | DeepSeek V4 Flash |
| Financial Health | 12% | DeepSeek V4 Flash |
| Company Fit | 10% | DeepSeek V4 Flash |
| Decision Maker Access | 10% | DeepSeek V4 Flash |
| Network/Relationships | 8% | DeepSeek V4 Flash |
| Opportunity Timing | 5% | DeepSeek V4 Flash |
| Evidence Quality | 5% | DeepSeek V4 Flash |

**Composite** = Σ(pillar_score × weight/100)

### Cost Gate

Cost gate at **composite ≥ 60** determines which leads proceed to paid enrichment:
- Score ≥ 60: Full export (Telegram + Sheets)
- Score < 60: Archived but not exported

### API Calls (per run with data)

| API | Count | Notes |
|-----|-------|-------|
| Supabase GET (queue) | 1 | Loads 12 |
| Supabase GET (extraction) | 12 | 1 per company |
| OpenCode GO (Scoring ×8) | 96 | 8 calls × 12 companies |
| OpenCode GO (Reflection) | 12 | MiMo V2.5 |
| Supabase POST (score) | 12 | 1 per company |
| Supabase PATCH (queue) | 12 | 1 per company |

### Usage Metrics

| Metric | Per Run | Per Week |
|--------|---------|----------|
| n8n executions | 96 | ~21 with data |
| OpenCode GO DeepSeek calls | 96 | 2,000 |
| OpenCode GO MiMo calls | 12 | 250 |
| OpenCode GO input tokens | ~1.9M | ~40M |
| OpenCode GO cost | ~$0.29 | ~$6.20 |
| Supabase reads | 13 | 275 |
| Supabase writes | 24 | 500 |

**This is the most expensive workflow** — 8 parallel scoring calls per company. The DeepSeek V4 Flash is cheap ($0.14/M input) so even 2,000 calls cost only ~$0.80/week.

---

# Workflow 5: Export Processor

**Trigger:** Cron `0,30 0-23 * * 1-2` (Mon-Tue, every 30min)
**File:** `workflows/n8n/jasfo-export-processor.json`

### Nodes

| # | Node | Type | Purpose |
|---|------|------|---------|
| 1 | Schedule Trigger | scheduleTrigger | Cron every 30min Mon-Tue |
| 2 | Load Items | HTTP GET | Supabase: `scenario_queue?next_step=eq.export_ready&limit=30` |
| 3 | Split In Batches | splitInBatches | batchSize:1 |
| 4 | Load Score Card | HTTP GET | Supabase: load score data |
| 5 | Load AI Extraction | HTTP GET | Supabase: load extraction data |
| 6 | Build Telegram Message | Code | JS: format score + extraction → Markdown |
| 7 | Send Telegram | HTTP POST | Telegram Bot API: send to group |
| 8 | (Optional) Google Sheets Export | googleSheets | Append row to spreadsheet |
| 9 | Insert Report Archive | HTTP POST | Supabase: archive delivery |
| 10 | Update Queue | HTTP PATCH | Supabase: `status=done` |

### Telegram Message Format

```
📊 *CompanyName (domain.com)*
Score: 78/100 — Medium Confidence

*Top Pillars*
Move Intent: 82 | Financial: 65 | Growth: 71

*Key Risks*
🔴 Limited decision-maker access
🟡 Recent leadership change

_Score breakdown & full report ⬇️_
```

### API Calls (per run with data)

| API | Count | Notes |
|-----|-------|-------|
| Supabase GET (queue) | 1 | Loads 30 |
| Supabase GET (scores) | 30 | 1 per company |
| Supabase GET (extractions) | 30 | 1 per company |
| Telegram POST | 30 | (score >= 60 only) |
| Google Sheets POST | 30 | (when configured) |
| Supabase POST (archive) | 30 | |
| Supabase PATCH (queue) | 30 | |

### Usage Metrics

| Metric | Per Run | Per Week |
|--------|---------|----------|
| n8n executions | 96 | ~9 with data |
| Telegram messages | 27 | ~27 (only scored leads) |
| Supabase reads | 61 | 550 |
| Supabase writes | 60 | 540 |

---

# Cost Gate (Layer 7)

The pipeline has a built-in cost gate at the scoring stage:

```
Layer 1-6: Free tier — DeepSeek V4 Flash ($0.14/M)
  ↓
Layer 7: Cost Gate — Composite Score ≥ 60?
  ├── YES → Proceed to Export (Telegram + archive)
  ├── NO  → Archive only, no Telegram delivery
  ↓
Layer 8-11: Future — Only top 27 leads get paid enrichment
            (Hunter/Apollo/Snov + Claude Sonnet 4)
```

**Current behavior:** All scored leads go to Telegram for review.
**Future behavior:** Only score ≥ 60 leads proceed to paid enrichment layers.

---

# Execution Budget Calculation

## n8n Monthly Executions

| Workflow | Runs/Month | With Data | Empty Skips |
|----------|-----------|-----------|-------------|
| Weekly Master | 4 | 4 | 0 |
| Discovery | 192 | 40 | 152 |
| AI | 192 | 52 | 140 |
| Scoring | 192 | 84 | 108 |
| Export | 192 | 36 | 156 |
| **Total** | **772** | **216** | **556** |

**n8n Starter:** 2,500 exec/month → **30% utilization**. Plenty of headroom.

## Cost Breakdown

| Item | Per Week | Per Month |
|------|----------|-----------|
| n8n Cloud | $6.00 | $24.00 |
| OpenCode GO | $1.15 | $5.00 |
| Firecrawl (Hobby) | $4.75 | $19.00 |
| **Total** | **$11.90** | **$48.00** |

**Cost per lead:** ~$0.05 for 250 qualified leads.  
**Cost per pipeline run:** ~$12/week.

---

# Data Lifecycle

## Tables

| Table | Purpose | Rows/Week | Retention |
|-------|---------|-----------|-----------|
| `company_queue` | Source companies to process | 250 | Indefinite |
| `scenario_queue` | Pipeline state tracking | 250 | 90 days |
| `scrape_cache` | Website scrape cache | 250 | 7 days TTL |
| `ai_extractions` | Entity extraction results | 250 | Indefinite |
| `score_cards` | 8-pillar scoring data | 250 | Indefinite |
| `report_archive` | Delivered report records | 27 | 90 days |
| `cost_log` | API cost tracking | 2,500 | 30 days |

## Cache Strategy

```sql
-- scrape_cache expires after 7 days
expires_at >= NOW() + INTERVAL '7 days'

-- Re-scrape same domain within 7 days → cache hit → NO Firecrawl call
-- After 7 days → cache miss → Firecrawl scrape again
```

Estimated cache hit rate for weekly runs:
- Week 1: 0% (all new)
- Week 2+: 60-80% (companies re-evaluated)

This means week 2+ costs drop by ~60%.

---

# Tool Deep Dive

## n8n — Workflow Orchestrator

**Role:** Cron-based pipeline scheduler, HTTP client, JS code execution, SplitInBatches looping.

**Used for:**
- ✅ Cron scheduling (5 schedules)
- ✅ Supabase REST API calls (GET/POST/PATCH)
- ✅ Telegram Bot API calls
- ✅ JavaScript code nodes (validation, transformation, aggregation)
- ✅ SplitInBatches (batching 25->250 companies)
- ✅ Branching with IF nodes (error handling, routing)

**Not used:**
- ❌ Postgres nodes (replaced by Supabase REST API for credential-free setup)
- ❌ Built-in Telegram node (replaced by raw HTTP for credential-free setup)
- ❌ Webhook triggers (all cron-based for queue processing)

**Configuration details:**
- All credentials embedded inline as HTTP headers
- authentication: "none" on every node
- continueOnFail: true on API calls for resilience
- Timeout: 30s-120s depending on API

---

## Supabase — Database + REST API

**Role:** PostgreSQL database, REST API layer, row-level security.

**Used for:**
- ✅ Storing company queue (company_queue)
- ✅ Pipeline state management (scenario_queue)
- ✅ Scrape cache (scrape_cache)
- ✅ AI extraction storage (ai_extractions)
- ✅ Score card storage (score_cards)
- ✅ Report archive (report_archive)
- ✅ Cost tracking (cost_log)

**Tables needed** (run these SQL commands once):

```sql
-- Create scenario_queue
CREATE TABLE scenario_queue (
  id SERIAL PRIMARY KEY,
  run_id TEXT NOT NULL,
  company_name TEXT,
  company_domain TEXT,
  scenario_step TEXT DEFAULT 'discovery',
  status TEXT DEFAULT 'pending',
  next_step TEXT,
  output_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create scrape_cache
CREATE TABLE scrape_cache (
  id SERIAL PRIMARY KEY,
  cache_key TEXT UNIQUE,
  company_domain TEXT,
  source_type TEXT,
  response_data JSONB,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create ai_extractions
CREATE TABLE ai_extractions (
  id SERIAL PRIMARY KEY,
  run_id TEXT,
  company_domain TEXT,
  company_data JSONB,
  confidence_scores JSONB,
  model_used TEXT,
  processing_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create score_cards
CREATE TABLE score_cards (
  id SERIAL PRIMARY KEY,
  run_id TEXT,
  company_domain TEXT,
  pillar_scores JSONB,
  composite_score INTEGER,
  confidence TEXT,
  risk_factors JSONB,
  reflection_passed BOOLEAN,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create report_archive
CREATE TABLE report_archive (
  id SERIAL PRIMARY KEY,
  run_id TEXT,
  company_domain TEXT,
  format TEXT,
  content JSONB,
  delivered_at TIMESTAMPTZ,
  delivery_status TEXT
);

-- Create cost_log
CREATE TABLE cost_log (
  id SERIAL PRIMARY KEY,
  company_id TEXT,
  pipeline_run_id TEXT,
  layer_id TEXT,
  model_used TEXT,
  cost_cents INTEGER,
  tokens_used INTEGER,
  source_type TEXT,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Connection details:**
- URL: `https://nswlrolnbvjzgbkyxrkp.supabase.co/rest/v1`
- Auth: Bearer token (service_role key, can bypass RLS)
- REST operations: SELECT, POST (insert), PATCH (update)

---

## OpenCode GO — AI Provider

**Role:** Provides DeepSeek V4 Flash and MiMo V2.5 models via OpenAI-compatible API.

**Endpoint:** `https://opencode.ai/zen/go/v1/chat/completions`
**Auth:** Bearer token with API key

**Pricing:**

| Model | Input | Output | Cached Read |
|-------|-------|--------|-------------|
| DeepSeek V4 Flash | $0.14/M | $0.28/M | $0.0028/M |
| MiMo V2.5 | $0.14/M | $0.28/M | $0.0028/M |

**Monthly cost at scale (250 companies):**
- DeepSeek scoring calls: 2,000/week × ~2K tokens → ~$0.80/week
- DeepSeek entity extraction: 250/week × ~20K tokens → ~$0.70/week
- MiMo reflection: 250/week × ~2K tokens → ~$0.10/week
- Total: ~$1.60/week → **~$6.40/month**

**Prompt caching benefit:** Cached read pricing ($0.0028/M) is 50× cheaper than uncached ($0.14/M). Repeat analysis of same companies week-over-week hits cache ~90%.

**Trial plan limits:**
- 5-hour sliding window: ~$12 (30,000+ DeepSeek calls — 3× our weekly need)
- Monthly cap: $60 (10× our monthly need)

---

## Firecrawl — Web Scraping

**Role:** Website deep crawling, page scraping, and search.

**Endpoint:** `https://api.firecrawl.dev/v1/crawl` / `/v1/scrape` / `/v1/search`
**Auth:** Bearer token `fc-03ee582d75c647c59555df35374d8fa2`

**Credit usage per company:**

| Action | Credits | Notes |
|--------|---------|-------|
| `/v1/crawl` | 1 | Starts crawl job |
| `/v1/scrape` (about page) | 1 | Extracts structured data |
| `/v1/search` (fallback) | 1 | Only if crawl fails |
| **Total per company** | **2-3** | Average 2.5 |

**Weekly total:** 250 × 2.5 = 625 credits

**Plans:**
| Plan | Credits/Month | Cost | Weekly Run? |
|------|---------------|------|-------------|
| Free | 500 | $0 | ❌ Need 625/wk |
| Hobby | 5,000 | $19/mo | ✅ 8 weeks coverage |
| Standard | 30,000 | $49/mo | ✅ 48 weeks coverage |

**Cache efficiency:** Week 1 burns full credits. Week 2+ hits scrape_cache for ~70% of companies, cutting Firecrawl usage to ~75 credits/week.

---

## Telegram — Output Delivery

**Role:** Real-time lead notifications and weekly pipeline reports.

**Bot token:** `8688503635:AAH4obxx3lGXYhoke1hR8mFJvoTvflVRrnE`
**Group chat:** `-5497421027`
**Admin chat:** `5936648348`

**API used:**
- `POST https://api.telegram.org/bot{token}/sendMessage`
- Parameters: `chat_id`, `text`, `parse_mode: "Markdown"`

**Message types sent:**
1. Pipeline start notification (1/week)
2. Individual lead reports (~27/week)
3. Pipeline completion summary (1/week)
4. Cost monitor alerts (hourly, optional)

**Cost:** Free. No usage limits for standard Bot API.

---

# Monitoring

## Cost Monitor (Optional)

The cost monitor workflow (`jasfo-cost-monitor`) runs hourly and:
1. Queries `cost_log` for today's spending
2. Compares against $20/day budget cap
3. Sends Telegram alert at 80% ($16) warning
4. Sends critical alert at 100% ($20)

**Current status:** Not activated (to stay within 5-workflow trial limit). Activate manually when needed.

---

# Failure Recovery

| Failure Mode | Automation | Manual Recovery |
|-------------|------------|-----------------|
| Firecrawl API down | Auto retry + search fallback | Change FC_KEY |
| OpenCode GO rate limit | Auto retry, fallback to MiMo | Wait 5 min |
| Supabase timeout | continueOnFail: true | Re-run processor |
| n8n execution timeout | Next cron picks up remaining | Manual execution |
| Telegram API failure | continueOnFail: true | Check bot token |
| Any API 5xx | continueOnFail: true | Next cron cycle retries |

Processors are **idempotent** — re-running picks up pending items from the queue without duplicating work.

---

# Quick Start Cheatsheet

## Before first run
```bash
# 1. Import 5 n8n workflows via Settings → Import
# 2. Create Supabase tables (SQL above)
# 3. Add Google Sheets node to Export Processor (optional)
# 4. Activate all 5 workflows
```

## On Monday 1AM UTC
Pipeline starts automatically. First lead on Telegram ~2:30AM.

## What to check
- 📱 Telegram group `@Mudar jasfo` — live leads arriving
- 🔍 Supabase `score_cards` — query all scores:
  ```sql
  SELECT company_domain, composite_score, confidence
  FROM score_cards ORDER BY composite_score DESC LIMIT 10;
  ```
- 📊 Google Sheet — leads in spreadsheet format

## Cost tracking
```sql
-- Check today's spending
SELECT model_used, SUM(cost_cents) AS total_cents
FROM cost_log
WHERE recorded_at >= CURRENT_DATE
GROUP BY model_used;
```
