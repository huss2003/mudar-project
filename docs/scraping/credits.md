# Credit Management

This document covers Firecrawl credit tracking, budget management, and optimization strategies for the Jasfo Lead Intelligence Platform.

---

## Credit System Overview

Firecrawl operates on a credit-based pricing model. Each API operation consumes a specific number of credits from the monthly plan allocation.

### Credit Consumption Rates

| Operation | Credits Consumed | Effective Cost (Growth Plan) |
|-----------|-----------------|------------------------------|
| Scrape (single page) | 1 | .03 |
| Crawl (per 500 pages) | 1 | .03 |
| Search (per 100 searches) | 1 | .0003 |
| Extract (per request) | 1 | .03 |

---

## Budget Tracking

### Monthly Budget

| Category | Monthly Credits | Monthly Cost |
|----------|----------------|--------------|
| Growth Plan | 10,000 |  |
| Estimated usage | ~2,500 | ~ |
| Buffer | 7,500 |  |

### Usage Tracking Table

`sql
CREATE TABLE credit_usage (
  id SERIAL PRIMARY KEY,
  scenario_run_id TEXT NOT NULL,
  source_type TEXT NOT NULL,
  operation TEXT NOT NULL,
  credits_consumed INTEGER NOT NULL,
  api_response_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_credit_usage_date ON credit_usage (created_at);
`

### Weekly Usage Report

`sql
SELECT
  DATE_TRUNC('week', created_at) AS week,
  source_type,
  operation,
  SUM(credits_consumed) AS total_credits,
  COUNT(*) AS total_requests
FROM credit_usage
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY week, source_type, operation
ORDER BY week DESC;
`

---

## Alert Thresholds

The platform sends alerts when credit usage approaches limits:

| Threshold | Action |
|-----------|--------|
| 50% of monthly credits used | Info log entry |
| 75% of monthly credits used | Warning notification to Telegram |
| 90% of monthly credits used | Critical alert, scenario throttling enabled |
| 100% of monthly credits used | All non-essential scraping halted |

### Alert Configuration (Make.com)

`json
{
  "module": "Telegram / Send Message",
  "config": {
    "chat_id": "{{secrets.TELEGRAM_ADMIN_CHAT_ID}}",
    "text": "⚠️ *Firecrawl Credit Alert*\n\nUsage: {{usage_percent}}%\nRemaining: {{credits_remaining}} credits\nOperation: {{triggering_operation}}\n\n{{alert_message}}"
  }
}
`

---

## Optimization Strategies

### 1. Cache First

Before any Firecrawl API call, check the Supabase cache (see caching.md). This is the single most effective cost-saving measure.

`python
# Without cache: 100 credits/day
# With cache: ~40 credits/day
# Savings: 60%
`

### 2. Extract Over Crawl

Use the Extract API instead of deep crawl when you need specific data points:

| Scenario | Crawl Cost | Extract Cost | Savings |
|----------|-----------|--------------|---------|
| Get pricing data | 3 credits (3 pages) | 1 credit (1 page) | 66% |
| Get leadership data | 2 credits (2 pages) | 1 credit (1 page) | 50% |

### 3. Depth Control

| Research Level | Avg Pages | Credits | When to Use |
|----------------|-----------|---------|-------------|
| Basic | 5 | 0.01 | > 100 companies batch |
| Standard | 15 | 0.03 | Weekly batch (default) |
| Deep | 50 | 0.10 | High-priority leads only |

### 4. Selective Extraction

Not every page needs to be scraped. Target only high-value pages and skip:
- Blog archives (low data density)
- Legal / privacy pages (no business data)
- Image galleries (no text content)

---

## Cost Per Company Estimate

| Operation | Credits | Effective Cost |
|-----------|---------|---------------|
| Deep crawl (standard depth) | 0.03 | .001 |
| Extract (2 pages) | 2.00 | .06 |
| Search (3 queries) | 0.03 | .001 |
| **Total per company** | **~2.06** | **~.062** |

For the weekly batch of 250 companies:

| Metric | Value |
|--------|-------|
| Total credits | ~515 |
| Total cost | ~.45 |
| Plan allocation | 10,000 credits |
| Utilization | ~5% |

---

## Dashboard

A credit usage dashboard is available in Supabase:

`sql
-- Current month summary
SELECT
  SUM(credits_consumed) AS total_used,
  (10000 - SUM(credits_consumed)) AS remaining,
  ROUND(SUM(credits_consumed)::numeric / 10000 * 100, 1) AS percent_used
FROM credit_usage
WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', NOW());
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial credit management documentation |
