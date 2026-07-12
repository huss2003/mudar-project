# Extract API Usage

The Firecrawl Extract API extracts structured data from web pages using AI-powered schema extraction. This is the primary method for capturing specific, formatted data points from company websites.

---

## Overview

Unlike the deep crawl which captures full page content as markdown, the Extract API identifies and returns only the data fields you specify in a schema. This is more cost-effective and produces cleaner output for AI analysis.

### When to Use Extract

| Use Case | Extract | Deep Crawl |
|----------|---------|------------|
| Pricing data | Yes | Partial |
| Leadership team | Yes | Yes |
| Product descriptions | Yes | Yes |
| Funding history | Yes | No |
| Full website content | No | Yes |

---

## API Request

`json
POST https://api.firecrawl.dev/v1/scrape

{
  "url": "https://acme.com/about",
  "formats": ["markdown", "extract"],
  "extract": {
    "schema": {
      "type": "object",
      "properties": {
        "company_name": { "type": "string" },
        "founded_year": { "type": "number" },
        "headquarters": { "type": "string" },
        "ceo": { "type": "string" },
        "employees": { "type": "string" },
        "mission_statement": { "type": "string" }
      },
      "required": ["company_name"]
    }
  },
  "onlyMainContent": true
}
`

---

## Schema Definition

Extract schemas define the exact data fields to pull from a page. The schema uses JSON Schema syntax.

### Pricing Page Schema

`json
{
  "type": "object",
  "properties": {
    "pricing_model": {
      "type": "string",
      "enum": ["free", "freemium", "usage-based", "seat-based", "quote-based", "hybrid", "not found"]
    },
    "tiers": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "price": { "type": "number" },
          "currency": { "type": "string" },
          "billing": { "type": "string", "enum": ["monthly", "annual", "one-time"] },
          "description": { "type": "string" }
        }
      }
    },
    "has_free_trial": { "type": "boolean" },
    "trial_days": { "type": "number" }
  }
}
`

### Leadership Page Schema

`json
{
  "type": "object",
  "properties": {
    "executives": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "title": { "type": "string" },
          "bio_summary": { "type": "string" },
          "linkedin_url": { "type": "string" }
        },
        "required": ["name", "title"]
      }
    },
    "board_members": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "name": { "type": "string" },
          "title": { "type": "string" },
          "affiliation": { "type": "string" }
        }
      }
    }
  }
}
`

### Funding Page Schema

`json
{
  "type": "object",
  "properties": {
    "total_raised": { "type": "number" },
    "currency": { "type": "string", "default": "USD" },
    "rounds": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "date": { "type": "string" },
          "round_type": { "type": "string" },
          "amount": { "type": "number" },
          "investors": {
            "type": "array",
            "items": { "type": "string" }
          },
          "valuation": { "type": "number" }
        }
      }
    },
    "last_funding_date": { "type": "string" }
  }
}
`

---

## Response Format

`json
{
  "success": true,
  "data": {
    "markdown": "# About Acme Corp\n...",
    "extract": {
      "company_name": "Acme Corp",
      "founded_year": 2015,
      "headquarters": "San Francisco, CA",
      "ceo": "Jane Smith",
      "employees": "201-500",
      "mission_statement": "Making enterprise software delightful"
    },
    "metadata": {
      "title": "About - Acme Corp",
      "sourceURL": "https://acme.com/about",
      "statusCode": 200,
      "extract_schema": "company_identity"
    }
  }
}
`

---

## Pricing

| Operation | Cost |
|-----------|------|
| Scrape + Extract | 1 credit per request |
| Extract only (no markdown) | 1 credit per request |

Extract costs 1 credit regardless of schema complexity. Using Extract is more cost-effective than crawling 3+ pages for structured data.

---

## Best Practices

### Schema Design

1. **Keep schemas focused**: A schema should target one page type. Do not create a single schema for all data.
2. **Use enums for constrained fields**: This improves extraction accuracy (e.g., pricing model enum).
3. **Mark truly required fields**: The AI will prioritize extracting required fields over optional ones.
4. **Limit array items**: Set a reasonable maxItems on array fields to prevent bloated responses.

### URL Selection

| Schema | Target URL Pattern |
|--------|-------------------|
| Company identity | /about, /company |
| Pricing | /pricing, /plans |
| Leadership | /team, /leadership, /management |
| Customers | /customers, /case-studies |
| Product | /product, /solutions, /features |

### Fallback Strategy

If Extract returns empty or low-confidence results for a page:

1. Fall back to markdown-only scrape and parse with the AI pipeline.
2. If the target URL does not exist (404), try alternative URL patterns.
3. If no relevant page exists on the site, mark the data as unavailable.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial Extract API documentation |
