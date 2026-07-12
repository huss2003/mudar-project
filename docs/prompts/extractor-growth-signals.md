# Extractor: Growth Signals
Uses: blog, press releases, news, LinkedIn feed, product changelog

Extract:
- recent_funding (object or null — amount, round, date, investors)
- revenue_growth (enum: high, moderate, flat, declining, null)
- expansion_signals (array of strings, e.g. ["opened new office", "entered new market", "launched new product line"])
- partnerships (array of strings, notable recent partnerships, null)
- acquisition_target (boolean or null — is the company likely being acquired?)
- office_count (integer or null)
- new_markets (array of strings, geographic or vertical markets entered recently, null)
- press_mentions_30d (integer or null — number of news mentions in last 30 days)
- product_launches_90d (integer or null — new products/features launched in last 90 days)
- social_followers (object with linkedin, twitter counts or null)

Schema:
{
  "recent_funding": { "value": { "amount_usd": "number or null", "round": "string or null", "date": "string or null", "investors": [ "string" ] or null } or null, ... },
  "revenue_growth": { "value": "enum or null", ... },
  "expansion_signals": { "value": [ "string" ] or null, ... },
  "partnerships": { "value": [ "string" ] or null, ... },
  "acquisition_target": { "value": "boolean or null", ... },
  "office_count": { "value": "integer or null", ... },
  "new_markets": { "value": [ "string" ] or null, ... },
  "press_mentions_30d": { "value": "integer or null", ... },
  "product_launches_90d": { "value": "integer or null", ... },
  "social_followers": { "value": { "linkedin": "integer or null", "twitter": "integer or null" } or null, ... }
}

Response must be ONLY valid JSON matching schema exactly. No markdown, no code fences, no extra text.
