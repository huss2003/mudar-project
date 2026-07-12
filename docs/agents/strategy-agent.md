# Strategy Agent

> **Layer 5 — Commercial strategy generation. Building recommendations, budget ranges, solution approach. MiMo V2.5.**

---

## Purpose

The Strategy Agent is the first agent in the delivery layer that connects the scored company profile to the broker's actual property inventory and produces a actionable commercial strategy brief. After the Judge Agent has approved a lead, the Strategy Agent determines: (a) which specific property best fits the company's needs, (b) what budget range the company can afford, (c) what value proposition will resonate with the decision-maker, and (d) what likely objections will arise and how to preempt them.

This agent transforms a scored lead into a *sales-ready opportunity*. The output is a structured brief that the broker can read in 2 minutes and act on immediately.

---

## Model

| Property | Value |
|----------|-------|
| **Model** | MiMo V2.5 |
| **Provider** | OpenRouter |
| **Cost (input)** | $2.00/1M tokens |
| **Cost (output)** | $8.00/1M tokens |
| **Avg tokens per company** | 1,200 |
| **Cost per company** | ~$0.0048 |
| **Avg latency** | 7 seconds |
| **Batch size** | 30 leads (post-Judge) |

---

## Input

The agent receives the full post-Judge lead packet:

| Data | Source | Purpose |
|------|--------|---------|
| Company profile | Layers 1–2 | Name, size, industry, location |
| Pillar scores | Layer 2 | Move intent, growth, financial capacity |
| Property inventory | Broker input | Available spaces with rates, grades, submarkets |
| Decision-maker contact | Layer 5 | Name, title, email, LinkedIn |
| Network path | Layer 6 | Warm intro recommendation |
| Consensus score | Layer 3 | Overall quality indicator |
| Judge notes | Layer 3 | Approval rationale, broker notes |

---

## Budget Calculation

The agent computes a defensible monthly rent range:

```
monthly_budget = revenue_midpoint × industry_rent_ratio × pune_market_factor
```

Where:
- `industry_rent_ratio` = fraction of revenue typically allocated to real estate (SaaS = 3–5%, manufacturing = 5–8%, logistics = 8–12%)
- `pune_market_factor` = 0.7 (Pune vs Mumbai/Bangalore benchmark)

If the company has positive growth trajectory, the budget includes an expansion contingency:

```
expansion_contingency = monthly_budget × 0.20 (if growth score > 60)
```

---

## Property Matching

The matching algorithm considers eight variables:

| Variable | Weight | Data Source |
|----------|--------|-------------|
| Employee count | 0.25 | Feature Agent |
| Growth rate | 0.15 | Feature Agent |
| Revenue band | 0.20 | Feature Agent |
| Industry micromarket | 0.15 | Normalization Agent |
| Current submarket | 0.10 | Feature Agent |
| Tech stack | 0.05 | Normalization Agent |
| Growth stage | 0.05 | Feature Agent |
| Team distribution | 0.05 | Feature Agent |

Properties scoring 80+ fit are "strong matches." Properties scoring 60–79 are "secondary options." Below 60 are not presented.

---

## Objection Preemption

The agent generates likely objections based on the company profile:

| Objection | Preemptive Response |
|-----------|-------------------|
| "We already have space in Mumbai" | "Your LinkedIn shows 60% of new hires are in Pune" |
| "Too expensive" | "At ₹6.5L/month, rent is 4.2% of revenue — within industry norm" |
| "We're fully remote" | "Your careers page shows 42 open positions in Pune" |
| "Not expanding now" | "Your $12M Series A suggests expansion within 12 months" |
| "Need shorter lease" | Several properties offer 12–24 month terms" |

---

## Output

```json
{
  "agent": "strategy-agent",
  "company_id": "uuid",
  "strategy_brief": {
    "recommended_property": {
      "name": "Panchshil Business Park",
      "fit_score": 88,
      "grade": "A+",
      "submarket": "Hinjewadi",
      "available_sqft": "45,000",
      "suggested_sqft": "28,000",
      "monthly_budget_estimate": "₹6.5L–₹7.5L",
      "rate_per_sqft": "₹85"
    },
    "alternative_properties": [
      {
        "name": "Eon Free Zone",
        "fit_score": 72,
        "submarket": "Kharadi",
        "note": "Lower cost option if budget is a concern"
      }
    ],
    "value_proposition": "Acme Corp's 22% YoY employee growth and recent $12M Series A create an immediate need for scalable office space. Panchshil Business Park in Hinjewadi (same submarket as current HQ) offers Grade A+ SEZ space at a rent burden of just 4.2% of revenue — well within the 3–5% industry benchmark for manufacturing ERP companies.",
    "likely_objections": [
      {
        "objection": "We're not ready to commit to a 5-year lease",
        "response": "Panchshil offers flexible 3-year terms with a 2-year break clause — perfect for your growth trajectory."
      },
      {
        "objection": "We're evaluating Mumbai, not Pune",
        "response": "85% of your new hires are in Pune. Adding Mumbai capacity makes sense only after Pune base is secured."
      }
    ],
    "engagement_approach": "Warm intro via Raj Patel (VP Engineering, mutual connection)",
    "priority": "high",
    "timeline_recommendation": "Contact within 7 days — recent funding creates urgency window"
  },
  "budget_detail": {
    "monthly_rent_lower": 650000,
    "monthly_rent_upper": 750000,
    "currency": "INR",
    "rent_burden_pct": 4.2,
    "industry_benchmark_pct": "3-5",
    "expansion_contingency_applied": true
  },
  "rationale": "Acme Corp is an excellent match for Panchshil Business Park. Same submarket (Hinjewadi), budget aligns at ₹6.5L–₹7.5L/month, and the Grade A+ SEZ status matches their manufacturing ERP profile. Warm intro via Raj Patel makes this actionable immediately."
}
```

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Strong property match rate | 84% | > 75% |
| Objection preemption accuracy | 88% | > 80% |
| Budget estimate accuracy | ±12% | < ±15% |
| Processing time | 7s per company | < 12s |
| Strategy brief acceptance (broker) | 91% | > 85% |
