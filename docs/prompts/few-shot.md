# Few-Shot Examples

This document contains the few-shot examples used in prompts across the Jasfo Lead Intelligence Platform. Each agent type has at least one complete example showing expected input, reasoning process, and output.

---

## Discovery Agent — One Example

### Input

```json
{
  "company_name": "Stripe",
  "domain": "stripe.com",
  "depth": "standard",
  "industry": "Fintech",
  "crawl_data": {
    "website_markdown": "# Stripe\n\nStripe is a technology company that builds economic infrastructure for the internet. Businesses of every size — from new startups to public companies — use Stripe's software to accept payments and manage their operations online.",
    "search_results": [
      {
        "title": "Stripe — Payment Processing Platform",
        "url": "https://stripe.com",
        "snippet": "Stripe is a payment processing platform for online businesses."
      }
    ]
  }
}
```

### Expected Reasoning

```
1. Extract company name and domain from input
2. Identify founding year from website content (2010, noted in footer)
3. Identify headquarters from About page (South San Francisco, CA)
4. Extract product lines from navigation: Payments, Connect, Atlas, Billing, etc.
5. Note pricing is usage-based, publicly listed at Stripe.com/pricing
6. Search results provide additional context about investors and valuation
7. Technology stack inferred from developer documentation (API-first, REST)
8. Leadership team found via About/Leadership page
```

### Expected Output (truncated)

```json
{
  "identity": {
    "name": "Stripe",
    "domain": "stripe.com",
    "founding_year": 2010,
    "headquarters": { "city": "South San Francisco", "state": "CA", "country": "US" },
    "company_type": "private",
    "employee_count": { "range": "5001-10000", "confidence": 0.9 },
    "social_links": {
      "linkedin": "https://linkedin.com/company/stripe",
      "crunchbase": "https://crunchbase.com/organization/stripe"
    }
  },
  "products": [
    {
      "name": "Stripe Payments",
      "description": "Online payment processing for internet businesses",
      "pricing_model": "usage-based",
      "confidence": 0.95
    }
  ],
  "funding": {
    "total_raised": 2200000000,
    "rounds": [
      {
        "date": "2021-03-14",
        "round_type": "Series H",
        "amount": 600000000,
        "investors": ["Allianz", "AXA", "Fidelity"],
        "valuation": 95000000000,
        "confidence": 0.9
      }
    ],
    "confidence": 0.9
  },
  "metadata": {
    "completeness_score": 0.85,
    "sources_used": ["https://stripe.com", "https://crunchbase.com/organization/stripe"]
  }
}
```

---

## Scoring Agent — One Example

### Input

```json
{
  "company_name": "Stripe",
  "domain": "stripe.com",
  "company_data": {
    "identity": { "name": "Stripe", "founding_year": 2010, "company_type": "private" },
    "products": [{ "name": "Stripe Payments", "description": "Online payment processing" }],
    "funding": { "total_raised": 2200000000, "confidence": 0.9 },
    "technology_stack": { "categories": [{ "name": "Payments", "technologies": [{ "name": "Stripe API", "confidence": 0.95 }] }] }
  }
}
```

### Expected Reasoning

```
Product Fit (85/100):
Stripe's payment processing directly serves the fintech/payments sector.
Their API-first approach aligns with our ideal customer profile of
developer-centric companies. Justification: Product is the market leader
in online payments with broad vertical applicability.

ICP Alignment (90/100):
Stripe serves businesses of all sizes but their core ICP is
internet-first companies, which matches our target segment.
Justification: B2B, internet-native, scaling rapidly.

Technology Fit (75/100):
Their technology is API-based with broad integration capabilities.
Our platform integrates with Stripe via webhooks, making integration
straightforward. Justification: Native integration available.

Funding Health (95/100):
$2.2B raised across Series A-H with $95B valuation.
Investors include top-tier firms. Very well capitalized.
Justification: Exceptional funding history with blue-chip investors.

Growth Signal (80/100):
Consistent product expansion (Atlas, Connect, Billing).
Hiring across engineering, sales, and support globally.
Justification: Active hiring and expanding product surface.

Intent Signal (40/100):
Low direct buying intent — well-established company.
Industry movement toward payment modernization is a positive signal.
Justification: Established player; limited short-term buying intent.

Competitive Moat (90/100):
Network effects: more merchants → more data → better products.
Developer loyalty and ecosystem lock-in. High switching costs.
Justification: Strong moat through developer ecosystem.

Relationship (30/100):
No existing warm relationships in our network.
Justification: Relationship score is low.
```

