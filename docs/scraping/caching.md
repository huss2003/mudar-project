# Scrape Result Caching

All scraping results are cached in Supabase to avoid redundant API calls, control costs, and improve scenario execution speed.

---

## Cache Architecture

`mermaid
flowchart TD
    A[Scrape Request] --> B{Cache Check}
    B -->|Hit| C[Return Cached]
    B -->|Miss| D[Execute Scrape]
    D --> E[Store in Cache]
    E --> F[Return Fresh]
    C --> G[Check TTL]
    G -->|Expired| D
`

### Cache Storage

Results are stored in the scrape_cache table in Supabase:

`sql
CREATE TABLE scrape_cache (
  cache_key TEXT PRIMARY KEY,
  source_type TEXT NOT NULL,        -- 'crawl', 'extract', 'search', 'markdown'
  company_domain TEXT NOT NULL,
  url TEXT,
  response_data JSONB NOT NULL,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  hit_count INTEGER DEFAULT 1
);

CREATE INDEX idx_cache_expires ON scrape_cache (expires_at);
CREATE INDEX idx_cache_company ON scrape_cache (company_domain);
CREATE INDEX idx_cache_source ON scrape_cache (source_type);
`

### Cache Key Generation

`python
def generate_cache_key(source_type, url, params):
    raw = f"{source_type}:{url}:{json.dumps(params, sort_keys=True)}"
    return hashlib.sha256(raw.encode()).hexdigest()
`

---

## TTL Configuration

| Source Type | TTL | Rationale |
|-------------|-----|-----------|
| Company profile (about, leadership) | 30 days | Identity data changes slowly |
| Product pages | 14 days | Product offerings change quarterly |
| Pricing pages | 7 days | Pricing changes are infrequent |
| Search results | 7 days | Search rankings change weekly |
| News results | 1 day | News is time-sensitive |
| Blog content | 7 days | Blog archives are relatively stable |

### Supabase Row Definition

`json
{
  "cache_key": "a1b2c3d4...",
  "source_type": "crawl",
  "company_domain": "acme.com",
  "url": "https://acme.com/about",
  "response_data": { ... },
  "metadata": {
    "pages_crawled": 12,
    "crawl_duration_ms": 45000,
    "credit_cost": 1
  },
  "created_at": "2026-07-10T14:00:00Z",
  "expires_at": "2026-08-09T14:00:00Z",
  "hit_count": 3
}
`

---

## Cache Check Flow (Make.com)

In Make.com scenarios, the cache is checked before any Firecrawl API call:

`mermaid
sequenceDiagram
    participant S as Scenario
    participant DB as Supabase
    participant F as Firecrawl

    S->>DB: SELECT * FROM scrape_cache WHERE cache_key = ?
    alt Cache Hit (not expired)
        DB-->>S: Cached data
        S->>S: Increment hit_count
    else Cache Miss or Expired
        S->>F: Firecrawl API call
        F-->>S: Fresh data
        S->>DB: INSERT OR REPLACE INTO scrape_cache
    end
`

### Cache Check Module

`json
{
  "module": "Supabase / Select rows",
  "config": {
    "table": "scrape_cache",
    "filter": {
      "cache_key": "{{cache_key}}",
      "expires_at": { ">": "{{now}}" }
    },
    "limit": 1
  }
}
`

---

## Re-Scrape Avoidance

The platform avoids unnecessary re-scraping through several mechanisms:

1. **TTL-based expiration**: Data is reused until the TTL expires.
2. **Content fingerprinting**: If the cached content hash matches the live page hash (checked via HEAD request), the TTL is extended.
3. **Priority-based refresh**: High-priority leads may trigger early cache refresh regardless of TTL.
4. **Manual override**: Users can force a refresh via the orce_refresh=true parameter.

### Cache Hit Logic

`python
if cache_entry and cache_entry.expires_at > now():
    if cache_entry.hit_count < 5:
        return cache_entry.response_data
    else:
        # Refresh early for popular entries
        if cache_entry.created_at + timedelta(days=1) < now():
            return refresh_cache(cache_entry)
        return cache_entry.response_data
`

---

## Cache Maintenance

### Cleanup Job

A weekly cleanup job removes expired entries:

`sql
DELETE FROM scrape_cache WHERE expires_at < NOW() - INTERVAL '30 days';

-- Keep only expired entries that have been hit > 5 times
DELETE FROM scrape_cache
WHERE expires_at < NOW()
  AND hit_count <= 5
  AND created_at < NOW() - INTERVAL '60 days';
`

### Monitoring

`sql
-- Cache hit rate by source type
SELECT
  source_type,
  COUNT(*) as total_entries,
  SUM(hit_count) as total_hits,
  AVG(hit_count) as avg_hits,
  COUNT(*) FILTER (WHERE expires_at > NOW()) as active_entries
FROM scrape_cache
GROUP BY source_type;
`

---

## Cost Impact

| Metric | Without Cache | With Cache | Savings |
|--------|--------------|------------|---------|
| Weekly Firecrawl credits | ~505 | ~200 | 60% |
| API calls per week | ~2,250 | ~900 | 60% |
| Scenario execution time | ~45 min | ~18 min | 60% |

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial caching documentation |
