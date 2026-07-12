# Filter Patterns

Filters are used throughout the Jasfo Lead Intelligence Platform to control data flow, enforce quality gates, and manage conditional processing.

---

## Filter Types

### Score Threshold Filters

Applied after scoring to determine which companies receive full reports:

| Filter | Condition | Action |
|--------|-----------|--------|
| High Priority | Composite >= 70 | Full Telegram report, flagged for outreach |
| Medium Priority | Composite 40–69 | Standard report, stored in archive |
| Low Priority | Composite < 40 | Minimal record, no active outreach |
| Insufficient Data | Confidence = Low | Stored for later re-evaluation |

`json
{
  "module": "Flow Control / Filter",
  "config": {
    "condition": {
      "field": "scorecard.composite.rounded_score",
      "operator": "greater_than_or_equal",
      "value": 70
    }
  }
}
`

### Verification Gate Filters

Applied after AI extraction to verify data quality:

`json
{
  "module": "Flow Control / Filter",
  "config": {
    "condition": {
      "formula": "extraction.company_data.metadata.completeness_score >= 0.5"
    }
  }
}
`

| Gate | Condition | Failed Action |
|------|-----------|---------------|
| Identity Gate | identity.name exists | Mark as failed, skip |
| Content Gate | completeness_score >= 0.3 | Use partial data, flag |
| Scoring Gate | eflection.passed == true | Re-run scoring |
| Export Gate | composite.confidence != Low | Skip Telegram, archive only |

### Quality Filters

`json
{
  "module": "Flow Control / Filter",
  "config": {
    "condition": {
      "formula": "scrape.pages_crawled >= 3 OR extraction.company_data.metadata.completeness_score >= 0.4"
    }
  }
}
`

Quality filters prevent low-quality data from entering the AI pipeline:

| Filter | Purpose | Threshold |
|--------|---------|-----------|
| Min pages crawled | Ensure sufficient content | >= 3 pages |
| Min completeness | Enough data to score | >= 0.4 score |
| Max risk factors | Not too many red flags | <= 5 factors |
| Source diversity | Data from multiple sources | >= 2 sources |

### Deduplication Filters

`sql
-- Supabase query before enqueueing
SELECT COUNT(*) FROM scenario_queue
WHERE company_domain = '{{company_domain}}'
  AND status != 'failed'
  AND created_at > NOW() - INTERVAL '30 days';
`

If count > 0, the company is skipped (already processed recently).

---

## Filter Chain Pattern

Filters are typically chained in sequence:

`mermaid
flowchart TD
    A[Raw Data] --> B[Quality Filter]
    B --> C{Pass?}
    C -->|Yes| D[Dedupe Filter]
    C -->|No| E[Discard]
    D --> F{Pass?}
    F -->|Yes| G[Proceed]
    F -->|No| H[Skip]
`

### Make.com Implementation

`json
{
  "module_1": {
    "module": "Flow Control / Filter",
    "config": {
      "condition": { "field": "scrape.pages_crawled", "operator": "greater_than_or_equal", "value": 3 },
      "label": "Quality Gate"
    }
  },
  "module_2": {
    "module": "Flow Control / Filter",
    "config": {
      "condition": { "formula": "!checkDuplicate(company_domain)" },
      "label": "Dedupe Gate"
    }
  },
  "module_3": {
    "module": "Flow Control / Filter",
    "config": {
      "condition": { "field": "extraction.metadata.completeness_score", "operator": "greater_than_or_equal", "value": 0.4 },
      "label": "Completeness Gate"
    }
  }
}
`

---

## Configuration-Based Filters

Filters are parameterized per run through the queue item configuration:

`json
{
  "input_data": {
    "filters": {
      "min_score": 40,
      "min_confidence": "Medium",
      "max_risk_factors": 5,
      "require_website": true
    }
  }
}
`

The Master Scenario passes these filter configurations downstream. The scoring scenario uses them to determine which companies advance to export.

---

## Logging Filtered Items

All filtered items are logged with the reason:

`json
{
  "company_domain": "acme.com",
  "filter": "Quality Gate (PASS)",
  "filter": "Dedupe Gate (FAIL)",
  "reason": "Already processed in run run-2026-06-30-001",
  "action": "Skip"
}
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial filter patterns documentation |
