# Logging

Logging is implemented across all Make.com scenarios to track execution, errors, costs, and performance metrics. All logs are stored in Supabase for querying and dashboard use.

---

## Log Architecture

`mermaid
flowchart TD
    A[Scenario Execution] --> B[Module Logs]
    B --> C[Supabase: scenario_logs]
    A --> D[Error Logs]
    D --> E[Supabase: scenario_errors]
    A --> F[Cost Logs]
    F --> G[Supabase: credit_usage]
    A --> H[Queue Logs]
    H --> I[Supabase: scenario_queue]
`

---

## Log Tables

### scenario_logs

Tracks every module execution across all scenarios:

`sql
CREATE TABLE scenario_logs (
  id SERIAL PRIMARY KEY,
  run_id UUID NOT NULL,
  scenario_name TEXT NOT NULL,
  module_name TEXT,
  company_domain TEXT,
  status TEXT NOT NULL,           -- 'success', 'error', 'skipped'
  duration_ms INTEGER,
  input_summary TEXT,             -- Truncated input for debugging
  output_summary TEXT,            -- Truncated output for debugging
  credits_consumed INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_logs_run ON scenario_logs (run_id);
CREATE INDEX idx_logs_scenario ON scenario_logs (scenario_name);
CREATE INDEX idx_logs_company ON scenario_logs (company_domain);
CREATE INDEX idx_logs_created ON scenario_logs (created_at);
`

### scenario_errors

Tracks all errors with detailed context:

`sql
CREATE TABLE scenario_errors (
  id SERIAL PRIMARY KEY,
  run_id UUID NOT NULL,
  scenario_name TEXT NOT NULL,
  company_domain TEXT,
  module_name TEXT,
  error_category TEXT NOT NULL,    -- 'transient', 'auth', 'data', 'infra'
  error_message TEXT,
  error_detail JSONB,              -- Full error payload
  status_code INTEGER,
  attempt_number INTEGER DEFAULT 1,
  resolved BOOLEAN DEFAULT false,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
`

### credit_usage

Tracks Firecrawl and AI API credit consumption:

`sql
CREATE TABLE credit_usage (
  id SERIAL PRIMARY KEY,
  run_id UUID NOT NULL,
  company_domain TEXT,
  source_type TEXT NOT NULL,       -- 'firecrawl', 'openai', 'anthropic'
  operation TEXT NOT NULL,         -- 'crawl', 'scrape', 'extract', 'search', 'completion'
  credits_consumed NUMERIC(10, 4) NOT NULL,
  tokens_consumed INTEGER,         -- For AI models
  model_used TEXT,                  -- For AI models
  created_at TIMESTAMPTZ DEFAULT NOW()
);
`

---

## Logging Modules (Make.com)

### Module Logging Pattern

Every HTTP module writes a log entry after execution:

`json
{
  "module": "Supabase / Insert Row",
  "config": {
    "table": "scenario_logs",
    "columns": {
      "run_id": "{{run_id}}",
      "scenario_name": "scenario-03-firecrawl",
      "module_name": "Firecrawl Deep Crawl",
      "company_domain": "{{company_domain}}",
      "status": "{{http.status_code == 200 ? 'success' : 'error'}}",
      "duration_ms": "{{http.duration_ms}}",
      "input_summary": "{{truncate(request_body, 200)}}",
      "output_summary": "{{truncate(response_body, 200)}}",
      "credits_consumed": "{{http.status_code == 200 ? 1 : 0}}",
      "created_at": "{{now}}"
    }
  }
}
`

### Error Logging Module

`json
{
  "module": "Supabase / Insert Row",
  "config": {
    "table": "scenario_errors",
    "columns": {
      "run_id": "{{run_id}}",
      "scenario_name": "{{scenario_name}}",
      "company_domain": "{{company_domain}}",
      "module_name": "{{module_name}}",
      "error_category": "{{classify_error(http)}}",
      "error_message": "{{http.error}}",
      "error_detail": "{{http.response}}",
      "status_code": "{{http.status_code}}",
      "attempt_number": "{{retry_attempt}}",
      "created_at": "{{now}}"
    }
  }
}
`

---

## Dashboard Queries

### Run Summary

`sql
SELECT
  run_id,
  scenario_name,
  COUNT(*) AS total_modules,
  COUNT(*) FILTER (WHERE status = 'success') AS success_count,
  COUNT(*) FILTER (WHERE status = 'error') AS error_count,
  SUM(duration_ms) AS total_duration_ms,
  SUM(credits_consumed) AS total_credits
FROM scenario_logs
WHERE run_id = '{{run_id}}'
GROUP BY run_id, scenario_name;
`

### Error Rate Over Time

`sql
SELECT
  DATE_TRUNC('hour', created_at) AS hour,
  COUNT(*) AS total_logs,
  COUNT(*) FILTER (WHERE status = 'error') AS errors,
  ROUND(
    COUNT(*) FILTER (WHERE status = 'error')::numeric / COUNT(*) * 100, 2
  ) AS error_rate
FROM scenario_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour;
`

### Most Common Errors

`sql
SELECT
  error_category,
  error_message,
  COUNT(*) AS occurrences,
  COUNT(DISTINCT company_domain) AS affected_companies
FROM scenario_errors
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY error_category, error_message
ORDER BY occurrences DESC
LIMIT 20;
`

---

## Telegram Log Notifications

### Execution Summary (per batch)

`json
{
  "module": "Telegram / Send Message",
  "config": {
    "chat_id": "{{secrets.TELEGRAM_CHANNEL_ID}}",
    "text": "📊 *Batch Complete: {{scenario_name}}*\n\nCompanies: {{total}} ✅ {{success}} | ❌ {{errors}} | ⏭️ {{skipped}}\nDuration: {{duration_minutes}} min\nCredits: {{credits}}\n\nRun ID: {{run_id}}"
  }
}
`

### Error Summary (per batch)

`json
{
  "module": "Telegram / Send Message",
  "config": {
    "chat_id": "{{secrets.TELEGRAM_ADMIN_CHAT_ID}}",
    "text": "⚠️ *Error Summary*\n\n{{errors_count}} errors in {{scenario_name}}\n\nTop errors:\n{{formatted_error_list}}\n\nRun ID: {{run_id}}"
  }
}
`

---

## Log Retention

| Log Type | Retention | Cleanup Policy |
|----------|-----------|----------------|
| scenario_logs | 90 days | Weekly delete job |
| scenario_errors | 180 days | Monthly archive |
| credit_usage | 365 days | Yearly archive |
| scenario_queue | 30 days after completion | Weekly delete job |

### Cleanup Query

`sql
DELETE FROM scenario_logs
WHERE created_at < NOW() - INTERVAL '90 days';

DELETE FROM scenario_errors
WHERE created_at < NOW() - INTERVAL '180 days'
  AND resolved = true;
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial logging documentation |
