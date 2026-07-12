# Firecrawl Search

The Firecrawl Search endpoint finds company information across the web when a direct website URL is not available, or to supplement deep crawl data with external sources.

---

## When to Use Search

Search serves as the primary discovery mechanism when:

1. The company URL is unknown — search by company name to find the website.
2. The deep crawl returned limited data — search for supplementary information.
3. Specific data points are missing — search for pricing, funding, or leadership information.

### Search Decision Flow

`mermaid
flowchart TD
    A[Company Query] --> B{Has URL?}
    B -->|Yes| C[Deep Crawl]
    B -->|No| D[Firecrawl Search]
    C --> E{Data Sufficient?}
    E -->|Yes| F[Proceed to Analysis]
    E -->|No| D
    D --> G{Found Results?}
    G -->|Yes| H[Extract URLs]
    H --> C
    G -->|No| I[Mark Insufficient Data]
`

---

## API Request

`json
POST https://api.firecrawl.dev/v1/search

{
  "query": "Acme Corp funding investors valuation 2025 2026",
  "searchOptions": {
    "limit": 5,
    "lang": "en",
    "country": "us"
  },
  "scrapeOptions": {
    "formats": ["markdown"],
    "onlyMainContent": true
  }
}
`

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| query | string | — | Search query string |
| searchOptions.limit | integer | 5 | Max results to return |
| searchOptions.lang | string | en | Language filter |
| searchOptions.country | string | — | Country filter (ISO 3166-1 alpha-2) |
| scrapeOptions | object | — | Options for scraping each result |

---

## Query Templates

The platform uses specific search queries for each data dimension:

| Dimension | Query Template | Priority |
|-----------|---------------|----------|
| Company discovery | "company_name" funding OR investors OR valuation | Highest |
| Pricing | "company_name" pricing OR plans OR cost | High |
| Funding | "company_name" funding OR raise OR series investors | High |
| Leadership | "company_name" CEO OR founder OR leadership team | High |
| Technology | "company_name" technology stack OR platform | Medium |
| News | "company_name" 2026 news OR announcement | Medium |
| Reviews | "company_name" review OR rating OR G2 OR Capterra | Low |

### Example for Stripe

`json
{
  "query": "Stripe funding investors valuation 2025 2026",
  "searchOptions": { "limit": 5 }
}
`

Expected results:
1. Crunchbase profile (funding rounds, investors)
2. TechCrunch article (latest funding announcement)
3. PitchBook profile (valuation data)
4. Stripe investor page (if exists)
5. News article about Stripe growth

---

## Response Format

`json
{
  "success": true,
  "data": [
    {
      "url": "https://crunchbase.com/organization/stripe",
      "title": "Stripe - Crunchbase Company Profile",
      "description": "Stripe has raised .2B...",
      "markdown": "# Stripe\n\nStripe is a technology company...",
      "metadata": {
        "sourceURL": "https://crunchbase.com/organization/stripe",
        "statusCode": 200,
        "language": "en"
      }
    }
  ]
}
`

---

## Search Result Scoring

Each search result is scored for relevance:

| Factor | Weight | Description |
|--------|--------|-------------|
| Domain authority | 30% | Higher for known data sources (Crunchbase, LinkedIn) |
| Title match | 25% | Does the title match the company name? |
| Description match | 20% | Does the description reference the target? |
| Content length | 15% | Longer content generally has more data |
| Recency | 10% | Recent results are more valuable |

### Scoring Implementation

`python
def score_search_result(result, company_name):
    score = 0
    # Domain authority
    if any(d in result.url for d in AUTHORITY_DOMAINS):
        score += 30
    # Title match
    if company_name.lower() in result.title.lower():
        score += 25
    # Description match
    if company_name.lower() in (result.description or '').lower():
        score += 20
    # Content length
    if len(result.markdown) > 5000:
        score += 15
    elif len(result.markdown) > 1000:
        score += 10
    return score
`

Results scoring below 50 are discarded.

---

## Source Prioritization

| Source | Priority | Why |
|--------|----------|-----|
| Crunchbase | Highest | Structured funding and investor data |
| LinkedIn | Highest | Verified company page, employee data |
| G2 / Capterra | High | Product reviews, feature comparisons |
| TechCrunch / VentureBeat | High | Funding announcements |
| Company blog | Medium | Product updates, thought leadership |
| News sites | Medium | General coverage |
| Wikipedia | Low | Unreliable for business data |
| Social media | Low | Unstructured, hard to parse |

---

## Make.com Integration

Search is executed from Make.com scenarios as follows:

`json
{
  "module": "HTTP / Make a request",
  "config": {
    "url": "https://api.firecrawl.dev/v1/search",
    "method": "POST",
    "headers": {
      "Authorization": "Bearer {{secrets.FIRECRAWL_API_KEY}}"
    },
    "body": {
      "query": "{{company.name}} {{search.type}}",
      "searchOptions": {
        "limit": "{{search.limit}}"
      },
      "scrapeOptions": {
        "formats": ["markdown"],
        "onlyMainContent": true
      }
    }
  }
}
`

---

## Rate Limits & Credits

| Plan | Max Searches | Credit Cost |
|------|-------------|-------------|
| All plans | 100 searches per credit | 0.01 credits per search |

At the Growth tier, search costs are negligible. A batch of 250 companies × 3 searches = 750 searches = 7.5 credits.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial search documentation |