### Expected Output

```json
{
  "company_name": "Stripe",
  "domain": "stripe.com",
  "pillars": [
    { "name": "Product Fit", "score": 85, "weight": 0.125, "justification": "Market-leading payment platform for internet businesses", "data_available": true },
    { "name": "ICP Alignment", "score": 90, "weight": 0.125, "justification": "B2B, internet-first company, scaling rapidly", "data_available": true },
    { "name": "Technology Fit", "score": 75, "weight": 0.125, "justification": "API-based platform with native integration support", "data_available": true },
    { "name": "Funding Health", "score": 95, "weight": 0.125, "justification": "$2.2B raised, $95B valuation, blue-chip investors", "data_available": true },
    { "name": "Growth Signal", "score": 80, "weight": 0.125, "justification": "Expanding products and hiring globally", "data_available": true },
    { "name": "Intent Signal", "score": 40, "weight": 0.125, "justification": "Established player, limited short-term buying intent", "data_available": true },
    { "name": "Competitive Moat", "score": 90, "weight": 0.125, "justification": "Strong network effects and developer ecosystem", "data_available": true },
    { "name": "Relationship", "score": 30, "weight": 0.125, "justification": "No existing warm connections", "data_available": true }
  ],
  "composite": { "raw_score": 73.125, "rounded_score": 73, "confidence": "Medium" },
  "risk_factors": [
    { "description": "No warm relationships available for introduction", "severity": "Medium", "affected_pillars": ["Relationship"] },
    { "description": "Low intent signal for a well-established company", "severity": "Low", "affected_pillars": ["Intent Signal"] }
  ],
  "scored_at": "2026-07-11T10:30:00Z",
  "scoring_model": "8-pillar-v2"
}
```

---

## Export Agent — One Example

### Input

```json
{
  "company_name": "Stripe",
  "format": "telegram",
  "channel": "telegram",
  "score_card": { "composite": { "rounded_score": 73 } },
  "full_report": { "company_name": "Stripe", "domain": "stripe.com", "scorecard": { "composite": { "rounded_score": 73 } } }
}
```

### Expected Output

```
📊 *Stripe Intelligence Report*
*Score: 73/100 — Strong Lead*
━━━━━━━━━━━━━━━━━━━

*Company Overview*
• Domain: stripe.com
• Founded: 2010
• HQ: South San Francisco, CA
• Type: Private

*Score Breakdown*
Product Fit: 85/100
ICP Alignment: 90/100
Technology Fit: 75/100
Funding Health: 95/100
Growth Signal: 80/100
Intent Signal: 40/100
Competitive Moat: 90/100
Relationship: 30/100

*Key Findings*
• Market-leading payment platform
• $2.2B raised, $95B valuation
• Strong network effects moat
• No warm connections available

*Risk Factors*
• Low intent signal (established company)
• No existing relationships

*Generated:* 2026-07-11T10:30:00Z
```

---

## Best Practices for Few-Shot Design

1. **Real companies, real data**: All examples use actual company data. Never use fictional companies in few-shot prompts.
2. **One per agent type**: Each agent type has exactly one fully worked example. Additional edge-case examples are in separate guidance.
3. **Reasoning before output**: The reasoning section shows the agent *how* to think, not just *what* to output.
4. **Schema-accurate outputs**: Examples must match the schema definitions in `json-schema.md` exactly.
5. **Self-contained**: Each example includes input, reasoning, and output in a single block for easy reference.

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial release with Discovery, Scoring, Export examples |
| 1.1.0 | 2026-07-10 | Updated scoring example with new 8-pillar weights format |
