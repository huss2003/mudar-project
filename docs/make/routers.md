# Router Patterns

Make.com routers direct data flow based on conditions, data types, and error states. This document describes all router patterns used in the Jasfo Lead Intelligence Platform.

---

## Router Types

### 1. Data Router

Routes based on the presence or type of data:

`mermaid
flowchart TD
    A[Input Data] --> B{Has Domain?}
    B -->|Yes| C[Proceed with URL]
    B -->|No| D[Run Search Discovery]
    C --> E{Depth Setting}
    E -->|Basic| F[Shallow Crawl]
    E -->|Standard| G[Standard Crawl]
    E -->|Deep| H[Deep Crawl]
`

**Make.com Configuration:**

`json
{
  "module": "Flow Control / Router",
  "config": {
    "conditions": [
      {
        "label": "Has Domain",
        "condition": {
          "field": "company_domain",
          "operator": "exists"
        }
      },
      {
        "label": "No Domain",
        "condition": {
          "field": "company_domain",
          "operator": "not_exists"
        }
      }
    ]
  }
}
`

### 2. Status Router

Routes based on API response status codes:

`json
{
  "module": "Flow Control / Router",
  "config": {
    "conditions": [
      {
        "label": "Success (200)",
        "condition": {
          "field": "http.status_code",
          "operator": "equals",
          "value": 200
        }
      },
      {
        "label": "Rate Limited (429)",
        "condition": {
          "field": "http.status_code",
          "operator": "equals",
          "value": 429
        }
      },
      {
        "label": "Server Error (5xx)",
        "condition": {
          "field": "http.status_code",
          "operator": "matches_regex",
          "value": "^5\\d{2}$"
        }
      },
      {
        "label": "Other",
        "condition": {}
      }
    ]
  }
}
`

### 3. Score Router

Routes based on composite score thresholds:

`mermaid
flowchart TD
    A[Composite Score] --> B{Score Range}
    B -->|>= 70| C[High Priority]
    B -->|40-69| D[Medium Priority]
    B -->|< 40| E[Low Priority]
    C --> F[Full Telegram Report]
    C --> G[Flag for Outreach]
    D --> H[Standard Report]
    E --> I[Minimal Storage Only]
`

`json
{
  "module": "Flow Control / Router",
  "config": {
    "conditions": [
      {
        "label": "High (>= 70)",
        "condition": {
          "field": "scorecard.composite.rounded_score",
          "operator": "greater_than_or_equal",
          "value": 70
        }
      },
      {
        "label": "Medium (40-69)",
        "condition": {
          "field": "scorecard.composite.rounded_score",
          "operator": "between",
          "min": 40,
          "max": 69
        }
      },
      {
        "label": "Low (< 40)",
        "condition": {
          "field": "scorecard.composite.rounded_score",
          "operator": "less_than",
          "value": 40
        }
      }
    ]
  }
}
`

### 4. Error Router

Routes errors to the appropriate handler:

`json
{
  "module": "Flow Control / Router",
  "config": {
    "conditions": [
      {
        "label": "Transient Error",
        "condition": {
          "formula": "inArray([429, 502, 503, 504], http.status_code)"
        }
      },
      {
        "label": "Auth Error",
        "condition": {
          "formula": "inArray([401, 403], http.status_code)"
        }
      },
      {
        "label": "Client Error",
        "condition": {
          "formula": "inArray([400, 404, 405], http.status_code)"
        }
      }
    ]
  }
}
`

### 5. Cache Router

Routes based on cache status:

`mermaid
flowchart TD
    A[Cache Lookup] --> B{Result}
    B -->|Hit (fresh)| C[Use Cached Data]
    B -->|Hit (expired)| D[Use Cached + Refresh]
    B -->|Miss| E[Execute Fresh Scrape]
    D --> F[Queue Async Refresh]
    E --> G[Store in Cache]
`

---

## Compound Conditions

For complex routing, compound conditions combine multiple checks:

`json
{
  "label": "High Score With Data",
  "condition": {
    "formula": "scorecard.composite.rounded_score >= 70 AND scorecard.composite.confidence == 'High'"
  }
}
`

Supported operators:

| Operator | Description |
|----------|-------------|
| equals | Exact match |
| 
ot_equals | Negative match |
| greater_than | Numeric comparison |
| less_than | Numeric comparison |
| etween | Inclusive range |
| exists | Field is not null/empty |
| 
ot_exists | Field is null/empty |
| matches_regex | Regular expression |
| inArray | Value in array |
| ormula | Custom boolean expression |

---

## Data Integrity Routing

Before any processing, data integrity checks route to validation paths:

`json
{
  "label": "Data Complete",
  "condition": {
    "formula": "extraction.company_data.identity.name != null AND extraction.company_data.identity.domain != null"
  }
},
{
  "label": "Partial Data",
  "condition": {
    "formula": "extraction.company_data.identity.name != null AND extraction.company_data.identity.domain == null"
  }
}
`

---

## Error Path Routing

Every router has a default "Other" path that catches unhandled cases:

`mermaid
flowchart TD
    A[Router] --> B[Matched Route]
    A --> C[Other / Default]
    C --> D[Log Unhandled Case]
    D --> E[Flag for Review]
    E --> F[Notify Admin?]
    F -->|Error > 5/day| G[Send Alert]
    F -->|Rare| H[Log Only]
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial router patterns documentation |
