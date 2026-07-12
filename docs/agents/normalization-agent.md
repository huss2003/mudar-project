# Normalization Agent

> **Layer 1 — Data Normalization. Transforms raw scraped text into structured, schema-validated company records.**

---

## Purpose

Raw scraped data from the Discovery Agent is messy. Company names include taglines ("Acme Corp \| Enterprise Software"), employee counts are prose ("200-500 employees"), locations are inconsistent, and industry tags are freeform. The Normalization Agent uses DeepSeek V4 Flash to parse, clean, and standardize every field into a defined JSON schema. The model operates in structured-output mode — every response is validated against a JSON Schema before being accepted downstream.

---

## Model

| Property | Value |
|----------|-------|
| **Model** | DeepSeek V4 Flash |
| **Provider** | OpenRouter |
| **Cost (input)** | $0.50/1M tokens |
| **Cost (output)** | $2.00/1M tokens |
| **Avg tokens per record** | 300 |
| **Cost per record** | ~$0.0003 |
| **Batch size** | 20 records |
| **Batch latency** | ~3 seconds |

---

## Input

```json
{
  "raw_name": "Acme Corp | Enterprise Software Solutions",
  "raw_employees": "200-500 employees",
  "raw_revenue": "$10M-$50M",
  "raw_founded": "Founded 2012",
  "raw_location": "Pune, Maharashtra, India",
  "raw_industry_tags": ["ERP", "Cloud Software", "Manufacturing"],
  "management_raw": ["Jane Doe — CEO", "John Smith — CTO"],
  "tech_signals": ["React", "AWS", "Python"],
  "social_urls": { "linkedin": "...", "crunchbase": "..." },
  "reachability": "reachable"
}
```

---

## Normalization Rules

DeepSeek V4 Flash applies the following deterministic extraction rules via prompt:

| Field | Extraction Rule | Validation |
|-------|----------------|------------|
| `company_name` | Strip taglines, suffixes, punctuation after pipe/dash | Max 100 chars, no corporate suffixes in name field |
| `legal_suffix` | Match against 15-value enum: Inc, LLC, Ltd, GmbH, Pvt Ltd, LLP, Corp, etc. | Enum validation |
| `micromarket` | Classify into 200-value hierarchical taxonomy | Taxonomy lookup |
| `employee_band` | Map prose to 6-value band: band_1_50, band_50_200, band_200_1000, band_1000_5000, band_5000_plus | Band boundaries |
| `revenue_band` | Map prose to 6-value band: rev_0_1m, rev_1m_5m, rev_5m_20m, rev_20m_100m, rev_100m_plus, rev_unknown | Band boundaries |
| `founded_year` | Extract 4-digit year from text | Range 1950–2026, nullable |
| `hq_city` | Parse location string, resolve abbreviations | GeoNames index validation |
| `hq_state` | Extract 2-letter ISO code | ISO 3166-2 |
| `hq_country` | Extract ISO alpha-2 code | ISO 3166-1 alpha-2 |
| `tech_stack` | Normalize case, deduplicate | Max 20 items |

---

## Output Schema

Every output record must validate against this schema before being accepted:

| Field | Type | Example | Required |
|-------|------|---------|----------|
| `company_name` | string | "Acme Corp" | Yes |
| `legal_suffix` | enum | "Pvt Ltd" | No |
| `micromarket` | string | "Cloud ERP for mid-market manufacturing" | Yes |
| `employee_band` | enum | "band_200_1000" | Yes |
| `revenue_band` | enum | "rev_10m_50m" | No |
| `founded_year` | int | 2012 | No |
| `hq_city` | string | "Pune" | Yes |
| `hq_state` | string | "MH" | Yes |
| `hq_country` | string | "IN" | Yes |
| `pune_presence` | string | "hq", "branch", "satellite", "none" | Yes |
| `tech_stack` | string[] | ["React", "AWS", "Python"] | No |
| `management_roles` | object[] | `[{"name": "Jane Doe", "title": "CEO"}]` | No |
| `social_profiles` | object | `{"linkedin": "...", "crunchbase": "..."}` | No |
| `normalization_confidence` | float | 0.92 | Yes |

---

## Micromarket Classification

This is the most critical output of the Normalization Agent. DeepSeek assigns each company to a node in a 200-value hierarchical taxonomy specific to Pune's commercial real estate market. Examples:

- "Cloud-based ERP for mid-market manufacturing"
- "AI-powered customer support for BFSI"
- "IT services for US healthcare clients"
- "Pharma R&D outsourcing — clinical trials"
- "Engineering design & drafting for European auto"

The taxonomy includes a catch-all ("Other — free description") for companies outside defined categories. These are flagged for manual review but still proceed through the pipeline with reduced market-fit scores in later layers.

---

## Retry & Quarantine

Schema validation runs on every output. If validation fails, the agent retries up to 2 times with an enhanced prompt that includes the specific validation error. If all retries fail, the record is written to a `normalization_failures.jsonl` file for manual review. In production, approximately 1–2% of records fail normalization and enter quarantine. These are analyzed weekly by the Learning Agent to identify systematic extraction failures.

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Record throughput | 20 records / 3s | 20 / 5s |
| Schema compliance | 98.2% | > 95% |
| Retry rate | 3.5% | < 5% |
| Quarantine rate | 1.8% | < 3% |
| Confidence > 0.8 | 92% | > 90% |
