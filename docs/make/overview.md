# Make.com Automation Overview

The Make.com (formerly Integromat) automation layer orchestrates the entire Jasfo Lead Intelligence Platform pipeline. It schedules, executes, and monitors all scraping, AI analysis, scoring, and export scenarios.

---

## Scenario Architecture

The platform is built around 6 core scenarios that execute in sequence:

`mermaid
flowchart TD
    A[Scenario 01: Weekly Master] --> B[Scenario 02: Discovery]
    B --> C[Scenario 03: Firecrawl]
    C --> D[Scenario 04: AI Analysis]
    D --> E[Scenario 05: Scoring]
    E --> F[Scenario 06: Export]
    F --> G[Telegram Notification]
`

### Scenario Summary

| # | Scenario Name | Trigger | Duration | Modules |
|---|---------------|---------|----------|---------|
| 01 | Weekly Master | Cron (Mon 9AM) | 5 min | 8 |
| 02 | Discovery | Webhook | 10 min | 15 |
| 03 | Firecrawl | Queue | 15 min | 20 |
| 04 | AI Analysis | Queue | 20 min | 12 |
| 05 | Scoring | Queue | 15 min | 18 |
| 06 | Export | Queue | 5 min | 10 |

---

## Execution Flow

`mermaid
sequenceDiagram
    participant C as Cron (Mon 9AM)
    participant S1 as Scenario 01
    participant Q as Supabase Queue
    participant S2-6 as Scenarios 02-06
    participant TG as Telegram

    C->>S1: Trigger weekly run
    S1->>S1: Load company list from CSV
    S1->>Q: Enqueue 250 companies
    loop Per Company
        Q->>S2-6: Process company
        S2-6->>S2-6: Full pipeline
        S2-6-->>S1: Status update
    end
    S1->>TG: Weekly summary report
`

### Data Passing Between Scenarios

Scenarios pass data through a shared scenario_queue table in Supabase:

`sql
CREATE TABLE scenario_queue (
  id SERIAL PRIMARY KEY,
  run_id UUID NOT NULL,
  company_name TEXT NOT NULL,
  company_domain TEXT,
  scenario_step TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  input_data JSONB,
  output_data JSONB,
  error_message TEXT,
  attempts INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
`

---

## Scheduling

| Scenario | Schedule | Notes |
|----------|----------|-------|
| 01: Weekly Master | Every Monday 09:00 UTC | Full batch processing |
| 02: Discovery | On demand (queued) | Triggered by Master |
| 03: Firecrawl | On demand (queued) | Rate-limited per domain |
| 04: AI Analysis | On demand (queued) | Batch of 5 companies |
| 05: Scoring | On demand (queued) | Requires Discovery + AI data |
| 06: Export | On demand (queued) | Delivers final output |

### Cron Format

`	ext
# Weekly Monday 9AM UTC
0 9 * * 1
`

The Master scenario also supports manual triggering with a custom company list for on-demand runs.

---

## Error Handling

All scenarios implement a standardized error handling pattern:

1. **Retry**: Transient errors (network timeouts, API rate limits) trigger automatic retry with exponential backoff.
2. **Skip**: Non-critical errors (missing data field, wrong URL format) log the error and continue to the next company.
3. **Halt**: Critical errors (API key invalid, database unreachable) halt the scenario and send an alert.

### Error Logging

`json
{
  "run_id": "run-2026-07-11-001",
  "scenario": "scenario-03-firecrawl",
  "company": "acme.com",
  "module": "Firecrawl Deep Crawl",
  "error_type": "rate_limit",
  "error_message": "HTTP 429: Rate limit exceeded",
  "attempt": 2,
  "action": "Retry with backoff",
  "timestamp": "2026-07-11T14:30:00Z"
}
`

---

## Monitoring

Each scenario logs execution data to a scenario_logs table:

`sql
CREATE TABLE scenario_logs (
  id SERIAL PRIMARY KEY,
  run_id UUID NOT NULL,
  scenario_name TEXT NOT NULL,
  module_name TEXT,
  status TEXT NOT NULL,
  duration_ms INTEGER,
  credits_consumed INTEGER,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
`

### Alert Channels

| Severity | Channel | Example |
|----------|---------|---------|
| Info | Telegram channel | "Weekly run started: 250 companies" |
| Warning | Telegram admin chat | "15 companies failed scraping" |
| Error | Telegram admin chat | "Firecrawl API returning 500s" |
| Critical | Telegram + Email | "API key invalid or revoked" |

---

## Scenario Modules Breakdown

| # | Total Modules | Key Modules |
|---|---------------|-------------|
| 01 | 8 | Cron trigger, CSV parser, Supabase queue, Telegram |
| 02 | 15 | Webhook, Supabase lookup, Firecrawl search, Company matcher |
| 03 | 20 | HTTP router, Firecrawl API, Retry aggregator, Cache writer |
| 04 | 12 | AI model caller, Response parser, Retry logic |
| 05 | 18 | Score calculator, Consensus builder, Reflection caller |
| 06 | 10 | Format converter, Telegram sender, Supabase archiver |

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial Make.com architecture documentation |
