# Evidence Agent

> **Pillar 8 — Rates evidence quality per claim. Star rating system (1–5). Source strength evaluation. Weight: 5%.**

---

## Purpose

The Evidence Agent evaluates the quality and reliability of every data point used by the other 7 scoring agents. It assigns a star rating (1–5) to each claim based on source authority, verification status, recency, and directness. This pillar does not score the company itself — it scores the *confidence the system can have in the data about the company*. A lead with perfect scores across all pillars but low evidence quality should be treated as speculative, not actionable.

This agent serves as an integrity check across the entire scoring system. Its score modulates the confidence of every other pillar: when evidence quality is low, the system automatically discounts the scores from other agents.

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

## Star Rating System

Each evidence claim receives a rating from 1 to 5 stars:

| Stars | Label | Definition | Examples |
|-------|-------|------------|----------|
| ★★★★★ | **Verified** | 2+ independent primary sources agree | SEC filing + company website both confirm revenue |
| ★★★★☆ | **Strong** | 1 primary source + 1 secondary agree | LinkedIn + Crunchbase both confirm headcount |
| ★★★☆☆ | **Plausible** | 1 primary source only, or 2 secondary | Company website claims revenue range |
| ★★☆☆☆ | **Weak** | 1 secondary or inferred source | Industry average used, no direct data |
| ★☆☆☆☆ | **Unsupported** | No verifiable source, or sources contradict | Speculative inference, contradictory reports |

---

## Source Strength Definitions

| Source Type | Authority Score | Examples | Recency |
|-------------|----------------|----------|---------|
| **Primary** | 1.0 | SEC filing, RoC filing, company website, official press release | Apply recency decay |
| **Secondary** | 0.7 | Crunchbase, LinkedIn, credible news, industry report | Apply recency decay |
| **Inferred** | 0.3 | Industry average, statistical inference, competitor comparison | No decay (always stale) |
| **Unknown** | 0.1 | Anonymous source, hearsay, unverifiable claim | Not usable |

---

## Scoring Rubric

| Sub-dimension | Weight | 0–20 | 21–40 | 41–60 | 61–80 | 81–100 |
|--------------|--------|-------|-------|-------|-------|--------|
| **Source Coverage** | 30% | < 20% fields covered | 20–40% | 40–60% | 60–80% | 80–100% of fields sourced |
| **Source Authority** | 25% | All inferred | Mostly secondary | Balanced | Mostly primary | All primary sources |
| **Verification Rate** | 25% | < 30% fields verified | 30–50% | 50–70% | 70–85% | 85–100% verified |
| **Data Freshness** | 20% | All > 2 years old | Mixed old/current | Most < 1 year | Most < 6 months | All < 3 months |

---

## Per-Claim Evidence Scoring

The agent evaluates each material claim individually:

```
claim: "revenue = $30M"
  source_1: Crunchbase (secondary, published 2025-11) → weight: 0.7, recency: 0.9
  source_2: Company website (primary, published 2026-01) → weight: 1.0, recency: 1.0
  verification: 2 sources agree → multiplier: 1.0
  evidence_score = 0.85 → ★★★★☆
```

---

## Output

```json
{
  "agent": "evidence-agent",
  "company_id": "uuid",
  "pillar": 8,
  "weight": 0.05,
  "score": 78,
  "confidence": 0.92,
  "evidence_summary": {
    "total_claims": 24,
    "claims_verified": 18,
    "claims_plausible": 4,
    "claims_weak": 2,
    "claims_unsupported": 0
  },
  "star_breakdown": {
    "5star_verified": 12,
    "4star_strong": 6,
    "3star_plausible": 4,
    "2star_weak": 2,
    "1star_unsupported": 0
  },
  "sub_dimensions": {
    "source_coverage": { "score": 85, "weight": 0.30, "rationale": "22 of 24 fields have at least 1 source" },
    "source_authority": { "score": 82, "weight": 0.25, "rationale": "Mix of primary (website, filings) and secondary (Crunchbase)" },
    "verification_rate": { "score": 75, "weight": 0.25, "rationale": "18 of 24 fields have 2+ sources agreeing" },
    "data_freshness": { "score": 70, "weight": 0.20, "rationale": "Most sources are 6-12 months old" }
  },
  "weak_claims": [
    {
      "claim": "revenue_band",
      "stars": 3,
      "issue": "Only 1 source (company website), no secondary verification"
    },
    {
      "claim": "est_current_lease_age",
      "stars": 2,
      "issue": "Inferred from company age — no explicit lease date found"
    }
  ],
  "evidence_quality_label": "strong",
  "modifier_on_other_pillars": 0.90,
  "rationale": "Evidence quality is strong overall. 75% of claims are verified by 2+ sources. Two weak claims identified but they are non-critical (revenue band is approximable, lease age impact is marginal). Other pillar scores should be modulated by 0.90x for confidence."
}
```

---

## Evidence Quality Modifier

The Evidence Agent produces a `modifier_on_other_pillars` value (0.0–1.0) that is applied to the confidence of all other pillars:

| Agent Evidence Score | Modifier | Impact |
|--------------------|----------|--------|
| 85–100 | 1.0 | No modulation — evidence is excellent |
| 70–84 | 0.90 | Slight discount — some weak claims |
| 50–69 | 0.75 | Moderate discount — significant uncertainty |
| 30–49 | 0.50 | Heavy discount — most claims unverified |
| 0–29 | 0.25 | Severe discount — evidence unreliable |

This modifier is applied by the Consensus Agent when computing the final weighted score.

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| All sources from single provider (e.g., only Crunchbase) | Cap evidence score at 50, mark `single_source_dependency` |
| Multiple contradictory sources | Score the disputed field at 2 stars, log contradiction |
| Data older than 2 years | Score freshness sub-dimension at 30, flag `stale_data` |
| Company with no public presence | Evidence score defaults to 20, flag `no_public_data` |
| All fields inferred (no direct data) | Score capped at 30, recommend excluding from high-confidence path |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Avg evidence score | 71 | > 65 |
| Avg modifier on other pillars | 0.88 | > 0.80 |
| Weak claims per company (avg) | 3.2 | < 4 |
| Processing time | 1.0s per company | < 3s |
