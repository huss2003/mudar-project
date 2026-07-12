# Verification Agent

> **Layer 1 — Data Verification. Enforces the 2-source rule on every critical data point.**

---

## Purpose

The Verification Agent implements the platform's core data integrity principle: every critical field must be confirmed by at least two independent sources before it is considered reliable. MiMo V2.5 orchestrates this verification by querying supplementary data sources and comparing normalized data against them. Fields that cannot be verified are demoted to `unverified` status. If enough critical fields fail verification, the entire record is assigned a low confidence score and routed to a reduced scoring path.

---

## Model

| Property | Value |
|----------|-------|
| **Model** | MiMo V2.5 |
| **Provider** | OpenRouter |
| **Cost (input)** | $2.00/1M tokens |
| **Cost (output)** | $8.00/1M tokens |
| **Avg tokens per record** | 1,600 |
| **Cost per record** | ~$0.0056 |
| **Avg latency** | 7.2 seconds |
| **Max concurrency** | 30 records per chunk |

---

## Source Priority

The Verification Agent maintains a prioritized source list and queries them in order until 2+ agree:

| Priority | Source | Type | Best For |
|----------|--------|------|----------|
| 1 | Company website | Primary | Name, location, description, team |
| 2 | Crunchbase | Secondary | Funding, founding date, industry |
| 3 | LinkedIn public page | Primary | Employee count, location, team |
| 4 | SEC / RoC filings | Primary | Revenue, legal name, registered address |
| 5 | Google Business Profile | Primary | Location, hours, verified phone |
| 6 | Industry registries | Secondary | G2 for SaaS, FDA for medical, NASSCOM for IT |

---

## Verification Rules by Field

| Field | Required Agreement | Match Criteria | Failure Action |
|-------|-------------------|----------------|----------------|
| `company_name` | 2 of {website, Crunchbase, LinkedIn} | Fuzzy match ≥ 90% | Mark `unverified_name`, reduce confidence |
| `employee_band` | 2 of {website, LinkedIn, Crunchbase} | Same band or adjacent band | Accept adjacent band, mark `band_estimated` |
| `revenue_band` | 2 of {Crunchbase, SEC/RoC, registry} | Exact band match | Null the field entirely |
| `founded_year` | 2 of {website, Crunchbase, LinkedIn} | ±1 year tolerance | Accept or null if no 2 sources agree |
| `hq_city` | 2 of {website, LinkedIn, Google Business} | City-level match | Null city if 0 sources agree |
| `hq_state` | 2 of {website, LinkedIn} | ISO code match | Infer from city if possible |
| `pune_presence` | 2 of {website, LinkedIn, Google Business} | Binary + address precision | Flag `presence_unverified` |

---

## Verification Workflow

```
Normalized Record → MiMo V2.5 receives record + field list
         ↓
For each critical field:
  → Query Source 1 (company website)
  → Query Source 2 (Crunchbase/LinkedIn)
  → Compare extracted values
  → If both agree: mark VERIFIED
  → If disagree: query Source 3 (tiebreaker)
  → If still no agreement: mark DISPUTED
         ↓
Compute verification_score = verified_fields / total_critical_fields
         ↓
Route based on score:
  score ≥ 0.8 → Full pipeline
  score 0.4–0.79 → Reduced scoring path (max pillar score = 50)
  score < 0.4 → Flagged as low_confidence
  score = 0.0 → Record discarded entirely
```

---

## Confidence Scoring

Every field receives a `verification_confidence` score (0–100) that is a product of:

```
confidence = source_authority_score × agreement_multiplier × recency_multiplier
```

| Factor | Range | Description |
|--------|-------|-------------|
| Source authority | 0.3–1.0 | Primary = 1.0, Secondary = 0.7, Inferred = 0.3 |
| Agreement multiplier | 0.5–1.0 | 2+ sources agree = 1.0, disputed = 0.5 |
| Recency multiplier | 0.25–1.0 | < 90 days = 1.0, > 2 years = 0.25 |

---

## Record-Level Output

```json
{
  "company_id": "uuid",
  "verification_score": 0.88,
  "field_results": [
    {
      "field": "company_name",
      "status": "verified",
      "sources": [
        {"source": "company_website", "value": "Acme Corp", "match": true},
        {"source": "crunchbase", "value": "Acme Corp", "match": true}
      ],
      "verification_confidence": 95
    }
  ],
  "unverified_fields": [],
  "disputed_fields": [],
  "nulled_fields": [],
  "scoring_path": "full"
}
```

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Record throughput | ~4 records/second | > 3 rec/s |
| 2-source agreement rate | 81% | > 75% |
| Records fully verified | 68% | > 60% |
| Records discarded (score = 0) | 4.2% | < 5% |
| Low-confidence records | 11.3% | < 15% |
| Avg latency per record | 7.2s | < 10s |
