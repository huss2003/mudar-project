# Feature Agent

> **Layer 1 — Feature Engineering. Computes 40+ derived numeric features from verified company records.**

---

## Purpose

Verified company data points are categorical or text-based. The Feature Agent transforms them into numerical and ordinal features that the 8 pillar-scoring agents can consume directly. DeepSeek V4 Flash computes derived metrics using deterministic rules defined in the feature engineering prompt. No ML model training occurs — all features are computed via arithmetic, lookups, and heuristic rules calibrated to the Pune commercial real estate market.

Each derived feature belongs to one of 8 pillars that mirror the specialist scoring agents in Layer 2. Each pillar receives 3–7 features.

---

## Model

| Property | Value |
|----------|-------|
| **Model** | DeepSeek V4 Flash |
| **Provider** | OpenRouter |
| **Cost (input)** | $0.50/1M tokens |
| **Cost (output)** | $2.00/1M tokens |
| **Avg tokens per record** | 600 |
| **Cost per record** | ~$0.0005 |
| **Batch size** | 50 records |
| **Avg latency per batch** | ~10 seconds |

---

## Derived Features by Pillar

### Pillar 1 — Company Fit

| Feature | Formula | Range | Unit |
|---------|---------|-------|------|
| `employee_count_midpoint` | Band midpoint interpolation | 25–7500 | Employees |
| `revenue_midpoint` | Band midpoint interpolation | 500K–500M | USD |
| `company_age` | current_year − founded_year | 0–76 | Years |
| `pune_hq_flag` | 1 if HQ in Pune, else 0 | 0 or 1 | Binary |
| `industry_growth_rate` | Industry benchmark lookup | −5% to +25% | CAGR |

### Pillar 2 — Move Intent

| Feature | Formula | Range | Unit |
|---------|---------|-------|------|
| `est_current_lease_age` | Scraped lease mention age | 0–120 | Months |
| `est_rent_per_sqft` | Micromarket × Pune submarket lookup | 25–150 | INR/sqft |
| `rent_to_revenue_ratio` | (est_annual_rent × pune_occupancy) / revenue_midpoint | 0.0–1.0 | Ratio |
| `growth_rate_1yr` | (current_emp_band_idx − prev_emp_band_idx) / years | −1.0 to 1.0 | Delta/year |
| `funding_count` | Count of disclosed funding rounds | 0–10 | Count |
| `recent_funding_flag` | 1 if funding within 12 months, else 0 | 0 or 1 | Binary |
| `overcrowding_score` | est_current_sqft / (headcount × 80) — below 1.0 = overcrowded | 0.3–3.0 | Ratio |

### Pillar 3 — Growth

| Feature | Formula | Range | Unit |
|---------|---------|-------|------|
| `employee_growth_rate` | (current − historical) / years_since_last | −0.5 to 1.0 | Delta/year |
| `linkedin_follower_growth` | follower_count_change / 90 days | −1000 to 10000 | Followers/quarter |
| `hiring_velocity` | active_job_count / total_headcount | 0–0.3 | Ratio |
| `revenue_growth_estimate` | industry_benchmark_growth + company_size_modifier | −10% to 50% | % |
| `expansion_announcements` | Count of news mentions containing "expansion", "new office", "growth" | 0–20 | Count |

### Pillar 4 — Financial

| Feature | Formula | Range | Unit |
|---------|---------|-------|------|
| `revenue_per_employee` | revenue_midpoint / employee_midpoint | 0–500K | USD |
| `est_gross_margin` | Industry benchmark × size modifier | 20–85% | Percentage |
| `funding_round_count` | From Crunchbase (null if unavailable) | 0–10 | Count |
| `total_funding_raised` | Sum of disclosed rounds | 0–500M | USD |
| `funding_recency_months` | Months since last disclosed funding | 0–120 | Months |
| `rent_burden_ratio` | est_annual_rent / revenue_midpoint | 0.0–1.0 | Ratio |
| `profitability_estimate` | revenue_midpoint − (emp_count × avg_salary) − est_rent | −50M to 200M | USD |

