# Firecrawl Integration

Firecrawl is the primary scraping engine for the Jasfo Lead Intelligence Platform. It provides a unified API for crawling, extracting, searching, and converting web content to markdown.

---

## API Setup

### Authentication

Firecrawl is accessed via an API key passed in the `Authorization` header:

```bash
Authorization: Bearer fc-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

The API key is stored in Supabase secrets and injected into Make.com scenarios as an environment variable:

```json
{
  "key": "FIRECRAWL_API_KEY",
  "source": "supabase://secrets/firecrawl_api_key"
}
```

### Base URL

```
https://api.firecrawl.dev/v1
```

### SDK Installation (for local development)

```bash
npm install @firecrawl/sdk
# or
pip install firecrawl-py
```

---

## Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/scrape` | Single-page scrape with optional structured extraction |
| `POST` | `/crawl` | Multi-page deep crawl with callback or polling |
| `GET` | `/crawl/{id}` | Check crawl job status |
| `POST` | `/search` | Web search for company information |
| `GET` | `/credits` | Check remaining credit balance |

---

## Pricing (as of July 2026)

| Plan | Monthly Credits | Price | Rate Limit |
|------|----------------|-------|------------|
| Hobby | 500 | $19/mo | 50 req/min |
| Standard | 3,000 | $79/mo | 100 req/min |
| Growth | 10,000 | $299/mo | 200 req/min |
| Enterprise | Custom | Custom | Custom |

The Jasfo platform operates on the **Growth plan** to handle the weekly batch of ~250 companies.

### Credit Consumption

| Operation | Credit Cost |
|-----------|-------------|
| Scrape (single page) | 1 credit |
| Crawl (per 500 pages) | 1 credit |
| Search (per 100 searches) | 1 credit |
| Extract (structured) | 1 credit per request |

**Monthly estimate** (current usage):

| Operation | Volume | Credits |
|-----------|--------|---------|
| Deep crawl (250 companies × 4 pages avg) | ~1,000 pages | 2 credits |
| Extract (250 companies × 2 pages) | 500 requests | 500 credits |
| Search (250 companies) | 250 searches | 3 credits |
| Markdown conversion | ~1,000 pages | 0.25 credits |
| **Total** | | **~505 credits** |

---

## Rate Limits

| Tier | Requests/Minute | Concurrency | Burst |
|------|----------------|-------------|-------|
| Growth | 200 | 10 | 50 |
| Standard | 100 | 5 | 25 |
| Hobby | 50 | 3 | 10 |

### Our Rate Limiting Config

```json
{
  "requests_per_minute": 150,
  "concurrency": 5,
  "retry_on_429": true,
  "retry_delay_ms": 60000,
  "max_retries": 3
}
```

We stay below the Growth tier limit (200/min) to leave headroom for burst traffic.

---

## Error Handling

| HTTP Status | Meaning | Action |
|-------------|---------|--------|
| 200 | Success | Process response |
| 400 | Bad request | Check parameters, fix and retry |
| 401 | Unauthorized | Rotate API key |
| 429 | Rate limited | Back off and retry with delay |
| 500 | Server error | Retry with exponential backoff |
| 502/503 | Temporary failure | Retry after 30s |

### Common Errors

```json
{
  "error": "Rate limit exceeded",
  "retry_after": 60,
  "action": "Wait 60 seconds before retrying"
}
```

```json
{
  "error": "Invalid URL",
  "detail": "The provided URL is malformed or unreachable",
  "action": "Verify URL format and domain resolution before retrying"
}
```

---

## Response Format

All Firecrawl endpoints return JSON with the following envelope:

```json
{
  "success": true,
  "data": {
    "markdown": "...",
    "metadata": {
      "title": "About - Acme Corp",
      "description": "Acme Corp is a...",
      "language": "en",
      "sourceURL": "https://acme.com/about",
      "statusCode": 200
    }
  }
}
```

For crawl operations, the response includes a job ID:

```json
{
  "success": true,
  "id": "crawl-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "url": "https://api.firecrawl.dev/v1/crawl/..."
}
```

---

## Make.com Integration

Firecrawl is called from Make.com scenarios via HTTP modules:

```json
{
  "module": "HTTP / Make a request",
  "config": {
    "url": "https://api.firecrawl.dev/v1/scrape",
    "method": "POST",
    "headers": {
      "Authorization": "Bearer {{secrets.FIRECRAWL_API_KEY}}",
      "Content-Type": "application/json"
    },
    "body": {
      "url": "{{company.website_url}}",
      "formats": ["markdown"],
      "onlyMainContent": true
    }
  }
}
```

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial Firecrawl integration documentation |
