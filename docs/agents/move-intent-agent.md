# Move Intent Agent

> **Pillar 2 — Scores move intent from lease dates, rent levels, growth, funding, overcrowding signals. Weight: 35%. The most important agent in the system.**

---

## Purpose

The Move Intent Agent is the highest-weighted agent in the scoring system (35% of the total composite score). Its job is to answer one question: **how likely is this company to need new commercial space within the next 6–12 months?** This is the core predictive signal that drives the entire platform. If a company has no move intent, the remaining pillars (fit, growth, financial health) are largely irrelevant — a company that is perfectly fit but has no need to move is not a lead.

The agent analyzes a combination of explicit signals (lease expiry dates, expansion announcements) and implicit signals (rent-to-revenue ratio indicating cost pressure, hiring velocity creating space needs, overcrowding from headcount growth without square footage expansion).

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

## Input Features

| Feature | Type | Signal Strength |
|---------|------|----------------|
| `est_current_lease_age` | int (months) | **Strong** — older leases are closer to expiry |
| `est_rent_per_sqft` | float (INR) | Medium — high rent signals cost pressure |
| `rent_to_revenue_ratio` | float (0–1) | **Strong** — ratio > 0.08 signals unsustainable rent |
| `employee_growth_rate` | float (−1 to 1) | **Strong** — growth creates space need |
| `funding_count` | int | Medium — funded companies expand |
| `recent_funding_flag` | binary | **Strong** — recent funding triggers expansion |
| `overcrowding_score` | float (0.3–3.0) | **Strong** — below 1.0 = overcrowded |
| `pune_hq_flag` | binary | Medium — HQ companies have more authority to move |
| `expansion_announcements` | int | **Strong** — explicit expansion signal |
| `hiring_velocity` | float (0–0.3) | Medium — rapid hiring creates space pressure |

---

## Scoring Rubric

The agent evaluates move intent across five sub-dimensions:

| Sub-dimension | Weight | Signal Source | High Score Indicators |
|--------------|--------|---------------|----------------------|
| **Lease & Rent Pressure** | 30% | Lease age + rent-to-revenue | Lease > 36 months old, rent-to-revenue > 8% |
| **Growth-Driven Need** | 25% | Employee growth + hiring | Growth > 20% YoY, hiring velocity > 0.1 |
| **Funding & Expansion** | 20% | Funding events + announcements | Series A/B within 12 months, official expansion news |
| **Overcrowding** | 15% | Space-per-employee estimate | Current space < 60 sqft/employee |
| **Timeline Urgency** | 10% | Combined signal synthesis | Multiple signals converging in 6-month window |

---

## Signal Weighting Table

| Signal | Weight | Leased-Based | Growth-Based | Funding-Based |
|--------|--------|-------------|-------------|---------------|
| Lease age ≥ 36 months | +25 | ✓ | | |
| Lease age ≥ 60 months | +35 | ✓ | | |
| Rent-to-revenue > 8% | +20 | ✓ | | |
| Rent-to-revenue > 12% | +30 | ✓ | | |
| Employee growth > 20% YoY | +20 | | ✓ | |
| Employee growth > 50% YoY | +35 | | ✓ | |
| Recent funding (< 12 months) | +25 | | | ✓ |
| Large round (> $10M) | +15 | | | ✓ |
| Overcrowding score < 0.8 | +20 | ✓ | | |
| Expansion announcement | +30 | ✓ | ✓ | ✓ |
| Hiring velocity > 0.15 | +15 | | ✓ | |

---

## Move Intent Categories

Based on the total score, the agent classifies the company into one of five categories:

| Score Range | Category | Definition | Recommended Action |
|-------------|----------|------------|-------------------|
| 80–100 | **Critical** | Active space search underway | Immediate outreach, priority queue |
| 60–79 | **High** | Likely to move within 6 months | Standard outreach within 1 week |
| 40–59 | **Medium** | May move within 12 months | Add to nurture sequence |
| 20–39 | **Low** | Stable — no near-term need | Monitor for change events |
| 0–19 | **None** | No move intent detected | Exclude from active pipeline |

---

## Output

```json
{
  "agent": "move-intent-agent",
  "company_id": "uuid",
  "pillar": 2,
  "weight": 0.35,
  "score": 74,
  "confidence": 0.82,
  "sub_dimensions": {
    "lease_pressure": { "score": 68, "weight": 0.30, "rationale": "Lease age ~48 months, rent-to-revenue at 5.2%" },
    "growth_driven": { "score": 82, "weight": 0.25, "rationale": "Employee growth 22% YoY, hiring velocity 0.12" },
    "funding_expansion": { "score": 71, "weight": 0.20, "rationale": "$12M Series A 8 months ago" },
    "overcrowding": { "score": 65, "weight": 0.15, "rationale": "Est. 72 sqft/employee — approaching threshold" },
    "timeline_urgency": { "score": 80, "weight": 0.10, "rationale": "Multiple signals converge in next 6 months" }
  },
  "intent_category": "high",
  "predicted_timeline": "3–9 months",
  "strengths": ["Recent funding + employee growth combination", "Lease approaching typical renewal window"],
  "weaknesses": ["Rent-to-revenue ratio still manageable — cost pressure alone insufficient"],
  "rationale": "Company shows strong but not critical move intent. Recent $12M funding drives expansion plans, employee growth is creating space pressure, and the lease is approaching the renewal window. The combination of growth + funding is the primary driver."
}
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| No lease data available | Default to estimated lease age from company age (assume 5-year lease, company age / 5), reduce confidence |
| No funding data | Score funding sub-dimension as neutral (50), reduce confidence by 15 |
| Remote-first company | Overcrowding signal irrelevant — reduce overcrowding weight to 5%, redistribute to growth |
| Employee count estimated (not verified) | Apply −15 confidence penalty to growth-driven signals |
| Multiple contradictory signals | Flag for Reflection Agent, note disagreement type |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Avg score | 48 | N/A (market dependent) |
| Avg confidence | 0.78 | > 0.70 |
| Critical classification rate | 6% | 5–10% |
| High classification rate | 22% | 20–30% |
| False positive rate (from feedback) | 12% | < 15% |
| Processing time | 1.4s per company | < 3s |
