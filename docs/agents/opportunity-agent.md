# Opportunity Agent

> **Pillar 7 — Scores match between company needs and available properties. Weight: 5%.**

---

## Purpose

The Opportunity Agent evaluates how well the company's requirements align with the broker's current property inventory. A company may score highly on all other pillars but have no suitable available properties — either because the company needs a space size or type that is not in inventory, or because the budget does not match. This agent prevents the broker from pursuing leads that cannot be served by the current portfolio.

The agent performs a three-way match: (1) **space match** — does the company's employee count and growth trajectory fit available square footage ranges? (2) **budget match** — can the company afford the rent for suitable properties? (3) **quality match** — does the company's profile (industry, brand, culture) align with the building grade?

---

## Model

| Property | Value |
|----------|-------|
| **Model** | DeepSeek V4 Flash |
| **Provider** | OpenRouter |
| **Cost (input)** | $0.50/1M tokens |
| **Cost (output)** | $2.00/1M tokens |
| **Avg tokens per company** | 800 |
| **Cost per company** | ~$0.00068 |

---

## Input: Property Inventory

The agent receives the current property inventory at scoring time. Typical inventory includes:

| Property | Submarket | Grade | Total Sqft | Available Sqft | Rate/sqft | Min Lease |
|----------|-----------|-------|------------|----------------|-----------|-----------|
| Panchshil Business Park | Hinjewadi | A+ | 500,000 | 45,000 | ₹85 | 3 years |
| Eon Free Zone | Kharadi | A | 350,000 | 30,000 | ₹72 | 3 years |
| Magarpatta Cyber City | Hadapsar | A | 400,000 | 25,000 | ₹68 | 5 years |
| Viman Nagar Tech Park | Viman Nagar | A | 200,000 | 15,000 | ₹95 | 3 years |
| Baner Prime Workspace | Baner | B+ | 80,000 | 8,000 | ₹55 | 12 months |

Inventory is refreshed from the broker's database at the start of each batch run.

---

## Scoring Rubric

| Sub-dimension | Weight | 0–20 | 21–40 | 41–60 | 61–80 | 81–100 |
|--------------|--------|-------|-------|-------|-------|--------|
| **Space Match** | 40% | No property fits space needs | Matches > 50% over/under | Matches within 30% | Matches within 15% | Perfect sqft match available |
| **Budget Match** | 35% | Budget < 60% of cheapest option | Budget 60–80% | Budget 80–100% | Budget 100–120% | Budget exceeds requirement |
| **Quality & Fit** | 15% | Industry incompatible | B Grade or below | B+ to A- | A Grade | A+ / SEZ / premium |
| **Submarket Preference** | 10% | No matching submarket | Adjacent submarket | Same submarket | Preferred submarket | HQ already in submarket |

---

## Space Calculation

The agent estimates space requirements using:

```
base_sqft = current_employees × 80 (industry avg sqft/employee)
growth_buffer = projected_new_hires_12mo × 80
total_requirement = base_sqft + growth_buffer
```

The `growth_buffer` is only added if the Growth Agent score > 60. For stable or declining companies, total requirement = base_sqft only.

---

## Output

```json
{
  "agent": "opportunity-agent",
  "company_id": "uuid",
  "pillar": 7,
  "weight": 0.05,
  "score": 82,
  "confidence": 0.90,
  "sub_dimensions": {
    "space_match": { "score": 78, "weight": 0.40, "rationale": "Requires ~28,000 sqft with growth buffer. Panchshil has 45,000 available." },
    "budget_match": { "score": 85, "weight": 0.35, "rationale": "Est. budget of ₹6.5L/month matches Panchshil at ₹85/sqft" },
    "quality_fit": { "score": 80, "weight": 0.15, "rationale": "ERP company fits Grade A SEZ requirement" },
    "submarket_preference": { "score": 90, "weight": 0.10, "rationale": "Already in Hinjewadi — Panchshil is same submarket" }
  },
  "best_property_match": {
    "property": "Panchshil Business Park",
    "fit_score": 88,
    "suggested_sqft": 28000,
    "est_monthly_rent": "₹6.5L–₹7.5L"
  },
  "alternative_matches": [
    { "property": "Eon Free Zone", "fit_score": 72, "note": "Secondary option if budget prioritization needed" }
  ],
  "no_match_properties": [],
  "strengths": ["Strong match with Panchshil Business Park — same submarket, right size, budget aligns"],
  "weaknesses": ["Only 1 strong match — limited alternatives if Panchshil is unavailable"],
  "rationale": "Excellent opportunity match. Company's estimated 28,000 sqft requirement, ₹6.5L+ budget, and Grade A preference align perfectly with available inventory at Panchshil Business Park."
}
```

---

## Match Categories

| Category | Criteria | Action |
|----------|----------|--------|
| **Strong match** | Fit score ≥ 75 for at least 1 property | Include in commercial strategy brief |
| **Partial match** | Fit score 50–74 for at least 1 property | Include as secondary option |
| **Weak match** | Fit score < 50 for all properties | Add to hold queue, re-evaluate on inventory change |
| **No match** | No inventory fit at any level | Flag `no_inventory_match`, exclude from outreach |

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Company needs 100K+ sqft | Check if inventory has contiguous space; if not, score capped at 40 |
| Growth buffer makes requirement exceed inventory | Note limitation, score based on current headcount only |
| Company budget unknown | Default to industry average for micromarket, reduce confidence |
| Inventory empty (no properties loaded) | Score all leads at 50, flag `inventory_missing` |
| Multiple strong matches | Score based on best match, list alternatives |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Leads with strong property match | 38% | > 30% |
| Leads with no match | 22% | < 25% |
| Best match fit score avg | 74 | > 65 |
| Processing time | 1.3s per company | < 3s |
