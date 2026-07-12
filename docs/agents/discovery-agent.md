# Discovery Agent

> **Layer 1 — Data Collection. Intake valve of the entire pipeline.**

---

## Purpose

The Discovery Agent is responsible for identifying and scraping 10,000+ potential commercial real estate leads every week. It uses Firecrawl as the primary scraping engine and supplements with free public data sources (Crunchbase, LinkedIn public pages, company websites). No AI model is involved at this stage — this is pure data acquisition at high volume.

The agent operates against a curated target list derived from two inputs: (a) industry-vertical keyword searches (e.g., "IT services companies in Pune," "manufacturing firms in Hinjewadi"), and (b) broker-provided company URLs and domains. The target list typically contains 12,000–15,000 entries to account for 20–30% attrition from unreachable domains, non-commercial entities, and redirects.

---

## Input

| Field | Type | Description | Source |
|-------|------|-------------|--------|
| `target_urls` | string[] | Company website URLs or domains | Broker provided + keyword search |
| `industry_filters` | string[] | Target industries (e.g., IT, manufacturing, BFSI) | Configuration |
| `micromarket_focus` | string | Pune-specific submarkets (Hinjewadi, Kharadi, Viman Nagar) | Configuration |
| `employee_range` | object | Min/max employee count filter | Configuration |
| `batch_size` | integer | Number of companies per batch (default 500) | Orchestrator parameter |

---

## Output

The agent emits one JSON record per company. Fields are captured as raw strings — no normalization or validation occurs at this layer.

```json
{
  "input_domain": "acmecorp.com",
  "scraped_urls": [
    "https://acmecorp.com",
    "https://acmecorp.com/about",
    "https://acmecorp.com/team",
    "https://acmecorp.com/contact"
  ],
  "crawl_timestamp": "2026-07-12T09:00:15Z",
  "raw_name": "Acme Corp | Enterprise Software Solutions",
  "raw_description": "Acme Corp provides cloud-based ERP solutions for mid-market manufacturing companies across India.",
  "raw_employees": "200-500 employees",
  "raw_revenue": "$10M-$50M",
  "raw_founded": "Founded 2012",
  "raw_location": "Pune, Maharashtra, India",
  "raw_industry_tags": ["ERP", "Cloud Software", "Manufacturing", "SaaS"],
  "management_raw": ["Jane Doe — CEO", "John Smith — CTO", "Raj Patel — VP Engineering"],
  "tech_signals": ["React", "AWS", "Python", "PostgreSQL"],
  "social_urls": {
    "linkedin": "https://linkedin.com/company/acmecorp",
    "crunchbase": "https://crunchbase.com/organization/acmecorp"
  },
  "contact_page_url": "https://acmecorp.com/contact",
  "reachability": "reachable",
  "error": null
}
```

---

## Implementation

Firecrawl is configured with a depth-1 crawl strategy per domain. The scraper visits the homepage, about page, team page, and contact page. It operates with headless Chrome using a 15-second render timeout for JavaScript-heavy sites. Rate limiting is set to 2 requests per second per domain to avoid IP blocking. Failed requests are retried twice with exponential backoff (1s, 3s).

The source priority order is:
1. **Company website** — Primary source for name, description, location, employee count
2. **Crunchbase** — Funding data, founding date, industry tags, management team
3. **LinkedIn public data** — Employee count ranges, recent hires, headquarters location
4. **Google Business Profile** — Location verification, hours, reviews
5. **Industry directories** — NASSCOM, G2, Capterra for tech companies

All HTTP status codes, response times, and redirect chains are logged. Domains returning 4xx or 5xx after retries are marked with the error code and `reachability: "unreachable"`. These still enter the Normalization Agent as minimal records — if the Normalization Agent cannot produce a valid record from partial data, the entry is discarded.

---

## Scraper Performance

| Metric | Value | Target |
|--------|-------|--------|
| Crawl rate | 2 req/s per domain | < 3 req/s |
| Render timeout | 15s | < 20s |
| Retry count | 2 | ≥ 2 |
| Success rate | 78–85% | > 75% |
| Avg record size | 2.4 KB | < 5 KB |
| Batch throughput | 500 records / 8 min | 500 / 10 min |
| Total throughput | 10,000 records / ~3 hrs | 10K / 4 hrs |

---

## Cost

Firecrawl operates on a free tier up to 500 pages per run. At 12,000 target domains × 4 pages each = 48,000 pages, the free tier covers approximately one full run. For larger batches, paid Firecrawl credits at $0.003 per page add approximately $0.12 per 1,000 pages — roughly $5.76 for a full 48,000-page run. No AI model costs are incurred at this layer.

---

## Fallback Strategy

If Firecrawl cannot reach a domain after 3 retries, the Agent attempts:
- **Crunchbase API** (free tier, 100 req/day) for company metadata
- **Google cache** retrieval (if available)
- **Wayback Machine** CDX API for historical snapshots

If all three fallbacks fail, the domain is marked `unreachable` with a `reachability` score of 0 and passed to the Normalization Agent with a `null` quality marker. The broker is notified of unreachable domains in the weekly digest.
