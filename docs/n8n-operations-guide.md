# Jasfo — n8n Operations Guide (A–Z)

> Version: 2.0  
> Last updated: 2026-07-13  
> Platform: n8n Cloud (learningn8nudemy.app.n8n.cloud)

---

## Table of Contents

1. [Platform Overview](#1-platform-overview)
2. [Architecture: v1 vs v2](#2-architecture-v1-vs-v2)
3. [Workflow Inventory](#3-workflow-inventory)
4. [Workflow Details — v1 (Stable)](#4-workflow-details--v1-stable)
5. [Workflow Details — v2 (In Progress)](#5-workflow-details--v2-in-progress)
6. [Supabase Integration](#6-supabase-integration)
7. [Credentials & API Keys](#7-credentials--api-keys)
8. [Common Failures & Fixes](#8-common-failures--fixes)
9. [n8n MCP Operations](#9-n8n-mcp-operations)
10. [Pipeline Data Flow](#10-pipeline-data-flow)
11. [Cost & Usage](#11-cost--usage)
12. [Troubleshooting](#12-troubleshooting)
13. [What We Want to Achieve](#13-what-we-want-to-achieve)

---

## 1. Platform Overview

Jasfo is an autonomous lead intelligence platform that discovers B2B companies matching a user-defined Ideal Customer Profile (ICP), enriches them with data from public sources, scores them across 8 dimensions, and delivers qualified leads via Telegram and Google Sheets.

**Tech Stack (n8n-related):**

| Component | Version / Type | Purpose |
|-----------|---------------|---------|
| n8n Cloud | SaaS (learningn8nudemy.app.n8n.cloud) | Workflow orchestration |
| n8n Plan | Starter ($24/mo) | 2,500 executions/month |
| Active workflow limit | 5 (Starter plan) | Maximum concurrent active workflows |
| Supabase | PostgreSQL + REST API | Database, state management, caching |
| OpenCode GO | AI model provider | DeepSeek V4 Flash + MiMo V2.5 |
| Firecrawl | Web scraping | Company website crawling |
| Telegram | Bot API | Lead delivery, notifications |
| GitHub | Repository | Code, workflow JSON, docs |

---

## 2. Architecture: v1 vs v2

### v1 (Original — Stable, Running)

```
Manual company entry → company_queue
  ↓
Discovery (Firecrawl scrape) → ai_ready
  ↓
AI Extraction (DeepSeek) → scoring_ready
  ↓
Scoring (8 parallel DeepSeek calls) → export_ready
  ↓
Export (Telegram + Google Sheets) → done
```

**Problems with v1:**
- Manual company entry required (no discovery)
- AI hallucinated data (no evidence tracking)
- 8 separate scoring calls (wasteful)
- No retry logic (single failure = skipped company)
- No cache (re-scraped unchanged pages weekly)
- No duplicate detection
- Fixed weights (couldn't adapt)

### v2 (New — Under Development)

```
ICP Definition → Planner Agent
  ↓
Search Query Generator (50 queries)
  ↓
Source Executor (Google Maps, TradeIndia, Indiamart, etc.)
  ↓
Domain Validation + Normalization + Dedup
  ↓
Initial Qualification (score >= 60?)
  ↓
company_queue (same entry point)
  ↓
Rule Engine (regex before AI)
  ↓
Evidence Extraction (8 specialized extractors in parallel)
  ↓
AI Planner (decides which source to query next)
  ↓
Multi-Model Verification (DeepSeek → MiMo → agreement)
  ↓
Single Scoring Call (not 8)
  ↓
Export with Evidence Envelopes
```

**v2 improvements:**
- Autonomous company discovery (zero manual entry)
- Evidence-based extraction (every field has `{value, confidence, source, evidence, source_url}`)
- No hallucinations (if no evidence, field is null)
- Multi-model verification (DeepSeek + MiMo, discard if disagreement)
- Single scoring call (87% cheaper)
- Rule engine (regex first, AI only for gaps)
- Hash-based caching (skip unchanged pages)
- Duplicate detection (fuzzy name + domain matching)
- Learning system (tracks source performance over time)
- AI Planner (decides what to search next)

---

## 3. Workflow Inventory

### Current Active Workflows (As of July 2026)

| # | Name | File | Status | Purpose |
|---|------|------|--------|---------|
| 1 | Jasfo Weekly Master | `jasfo-weekly-master.json` | ✅ Active | Enqueues companies Mon 1AM |
| 2 | Jasfo Discovery Processor | `jasfo-discovery-processor.json` | ✅ Active | Firecrawl scrape, cache check |
| 3 | JASFO AI Processor | `jasfo-ai-processor.json` | ✅ Active | DeepSeek entity extraction |
| 4 | JASFO Scoring Processor | `jasfo-scoring-processor.json` | ✅ Active | 8-pillar scoring |
| 5 | JASFO Export Processor | `jasfo-export-processor.json` | ✅ Active | Telegram + Google Sheets |

### v2 Workflows (In Development)

| # | Name | File | Status | Purpose |
|---|------|------|--------|---------|
| 6 | Jasfo v2 - ICP Manager | `jasfo-v2-icp-manager.json` | ✅ Active | Triggered discovery cycles |
| 7 | Jasfo v2 - Discovery Planner | `jasfo-v2-discovery-planner.json` | ❌ Buggy | AI planner → 50 search queries |
| 8 | Jasfo v2 - Source Executor | `jasfo-v2-source-executor.json` | ✅ Untested | Execute queries against sources |
| 9 | Jasfo v2 - Normalizer & Qualifier | `jasfo-v2-normalizer-qualifier.json` | ❌ Error | Domain validation, dedup, scoring |
| 10 | Jasfo v2 - Learner | `jasfo-v2-learner.json` | ✅ Untested | Source performance analytics |

### Archived (Replaced)

| Name | Reason |
|------|--------|
| Jasfo v2 - Discovery Planner (archived) | Buggy code node API syntax, re-imported fresh |

---

## 4. Workflow Details — v1 (Stable)

### 4.1 Jasfo Weekly Master

**Trigger:** Cron `0 1 * * 1` (Monday 1AM)

**Nodes (5):**
1. Schedule Trigger — Cron
2. HTTP GET — Load companies from Supabase `company_queue`
3. Code — Validate companies (name >= 2 chars), generate run_id
4. IF — Route valid companies to insert, meta to Telegram
5. HTTP POST — Insert into `scenario_queue`
6. HTTP POST — Telegram start notification

**What it does:** Loads the manually populated `company_queue` table, validates entries, inserts them into `scenario_queue` with status `pending`, and sends a Telegram notification.

**Known issues:** None (stable, running weekly).

---

### 4.2 Jasfo Discovery Processor

**Trigger:** Cron `0,30 0-23 * * 1` (Monday every 30min)

**Nodes (11):**
1. Schedule Trigger
2. HTTP GET — Load pending items from `scenario_queue` (limit 25)
3. IF — Items found?
4. SplitInBatches — batchSize 1
5. HTTP GET — Check `scrape_cache`
6. IF — Cache hit?
7. HTTP POST — Firecrawl `/v1/crawl`
8. HTTP POST — Firecrawl `/v1/scrape`
9. Code — Merge scraped data
10. HTTP POST — Insert into `scrape_cache`
11. HTTP PATCH — Update queue status to `ai_ready`

**What it does:** Picks pending companies (25 per run), checks cache, scrapes with Firecrawl, stores results, marks as `ai_ready`.

**Known issues:** None (stable).

---

### 4.3 JASFO AI Processor

**Trigger:** Cron `0,30 0-23 * * 1-2` (Mon-Tue every 30min)

**Nodes (9):**
1. Schedule Trigger
2. HTTP GET — Load `ai_ready` items (limit 20)
3. SplitInBatches
4. HTTP GET — Load scrape cache
5. Code — Build AI prompt
6. HTTP POST — OpenCode GO chat completion (DeepSeek V4 Flash)
7. Code — Parse and validate JSON
8. HTTP POST — Insert into `ai_extractions`
9. HTTP PATCH — Update queue to `scoring_ready`

**What it does:** Calls DeepSeek V4 Flash to extract structured company data from scraped content.

**Known issues:** No evidence tracking (v1 limitation).

---

### 4.4 JASFO Scoring Processor

**Trigger:** Cron `0,30 0-23 * * 1-2` (Mon-Tue every 30min)

**Nodes (16):**
1. Schedule Trigger
2. HTTP GET — Load `scoring_ready` items (limit 12)
3. SplitInBatches
4. HTTP GET — Load AI extraction
5-12. 8× HTTP POST — Score each pillar (Move Intent 35%, Growth 15%, etc.)
13. Code — Calculate weighted composite
14. HTTP POST — MiMo verification
15. HTTP POST — Insert into `score_cards`
16. HTTP PATCH — Update queue to `export_ready`

**What it does:** Calls DeepSeek 8 times per company (one per pillar), aggregates into composite score, verifies with MiMo.

**Known issues:** Expensive (8 API calls per company), no evidence tracking.

---

### 4.5 JASFO Export Processor

**Trigger:** Cron `0,30 0-23 * * 1-2` (Mon-Tue every 30min)

**Nodes (10):**
1. Schedule Trigger
2. HTTP GET — Load `export_ready` items (limit 30)
3. SplitInBatches
4. HTTP GET — Load score card
5. HTTP GET — Load AI extraction
6. Code — Build Telegram message
7. HTTP POST — Send to Telegram
8. HTTP POST — (Optional) Google Sheets append
9. HTTP POST — Insert into `report_archive`
10. HTTP PATCH — Update queue to `done`

**What it does:** Formats scored leads and delivers them to Telegram group and (optionally) Google Sheets.

**Known issues:** None (stable).

---

## 5. Workflow Details — v2 (In Progress)

### 5.1 Jasfo v2 - ICP Manager

**Trigger:** Cron `0 6 * * 1` (Monday 6AM)

**Nodes (5):**
1. Schedule Trigger
2. HTTP GET — Load active ICPs from `icp_profiles`
3. IF — Any active ICPs?
4. HTTP POST — Create `planner_runs` entry
5. HTTP POST — Telegram notification

**History of bugs & fixes:**

| Date | Issue | Fix |
|------|-------|-----|
| Jul 12 | Workflow imported but didn't create planner runs | Added `response.simplify: true` to HTTP node options |
| Jul 12 | POST to `planner_runs` failed (unknown columns `icp_name`, `triggered_at`) | Changed to valid columns: `icp_id`, `status`, `started_at` |
| Jul 13 | IF condition `$json.id != null` false for Supabase array response | Changed to `$json.length > 0` for array + `simplify: true` |

**Status:** ✅ Active and working. Creates `planner_runs` when ICP exists.

---

### 5.2 Jasfo v2 - Discovery Planner

**Trigger:** Cron `*/15 * * * 1` (Monday every 15min)

**Nodes (12):**
1. Schedule Trigger
2. HTTP GET — Load pending planner run
3. IF — Run found?
4. HTTP GET — Load ICP profile
5. Code — Build planner prompt
6. HTTP POST — OpenCode GO (DeepSeek)
7. Code — Parse planner decision
8. Code — Generate 50 search queries
9. HTTP POST — Insert search queries
10. HTTP POST — Insert planner decision
11. HTTP POST — Update run status to `executing`
12. Code — Collapse 50 items to 1 for PATCH

**History of bugs & fixes:**

| Date | Issue | Fix |
|------|-------|------|
| Jul 12 | Task agent created with `$node["Name"].json` (deprecated syntax in n8n Cloud) | Need `$("Name").first().json` |
| Jul 12 | Column `source_type` doesn't exist in `search_queries` table | Changed to `source` |
| Jul 12 | Column `query` doesn't exist | Changed to `query_text` |
| Jul 12 | URL in Load ICP Profile was literal text, not expression | Changed to `={{ 'url...' + expression }}` |
| Jul 13 | IF condition `$json.length > 0` fails when n8n auto-simplifies response | Changed to handle both `$json.id` (simplified) and `$json[0]` (array) |
| Jul 13 | Code node async `$helpers.httpRequest()` may not work | Simplified to synchronous code |
| Jul 13 | Generated 50 items → PATCH called 50 times individually | Added collapse-to-single Code node |

**Status:** ❌ Still debugging. The IF condition and data flow through nodes needs final fix.

**Root cause of all v2 bugs:**
1. Task agent generated workflows using `$node["Name"].json` syntax — this is deprecated in current n8n Cloud. Correct: `$("Name").first().json`
2. Task agent used wrong column names (`query` instead of `query_text`, `source_type` instead of `source`, `triggered_at` instead of `started_at`)
3. Supabase REST API returns arrays — n8n HTTP nodes need `response.simplify: true` to convert to individual items
4. URL expressions need `={{ }}` wrapper — without it, n8n treats them as literal strings
5. MCP `setNodeParameter` operations sometimes corrupt node config by adding duplicate parameter blocks instead of replacing

---

### 5.3 Jasfo v2 - Source Executor

**Trigger:** Cron `*/15 * * * 1` (Monday every 15min)

**Nodes (9):**
1. Schedule Trigger
2. HTTP GET — Load search queries without results
3. IF — Found any?
4. SplitInBatches
5. Code — Route to source-specific handler
6. HTTP POST — Firecrawl search/scrape
7. HTTP POST — GitHub search
8. Code — Parse results
9. HTTP POST — Insert raw companies

**Status:** ✅ Valid JSON, not yet tested (depends on Discovery Planner producing queries).

---

### 5.4 Jasfo v2 - Normalizer & Qualifier

**Trigger:** Cron `*/30 * * * 1-2` (Mon-Tue every 30min)

**Status:** ❌ Archived — had same `source_type`/`source` column issues and code node syntax issues. Needs re-import from fixed file.

---

### 5.5 Jasfo v2 - Learner

**Trigger:** Cron `0 8 * * 1` (Monday 8AM)

**Status:** ✅ Valid JSON, not yet tested (depends on pipeline completing).

---

## 6. Supabase Integration

### Key Tables

| Table | Purpose | Used By |
|-------|---------|---------|
| `company_queue` | Source companies (v1 entry point) | Weekly Master (v1) |
| `scenario_queue` | Pipeline state machine | All v1 workflows |
| `scrape_cache` | Website scrape results (7-day TTL) | Discovery Processor |
| `ai_extractions` | AI entity extraction results | AI Processor |
| `score_cards` | 8-pillar scoring results | Scoring Processor |
| `report_archive` | Delivered report records | Export Processor |
| `cost_log` | API cost tracking | Cost Monitor |
| `icp_profiles` | Ideal Customer Profiles | v2 ICP Manager |
| `planner_runs` | Discovery cycle tracker | v2 Discovery Planner |
| `planner_decisions` | AI planner decisions | v2 Discovery Planner |
| `search_queries` | Generated search queries | v2 Source Executor |
| `raw_companies` | Unprocessed discovered companies | v2 Source Executor |
| `normalized_companies` | Deduplicated, validated companies | v2 Normalizer |
| `duplicate_matches` | Duplicate pairs | v2 Normalizer |
| `domain_validation` | Domain check results | v2 Normalizer |
| `initial_scores` | Lightweight qualification scores | v2 Normalizer |
| `source_statistics` | Source performance metrics | v2 Learner |
| `signal_groups` | Scoring signal group definitions | v2 Scoring |
| `scoring_weights` | Evolvable scoring weights | v2 Scoring |
| `scoring_outcomes` | Actual sales outcomes | v2 Learning |
| `observability_events` | Pipeline metrics | All v2 workflows |

### Connection Details
- **URL:** `https://nswlrolnbvjzgbkyxrkp.supabase.co/rest/v1`
- **Auth:** Bearer token (service_role key)
- **SQL Editor:** `https://supabase.com/dashboard/project/nswlrolnbvjzgbkyxrkp`

### Important — API Behavior

The Supabase REST API (`/rest/v1/{table}`) returns data as **JSON arrays**. For example:
```json
[{ "id": "abc", "status": "planning" }]
```

In n8n, HTTP Request nodes handle this in two ways:
- **Without `simplify` option:** `$json` = the full array `[{...}]`. Access elements via `$json[0]`.
- **With `response.simplify: true`:** `$json` = individual item `{...}`. Access via `$json.id`.

We use **without simplify** in most cases to keep it simple, and handle arrays in Code nodes using `Array.isArray($json) ? $json[0] : $json`.

---

## 7. Credentials & API Keys

### Embedded Inline in Workflows

| Service | Key | Where Used |
|---------|-----|------------|
| Supabase service_role | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...YpeEY5vzkrGzwnMv5wIKvGGAZYE6sTABwyLm4PGMHRk` | All HTTP nodes to Supabase |
| OpenCode GO | `sk-MmeX9RLWQrIFngobzyoLIoVjLx58ObW5ZhUmqYbwhPucZc8Nn46jQbvw4Vuf2yCA` | All AI calls |
| Firecrawl | `fc-03ee582d75c647c59555df35374d8fa2` | Scraping nodes |
| Telegram Bot | `8688503635:AAH4obxx3lGXYhoke1hR8mFJvoTvflVRrnE` | Notification nodes |
| Telegram Group | `-5497421027` | Lead delivery |
| Telegram Admin | `5936648348` | Cost alerts |

### Stored in GitHub (public repo risk)

These keys are in the workflow JSON files on GitHub. The repository is public. **If security is a concern, rotate these keys and use n8n credential store instead.**

---

## 8. Common Failures & Fixes

### 8.1 "invalid input syntax for type uuid: "" $json[0].icp_id """

**Cause:** URL expression is treated as literal text because it lacks `={{ }}` wrapper.
**Fix:** Change URL field to:
```
={{ 'https://.../table?id=eq.' + $json[0].icp_id + '&select=*' }}
```

### 8.2 "Unknown alias: und"

**Cause:** Schedule Trigger field set to `"cron"` instead of `"cronExpression"`.
**Fix:** Change to `"field": "cronExpression"`.

### 8.3 Workflow executes in <500ms (too fast)

**Cause:** IF node condition fails → workflow takes empty false branch → no work done.
**Common causes:**
- Supabase response is array, but IF checks `$json.id` (should be `$json[0].id` or `$json.length > 0`)
- No data in table matching filter condition
- HTTP node response not properly parsed

### 8.4 "d[g] is not iterable" on import

**Cause:** JSON file has invalid structure, non-UUID node IDs, or missing required fields.
**Fix:** Use valid UUID v4 for all node IDs. Ensure `nodes` array and `connections` object are correct.

### 8.5 MCP `setNodeParameter` creates duplicate configs

**Cause:** MCP operations add parameter blocks without removing old ones, causing node to have two conflicting configurations.
**Fix:** Delete and re-import the workflow when MCP operations corrupt it.

### 8.6 `$node["Name"].json` returns undefined in Code nodes

**Cause:** Modern n8n Cloud uses `$("Name").first().json` API, not `$node["Name"].json`.
**Fix:** Replace `$node["NodeName"].json` with `$("NodeName").first().json`.

### 8.7 Supabase INSERT fails with unknown columns

**Cause:** Body parameters include column names that don't exist in the table.
**Fix:** Check table schema in Supabase and only use valid column names.

---

## 9. n8n MCP Operations

### How MCP is accessed

```
URL: https://learningn8nudemy.app.n8n.cloud/mcp-server/http
Method: POST
Headers:
  Authorization: Bearer {token}
  Content-Type: application/json
  Accept: application/json, text/event-stream
Body: JSON-RPC format
```

### Available MCP Tools

| Tool | Purpose | Key Arguments |
|------|---------|---------------|
| `search_workflows` | List/search workflows | `query`, `limit`, `sortBy` |
| `get_workflow_details` | Get full workflow JSON | `workflowId` |
| `create_workflow_from_code` | Import new workflow | `workflow` (full JSON) |
| `update_workflow` | Modify existing workflow | `workflowId`, `operations[]` |
| `publish_workflow` | Activate workflow | `workflowId` |
| `unpublish_workflow` | Deactivate workflow | `workflowId` |
| `archive_workflow` | Soft-delete workflow | `workflowId` |
| `execute_workflow` | Run workflow once | `workflowId` |
| `get_execution` | Get execution details | `workflowId`, `executionId` |
| `search_executions` | List recent executions | `workflowId`, `limit` |
| `list_credentials` | List configured credentials | (none) |

### MCP Operations for `update_workflow`

| Operation Type | Description | Arguments |
|---------------|-------------|-----------|
| `setNodeParameter` | Set a node parameter | `nodeName`, `path`, `value`, `replace` |
| `addNode` | Add a new node | `node` (full node object) |
| `addConnection` | Add connection between nodes | `source`, `target` |
| `removeConnection` | Remove connection | `source`, `target` |

### Important — MCP Limitations

1. **Upload timeouts:** Large workflow JSON files (>50KB) frequently time out from slow networks. Solution: Import via n8n UI instead.
2. **Token expiry:** MCP Bearer tokens expire periodically. Refresh from n8n Settings → MCP Server.
3. **Corrupting updates:** `setNodeParameter` can create duplicate parameter blocks if not careful with `replace: true`.
4. **No detailed error messages:** `get_execution` returns high-level success/error but not node-level error details. Check n8n UI for actual error messages.

---

## 10. Pipeline Data Flow

### v1 Pipeline (Working)

```
Monday 1AM
  │
Weekly Master ──→ company_queue ──→ scenario_queue (status=pending)
  │                                          │
  ▼                                          ▼
Discovery Processor (every 30min) ──→ status=completed, next_step=ai_ready
  │                                          │
  ▼                                          ▼
AI Processor (every 30min) ──→ status=completed, next_step=scoring_ready
  │                                          │
  ▼                                          ▼
Scoring Processor (every 30min) ──→ status=completed, next_step=export_ready
  │                                          │
  ▼                                          ▼
Export Processor (every 30min) ──→ Telegram + Sheets → status=done
```

### v2 Pipeline (Target)

```
ICP Definition
  │
  ▼
ICP Manager (Mon 6AM) ──→ planner_runs (status=planning)
  │
  ▼
Discovery Planner (every 15min) ──→ 50 search queries ──→ status=executing
  │
  ▼
Source Executor (every 15min) ──→ raw_companies
  │
  ▼
Normalizer & Qualifier (every 30min) ──→ normalized_companies
  │                                         │
  ▼                                         ▼
Domain Validation ──→ Duplicate Check ──→ Initial Score >= 60?
  │                                         │
  ▼                                         ▼
company_queue (same as v1) ←────────────────┘
  │
  ▼
v1 pipeline takes over (scrape → AI → score → export)
```

---

## 11. Cost & Usage

### n8n Plan

| Tiers | Executions/Month | Active Workflows | Cost |
|-------|-----------------|-----------------|------|
| Starter | 2,500 | 5 | $24/mo |

### Weekly Execution Budget (v1)

| Workflow | Runs/Week | With Data | Empty |
|----------|-----------|-----------|-------|
| Weekly Master | 1 | 1 | 0 |
| Discovery Processor | 48 | ~10 | 38 |
| AI Processor | 96 | ~13 | 83 |
| Scoring Processor | 96 | ~21 | 75 |
| Export Processor | 96 | ~9 | 87 |
| **Total** | **~337** | **~54** | **~283** |

**Monthly:** ~337 executions/week × 4.3 = ~1,449/month (within 2,500 Starter limit)

### API Costs

| Service | Weekly Cost | Monthly Cost |
|---------|-------------|--------------|
| OpenCode GO (DeepSeek) | ~$1.00 | ~$4.00 |
| OpenCode GO (MiMo) | ~$0.10 | ~$0.40 |
| Firecrawl (Hobby plan) | Fixed $19/mo | $19.00 |
| Supabase (Free plan) | $0 | $0 |
| Telegram | $0 | $0 |
| **Total** | **~$1.10 + FC** | **~$23.40** |

---

## 12. Troubleshooting

### Workflow won't activate

Check:
1. Is it within the 5 active workflow limit? Deactivate unused ones.
2. Are all required credentials configured?
3. Are there any expression errors in node parameters?

### "Unauthorized" on MCP

Token expired. Get new one:
1. n8n → Settings → MCP Server → Copy token
2. Use new token in Authorization header

### Import fails with JSON error

1. Validate JSON at https://jsonlint.com
2. Check node IDs are valid UUID v4 format
3. Check all node types exist (e.g., `n8n-nodes-base.httpRequest`)
4. Check connections don't reference non-existent nodes

### Pipeline runs but no output

1. Check Supabase tables have data
2. Check IF node conditions are correct
3. Check cron schedules — are they set for the right days?
4. Check workflow execution logs in n8n UI

### v2 workflows not producing results

**Checklist:**
1. `icp_profiles` table has at least one active ICP (`is_active = true`)
2. `planner_runs` table has a run with `status = 'planning'`
3. Discovery Planner IF condition correctly evaluates to true
4. OpenCode GO API is reachable and returns valid JSON
5. Search queries are inserted into `search_queries` table
6. Source Executor finds queries and executes them
7. Raw companies are inserted into `raw_companies` table
8. Normalizer processes raw companies and inserts into `company_queue`

### API returns 400 "invalid input syntax"

Check:
1. UUID values are valid UUIDs (not empty strings, not labels)
2. Column names match the database schema
3. Enum values match the column constraints

---

## 13. What We Want to Achieve

### Short-term Goals (This Week)

1. ✅ v2 ICP Manager working — creates planner runs
2. ❌ v2 Discovery Planner working — generates 50 search queries
3. ❌ v2 Source Executor working — discovers companies from sources
4. ❌ v2 Normalizer working — validates, deduplicates, scores, queues
5. ✅ All v1 workflows stable and running weekly

### Medium-term Goals (2-3 Weeks)

1. Autonomous pipeline runs without manual company entry
2. Evidence-based extraction with multi-model verification
3. Explainable scoring with dynamic weights
4. Learning system adjusts source priorities based on performance
5. Cost monitor alerts when budget exceeded

### Long-term Goals (1-2 Months)

1. Scale to 10,000 companies/week without cost increase
2. Integrate 10+ free enrichment sources
3. ML-based duplicate detection (vector similarity)
4. Automated ICP refinement based on conversion data
5. Self-healing pipeline (auto-retry, fallback chains)

### Key Metrics

| Metric | Current (v1) | Target (v2) |
|--------|-------------|-------------|
| Companies discovered/week | Manual only | 500+ |
| Hallucination rate | ~5-8% | <0.5% |
| Cost per lead | ~$0.05 | ~$0.03 |
| Pipeline completion time | ~12h | ~6h |
| Evidence coverage | None | 100% |
| Duplicate detection | None | >=95% |
| Source automation | None | 15+ sources |

---

## Quick Reference — Common n8n Expressions

```javascript
// Reference another node in expressions
{{ $node["Node Name"].json.field }}          // legacy (deprecated in some versions)
{{ $("Node Name").json.field }}              // current API

// Reference another node in Code nodes
$("Node Name").first().json                  // first item
$("Node Name").all()                          // all items

// Access webhook data
$json.body.field                              // Webhook payload

// Current timestamp
{{ $now.toFormat('yyyy-MM-dd') }}             // formatted date
{{ new Date().toISOString() }}                // ISO timestamp in Code

// Supabase array handling (in Code nodes)
const data = Array.isArray($json) ? $json[0] : $json;

// IF node condition (works for both array and simplified)
{{ $json.id != null || (Array.isArray($json) && $json.length > 0) }}

// HTTP Request URL expression
={{ 'https://supabase.co/rest/v1/table?id=eq.' + $json[0].id + '&select=*' }}
```
