# Scenario 03: Firecrawl

The Firecrawl Scenario executes the actual web scraping operations against Firecrawl API. It handles deep crawl, extract, search, and markdown operations with retry logic.

---

## Trigger

**Trigger Type**: Queue entry with scenario_step = "firecrawl"

`json
{
  "run_id": "UUID",
  "company_name": "Acme Corp",
  "company_domain": "acme.com",
  "input_data": {
    "url": "https://acme.com",
    "depth": "standard"
  }
}
`

---

## Scenario Flow

`mermaid
flowchart TD
    A[Receive Queue Item] --> B[Firecrawl Deep Crawl]
    B --> C{Success?}
    C -->|Yes| D[Extract Structured Data]
    C -->|Partial| E[Use Partial + Search]
    C -->|No| F[Firecrawl Search]
    D --> G[Cache Results]
    E --> G
    F --> G
    G --> H[Parse & Normalize]
    H --> I[Update Queue Status]
    I --> J[Pass to AI Scenario]
`

---

## Modules

### Module 1: Read Queue Item

`json
{
  "module": "Supabase / Select Rows",
  "config": {
    "table": "scenario_queue",
    "filter": { "scenario_step": "firecrawl", "status": "pending" },
    "limit": 1,
    "sort": [{ "field": "created_at", "direction": "asc" }]
  }
}
`

### Module 2: Mark In Progress

`json
{
  "module": "Supabase / Update Row",
  "config": {
    "table": "scenario_queue",
    "filter": { "id": "{{queue.id}}" },
    "columns": { "status": "processing", "updated_at": "{{now}}" }
  }
}
`

### Module 3: Deep Crawl Request

`json
{
  "module": "HTTP / Make a Request",
  "config": {
    "url": "https://api.firecrawl.dev/v1/crawl",
    "method": "POST",
    "headers": {
      "Authorization": "Bearer {{secrets.FIRECRAWL_API_KEY}}"
    },
    "body": {
      "url": "{{queue.input_data.url}}",
      "maxDepth": 2,
      "maxPages": 15,
      "includePaths": ["/about*", "/product*", "/pricing*", "/team*", "/customers*"],
      "scrapeOptions": { "formats": ["markdown", "extract"], "onlyMainContent": true }
    }
  }
}
`

### Module 4: Poll Crawl Status

`json
{
  "module": "Flow Control / Repeater",
  "config": {
    "max_iterations": 60,
    "interval_seconds": 5
  },
  "modules": [
    {
      "module": "HTTP / Make a Request",
      "config": {
        "url": "https://api.firecrawl.dev/v1/crawl/{{crawl.id}}",
        "method": "GET",
        "headers": { "Authorization": "Bearer {{secrets.FIRECRAWL_API_KEY}}" }
      }
    },
    {
      "module": "Flow Control / Router",
      "config": {
        "conditions": [
          { "label": "Completed", "condition": { "field": "status", "operator": "equals", "value": "completed" } },
          { "label": "Failed", "condition": { "field": "status", "operator": "equals", "value": "failed" } },
          { "label": "Processing", "condition": { "field": "status", "operator": "equals", "value": "processing" } }
        ]
      }
    }
  ]
}
`

### Module 5: Extract Structured Data

`json
{
  "module": "HTTP / Make a Request",
  "config": {
    "url": "https://api.firecrawl.dev/v1/scrape",
    "method": "POST",
    "headers": { "Authorization": "Bearer {{secrets.FIRECRAWL_API_KEY}}" },
    "body": {
      "url": "https://{{company_domain}}/about",
      "formats": ["markdown", "extract"],
      "extract": {
        "schema": {
          "type": "object",
          "properties": {
            "company_name": { "type": "string" },
            "founded_year": { "type": "number" },
            "headquarters": { "type": "string" },
            "ceo": { "type": "string" }
          }
        }
      }
    }
  }
}
`

### Module 6: Search Fallback

`json
{
  "module": "HTTP / Make a Request",
  "config": {
    "url": "https://api.firecrawl.dev/v1/search",
    "method": "POST",
    "headers": { "Authorization": "Bearer {{secrets.FIRECRAWL_API_KEY}}" },
    "body": {
      "query": "{{company_name}} company funding investors",
      "searchOptions": { "limit": 5 }
    }
  }
}
`

### Module 7: Cache Results

`json
{
  "module": "Supabase / Insert Row",
  "config": {
    "table": "scrape_cache",
    "columns": {
      "cache_key": "{{sha256(company_domain + '_crawl')}}",
      "source_type": "crawl",
      "company_domain": "{{company_domain}}",
      "response_data": "{{crawl_results}}",
      "expires_at": "{{addDays(now, 7)}}",
      "metadata": { "pages_crawled": "{{crawl_results.pages.length}}" }
    }
  }
}
`

### Module 8: Update Queue Status

`json
{
  "module": "Supabase / Update Row",
  "config": {
    "table": "scenario_queue",
    "filter": { "id": "{{queue.id}}" },
    "columns": {
      "status": "completed",
      "output_data": "{{combined_scrape_data}}",
      "updated_at": "{{now}}"
    }
  }
}
`

---

## Retry Configuration

See etry.md for full details. Summary:

| Failure | Retries | Backoff | Action on Exhaust |
|---------|---------|---------|-------------------|
| Crawl rate limit | 3 | 2x jittered | Use search fallback |
| Extract failure | 3 | 2x jittered | Use markdown-only |
| Search failure | 2 | 2x jittered | Mark as insufficient |
| Cache write failure | 2 | 2x jittered | Log warning, continue |

---

## Output Data

`json
{
  "company_domain": "acme.com",
  "crawl_results": {
    "pages": [ { "url": "...", "markdown": "..." } ],
    "total_pages": 12,
    "duration_ms": 45000
  },
  "extract_results": {
    "about": { "company_name": "Acme Corp", "founded_year": 2015 },
    "pricing": { "model": "seat-based" }
  },
  "search_results": [ { "url": "...", "title": "...", "markdown": "..." } ],
  "cache_written": true
}
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial Firecrawl Scenario documentation |
