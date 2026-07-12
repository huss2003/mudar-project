# Retry Configuration

This document details the retry configuration for all Make.com scenario modules, including backoff strategies, maximum attempts, and per-module timeout values.

---

## Global Retry Settings

These settings apply to all modules that interact with external APIs:

`json
{
  "global_retry": {
    "enabled": true,
    "max_retries": 3,
    "initial_delay_ms": 1000,
    "backoff": "exponential",
    "backoff_factor": 2,
    "max_delay_ms": 30000,
    "jitter_ms": 1000,
    "retry_on_timeout": true,
    "retry_on_error_codes": [429, 500, 502, 503, 504],
    "timeout_ms": 30000
  }
}
`

### Backoff Algorithm

`python
def get_delay(attempt, initial=1000, factor=2, max_delay=30000, jitter=1000):
    base_delay = initial * (factor ** (attempt - 1))
    capped_delay = min(base_delay, max_delay)
    jitter_amount = random.randint(0, jitter)
    return capped_delay + jitter_amount
`

| Attempt | Base Delay (2x) | With Jitter (+1s) |
|---------|-----------------|-------------------|
| 1 | 1,000 ms | 1,000–2,000 ms |
| 2 | 2,000 ms | 2,000–3,000 ms |
| 3 | 4,000 ms | 4,000–5,000 ms |
| 4 | 8,000 ms | 8,000–9,000 ms |

---

## Per-Module Retry Configuration

### Firecrawl Modules

| Module | Max Retries | Timeout | Backoff | Notes |
|--------|-------------|---------|---------|-------|
| Deep Crawl (POST) | 3 | 30s | 2x | Polling uses separate retry |
| Crawl Poll (GET) | 60 (poll intervals) | 5s per poll | N/A | Polls every 5s, 5min max |
| Scrape (POST) | 3 | 30s | 2x | |
| Extract (POST) | 3 | 30s | 2x | |
| Search (POST) | 2 | 15s | 2x | |

`json
{
  "module": "HTTP / Make a Request",
  "config": {
    "timeout": 30000,
    "retry": {
      "max_attempts": 3,
      "delay": 1000,
      "backoff": "exponential",
      "max_delay": 10000
    }
  }
}
`

### AI API Modules

| Module | Max Retries | Timeout | Backoff | Notes |
|--------|-------------|---------|---------|-------|
| OpenAI Completion | 3 | 60s | 2x | Includes token limit check |
| Anthropic Messages | 3 | 120s | 2x | Longer timeout for long contexts |
| JSON Repair | 2 | 30s | 2x | Uses cheaper model |

### Supabase Modules

| Module | Max Retries | Timeout | Backoff | Notes |
|--------|-------------|---------|---------|-------|
| Select Rows | 2 | 10s | 2x | Generally fast |
| Insert Row | 2 | 10s | 2x | |
| Update Row | 2 | 10s | 2x | |
| Delete Rows | 2 | 15s | 2x | |

### Telegram Modules

| Module | Max Retries | Timeout | Backoff | Notes |
|--------|-------------|---------|---------|-------|
| Send Message | 2 | 15s | 2x | Low priority, quick retry |

---

## Retry Scenarios

### Rate Limited (HTTP 429)

`mermaid
sequenceDiagram
    participant M as Module
    participant API as External API

    M->>API: Request
    API-->>M: 429 + Retry-After: 60
    M->>M: Wait Retry-After
    M->>API: Retry (1)
    API-->>M: 429 + Retry-After: 120
    M->>M: Wait + Backoff
    M->>API: Retry (2)
    API-->>M: 200 OK
`

When Firecrawl returns 429:

1. Extract the Retry-After header value.
2. Wait that many seconds (minimum 5s).
3. Retry with standard backoff.
4. If all retries exhausted, use search fallback.

### Server Error (HTTP 5xx)

`mermaid
sequenceDiagram
    participant M as Module
    participant API as External API

    M->>API: Request
    API-->>M: 503 Service Unavailable
    M->>M: Wait 2s (backoff 1)
    M->>API: Retry
    API-->>M: 503 Service Unavailable
    M->>M: Wait 4s (backoff 2) 
    M->>API: Retry
    API-->>M: 200 OK
`

### Timeout

`json
{
  "module": "HTTP / Make a Request",
  "config": {
    "timeout": 30000,
    "retry": {
      "max_attempts": 2,
      "on_timeout": true,
      "extended_timeout_ms": 60000,
      "delay_ms": 2000
    }
  }
}
`

On timeout:
1. Double the timeout value for the retry.
2. Wait 2 seconds.
3. Retry. If it times out again, mark as failed.

---

## Retry State Tracking

The retry state is tracked per-company in the queue item:

`json
{
  "error_history": [
    {
      "attempt": 1,
      "error": "HTTP 429",
      "timestamp": "2026-07-11T14:30:00Z",
      "delay_ms": 1000
    },
    {
      "attempt": 2,
      "error": "HTTP 429",
      "timestamp": "2026-07-11T14:31:05Z",
      "delay_ms": 2000
    },
    {
      "attempt": 3,
      "error": "HTTP 200",
      "timestamp": "2026-07-11T14:32:10Z",
      "delay_ms": 4000
    }
  ]
}
`

---

## Retry Limits by Module Category

| Category | Per-Item Max Retries | Batch Retry Limit | Cooldown Between Batches |
|----------|---------------------|-------------------|--------------------------|
| Firecrawl API | 3 per call | 50 failures/batch | 60s after 10 failures |
| OpenAI API | 3 per call | 20 failures/batch | 30s after 5 failures |
| Anthropic API | 3 per call | 20 failures/batch | 30s after 5 failures |
| Supabase DB | 2 per call | No limit | No cooldown |
| Telegram | 2 per message | No limit | 5s between messages |

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial retry configuration documentation |
