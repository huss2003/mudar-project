# Scraping Best Practices

This document covers rate limiting, politeness, anti-blocking, and other best practices for the Jasfo Lead Intelligence Platform's scraping layer.

---

## Rate Limiting

### Per-Domain Limits

To avoid triggering rate limits or blocking on target websites:

| Setting | Value | Rationale |
|---------|-------|-----------|
| Max requests per domain | 10 per minute | Standard politeness policy |
| Min delay between requests | 6 seconds | Respect server load |
| Max concurrent connections | 2 per domain | Avoid connection pool exhaustion |
| Request jitter | +/– 2 seconds | Avoid pattern detection |

### Implementation (Make.com)

`json
{
  "rate_limiter": {
    "module": "Flow Control / Rate Limiter",
    "config": {
      "max_operations": 10,
      "time_window_seconds": 60,
      "distribute_evenly": true
    }
  }
}
`

A token bucket algorithm manages per-domain rate limits:

`python
class TokenBucket:
    def __init__(self, rate=10, per=60, burst=5):
        self.rate = rate
        self.per = per
        self.burst = burst
        self.tokens = burst
        self.last_refill = time.time()

    def consume(self):
        now = time.time()
        elapsed = now - self.last_refill
        self.tokens = min(self.burst, self.tokens + elapsed * (self.rate / self.per))
        self.last_refill = now
        if self.tokens >= 1:
            self.tokens -= 1
            return True
        return False
`

---

## Politeness Policy

### Robots.txt Compliance

Before scraping any domain, check obots.txt:

`http
GET https://acme.com/robots.txt
`

The scraper respects all Disallow directives. If a path is disallowed, it is skipped entirely.

`python
from urllib.robotparser import RobotFileParser

def check_allowed(url, user_agent="JasfoBot/1.0"):
    rp = RobotFileParser()
    rp.set_url(f"{url.scheme}://{url.netloc}/robots.txt")
    rp.read()
    return rp.can_fetch(user_agent, url.geturl())
`

### User-Agent

`http
User-Agent: JasfoBot/1.0 (Lead Intelligence Platform; +https://jasfo.com/bot)
`

The user agent identifies the scraper and provides a contact URL for site owners who wish to block or discuss access.

### Crawl Delay

If the obots.txt specifies a Crawl-Delay, it is honored:

`python
crawl_delay = rp.crawl_delay("*")  # Seconds between requests
request_delay = max(crawl_delay or 6, 6)
`

---

## Anti-Blocking Measures

### Headers

All requests include standard browser-like headers:

`http
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8
Accept-Language: en-US,en;q=0.5
Accept-Encoding: gzip, deflate, br
Connection: keep-alive
Upgrade-Insecure-Requests: 1
Sec-Fetch-Dest: document
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: none
Sec-Fetch-User: ?1
`

### Request Timing

Requests are distributed with jitter to avoid pattern detection:

`python
import random
import time

def polite_delay(base_seconds=6):
    jitter = random.uniform(-2, 3)  # +/- 2 seconds, biased longer
    total = base_seconds + jitter
    time.sleep(total)
`

### Detection Avoidance

| Signal | Mitigation |
|--------|-----------|
| Fixed interval requests | Add random jitter (+/- 30%) |
| Missing headers | Set complete browser-like headers |
| No JavaScript | Accept that some sites require JS |
| Known bot IP ranges | Firecrawl handles IP rotation |
| High request rate | Per-domain rate limiter |

---

## Block Detection

The platform detects blocks by checking for:

`python
BLOCK_PATTERNS = [
    "captcha",
    "access denied",
    "please verify",
    "suspicious activity",
    "too many requests",
    "try again later",
    "403 Forbidden",
    "404 Not Found",  # As a redirect from valid pages
]
`

When a block is detected:

1. Abort current request immediately.
2. Wait 60 seconds before retrying the domain.
3. Reduce the rate limit for that domain by 50%.
4. Log the block event for analysis.

---

## Data Quality Checks

Every scrape result passes through quality gates:

`python
def validate_scrape_result(result):
    checks = []

    # Content length
    if len(result.markdown) < 200:
        checks.append(("Content too short", "FAIL"))

    # Error page detection
    if any(p in result.markdown.lower() for p in ERROR_PATTERNS):
        checks.append(("Error page detected", "FAIL"))

    # Domain match
    if result.metadata.source_url and result.company_domain:
        if result.metadata.source_url.domain != result.company_domain:
            checks.append(("Domain mismatch", "WARN"))

    # Language check
    if result.metadata.language and result.metadata.language != "en":
        checks.append(("Non-English content", "WARN"))

    return checks
`

Results with any FAIL are retried or discarded. WARN results proceed with a confidence penalty.

---

## Error Recovery

| Scenario | Recovery | Priority |
|----------|----------|----------|
| Single page fails | Retry 3x, then skip | Low |
| All pages for a company fail | Try search fallback | High |
| Domain consistently blocking | Add to blocklist, skip | Medium |
| Firecrawl API down | Wait 5 min, retry all | Critical |
| Credit limit reached | Halt non-essential scraping | Critical |

---

## Monitoring

### Key Metrics

| Metric | Target | Alert if |
|--------|--------|----------|
| Success rate | > 95% | < 90% over 1 hour |
| Average response time | < 5s | > 10s over 10 requests |
| Block rate | < 1% | > 5% over 1 hour |
| Cache hit rate | > 40% | < 20% over 1 day |
| Credit utilization | < 25% monthly | > 50% monthly |

### Dashboard Query

`sql
SELECT
  DATE_TRUNC('hour', created_at) AS hour,
  source_type,
  COUNT(*) AS total_requests,
  COUNT(*) FILTER (WHERE status = 'success') AS successful,
  ROUND(COUNT(*) FILTER (WHERE status = 'success')::numeric / COUNT(*) * 100, 1) AS success_rate,
  AVG(response_time_ms)::int AS avg_response_ms
FROM scrape_log
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY hour, source_type
ORDER BY hour DESC;
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial best practices documentation |
