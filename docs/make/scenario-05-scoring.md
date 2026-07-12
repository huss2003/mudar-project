# Scenario 05: Scoring

The Scoring Scenario evaluates companies across 8 pillars and produces a composite lead score. It includes a reflection pass for quality assurance.

---

## Trigger

**Trigger Type**: Queue entry with scenario_step = "scoring"

Triggered after the AI Analysis scenario completes.

---

## Scenario Flow

`mermaid
flowchart TD
    A[Receive Queue Item] --> B[Load AI Extraction]
    B --> C[Prepare Scoring Context]
    C --> D[Call AI for Scoring]
    D --> E{Success?}
    E -->|Yes| F[Parse Score Card]
    E -->|No| G[Retry 3x]
    G --> D
    F --> H[Validate Scores]
    H --> I{Valid?}
    I -->|Yes| J[Run Reflection Pass]
    I -->|No| K[Flag for Review]
    K --> L[Manual Override]
    J --> M{Reflection Pass?}
    M -->|Yes| N[Store Score Card]
    M -->|No| O[Re-score]
    O --> D
    N --> P[Update Queue Status]
`

---

## Modules

### Module 1: Load AI Extraction

`json
{
  "module": "Supabase / Select Rows",
  "config": {
    "table": "ai_extractions",
    "filter": { "company_domain": "{{company_domain}}", "run_id": "{{run_id}}" },
    "limit": 1
  }
}
`

### Module 2: Prepare Scoring Context

`json
{
  "module": "Tools / Compose String",
  "config": {
    "text": "Company: {{company_name}}\nDomain: {{company_domain}}\n\n=== COMPANY DATA ===\n{{extraction.company_data}}\n\nScore this company across all 8 pillars. Score each independently 0-100.\nProvide justification and evidence for each score."
  }
}
`

### Module 3: Call AI for Scoring

`json
{
  "module": "OpenAI / Create Completion",
  "config": {
    "model": "gpt-4o-2026-05-13",
    "messages": [
      { "role": "system", "content": "{{system_prompt_scoring}}" },
      { "role": "user", "content": "{{scoring_context}}" }
    ],
    "response_format": { "type": "json_object" },
    "temperature": 0.2,
    "max_tokens": 2000
  }
}
`

### Module 4: Validate Scores

`json
{
  "module": "Tools / Parse JSON",
  "config": {
    "data": "{{ai.response.choices[0].message.content}}"
  }
}
`

Validation checks:

`python
def validate_scorecard(scores):
    errors = []
    if len(scores.pillars) != 8:
        errors.append("Must have exactly 8 pillars")
    for p in scores.pillars:
        if p.score < 0 or p.score > 100:
            errors.append(f"{p.name}: Score {p.score} out of range")
        if not p.justification or len(p.justification) < 20:
            errors.append(f"{p.name}: Justification too short")
    total_weight = sum(p.weight for p in scores.pillars)
    if abs(total_weight - 1.0) > 0.01:
        errors.append(f"Weights sum to {total_weight}, expected 1.0")
    return errors
`

### Module 5: Run Reflection Pass

`json
{
  "module": "OpenAI / Create Completion",
  "config": {
    "model": "gpt-4o-2026-05-13",
    "messages": [
      { "role": "system", "content": "{{system_prompt_reflection}}" },
      { "role": "user", "content": "Review the following scorecard for consistency, accuracy, and hallucination:\n\n{{scorecard_json}}\n\nSource data: {{company_data}}" }
    ],
    "temperature": 0.1,
    "max_tokens": 1500
  }
}
`

### Module 6: Reflection Decision

| Reflection Verdict | Action |
|--------------------|--------|
| PASS | Store score card, proceed to export |
| FAIL with CRITICAL errors | Re-run scoring from scratch |
| FAIL with HIGH errors | Flag for manual review |
| Minor issues | Auto-correct and store |

### Module 7: Store Score Card

`json
{
  "module": "Supabase / Insert Row",
  "config": {
    "table": "score_cards",
    "columns": {
      "run_id": "{{run_id}}",
      "company_domain": "{{company_domain}}",
      "pillar_scores": "{{scorecard.pillars}}",
      "composite_score": "{{scorecard.composite.rounded_score}}",
      "confidence": "{{scorecard.composite.confidence}}",
      "risk_factors": "{{scorecard.risk_factors}}",
      "reflection_passed": true,
      "created_at": "{{now}}"
    }
  }
}
`

---

## 8 Pillar Scoring Reference

| Pillar | Score Weight | Data Requirements | Scoring Guide |
|--------|-------------|-------------------|---------------|
| Product Fit | 12.5% | Product description, features | 0 = no fit, 100 = perfect match |
| ICP Alignment | 12.5% | Industry, segment, company size | 0 = out of ICP, 100 = ideal |
| Technology Fit | 12.5% | Tech stack, integrations | 0 = incompatible, 100 = native integration |
| Funding Health | 12.5% | Total raised, investors, runway | 0 = unfunded, 100 = well-capitalized |
| Growth Signal | 12.5% | Hiring, expansion, product launches | 0 = shrinking, 100 = rapid growth |
| Intent Signal | 12.5% | SEO activity, ads, job postings | 0 = no intent, 100 = active buyer |
| Competitive Moat | 12.5% | Market position, differentiation | 0 = commodity, 100 = defensible |
| Relationship | 12.5% | Warm intros, existing connections | 0 = no connection, 100 = warm intro |

---

## Output Score Card

`json
{
  "company_name": "Acme Corp",
  "domain": "acme.com",
  "pillars": [
    { "name": "Product Fit", "score": 75, "weight": 0.125, "justification": "Product aligns well with ICP", "data_available": true },
    { "name": "ICP Alignment", "score": 80, "weight": 0.125, "justification": "Target segment matches", "data_available": true }
  ],
  "composite": { "raw_score": 68.5, "rounded_score": 69, "confidence": "Medium" },
  "risk_factors": [
    { "description": "Limited data on technology stack", "severity": "Medium", "affected_pillars": ["Technology Fit"] }
  ],
  "reflection": { "passed": true, "findings": [] }
}
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial Scoring Scenario documentation |
