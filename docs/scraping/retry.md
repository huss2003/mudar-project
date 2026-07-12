# Retry Logic

The scraping layer implements a comprehensive retry strategy to handle transient failures, rate limits, and service interruptions across all data sources.

---

## Retry Architecture

`mermaid
flowchart TD
    A[API Request] --> B{Success?}
    B -->|Yes| C[Return Data]
    B -->|No| D{Retry Count < Max?}
    D -->|Yes| E[Calculate Delay]
    E --> F[Wait]
    F --> B
    D -->|No| G[Mark as Failed]
    G --> H[Log Error]
    H --> I[Fallback Source?]
    I -->|Yes| J[Try Fallback]
    I -->|No| K[Return Empty]
`

---

## Firecrawl Retry Configuration

`json
{
  "firecrawl": {
    "max_retries": 3,
    "initial_delay_ms": 1000,
    "backoff_factor": 2,
    "max_delay_ms": 10000,
    "jitter_ms": 500,
    "timeout_ms": 30000,
    "retry_on_status": [429, 500, 502, 503, 504],
    "retry_on_error": ["timeout", "rate_limit", "server_error"]
  }
}
`

### Backoff Calculation

`python
def calculate_delay(attempt, initial=1000, factor=2, max_delay=10000, jitter=500):
    delay = min(initial * (factor ** attempt), max_delay)
    jitter = random.uniform(0, jitter)
    return delay + jitter
`

| Attempt | Base Delay | With Jitter |
|---------|-----------|-------------|
| 1 | 1,000 ms | 1,000–1,500 ms |
| 2 | 2,000 ms | 2,000–2,500 ms |
| 3 | 4,000 ms | 4,000–4,500 ms |

---

## Apify Retry Configuration

`json
{
  "apify": {
    "max_retries": 2,
    "initial_delay_ms": 5000,
    "backoff_factor": 3,
    "max_delay_ms": 60000,
    "jitter_ms": 2000,
    "timeout_ms": 120000,
    "retry_on_status": [429, 500],
    "retry_on_error": ["actor_error", "timeout", "credit_limit"]
  }
}
`

Apify retries are more conservative because:
- Actors take longer to execute (30s–120s).
- Actor failures are often due to site changes (not transient).
- Apify credits cost real money per run.

---

## Error Classification

| Error Type | Examples | Retry Strategy |
|------------|----------|----------------|
| **Transient** | 429 (rate limit), 502 (bad gateway), 503 (unavailable) | Full retry with backoff |
| **Timeout** | Request exceeded timeout, DNS timeout | Retry with extended timeout |
| **Auth** | 401 (unauthorized), 403 (forbidden) | Do not retry — rotate credentials |
| **Client** | 400 (bad request), 404 (not found) | Do not retry — fix request |
| **Actor Error** | Apify actor crashed | Retry once, then use fallback |

### Retry Decision Matrix

`python
def should_retry(error, attempt, max_retries):
    if isinstance(error, TransientError):
        return attempt < max_retries
    elif isinstance(error, TimeoutError):
        return attempt < max_retries
    elif isinstance(error, AuthError):
        return False
    elif isinstance(error, ClientError):
        return False
    elif isinstance(error, ActorError):
        return attempt < 2
    return False
`

---

## Make.com Retry Implementation

Retry logic is implemented using Make.com's router module and aggregation:

### Retry Pattern

`low
# Scenario structure:
# 1. HTTP module (Firecrawl API call)
# 2. Router: Success vs Error path
# 3. Error path → Retry aggregator
# 4. Retry aggregator → Increment counter → Wait → HTTP module
`

### Configuration

`json
{
  "retry_aggregator": {
    "module": "Flow Control / Repeater",
    "config": {
      "max_iterations": "{{max_retries}}",
      "break_early": true
    }
  },
  "wait_module": {
    "module": "Flow Control / Sleep",
    "config": {
      "duration_ms": "{{calculate_delay(attempt)}}"
    }
  }
}
`

---

## Per-Source Type Retry

| Source Type | Max Retries | Backoff | Total Max Wait |
|-------------|-------------|---------|----------------|
| Firecrawl Crawl | 3 | Exponential (2x) | ~7.5 seconds |
| Firecrawl Scrape | 3 | Exponential (2x) | ~7.5 seconds |
| Firecrawl Search | 2 | Exponential (2x) | ~3.5 seconds |
| Firecrawl Extract | 3 | Exponential (2x) | ~7.5 seconds |
| Apify LinkedIn | 1 | Linear (30s) | 30 seconds |
| Apify Crunchbase | 1 | Linear (30s) | 30 seconds |

---

## Failure Handling

When all retries are exhausted:

### 1. Log the Failure

`json
{
  "error_type": "rate_limit",
  "source_type": "firecrawl_crawl",
  "company": "acme.com",
  "attempts": 3,
  "total_duration_ms": 7500,
  "final_error": "HTTP 429: Rate limit exceeded"
}
`

### 2. Attempt Fallback

| Primary | Fallback | Fallback Delay |
|---------|----------|----------------|
| Firecrawl deep crawl | Firecrawl search | Immediate |
| Firecrawl extract | Markdown scrape + AI parse | Immediate |
| Firecrawl search | Apify actor | 30s |
| Apify LinkedIn | Manual entry | N/A |

### 3. Mark as Failed

If both primary and fallback fail, the company is flagged in the pipeline:

`json
{
  "company_domain": "acme.com",
  "scrape_status": "failed",
  "failure_reason": "All retries exhausted for crawl and search",
  "next_action": "Manual review recommended"
}
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial retry logic documentation |
