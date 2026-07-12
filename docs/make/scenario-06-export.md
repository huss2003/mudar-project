# Scenario 06: Export

The Export Scenario formats completed lead intelligence data into the requested output format and delivers it through the configured channel.

---

## Trigger

**Trigger Type**: Queue entry with scenario_step = "export"

Triggered after the Scoring scenario completes.

---

## Scenario Flow

`mermaid
flowchart TD
    A[Receive Queue Item] --> B[Load All Data]
    B --> C{Export Format}
    C -->|JSON| D[Build JSON Export]
    C -->|CSV| E[Build CSV Export]
    C -->|Markdown| F[Build Markdown Report]
    C -->|Telegram| G[Build Telegram Message]
    D --> H[Validate Output]
    E --> H
    F --> H
    G --> H
    H --> I{Valid?}
    I -->|Yes| J[Deliver via Channel]
    I -->|No| K[Flag Error]
    K --> L[Notify Admin]
    J --> M[Store in Archive]
    M --> N[Update Queue Status]
    N --> O[Send Notification]
`

---

## Modules

### Module 1: Load All Data

`json
{
  "module": "Supabase / Select Rows",
  "config": {
    "table": "score_cards",
    "filter": { "company_domain": "{{company_domain}}", "run_id": "{{run_id}}" },
    "limit": 1
  }
}
`

Additional data loads:
- i_extractions for full company data
- scrape_cache for source URLs

### Module 2: Format Router

`json
{
  "module": "Flow Control / Router",
  "config": {
    "conditions": [
      { "label": "JSON", "condition": { "field": "export_format", "operator": "equals", "value": "json" } },
      { "label": "CSV", "condition": { "field": "export_format", "operator": "equals", "value": "csv" } },
      { "label": "Markdown", "condition": { "field": "export_format", "operator": "equals", "value": "markdown" } },
      { "label": "Telegram", "condition": { "field": "export_format", "operator": "equals", "value": "telegram" } }
    ]
  }
}
`

### Module 3: Build JSON Export

`json
{
  "module": "Tools / Compose JSON",
  "config": {
    "structure": {
      "report_id": "{{uuid}}",
      "generated_at": "{{now}}",
      "company": "{{scorecard.company_name}}",
      "domain": "{{scorecard.domain}}",
      "executive_summary": "{{generate_summary(scorecard, extraction)}}",
      "scorecard": "{{scorecard}}",
      "company_data": "{{extraction.company_data}}",
      "risk_factors": "{{scorecard.risk_factors}}",
      "next_steps": "{{generate_next_steps(scorecard)}}"
    }
  }
}
`

### Module 4: Build CSV Export

`json
{
  "module": "Tools / Compose CSV",
  "config": {
    "columns": [
      { "header": "Company", "value": "{{scorecard.company_name}}" },
      { "header": "Domain", "value": "{{scorecard.domain}}" },
      { "header": "Composite Score", "value": "{{scorecard.composite.rounded_score}}" },
      { "header": "Confidence", "value": "{{scorecard.composite.confidence}}" },
      { "header": "Product Fit", "value": "{{pillar('Product Fit').score}}" },
      { "header": "ICP Alignment", "value": "{{pillar('ICP Alignment').score}}" },
      { "header": "Technology Fit", "value": "{{pillar('Technology Fit').score}}" },
      { "header": "Funding Health", "value": "{{pillar('Funding Health').score}}" },
      { "header": "Growth Signal", "value": "{{pillar('Growth Signal').score}}" },
      { "header": "Intent Signal", "value": "{{pillar('Intent Signal').score}}" },
      { "header": "Competitive Moat", "value": "{{pillar('Competitive Moat').score}}" },
      { "header": "Relationship", "value": "{{pillar('Relationship').score}}" },
      { "header": "Industry", "value": "{{extraction.company_data.identity.industry}}" },
      { "header": "Employees", "value": "{{extraction.company_data.identity.employee_count.range}}" },
      { "header": "Funding Total", "value": "{{extraction.company_data.funding.total_raised}}" },
      { "header": "Top Risk", "value": "{{first(scorecard.risk_factors).description}}" },
      { "header": "Report URL", "value": "{{report_url}}" }
    ]
  }
}
`

### Module 5: Build Markdown Report

`markdown
# {{scorecard.company_name}} — Lead Intelligence Report

**Generated**: {{formatDate(now, 'YYYY-MM-DD HH:mm UTC')}}
**Score**: {{scorecard.composite.rounded_score}}/100 ({{scorecard.composite.confidence}})

## Score Card

| Pillar | Score | Weight |
|--------|-------|--------|
{{#each scorecard.pillars}}
| {{name}} | {{score}}/100 | {{weight}}% |
{{/each}}

**Composite**: {{scorecard.composite.rounded_score}}/100

## Company Overview

{{extraction.company_data.identity.name}} was founded in {{extraction.company_data.identity.founding_year}} and is headquartered in {{extraction.company_data.identity.headquarters.city}}, {{extraction.company_data.identity.headquarters.country}}.

## Products

{{#each extraction.company_data.products}}
- **{{name}}**: {{description}}
{{/each}}

## Funding

{{extraction.company_data.funding.total_raised}} USD raised across {{extraction.company_data.funding.rounds.length}} rounds.

## Risk Factors

{{#each scorecard.risk_factors}}
- [{{severity}}] {{description}}
{{/each}}
`

### Module 6: Build Telegram Message

`json
{
  "module": "Telegram / Send Message",
  "config": {
    "chat_id": "{{secrets.TELEGRAM_CHANNEL_ID}}",
    "text": "📊 *{{scorecard.company_name}}*\nScore: {{scorecard.composite.rounded_score}}/100 — {{scorecard.composite.confidence}}\n\n*Key Pillars*\nProduct: {{pillar_score('Product Fit')}} | ICP: {{pillar_score('ICP Alignment')}}\nFunding: {{pillar_score('Funding Health')}} | Growth: {{pillar_score('Growth Signal')}}\n\n*Risk Factors*\n{{risk_summary}}\n\n*Next Steps*\n{{next_steps_summary}}\n\n🔗 [Full Report]({{report_url}})",
    "parse_mode": "Markdown"
  }
}
`

### Module 7: Store in Archive

`json
{
  "module": "Supabase / Insert Row",
  "config": {
    "table": "report_archive",
    "columns": {
      "run_id": "{{run_id}}",
      "company_domain": "{{company_domain}}",
      "format": "{{export_format}}",
      "content": "{{formatted_content}}",
      "delivered_at": "{{now}}",
      "delivery_status": "sent"
    }
  }
}
`

---

## Weekly Summary Export

In addition to per-company exports, a weekly summary CSV is generated at the end of the batch:

`csv
Company,Domain,Score,Confidence,Top Pillar,Weakest Pillar,Top Risk
Acme Corp,acme.com,73,Medium,Funding Health,Relationship,No warm connections
Beta Inc,betainc.io,45,Low,Product Fit,Intent Signal,Insufficient data
`

This summary is delivered via Telegram and stored in Supabase for dashboard use.

---

## XLSX Report

When export_format = "csv", the CSV is automatically converted to XLSX for better formatting:

- Headers are bold with background color (#E8E8E8).
- Scores are conditionally formatted (red < 40, yellow 40-70, green > 70).
- Column widths are auto-sized.
- A second sheet contains the full score key.

---

## Delivery Channels

| Channel | Format | Status Confirmation |
|---------|--------|-------------------|
| Telegram | Formatted message | Message ID |
| Supabase Archive | JSON | Row ID |
| Email (future) | PDF attachment | Send status |

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial Export Scenario documentation |
