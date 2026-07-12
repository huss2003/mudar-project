# Deep Crawl Strategy

The deep crawl operation is the primary data acquisition method for company websites. It uses the Firecrawl /crawl endpoint to systematically traverse a company's website and collect content from key pages.

---

## Crawl Request

### Basic Request

`json
POST https://api.firecrawl.dev/v1/crawl

{
  "url": "https://acme.com",
  "maxPages": 50,
  "maxDepth": 3,
  "limit": 30,
  "excludePaths": ["/blog/*", "/news/*", "/careers/*"],
  "includePaths": ["/about*", "/product*", "/pricing*", "/team*", "/customers*"],
  "scrapeOptions": {
    "formats": ["markdown", "html"],
    "onlyMainContent": true
  },
  "webhook": {
    "url": "https://hooks.make.com/..."
  }
}
`

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| url | string | — | Starting URL for the crawl |
| maxPages | integer | 10 | Maximum pages to crawl (hard limit) |
| maxDepth | integer | 2 | Maximum link depth from starting URL |
| limit | integer | maxPages | Soft limit, stops when reached |
| excludePaths | string[] | [] | Glob patterns to exclude |
| includePaths | string[] | [] | Glob patterns to include |
| scrapeOptions | object | — | Per-page scrape configuration |
| webhook | object | — | Async callback URL |

---

## Depth Settings by Research Level

| Level | maxDepth | maxPages | includePaths | Use Case |
|-------|----------|----------|--------------|----------|
| **Basic** | 1 | 5 | /about, /product | Quick check, large batches |
| **Standard** | 2 | 15 | /about*, /product*, /pricing*, /team* | Weekly batch processing |
| **Deep** | 3 | 50 | All relevant paths | High-priority leads |

### Standard Depth Configuration

`json
{
  "level": "standard",
  "maxDepth": 2,
  "maxPages": 15,
  "includePaths": [
    "/about*", "/product*", "/solutions*", "/pricing*",
    "/team*", "/leadership*", "/customers*", "/case-studies*"
  ],
  "excludePaths": [
    "/blog/*", "/news/*", "/careers/*", "/legal/*",
    "/privacy*", "/*.pdf", "/*.zip"
  ]
}
`

---

## Crawl Lifecycle

`mermaid
sequenceDiagram
    participant M as Make.com
    participant F as Firecrawl
    participant C as Cache

    M->>F: POST /crawl
    F-->>M: { id: "crawl-xxx" }
    loop Poll every 5s
        M->>F: GET /crawl/crawl-xxx
        F-->>M: { status: "processing", completed: 7, total: 15 }
    end
    F-->>M: { status: "completed", data: [...] }
    M->>C: Cache results
    M->>M: Process pages
`

### Polling Logic

`json
{
  "crawl_id": "crawl-xxx",
  "poll_interval_ms": 5000,
  "max_poll_attempts": 60,
  "timeout_ms": 300000
}
`

The crawler polls every 5 seconds for up to 5 minutes. If the crawl has not completed by then, it is marked as a timeout and partial results are used.

---

## Webhook Mode

For long-running crawls, a webhook callback is preferred over polling:

`json
{
  "webhook": {
    "url": "https://hooks.make.com/firecrawl-completion",
    "headers": { "Authorization": "Bearer {{webhook_secret}}" },
    "events": ["completed", "failed"]
  }
}
`

When the crawl completes, Firecrawl sends a POST to the webhook URL with the full results.

---

## Page Prioritization

Not all pages are equally valuable. The crawler prioritizes:

| Priority | Page | Value |
|----------|------|-------|
| Highest | /about | Company identity, founding story |
| High | /product, /solutions | Product descriptions, features |
| High | /pricing | Pricing tiers, models |
| High | /team, /leadership | Executive names, bios |
| Medium | /customers, /case-studies | Customer segments, proof points |
| Medium | /blog | Thought leadership, product updates |
| Low | /careers | Growth signals (hiring) |
| Low | /news, /press | Recent announcements |

### Processing Order

Pages are processed in priority order within the Make.com scenario:

`mermaid
flowchart LR
    A[Crawl Results] --> B[Sort by Priority]
    B --> C[Process About Page]
    C --> D[Process Product Pages]
    D --> E[Process Pricing]
    E --> F[Process Leadership]
    F --> G[Process Customers]
    G --> H[AI Pipeline]
`

---

## Handling Crawl Failures

| Failure Mode | Detection | Action |
|-------------|-----------|--------|
| DNS resolution failure | HTTP error or timeout | Flag domain as invalid, skip company |
| Blocked by robots.txt | 403 or meta tag | Reduce depth, retry with different path |
| Captcha challenge | Response pattern match | Use Search API as fallback |
| Empty site (SPA with no SSR) | Content < 200 chars | Try Apify fallback |
| Redirect loop | Infinite redirects detected | Hard limit at 10 redirects |

---

## Crawl Result Processing

After a successful crawl, pages are processed through a normalization pipeline:

1. **Deduplication**: Remove pages with identical or near-identical content (cosine similarity > 0.95).
2. **Truncation**: Each page is truncated to 10,000 characters maximum.
3. **Metadata Attachment**: Each page is tagged with its source URL, crawl timestamp, and priority.
4. **Concatenation**: Relevant pages are concatenated into a single markdown document, separated by --- section breaks.

### Output Format

`json
{
  "crawl_id": "crawl-xxx",
  "company_domain": "acme.com",
  "pages_crawled": 12,
  "pages_processed": 10,
  "pages_deduplicated": 2,
  "crawl_duration_ms": 45000,
  "pages": [
    {
      "url": "https://acme.com/about",
      "title": "About Acme Corp",
      "priority": "high",
      "content_markdown": "# About Acme Corp\n..."
    }
  ],
  "combined_markdown": "# About Acme Corp\n...\n---\n# Products\n..."
}
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial deep crawl documentation |
