# Growth Agent

> **Pillar 3 — Scores hiring velocity, headcount growth, revenue growth, funding, expansion announcements. Weight: 15%.**

---

## Purpose

The Growth Agent evaluates whether a company is in an expansion phase that would create need for additional commercial space. A growing company is more likely to outgrow its current premises, hire in new locations, and invest in real estate. This agent measures growth across three dimensions: headcount, revenue, and physical footprint. Unlike the Move Intent Agent which predicts *if* a company will move, the Growth Agent measures *how fast* the company is expanding — a fast-growing company may need space even if its current lease is not expiring.

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

| Feature | Type | Description |
|---------|------|-------------|
| `employee_growth_rate` | float (−0.5 to 1.0) | YoY headcount change |
| `linkedin_follower_growth` | int | Follower change over 90 days |
| `hiring_velocity` | float (0–0.3) | Active jobs / total headcount |
| `revenue_growth_estimate` | float (−10% to 50%) | Industry-benchmarked estimate |
| `expansion_announcements` | int | News count mentioning expansion |
| `funding_recency_months` | int | Months since last funding |
| `total_funding_raised` | float | Sum of all disclosed rounds |
| `company_age` | int | Used for growth stage classification |

---

## Scoring Rubric

| Sub-dimension | Weight | 0–20 | 21–40 | 41–60 | 61–80 | 81–100 |
|--------------|--------|-------|-------|-------|-------|--------|
| **Headcount Growth** | 35% | Declining or flat | 0–5% YoY | 5–15% YoY | 15–30% YoY | 30%+ YoY |
| **Hiring Velocity** | 25% | No active jobs | < 3% of headcount | 3–8% | 8–15% | 15%+ of headcount |
| **Revenue Trajectory** | 20% | Declining | Flat / unknown | 5–10% growth | 10–25% growth | 25%+ growth |
| **Expansion Signals** | 20% | No signals | 1 weak signal | 1 strong or 2 weak | 2+ strong signals | Funding + expansion news |

---

## Growth Stage Classification

The agent classifies the company into a growth stage that modulates how scores are interpreted:

| Stage | Criteria | Score Modifier | Typical Square Foot Need |
|-------|----------|---------------|--------------------------|
| **Startup** | Age < 5 years, < 50 employees | +5 (high growth potential) | 1,000–5,000 sqft |
| **Scale-up** | Age 5–10, 50–200 employees, recent funding | +10 (sweet spot) | 5,000–20,000 sqft |
| **Growth** | 200–1000 employees, 10%+ growth | 0 (stable growth) | 20,000–100,000 sqft |
| **Mature** | 1000+ employees, < 10% growth | −5 (consolidation risk) | 50,000–500,000 sqft |
| **Declining** | Negative growth, layoffs | −20 (avoid) | May be downsizing |
| **Unknown** | Insufficient data | −10 (uncertainty penalty) | Estimate based on headcount |

---

## Signal Sources

The agent sources growth data from:

1. **LinkedIn company page**: Headcount changes, recent hires, follower growth (primary)
2. **Crunchbase**: Funding rounds, acquisition history (secondary)
3. **Google News / Firecrawl**: Expansion announcements, new office openings, press releases
4. **Company careers page**: Active job listings count (via Firecrawl)
5. **Industry benchmarks**: Growth rate comparisons for the micromarket

---

## Output

```json
{
  "agent": "growth-agent",
  "company_id": "uuid",
  "pillar": 3,
  "weight": 0.15,
  "score": 81,
  "confidence": 0.79,
  "sub_dimensions": {
    "headcount_growth": { "score": 78, "weight": 0.35, "rationale": "22% YoY employee growth on LinkedIn" },
    "hiring_velocity": { "score": 85, "weight": 0.25, "rationale": "42 active jobs / 350 employees = 12% velocity" },
    "revenue_trajectory": { "score": 72, "weight": 0.20, "rationale": "Industry benchmark suggests 15-20% growth" },
    "expansion_signals": { "score": 90, "weight": 0.20, "rationale": "Series A 8 months ago + new Pune office announced" }
  },
  "growth_stage": "scale-up",
  "stage_modifier": 10,
  "strengths": ["Scale-up with recent funding", "Aggressive hiring across all departments"],
  "weaknesses": ["Revenue trajectory is estimated, not verified"],
  "rationale": "Company is in a clear scale-up phase. 22% employee growth paired with 12% hiring velocity and recent Series A creates strong space demand. The expansion announcement for a new Pune office is a direct signal."
}
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Headcount data from single source only | Apply −15 confidence penalty |
| No active job listings found | Score hiring velocity as 30 (low), note 'unknown' |
| Private company, no revenue data | Revenue trajectory defaults to industry benchmark, −10 confidence |
| Negative growth detected | Score capped at 30 unless expansion announcements contradict |
| Company age unknown | Default to growth stage classification of 'unknown' |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Avg score | 55 | N/A |
| Avg confidence | 0.76 | > 0.70 |
| Scale-up classification accuracy | 82% | > 75% |
| Growth signal detection rate | 74% | > 70% |
| Processing time | 1.3s per company | < 3s |
