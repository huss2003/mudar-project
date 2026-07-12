# Financial Agent

> **Pillar 4 — Scores revenue, profitability, funding reserves, rent-to-revenue ratio. Weight: 12%. Zauba Corp data integration.**

---

## Purpose

The Financial Agent evaluates a company's financial capacity to lease new commercial space in Pune. Financial health is a necessary condition for a qualified lead — even a company with strong move intent and growth cannot convert if it lacks the budget for Grade A office space. This agent scores the company's ability to afford and sustain a commercial lease, using Zauba Corp (Indian company financial filings) as a primary data source alongside Crunchbase, SEC filings, and public financial disclosures.

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

## Data Sources

| Source | Data Available | Currency | Coverage |
|--------|---------------|----------|----------|
| **Zauba Corp** | Registered address, paid-up capital, RoC filings | INR | All registered Indian companies |
| **Crunchbase** | Funding rounds, lead investors, valuation | USD | VC-backed companies |
| **SEC EDGAR** | Revenue, P&L, balance sheet | USD | US-listed subsidiaries |
| **Company website** | Self-reported revenue, client logos | — | All companies (low trust) |
| **Industry benchmarks** | Avg revenue/employee by micromarket | INR/USD | All companies |

---

## Zauba Corp Integration

For Indian companies, Zauba Corp is the most reliable financial data source. The agent queries Zauba via:

1. **Company search** by name or CIN (Corporate Identification Number)
2. **Paid-up capital** extraction — minimum capital indicates financial seriousness
3. **RoC filing status** — active/compliant indicates good standing
4. **Registered address** — cross-reference Pune presence

If Zauba data is available, the agent gives it highest weight for financial scoring. Zauba returns are typically 6–18 months delayed, so a recency decay is applied.

---

## Scoring Rubric

| Sub-dimension | Weight | 0–20 | 21–40 | 41–60 | 61–80 | 81–100 |
|--------------|--------|-------|-------|-------|-------|--------|
| **Revenue** | 30% | < $1M or unknown | $1M–$5M | $5M–$20M | $20M–$100M | $100M+ |
| **Funding Reserves** | 25% | No funding | Angel/Seed only | Series A (< $10M) | Series A/B ($10M–$50M) | Series C+ or profitable |
| **Rent Affordability** | 25% | Rent > 15% of revenue | Rent 10–15% | Rent 6–10% | Rent 3–6% | Rent < 3% of revenue |
| **Profitability Signal** | 20% | Known losses | Unknown (private) | Industry zero-profit | Break-even to 5% margin | 5%+ net margin or well-funded |

---

## Rent Affordability Calculation

The rent affordability score is computed from the `rent_burden_ratio` feature:

| Rent Burden Ratio | Score | Interpretation |
|------------------|-------|----------------|
| < 3% of revenue | 85–100 | Easily affordable |
| 3–6% of revenue | 65–84 | Comfortable |
| 6–10% of revenue | 45–64 | Manageable |
| 10–15% of revenue | 25–44 | Stretched |
| > 15% of revenue | 0–24 | Unsustainable |

The calculation assumes Pune market rates of ₹65–85/sqft for Grade A space (depending on submarket) and an average of 80 sqft per employee. For a 350-employee company: est. rent = 350 × 80 × ₹75 × 12 = ₹25.2M/year (~$300K).

---

## Output

```json
{
  "agent": "financial-agent",
  "company_id": "uuid",
  "pillar": 4,
  "weight": 0.12,
  "score": 72,
  "confidence": 0.81,
  "sub_dimensions": {
    "revenue": { "score": 65, "weight": 0.30, "rationale": "$30M revenue — solid mid-market" },
    "funding_reserves": { "score": 78, "weight": 0.25, "rationale": "$12M Series A — strong runway" },
    "rent_affordability": { "score": 82, "weight": 0.25, "rationale": "Rent burden 4.2% of revenue — comfortable" },
    "profitability_signal": { "score": 60, "weight": 0.20, "rationale": "Private company, no P&L data. Industry benchmark indicates break-even likely." }
  },
  "zauba_data_available": true,
  "zauba_findings": {
    "paid_up_capital": "INR 15,00,00,000",
    "roc_status": "active",
    "last_filing_date": "2025-09-30",
    "registered_address": "Hinjewadi, Pune, MH"
  },
  "rent_burden_ratio": 0.042,
  "est_annual_rent_inr": 25200000,
  "strengths": ["Comfortable rent burden", "Strong funding reserves", "Active RoC compliance"],
  "weaknesses": ["No direct profitability data — reliance on industry benchmark"],
  "rationale": "Company has $30M revenue with $12M in recent funding. Est. rent of INR 2.5Cr/year represents a comfortable 4.2% of revenue. Zauba confirms active status and adequate paid-up capital."
}
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Zauba data unavailable (non-Indian entity) | Use Crunchbase + SEC if available, else industry benchmarks with −20 confidence |
| No funding data | Score funding reserves sub-dimension as 30, flag `funding_data_gap` |
| Revenue estimated (not verified) | Apply −15 confidence to all revenue-based scores |
| Rent burden > 20% | Flag as `rent_burden_critical` — may indicate unsustainable situation |
| Paid-up capital < INR 1Cr | Cap financial score at 50 — insufficient capitalization |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Zauba data availability (Indian cos.) | 82% | > 75% |
| Zauba data availability (all cos.) | 46% | > 40% |
| Avg financial score | 58 | N/A |
| Avg confidence | 0.74 | > 0.70 |
| Processing time | 1.5s per company | < 3s |
