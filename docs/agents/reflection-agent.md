# Reflection Agent

> **Layer 3 — Self-critique pass after consensus. Reviews reasoning for weak spots. Adjusts scores if evidence insufficient.**

---

## Purpose

The Reflection Agent performs a structured self-critique after the Consensus Agent has produced an aggregate score. While the Consensus Agent reconciles *differences between* agents, the Reflection Agent checks for *shared blind spots* — patterns where all agents might be confidently wrong because they all relied on the same weak source, made the same logical error, or missed a critical signal.

Reflection forces the system to re-examine its own reasoning before the expensive Judge review. It catches overconfidence, stale data dependencies, and inference chains that are longer than justified. The output is an adjusted set of pillar scores and a flux measurement that indicates how much the system changed its own mind.

---

## Model

| Property | Value |
|----------|-------|
| **Model** | MiMo V2.5 |
| **Provider** | OpenRouter |
| **Cost (input)** | $2.00/1M tokens |
| **Cost (output)** | $8.00/1M tokens |
| **Avg tokens per company** | 2,300 |
| **Cost per company** | ~$0.0076 |
| **Avg latency** | 6.5 seconds |

---

## Reflection Prompt Structure

Each pillar agent's score is reviewed using a structured reflection prompt:

```
Agent [NAME] scored [LEAD_ID] on Pillar [N] with score [SCORE].
Evidence summary: [EVIDENCE]

Reflect on your assessment:

1. EVIDENCE QUALITY: Was the source authoritative, current, and directly relevant?
   - If not, how much should the score be reduced?

2. REASONING GAPS: Did you make any unsupported leaps?
   - Identify each inference that lacked direct evidence.

3. CONTRADICTIONS: Does any other agent's evidence contradict yours?
   - If so, which is more reliable and why?

4. CONFIDENCE: What is your adjusted confidence (0–100) after reflection?

5. SCORE DELTA: By how many points should your score change?
   (Negative, zero, or positive — integer between −30 and +10)
```

---

## Adjustment Rules

| Condition | Adjustment |
|-----------|------------|
| All sources primary (official filings, direct statements) | No adjustment |
| Mix of primary and secondary sources | −5 to −10 confidence |
| Secondary sources only | −15 to −25 confidence |
| Single source of any type | −20 confidence |
| Source date > 6 months old | Additional −10 confidence |
| Source date > 12 months old | Additional −20 confidence |
| Contradiction with stronger evidence | Adopt stronger position |
| Contradiction with equal evidence | Split the difference |
| Agent used industry average instead of actual data | −15 score, −20 confidence |
| Agent found NEW evidence missed initially | +5 to +10 score (rare) |

---

## Self-Critique Categories

| Category | Trigger | Typical Delta |
|----------|---------|---------------|
| Weak source | Single source, unknown domain, no date | −20 to −40 confidence |
| Outdated data | Source > 6 months old | −10 to −20 confidence |
| Correlation error | Claim implies causation without evidence | −15 score, flag |
| Missing context | Agent lacked micromarket/industry context | −10 score, −15 confidence |
| Conflicting evidence | Another agent has stronger counter-evidence | Reconcile or −10 |
| Overconfidence | Confidence > 90 but evidence is secondary | −15 confidence |
| False precision | Score given to exact integer when data is approximate | −5 confidence |

---

## Flux Measurement

The Reflection Agent measures "flux" — the total amount of score change across all 8 pillars:

```
flux = Σ(|original_score_i − adjusted_score_i|) / 8
```

| Flux Range | Classification | Meaning |
|-----------|----------------|---------|
| < 2 points | Low flux | System is confident in its assessment |
| 2–5 points | Medium flux | Some adjustments made, standard condition |
| 5–10 points | High flux | Significant self-correction — flag for human review |
| > 10 points | Critical flux | System fundamentally changed its mind — review mandatory |

---

## Output

```json
{
  "agent": "reflection-agent",
  "company_id": "uuid",
  "pre_reflection_score": 69.3,
  "post_reflection_score": 66.8,
  "flux": 2.5,
  "flux_classification": "medium",
  "pillar_adjustments": [
    {
      "pillar": 4,
      "name": "financial",
      "original_score": 72,
      "adjusted_score": 65,
      "delta": -7,
      "reason": "Revenue figure is from company website (primary but self-reported) — no secondary verification. Rent burden calculation uses estimated rather than actual revenue."
    },
    {
      "pillar": 2,
      "name": "move_intent",
      "original_score": 74,
      "adjusted_score": 72,
      "delta": -2,
      "reason": "Lease age is inferred, not directly sourced. Small adjustment warranted."
    }
  ],
  "weak_evidence_found": [
    {
      "claim": "revenue_band = $20M-$50M",
      "source": "company website (self-reported)",
      "issue": "single source, self-reported, no secondary verification",
      "severity": "medium"
    },
    {
      "claim": "lease_age = 48 months",
      "source": "inferred from company age",
      "issue": "indirect inference, no direct source",
      "severity": "low"
    }
  ],
  "reasoning_gaps": [
    "Move intent score partially relies on lease age inference which has low confidence",
    "Financial score may be inflated because self-reported revenue is not verified"
  ],
  "strengthened_claims": [],
  "rationale": "Reflection identified two areas for adjustment. Financial agent's revenue data lacks secondary verification — score reduced by 7 points. Move intent agent used inferred lease age — minor 2-point reduction. Total flux of 2.5 is within normal range. No critical blind spots detected."
}
```

---

## Integration with Consensus

The Reflection Agent runs **once** per lead, immediately after consensus aggregation. The adjusted scores are re-aggregated using the same weighted formula to produce a **post-reflection consensus score**. This adjusted score is what determines gate passage (≥ 60) and is what gets sent to the Judge Agent for final review.

If the flux is classified as **high** or **critical**, the lead is flagged in the output and the Judge Agent is prompted to pay special attention to the adjusted pillars.

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Avg flux | 3.1 points | < 5 points |
| High flux rate | 9% | < 10% |
| Critical flux rate | 1.2% | < 3% |
| Avg score delta | −2.5 points | N/A (typically negative) |
| Processing time | 6.5s per company | < 10s |
