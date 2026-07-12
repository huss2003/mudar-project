# Scenario 02: Discovery

The Discovery Scenario handles initial company data collection. It receives a company from the queue, checks the cache, and delegates to Firecrawl for web data acquisition.

---

## Trigger

**Trigger Type**: Webhook (from scenario queue)

`json
{
  "module": "Webhook / Custom Webhook",
  "config": {
    "data_structure": {
      "run_id": "UUID",
      "company_name": "Text",
      "company_domain": "Text"
    }
  }
}
`

---

## Scenario Flow

`mermaid
flowchart TD
    A[Receive Company] --> B{Has Domain?}
    B -->|Yes| C[Check Supabase Cache]
    B -->|No| D[Firecrawl Search]
    D --> E[Extract Domain]
    E --> C
    C --> F{Cache Hit?}
    F -->|Yes, Fresh| G[Use Cached Data]
    F -->|No or Expired| H[Queue for Firecrawl]
    G --> I[Prepare Company Data]
    H --> J[Enqueue to Firecrawl]
    I --> K[Update Queue Status]
    J --> K
`

---

## Modules

### Module 1: Webhook Receiver

`json
{
  "module": "Webhooks / Custom Webhook",
  "config": {
    "data_structure": {
      "run_id": "{{queue.run_id}}",
      "company_name": "{{queue.company_name}}",
      "company_domain": "{{queue.company_domain}}"
    }
  }
}
`

### Module 2: Domain Router

`json
{
  "module": "Flow Control / Router",
  "conditions": [
    {
      "label": "Has Domain",
      "condition": { "field": "company_domain", "operator": "exists" }
    },
    {
      "label": "No Domain",
      "condition": { "field": "company_domain", "operator": "not_exists" }
    }
  ]
}
`

### Module 3: Cache Check

`json
{
  "module": "Supabase / Select Rows",
  "config": {
    "table": "scrape_cache",
    "filter": {
      "company_domain": "{{company_domain}}",
      "source_type": "company_profile",
      "expires_at": { ">": "{{now}}" }
    },
    "limit": 1,
    "sort": [{ "field": "created_at", "direction": "desc" }]
  }
}
`

### Module 4: Cache Router

| Condition | Action |
|-----------|--------|
| Cache hit (created < 7 days ago) | Use cached data directly |
| Cache hit (created 7-30 days ago) | Use cached, flag for refresh |
| Cache miss | Enqueue for Firecrawl deep crawl |

### Module 5: Enqueue to Firecrawl

`json
{
  "module": "Supabase / Insert Row",
  "config": {
    "table": "scenario_queue",
    "columns": {
      "run_id": "{{run_id}}",
      "company_name": "{{company_name}}",
      "company_domain": "{{company_domain}}",
      "scenario_step": "firecrawl",
      "status": "pending",
      "input_data": {
        "url": "https://{{company_domain}}",
        "depth": "standard"
      }
    }
  }
}
`

### Module 6: Update Queue Status

`json
{
  "module": "Supabase / Update Row",
  "config": {
    "table": "scenario_queue",
    "filter": { "id": "{{queue.id}}" },
    "columns": {
      "status": "completed",
      "output_data": "{{cache_data}}",
      "updated_at": "{{now}}"
    }
  }
}
`

---

## Domain Discovery via Search

If no domain is provided, the scenario runs a Firecrawl search:

| Search Query | Expected Result |
|-------------|-----------------|
| "Acme Corp" company website | Official company website URL |
| "Acme Corp" LinkedIn | LinkedIn company page |

The search results are scored by relevance:

`python
def extract_domain(company_name, search_results):
    for result in search_results:
        domain = extract_domain_from_url(result.url)
        # Check if company name appears in title/description
        if company_name.lower() in result.title.lower():
            return domain
        if company_name.lower() in (result.description or '').lower():
            return domain
    return None  # Domain could not be determined
`

If no domain can be determined, the company is marked as skipped with reason "Domain not found."

---

## Data Collected

After the Discovery scenario completes, the following data is available:

| Data Point | Source | Format |
|-----------|--------|--------|
| Company domain | Search or input | URL string |
| LinkedIn URL | Search result | URL string |
| Crunchbase URL | Search result | URL string |
| Company description | Search result | Text (200 chars) |
| Cache status | Cache check | Hit/Miss/Expired |

---

## Error Handling

| Error | Action |
|-------|--------|
| Domain lookup failed | Mark as skipped, log reason |
| Cache read error | Proceed without cache (miss) |
| Search query failed | Retry once, then mark as skipped |
| Queue update failed | Log warning, data already collected |

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial Discovery Scenario documentation |
