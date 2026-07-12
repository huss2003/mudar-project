# Extractor: Products & Services
Uses: homepage, product pages, pricing page, case studies

Extract:
- main_product_category (string, what they primarily sell)
- products (array of objects, each with name + description)
- pricing_model (enum: subscription, usage-based, one-time, freemium, free, null)
- pricing_tiers (array of strings, list of plan names, null)
- price_range (object with min/max USD per month, null)
- target_customer (string, who they sell to, null)
- unique_selling_points (array of strings, null)

Schema:
{
  "main_product_category": { "value": "string or null", ... },
  "products": { "value": [ { "name": "string", "description": "string or null" } ] or null, ... },
  "pricing_model": { "value": "enum or null", ... },
  "pricing_tiers": { "value": [ "string" ] or null, ... },
  "price_range": { "value": { "min_usd_monthly": "number or null", "max_usd_monthly": "number or null" } or null, ... },
  "target_customer": { "value": "string or null", ... },
  "unique_selling_points": { "value": [ "string" ] or null, ... }
}

Response must be ONLY valid JSON matching schema exactly. No markdown, no code fences, no extra text.
