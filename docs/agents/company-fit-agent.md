# Company Fit Agent

> **Pillar 1 — Scores company fit: size, industry, revenue, Pune presence. Weight: 10%.**

---

## Purpose

The Company Fit Agent evaluates whether a company is a structural match for the broker's commercial real estate portfolio in Pune. This is the most basic filter — a company that is too small, too large, in the wrong industry, or without a Pune presence is unlikely to convert regardless of other signals. This agent scores the static, structural fit before dynamic signals (move intent, growth) are considered.

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

The agent receives the following features from the Feature Agent:

| Feature | Type | Source |
|---------|------|--------|
| `employee_count_midpoint` | int | Verified employee band midpoint |
| `revenue_midpoint` | float | Verified revenue band midpoint |
| `company_age` | int | Current year − founded year |
| `pune_hq_flag` | binary | Is HQ in Pune? |
| `pune_presence` | string | HQ, branch, satellite, none |
| `industry_growth_rate` | float | Industry CAGR benchmark |
| `micromarket` | string | Normalized micromarket classification |
| `hq_city` | string | City name |
| `hq_state` | string | ISO state code |

---

## Scoring Rubric

The agent scores on a 0–100 scale across four sub-dimensions:

| Sub-dimension | Weight | 0–20 | 21–40 | 41–60 | 61–80 | 81–100 |
|--------------|--------|-------|-------|-------|-------|--------|
| **Size Fit** | 30% | < 10 or > 5000 employees | 10–25 employees | 25–75 or 2000–5000 | 75–150 or 500–2000 | 150–500 employees |
| **Industry Fit** | 25% | No commercial real estate need | Fully remote industry | Industry rarely needs office | Industry sometimes needs office | Industry drives office demand |
| **Pune Presence** | 30% | No Pune presence | Satellite (1–5 people) | Branch (6–25) | Office (26–100) | HQ in Pune |
| **Revenue Adequacy** | 15% | Revenue < $1M or unknown | $1M–$5M | $5M–$20M | $20M–$100M | $100M+ |

**Total score formula**: weighted sum of sub-dimension scores / 100, mapped to 0–100.

---

## Pune Presence Scoring

This sub-dimension is critical for the broker's specific market. The agent assigns scores based on:

| Pune Presence | Score | Description |
|--------------|-------|-------------|
| **HQ** | 90–100 | Company headquartered in Pune. Strongest signal — local decision-making. |
| **Major branch** | 70–85 | 26+ employees in Pune. Likely has local decision-maker authority. |
| **Minor branch** | 50–65 | 6–25 employees. May need to escalate decisions to HQ. |
| **Satellite** | 30–45 | 1–5 employees. Low authority, likely remote workers. |
| **No presence** | 0–10 | No Pune presence at all. Cold outreach only. |
| **Unknown** | 20 (default) | Could not determine presence. Neutral score with low confidence. |

---

## Output

```json
{
  "agent": "company-fit-agent",
  "company_id": "uuid",
  "pillar": 1,
  "weight": 0.10,
  "score": 78,
  "confidence": 0.85,
  "sub_dimensions": {
    "size_fit": { "score": 85, "weight": 0.30, "rationale": "350 employees — ideal mid-market fit" },
    "industry_fit": { "score": 72, "weight": 0.25, "rationale": "Cloud ERP for manufacturing — strong office demand" },
    "pune_presence": { "score": 90, "weight": 0.30, "rationale": "HQ in Pune, Hinjewadi area" },
    "revenue_adequacy": { "score": 60, "weight": 0.15, "rationale": "$30M revenue — adequate for Grade A space" }
  },
  "strengths": ["HQ in target submarket", "Ideal employee range", "Growing industry"],
  "weaknesses": ["Revenue on lower end for Grade A+ properties"],
  "rationale": "Strong structural fit. Pune HQ with 350 employees in manufacturing ERP puts company in prime target demographic."
}
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Employee count unknown | Default to 100, reduce confidence by 30 points |
| Micromarket = catch-all | Reduce industry fit weight by 50%, flag for manual review |
| No Pune presence | Score capped at 40 unless other signals are very strong |
| Revenue = unknown | Revenue adequacy defaults to 40, confidence reduced |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Avg score | 62 | N/A (market dependent) |
| Avg confidence | 0.82 | > 0.75 |
| Processing time | 1.2s per company | < 3s |
| Cache hit rate | 34% | > 30% |