### Pillar 5 — Decision Maker

| Feature | Formula | Range | Unit |
|---------|---------|-------|------|
| `management_completeness` | filled_c_level_roles / expected_roles | 0.0–1.0 | Ratio |
| `ceo_linkedin_presence` | 1 if CEO has LinkedIn profile, else 0 | 0 or 1 | Binary |
| `decision_maker_seniority` | Max title rank found (CEO=5, CTO=4, Director=3, Manager=2, None=0) | 0–5 | Ordinal |
| `linkedin_staff_quality` | Percentage of staff with 5+ years at company | 0–100 | Percentage |

### Pillar 6 — Network

| Feature | Formula | Range | Unit |
|---------|---------|-------|------|
| `mutual_connection_count` | Count of overlapping LinkedIn connections with broker | 0–500 | Count |
| `mutual_connection_seniority` | Max rank of mutual connection | 0–5 | Ordinal |
| `past_broker_interaction` | 1 if previously contacted by broker, else 0 | 0 or 1 | Binary |
| `vendor_relationship_flag` | 1 if company is vendor/client of broker network | 0 or 1 | Binary |

### Pillar 7 — Opportunity

| Feature | Formula | Range | Unit |
|---------|---------|-------|------|
| `est_space_requirement_sqft` | employee_count × 80 (avg sqft/employee) | 2000–600K | Sq ft |
| `est_monthly_budget` | revenue_midpoint × industry_rent_ratio × pune_factor | 50K–50L | INR |
| `property_grade_preference` | Industry-based grade lookup (A, B, C) | 1–3 | Ordinal |
| `preferred_submarket` | Distance-weighted match to industry clusters | String | Submarket |

### Pillar 8 — Evidence

| Feature | Formula | Range | Unit |
|---------|---------|-------|------|
| `source_count_total` | Count of all unique sources for this company | 0–20 | Count |
| `primary_source_count` | Count of primary sources | 0–10 | Count |
| `data_freshness_days` | Max days since oldest source | 0–730 | Days |
| `verification_coverage` | verified_fields / total_critical_fields | 0–100% | Percentage |

---

## Missing Data Handling

Not all features can be computed for every company. The Feature Agent applies a three-tier approach:

1. **Impute from industry average**: For common missing fields (revenue, employee count), use the micromarket peer average stored in a lookup table.
2. **Set to neutral value**: For features where imputation introduces bias (tech stack signals), set to 0.5 (mid-range).
3. **Flag as null**: For critical features that cannot be imputed (funding data, lease dates), set to null and carry a `missing_feature_mask` array that downstream agents use to reduce confidence on affected pillar scores.

Records missing more than 60% of features are flagged `feature_sparse` and routed to a reduced scoring path where they receive a maximum composite score of 40.

---

## Output Example

```json
{
  "company_id": "uuid",
  "features": {
    "employee_count_midpoint": 350,
    "revenue_midpoint": 30000000,
    "company_age": 14,
    "pune_hq_flag": 1,
    "est_rent_per_sqft": 65,
    "rent_to_revenue_ratio": 0.042,
    "employee_growth_rate": 0.15,
    "hiring_velocity": 0.08,
    "revenue_per_employee": 85714,
    "est_gross_margin": 0.62,
    "total_funding_raised": 12000000,
    "rent_burden_ratio": 0.042,
    "management_completeness": 0.75,
    "decision_maker_seniority": 5,
    "mutual_connection_count": 3,
    "est_space_requirement_sqft": 28000,
    "source_count_total": 7,
    "verification_coverage": 0.88
  },
  "missing_feature_mask": [
    "funding_round_count",
    "expansion_announcements"
  ],
  "feature_sparse": false,
  "feature_confidence": 0.92
}
```
