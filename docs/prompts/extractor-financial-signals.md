# Extractor: Financial Signals
Uses: Crunchbase, PitchBook, SEC filings (EDGAR), news, funding announcements, annual reports

Extract:
- total_funding_usd (integer or null)
- last_round (string or null — e.g. "Series B")
- last_round_date (string or null — ISO date)
- last_round_amount_usd (integer or null)
- investors (array of strings, known investors, null)
- revenue_usd (integer or null — last known revenue)
- revenue_range (string or null — e.g. "$10M-$50M")
- valuation_usd (integer or null)
- valuation_range (string or null — e.g. "$100M-$500M")
- profitability_status (enum: profitable, break-even, unprofitable, null)
- stock_ticker (string or null — if public)
- sec_filings_found (boolean — whether SEC filings exist)
- debt_financing (boolean or null — known debt or loans)
- employees_growth_12m (number or null — % employee growth over 12 months)

Schema:
{
  "total_funding_usd": { "value": "integer or null", ... },
  "last_round": { "value": "string or null", ... },
  "last_round_date": { "value": "string or null", ... },
  "last_round_amount_usd": { "value": "integer or null", ... },
  "investors": { "value": [ "string" ] or null, ... },
  "revenue_usd": { "value": "integer or null", ... },
  "revenue_range": { "value": "string or null", ... },
  "valuation_usd": { "value": "integer or null", ... },
  "valuation_range": { "value": "string or null", ... },
  "profitability_status": { "value": "enum or null", ... },
  "stock_ticker": { "value": "string or null", ... },
  "sec_filings_found": { "value": "boolean", ... },
  "debt_financing": { "value": "boolean or null", ... },
  "employees_growth_12m": { "value": "number or null", ... }
}

Response must be ONLY valid JSON matching schema exactly. No markdown, no code fences, no extra text.
