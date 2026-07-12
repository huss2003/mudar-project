# Explainable Multi-Signal Scoring Engine

> **Version:** 2.0  
> **Status:** Draft  
> **Replaces:** 8-pillar opaque AI scoring  
> **Design Principle:** Every number must be explainable. Every score must cite its evidence.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Signal Groups](#2-signal-groups)
3. [Rule Engine](#3-rule-engine)
4. [AI Interpretation](#4-ai-interpretation)
5. [Multi-Model Validation](#5-multi-model-validation)
6. [Dynamic Weights](#6-dynamic-weights)
7. [Explainable Output](#7-explainable-output)
8. [Confidence Score](#8-confidence-score)
9. [Free Enrichment Integration](#9-free-enrichment-integration)
10. [Learning Engine](#10-learning-engine)
11. [Appendix: Formulas & Algorithms](#11-appendix-formulas--algorithms)

---

## 1. Architecture Overview

```
                        ┌─────────────────────────────────┐
                        │         RAW SIGNAL INPUT          │
                        │  (Free Enrichment + API sources)  │
                        └────────────┬────────────────────┘
                                     │
                                     ▼
                        ┌─────────────────────────────────┐
                        │         EVIDENCE STORE           │
                        │  (deduplicated, timestamped)     │
                        └────────────┬────────────────────┘
                                     │
                            ╭────────▼────────╮
                            │   RULE ENGINE    │
                            │  (deterministic) │
                            ╰────────┬────────╯
                                     │
                            ╭────────▼────────╮
                            │ SIGNAL EXTRACTION│
                            │ (normalize → map │
                            │  to signal group)│
                            ╰────────┬────────╯
                                     │
                            ╭────────▼────────╮
                            │  AI INTERPRET    │
                            │ (scores ONLY what│
                            │  rules cannot)   │
                            ╰────────┬────────╯
                                     │
                            ╭────────▼────────╮
                            │ MULTI-MODEL VAL  │
                            │ (DeepSeek ↔ MiMo)│
                            ╰────────┬────────╯
                                     │
                            ╭────────▼────────╮
                            │ SCORE CALCULATION│
                            │ (weighted sum →  │
                            │  0-100 per group)│
                            ╰────────┬────────╯
                                     │
                            ╭────────▼────────╮
                            │  CONFIDENCE CALC │
                            │ (data quality →  │
                            │  0-100 separate) │
                            ╰────────┬────────╯
                                     │
                            ╭────────▼────────╮
                            │ EXPLANATION GEN  │
                            │ (reason + evidence│
                            │  + source per pt)│
                            ╰────────┬────────╯
                                     │
                                     ▼
                      ┌──────────────────────────┐
                      │   LEAD SCORE + CONFIDENCE  │
                      │   + FULL EXPLANATION       │
                      └──────────────────────────┘
                                     │
                                     ▼
                      ┌──────────────────────────┐
                      │      LEARNING ENGINE       │
                      │ (outcome feedback → weight │
                      │  adjustment, re-calibrate) │
                      └──────────────────────────┘
```

### Pipeline Flow

1. **Evidence Ingestion** — Raw enrichment data enters the evidence store. Deduplication by `(signal_type, source, fingerprint)` with latest-timestamp-wins semantics.
2. **Rule Engine** — Deterministic rules fire first. Every rule produces a `(score, evidence_blob)` pair. Rules are O(1) lookups or simple thresholds.
3. **Signal Extraction** — Normalized signals are mapped to their signal groups. A single evidence item may feed multiple groups (e.g., `hiring_engineer` maps to both *Growth* and *Buying Intent*).
4. **AI Interpretation** — Only signals that lack deterministic rules are sent to the AI model. The AI receives the *evidence only*, never the intermediate score.
5. **Multi-Model Validation** — DeepSeek scores → MiMo agrees → if >5% disagreement, flag for re-evaluation (re-prompt with evidence + disagreement summary).
6. **Score Calculation** — Weighted sum within each group, then weighted sum across groups. All scores are 0–100.
7. **Confidence Calculation** — Independent of lead score. Based on data quality: recency, source reliability, corroboration count, signal completeness.
8. **Explanation Generation** — Every point in the final score includes a human-readable reason + cited evidence + source label + confidence sub-score + weight + contribution delta.
9. **Learning Engine** — As leads progress through the funnel (meeting → proposal → won/lost → revenue), outcome data flows back to adjust group weights and calibrate confidence thresholds.

---

## 2. Signal Groups

The 8 opaque pillars are replaced by 8 weighted signal groups. Each group is a logical cluster of evidence types.

### 2.1 Group Definitions

| # | Group | Default Weight | Description |
|---|-------|---------------|-------------|
| 1 | **Business Legitimacy** | 20% | Verifies the company is real, registered, and trustworthy |
| 2 | **Digital Presence** | 15% | Measures online footprint quality and sophistication |
| 3 | **Growth Indicators** | 15% | Detects positive momentum and expansion |
| 4 | **Pain Indicators** | 10% | Flags problems the company likely needs solved |
| 5 | **Buying Intent** | 15% | Identifies signals that precede a purchase decision |
| 6 | **Technology Compatibility** | 10% | Evaluates tech stack fit with your product |
| 7 | **Evidence Quality** | 5% | Measures reliability of all gathered evidence |
| 8 | **Freshness** | 10% | Decays older signals; rewards recent activity |

**Sum = 100%**

### 2.2 Business Legitimacy

| Signal | Source | Rule/AI | Default Score | Weight in Group |
|--------|--------|---------|---------------|-----------------|
| Domain age | WHOIS | Rule | `min(age_years / 10 * 100, 100)` | 20% |
| HTTPS valid | SSL check | Rule | `100 if valid, 0 if missing` | 15% |
| Email domain match | Enrichment | Rule | `100 if company domain == email domain` | 15% |
| Company registration | Govt registry | Rule | `100 if found, 0 if not` | 20% |
| Verified address | Maps/Geocode | Rule | `100 if geocodable + matches HQ` | 10% |
| Business license | Public records | Rule | `100 if active, 50 if expired, 0 if none` | 10% |
| Negative signals | Court/bankrupt/ sanctions | AI | AI scores 0–100 | 10% |

**Group Score Formula:**

```
Business_Legitimacy = Σ(signal_score_i × weight_i) / Σ(weight_i for present signals)
```

If no signals present → `score = 0, confidence = 0, explanation = "No business legitimacy data available"`

### 2.3 Digital Presence

| Signal | Source | Rule/AI | Default | Weight |
|--------|--------|---------|---------|--------|
| Website pages count | Crawl/API | Rule | `≥1000→100, ≥100→70, ≥10→40, <10→10` | 20% |
| SEO health | Crawl | Rule | `pages_indexed / total_pages * 100` | 15% |
| Mobile responsive | Crawl | Rule | `100 if pass, 0 if fail` | 15% |
| Tech stack detection | Wappalyzer | Rule | `known ? 80 : 20` | 10% |
| Social media presence | API | Rule | `profiles_found / expected_profiles * 100` | 15% |
| Blog active | RSS/API | Rule | `posts_last_90d > 4 → 100, else linear` | 10% |
| Website speed | Crawl | Rule | `LCP < 2.5s → 100, else linear decay` | 10% |
| Design quality | Crawl | AI | `0–100 based on visual/modern assessment` | 5% |

### 2.4 Growth Indicators

| Signal | Source | Rule/AI | Default | Weight |
|--------|--------|---------|---------|--------|
| Hiring volume | Job boards | Rule | `jobs_last_30d / total_employees * 100` | 25% |
| New locations | News/enrich | AI | `100 if confirmed, 50 if rumored, 0 if none` | 15% |
| Product launches | News/PR | AI | `100 if major, 60 if minor, 0 if none` | 20% |
| Funding rounds | Crunchbase | Rule | `Series B+ → 100, A → 80, Seed → 50, None → 0` | 20% |
| Press mentions | News API | Rule | `mentions_last_90d capped at 100` | 10% |
| Revenue growth | Enrichment | Rule | `YoY > 50% → 100, > 20% → 70, > 0% → 40` | 10% |

### 2.5 Pain Indicators

| Signal | Source | Rule/AI | Default | Weight |
|--------|--------|---------|---------|--------|
| Broken links | Crawl | Rule | `broken / total * 100 (inverted)` | 20% |
| Outdated CMS | Tech detect | Rule | `version > 2 major behind → 100 pain` | 15% |
| Missing SSL | SSL check | Rule | `100 pain if missing or expired` | 15% |
| No analytics | Tech detect | Rule | `100 pain if no GA/GTM/Piwik` | 10% |
| No CRM detected | Tech detect | Rule | `100 pain if no Salesforce/HubSpot` | 10% |
| Slow site | Crawl | Rule | `100 pain if LCP > 4s` | 10% |
| Security issues | Crawl | Rule | `CSP missing → 50, mixed content → 75` | 10% |
| Bad UX indicators | Crawl | AI | `0–100 based on popup density, clutter` | 10% |

### 2.6 Buying Intent

| Signal | Source | Rule/AI | Default | Weight |
|--------|--------|---------|---------|--------|
| Hiring for specific roles | Job boards | Rule | `target_role_score × openings` | 25% |
| Physical expansion | News | AI | `100 if confirmed new office/factory` | 15% |
| Platform migration | News/tech | AI | `100 if migrating from competitor` | 20% |
| Tech replacement | Tech detect | Rule | `old_tech_detected + new_tech_recent` | 15% |
| Leadership changes | LinkedIn | Rule | `CTO/CIO hired last 90d → 80` | 15% |
| Budget season signals | Calendar | Rule | `Q3/Q4 procurement cycle → 50` | 10% |

**Scoring Note:** Buying Intent is *asymmetric*. Score 0 does NOT mean "no intent" — it means "no intent detected." The explanation must clarify: *"No buying intent signals were found. This does not confirm absence of intent."*

### 2.7 Technology Compatibility

| Signal | Source | Rule/AI | Default | Weight |
|--------|--------|---------|---------|--------|
| Framework match | Tech detect | Rule | `100 if your_framework, 0 if competitor` | 25% |
| Cloud platform | Tech detect | Rule | `100 if matches your cloud (AWS/Azure/GCP)` | 15% |
| CMS type | Tech detect | Rule | `100 if compatible, 50 if neutral, 0 if incompatible` | 10% |
| CRM in use | Tech detect | Rule | `100 if integrates, 50 if neutral, 0 if competitor` | 15% |
| ERP system | Tech detect | Rule | `100 if integrates, 0 if competitor lock-in` | 10% |
| Language stack | Tech detect | Rule | `100 if your_primary_lang` | 10% |
| API maturity | Tech detect | AI | `0–100 based on REST/GraphQL evidence` | 15% |

### 2.8 Evidence Quality

This group scores the *data itself*, not the lead.

| Signal | Source | Rule/AI | Default | Weight |
|--------|--------|---------|---------|--------|
| Independent confirmations | Dedup | Rule | `min(corroborations / 3 * 100, 100)` | 30% |
| Source reliability avg | Source DB | Rule | `avg(reliability_score) across all sources` | 25% |
| AI confidence variance | Model output | Rule | `100 - (variance × 100 / max_variance)` | 15% |
| Data completeness | Schema | Rule | `fields_present / total_fields * 100` | 15% |
| Contradiction count | Cross-ref | Rule | `100 - (contradictions × 20)` floor 0 | 15% |

### 2.9 Freshness

| Signal | Source | Rule/AI | Default | Weight |
|--------|--------|---------|---------|--------|
| Last data update | Timestamp | Rule | `days_since_update: exp_decay` | 25% |
| Website last updated | Crawl | Rule | `days_since_last_change: exp_decay` | 20% |
| Recent hiring | Job boards | Rule | `hires_last_30d → 100, 90d → 50, >180d → 0` | 20% |
| Recent news | News API | Rule | `articles_last_30d capped at 100` | 15% |
| Social activity | API | Rule | `posts_last_7d > 5 → 100` | 10% |
| Tech last updated | Tech detect | Rule | `framework_versions: recent = high` | 10% |

**Freshness Decay Formula:**

```
freshness_score = base_score × e^(-λ × days_since_event)

Where λ (lambda) is decay rate per signal:
  - Hiring: λ = 0.01 (90 days to half-life)
  - News: λ = 0.02 (35 days to half-life)
  - Tech update: λ = 0.005 (139 days to half-life)
  - Website update: λ = 0.003 (231 days to half-life)
```

---

## 3. Rule Engine

The Rule Engine is a deterministic, zero-AI scoring layer. It fires first and establishes a baseline.

### 3.1 Rule Format

Every rule follows this structure:

```json
{
  "rule_id": "domain_age_001",
  "signal": "domain_age",
  "group": "business_legitimacy",
  "priority": 1,
  "condition": {
    "field": "domain_age_years",
    "operator": "gte",
    "value": 10
  },
  "score": 100,
  "reason": "Domain registered >10 years ago indicates established business",
  "weight_in_group": 0.20
}
```

### 3.2 Operator Types

| Operator | Description | Example |
|----------|-------------|---------|
| `gte` / `lte` | Numeric comparison | `domain_years >= 10` |
| `eq` / `neq` | Exact match | `ssl_valid == true` |
| `in` / `not_in` | Set membership | `industry in ["SaaS", "FinTech"]` |
| `exists` / `missing` | Field presence | `crm_type exists` |
| `regex` | Pattern match | `email matches "^[^@]+@company\.com$"` |
| `age_gt` / `age_lt` | Time since event | `last_ssl_check age_lt 30 days` |
| `linear` | Proportional scoring | `score = min(value / threshold * 100, 100)` |
| `exp_decay` | Exponential decay | `score = 100 × e^(-λ × days)` |

### 3.3 Deterministic Scoring Map

| Condition | Score | Reasoning |
|-----------|-------|-----------|
| Domain age >10yr | 95–100 | Established ≤2015, unlikely throwaway |
| Domain age 5–10yr | 70–94 | Mid-life company |
| Domain age 1–5yr | 30–69 | Young but possibly legitimate |
| Domain age <1yr | 0–29 | High churn/phishing risk |
| HTTPS valid + HSTS | 100 | Modern security posture |
| HTTPS valid only | 75 | Basic security |
| HTTPS expired | 10 | Negligence flag |
| No HTTPS | 0 | Critical red flag |
| Email @company.com | 100 | Matches domain |
| Email @gmail.com | 10 | Likely solo/ghost |
| Company registered >5yr | 100 | Legal entity stability |
| Company registered <1yr | 20 | High volatility |
| Geocodable address | 100 | Physical presence |
| PO Box only | 30 | Virtual operation |

### 3.4 Rule Chaining

Rules can chain: if condition A → score S₁, then condition B → adjust S₁ by delta.

```
domain >= 10yr → score = 95
+ https present → +5
+ company reg found → +0 (already capped)
Final: 100
```

### 3.5 Rule Engine Pseudocode

```
function runRuleEngine(evidence):
  scores_by_group = {}

  for each rule in rules (sorted by priority):
    if rule.condition matches evidence:
      group = rule.group
      scores_by_group[group].append({
        signal: rule.signal,
        score: rule.score,
        reason: rule.reason,
        evidence: matched_evidence,
        weight: rule.weight_in_group
      })

  return scores_by_group
```

---

## 4. AI Interpretation

The AI layer scores **only** what the rule engine cannot. This is a deliberate constraint to keep scoring deterministic where possible and reserve AI for ambiguous signals.

### 4.1 What the AI Scores

| Signal Group | AI-Scored Signals | Why AI Needed |
|-------------|-------------------|---------------|
| Business Legitimacy | Negative signals (reputation, sanctions risk) | Requires semantic understanding of news/court records |
| Digital Presence | Design quality, content quality | Subjective visual assessment |
| Growth Indicators | New locations, product launches | Requires reading press releases/announcements |
| Pain Indicators | Bad UX, confusing navigation | Needs human-like judgment |
| Buying Intent | Platform migration, expansion news | Requires semantic NLP on articles |
| Technology Compatibility | API maturity | Requires evaluating architectural indicators |
| Evidence Quality | (None — fully rule-driven) | |
| Freshness | (None — fully rule-driven) | |

### 4.2 AI Prompt Template

The AI receives a structured prompt containing ONLY the evidence, never previous scores:

```
You are scoring a single signal for a B2B lead scoring engine.

Signal: {signal_name}
Group: {group_name}
Evidence: {evidence_json}

Instructions:
- Score 0–100 where 100 = strongest possible signal
- If evidence is ambiguous, score toward the middle (40–60)
- If evidence is absent, score 0
- Provide a one-sentence reason

Output JSON:
{
  "score": <0–100>,
  "reason": "<one sentence>",
  "confidence": <0–100>,
  "requires_review": <true/false>
}
```

### 4.3 Guardrails

- AI may NEVER output a score >100 or <0
- AI may NEVER refuse to score based on insufficient evidence (score 0 instead)
- AI may NEVER reference scores from other signals or groups
- If `requires_review: true`, the score is flagged for human review and excluded from calculation until reviewed
- AI scores are bounded by the Evidence Quality weight: low-quality evidence suppresses AI score weight

### 4.4 AI Score Suppression

```
if (evidence_quality_group_score < 30):
  ai_weight_multiplier = evidence_quality_group_score / 100
  ai_contribution = ai_raw_score × ai_weight_multiplier
else:
  ai_contribution = ai_raw_score
```

---

## 5. Multi-Model Validation

Two models are used: **DeepSeek** (primary) and **MiMo** (validator).

### 5.1 Validation Flow

```
DeepSeek scores signal → score_ds
MiMo scores same signal (blind) → score_mm

if |score_ds - score_mm| <= 5:
  # Agreement — use average
  final_score = (score_ds + score_mm) / 2

elif |score_ds - score_mm| <= 20:
  # Moderate disagreement — use weighted average
  confidence_ds = DeepSeek confidence
  confidence_mm = MiMo confidence
  total_conf = confidence_ds + confidence_mm
  final_score = (score_ds × confidence_ds + score_mm × confidence_mm) / total_conf
  flag = "partial_disagreement"

else:
  # Significant disagreement — re-evaluate
  re_prompt with:
    - Original evidence
    - Both scores and reasons
    - Instruction: "These models disagree. Analyze the evidence again
      and explain which score is more accurate and why."
  Run both models again with the expanded prompt
  If still >20 apart → flag for human review, exclude from calculation
```

### 5.2 Model Routing

| Scenario | Models Used | Rationale |
|----------|-------------|-----------|
| All signals available | DeepSeek + MiMo | Full validation |
| One model unavailable | Single model | Fallback |
| Cost-sensitive mode | DeepSeek only, MiMo on >70 or <30 signals | Optimize cost |
| Batch scoring | DeepSeek primary, MiMo samples 10% | Statistical validation |

### 5.3 Agreement Metrics

```
agreement_rate = agreeing_scores / total_scores  # Target: >90%
mean_disagreement = avg(|score_ds - score_mm|)   # Target: <5 points
```

These metrics are logged and reported to the Learning Engine.

---

## 6. Dynamic Weights

Weights are not static. They evolve based on:
- **Industry vertical** (SaaS weights differ from Manufacturing)
- **Country/region** (Emerging markets weight Legitimacy higher)
- **Company size** (Enterprise weights Compatibility higher)
- **Historical outcome data** (Learning Engine feedback)

### 6.1 Weight Sources

```json
{
  "default": {
    "business_legitimacy": 0.20,
    "digital_presence": 0.15,
    "growth_indicators": 0.15,
    "pain_indicators": 0.10,
    "buying_intent": 0.15,
    "technology_compatibility": 0.10,
    "evidence_quality": 0.05,
    "freshness": 0.10
  },
  "overrides": {
    "industry": {
      "SaaS": {
        "technology_compatibility": 0.20,
        "digital_presence": 0.20
      },
      "Manufacturing": {
        "business_legitimacy": 0.30,
        "digital_presence": 0.05
      }
    },
    "country": {
      "Nigeria": {
        "business_legitimacy": 0.35,
        "evidence_quality": 0.10
      },
      "Germany": {
        "business_legitimacy": 0.10,
        "digital_presence": 0.20
      }
    },
    "size": {
      "1-10": {
        "digital_presence": 0.25,
        "growth_indicators": 0.05
      },
      "1000+": {
        "growth_indicators": 0.25,
        "technology_compatibility": 0.15
      }
    }
  }
}
```

### 6.2 Weight Resolution Order

1. Start with **default** weights
2. Apply **industry** overrides (additive delta)
3. Apply **country** overrides (additive delta)
4. Apply **size** overrides (additive delta)
5. Apply **learning engine** adjustments (multiplicative)
6. Normalize so Σ = 100%

### 6.3 Normalization

After all overrides and adjustments:

```
w_i' = w_i / Σ(w_j)   for all j in groups
```

---

## 7. Explainable Output

Every score produced by the engine includes a full explanation chain.

### 7.1 Output Structure

```json
{
  "lead_id": "abc-123",
  "overall_score": 73,
  "overall_confidence": 68,
  "timestamp": "2026-07-12T14:30:00Z",
  "model_version": "2.0.0",

  "groups": {
    "business_legitimacy": {
      "score": 85,
      "weight": 0.20,
      "contribution": 17.0,
      "confidence": 90,
      "signals": [
        {
          "signal": "domain_age",
          "score": 95,
          "weight_in_group": 0.20,
          "contribution": 19.0,
          "reason": "Domain registered 14 years ago (>10yr threshold)",
          "evidence": "WHOIS record shows creation_date=2012-03-15",
          "source": "whois.domaintools.com",
          "source_reliability": 90,
          "scored_by": "rule",
          "rule_id": "domain_age_001"
        },
        {
          "signal": "https_valid",
          "score": 100,
          "weight_in_group": 0.15,
          "contribution": 15.0,
          "reason": "Valid HTTPS certificate with HSTS enabled",
          "evidence": "SSL cert valid until 2027-01-20, HSTS header present",
          "source": "ssl_checker.local",
          "source_reliability": 95,
          "scored_by": "rule",
          "rule_id": "https_001"
        }
      ]
    }
  },

  "explanations": {
    "summary": "Lead scores 73/100 with 68/100 confidence. Strong Business Legitimacy (85) anchored by 14yr domain and valid HTTPS. Growth Indicators (60) driven by recent hiring (+12 engineers). Buying Intent low (20) — no intent signals detected, not absence confirmed.",
    "top_factors": [
      "Domain age >10yr (+19pts to Business Legitimacy)",
      "Valid HTTPS (+15pts to Business Legitimacy)",
      "Recent hiring surge (+25pts to Growth Indicators)",
      "No CRM detected (+10pts to Pain Indicators)"
    ],
    "concerns": [
      "Website last crawled 45 days ago (Freshness decay: -8pts)",
      "Buying Intent has no signals — may need outbound enrichment"
    ],
    "next_steps": [
      "Verify email deliverability before outreach",
      "Research if they're evaluating competitors"
    ]
  }
}
```

### 7.2 Contribution Calculation

```
signal_contribution = signal_score × signal_weight_in_group × group_weight
group_contribution = group_score × group_weight
overall_score = Σ(group_contribution) for all groups
```

### 7.3 Explanation Generation

Explanations are generated by templates, not AI:

- **Positive outlier:** `"{signal}" scored high ({score}) because {reason}`
- **Negative outlier:** `"{signal}" scored low ({score}) due to {reason}`
- **Missing data:** `"No {signal} data available — confidence reduced by {delta}"`
- **Top factor:** `"{signal} ({delta}pts to {group})"`

AI-generated explanations are used only for AI-scored signals, and only to restate the AI's reasoning in business terms.

---

## 8. Confidence Score

Confidence is **independent** from the lead score. A lead can score 90 with 42 confidence — "looks promising, but verify everything."

### 8.1 Confidence Components

| Factor | Weight | Description |
|--------|--------|-------------|
| Data freshness | 25% | How recent is the data? Uses freshness decay |
| Source reliability | 25% | Average reliability of all sources used |
| Corroboration | 20% | How many independent sources agree? |
| Coverage | 15% | What % of signal groups have data? |
| AI agreement | 10% | DeepSeek ↔ MiMo agreement level |
| Signal completeness | 5% | Within each group, what % of signals are populated? |

### 8.2 Source Reliability Ratings

| Source Type | Reliability Score |
|-------------|------------------|
| Government registry | 100 |
| Official API (LinkedIn, Crunchbase) | 90 |
| Direct crawl (website, SSL) | 85 |
| Established data provider (Clearbit, ZoomInfo) | 75 |
| News API (aggregated) | 60 |
| Social media scrape | 40 |
| User-provided | 30 |
| AI-inferred | 25 |

### 8.3 Confidence Formula

```
confidence = Σ(factor_score_i × factor_weight_i)

Where each factor_score is 0–100:
  - freshness_factor: avg freshness across all signals
  - reliability_factor: weighted avg of source_reliability
  - corroboration_factor: min(corroborated_signals / total_signals / 0.3, 1) × 100
  - coverage_factor: groups_with_data / total_groups × 100
  - ai_agreement_factor: 100 - mean_disagreement
  - completeness_factor: populated_signals / expected_signals × 100
```

### 8.4 Confidence Bands

| Confidence | Label | Meaning |
|------------|-------|---------|
| 80–100 | High | Data is fresh, corroborated, from reliable sources |
| 50–79 | Medium | Reasonable confidence, some gaps |
| 20–49 | Low | Significant gaps — verify key signals manually |
| 0–19 | Insufficient | Very little data — consider this an exploratory lead |

---

## 9. Free Enrichment Integration

The scoring engine must work even with zero-cost enrichment sources.

### 9.1 Free Signal Sources

| Source | Signals | Cost |
|--------|---------|------|
| WHOIS | Domain age, registrar | Free |
| SSL check | HTTPS validity, issuer, expiry | Free |
| Website crawl | Pages, speed, mobile, tech stack, SEO | Free (rate-limited) |
| DNS records | MX, SPF, DMARC | Free |
| Google cache | Last crawl date, index count | Free |
| LinkedIn (public) | Employee count, hiring, leadership | Free (scraped) |
| RSS feeds | Blog activity, press mentions | Free |
| GitHub API | Tech stack, activity, repos | Free (rate-limited) |
| BuiltWith (free tier) | Tech stack partial | Free |
| Wappalyzer (free) | Tech stack detection | Free |
| News API (free tier) | Press mentions | Free (100 req/day) |
| Crunchbase (free) | Funding, founded date | Free |

### 9.2 Scoring Without Paid Data

If only free enrichment is available:

| Group | Free Coverage | Max Score | Confidence Cap |
|-------|--------------|-----------|----------------|
| Business Legitimacy | Domain, HTTPS, email | 100 | 60 (no registration check) |
| Digital Presence | Crawl, social | 95 | 70 |
| Growth Indicators | Job boards, news | 70 | 50 (no funding data) |
| Pain Indicators | Crawl | 100 | 75 |
| Buying Intent | Limited (tech detect only) | 40 | 30 |
| Technology Compatibility | Wappalyzer | 80 | 60 |
| Evidence Quality | All free | 100 | 100 |
| Freshness | All free | 100 | 80 |

**Free-tier overall confidence cap: 65** — The engine tags the lead as "exploratory" and recommends paid enrichment before high-touch outreach.

### 9.3 Paid Upgrade Recommendations

When the engine detects a lead that would benefit from paid enrichment:

```json
{
  "recommend_enrichment": true,
  "reason": "Buying Intent confidence capped at 30 — funding and news API data would unlock full scoring",
  "recommended_sources": ["Crunchbase Pro", "Zoominfo", "SimilarWeb"],
  "estimated_score_improvement": "+15 points"
}
```

---

## 10. Learning Engine

The Learning Engine closes the loop: outcomes feed back to improve scoring.

### 10.1 Feedback Pipeline

```
Lead scored → Sales action taken → Outcome recorded → Weight adjustment
                           ↓
                   Abandoned/No response → Signal weights for that profile reduce
                   Meeting booked → Signal weights for that profile increase
                   Proposal sent → Signal weights for converting leads increase
                   Won → Revenue-weighted positive reinforcement
                   Lost → Signal weights for false positives reduce
```

### 10.2 Weight Adjustment Algorithm

```
for each group g:
  for each lead i in outcome_window:
    if outcome_i == "won":
      correct_classifications += weight_contribution_of_g > threshold
      false_positives += weight_contribution_of_g > threshold (for lost)

  adjustment_delta = (won_rate_g - overall_won_rate) × learning_rate

  w_g_new = w_g × (1 + adjustment_delta)

Normalize after adjustment
```

**Example:** If the *Pain Indicators* group has a 40% win rate vs a 25% overall win rate, its weight increases:

```
adjustment_delta = (0.40 - 0.25) × 0.1 = 0.015
w_new = 0.10 × 1.015 = 0.1015
```

### 10.3 Learning Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `learning_rate` | 0.1 | How aggressively weights adjust per cycle |
| `outcome_window` | 90 days | How far back to look for outcomes |
| `min_outcomes_for_adjustment` | 30 | Minimum data points before any adjustment |
| `max_adjustment_per_cycle` | 0.05 | Cap on any single weight change |
| `cooldown_days` | 7 | Minimum time between weight recalibrations |

### 10.4 Revenue-Weighted Learning

Not all wins are equal. A $50k deal counts more than a $5k deal.

```
revenue_weight = deal_revenue / median_deal_revenue
weighted_outcome_score = base_outcome × revenue_weight
```

### 10.5 Confidence Calibration

As outcomes accumulate, the engine recalibrates confidence:

```
optimal_confidence = actual_hit_rate_at_score_band

If leads scored 70–80 convert at 60% but engine confidence was 85:
  → Confidence calibration adjusts: score 70–80 → confidence 60
```

---

## 11. Appendix: Formulas & Algorithms

### 11.1 Overall Score

```
S = Σ(g_i × w_i)  for i = 1..8

Where:
  S = overall score (0–100)
  g_i = group i score (0–100)
  w_i = group i weight (Σw = 1.0)
```

### 11.2 Group Score

```
g = Σ(s_j × wg_j)  for j = 1..n

Where:
  g = group score
  s_j = signal j score (0–100)
  wg_j = signal j weight within group (Σwg = 1.0)
  n = number of signals present in group
```

If `n = 0` (no signals in group):
```
g = 0
confidence_penalty += w_i × 0.5
explanation = "No {group} data available"
```

### 11.3 Freshness Decay

```
fresh(t) = s_0 × exp(-λ × t)

Where:
  s_0 = original signal score
  t = days since signal was captured
  λ = decay constant (signal-specific)
  half_life = ln(2) / λ
```

### 11.4 Linear Threshold Score

```
linear_score(value, min, max) = {
  value <= min → 0
  value >= max → 100
  else → (value - min) / (max - min) × 100
}
```

### 11.5 Inverted Score (for Pain Indicators)

```
inverted(value, min, max) = 100 - linear_score(value, min, max)
```

### 11.6 Corroboration Score

```
corroboration(signal) = min(independent_sources / 3, 1) × 100

Where 3 is the "confidence threshold" — 3 independent sources
provide maximum corroboration.
```

### 11.7 Agreement Rate

```
agreement_rate = |A - B| disagreement
score_confidence = 100 - min(disagreement, 100)
```

### 11.8 Weighted Contribution

```
signal_contribution = s_j × wg_j × w_i
group_contribution = g × w_i

This means: group_score × group_weight tells you how many points
that group contributed to the final 100-point total.
```

### 11.9 Example Calculation

**Lead Profile:**

| Group | Score | Weight | Contribution |
|-------|-------|--------|-------------|
| Business Legitimacy | 90 | 0.20 | 18.0 |
| Digital Presence | 70 | 0.15 | 10.5 |
| Growth Indicators | 60 | 0.15 | 9.0 |
| Pain Indicators | 40 | 0.10 | 4.0 |
| Buying Intent | 20 | 0.15 | 3.0 |
| Technology Compatibility | 85 | 0.10 | 8.5 |
| Evidence Quality | 75 | 0.05 | 3.75 |
| Freshness | 65 | 0.10 | 6.5 |

**Overall Score:** 18.0 + 10.5 + 9.0 + 4.0 + 3.0 + 8.5 + 3.75 + 6.5 = **63.25**

**Confidence:**

| Factor | Score | Weight | Contribution |
|--------|-------|--------|-------------|
| Data freshness | 70 | 0.25 | 17.5 |
| Source reliability | 80 | 0.25 | 20.0 |
| Corroboration | 60 | 0.20 | 12.0 |
| Coverage | 75 | 0.15 | 11.25 |
| AI agreement | 85 | 0.10 | 8.5 |
| Signal completeness | 65 | 0.05 | 3.25 |

**Overall Confidence:** 17.5 + 20.0 + 12.0 + 11.25 + 8.5 + 3.25 = **72.5**

**Interpretation:** Lead scores 63/100 with 73/100 confidence. Moderate-fit lead with strong legitimacy and tech compatibility but low buying intent. Confidence is adequate to act.

---

*End of Document — Explainable Multi-Signal Scoring Engine v2.0*
