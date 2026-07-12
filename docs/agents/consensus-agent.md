# Consensus Agent

> **Layer 3 — Aggregates all 8 pillar scores. Weighted voting. Disagreement detection. Confidence calibration. Output: total score 0–100.**

---

## Purpose

The Consensus Agent is the central arbitration engine of the Jasfo scoring system. It receives the 8 independent pillar scores from Layer 2, computes a weighted composite score, detects disagreements between agents, and produces a calibrated total score (0–100) with a confidence interval. This agent does not re-score the company — it reconciles the scores that the specialist agents have already produced.

The output of this agent is the single number that determines whether a lead proceeds to paid enrichment (≥ 60) or is deprioritized. This is the most consequential decision point in the pipeline.

---

## Model

| Property | Value |
|----------|-------|
| **Model** | MiMo V2.5 |
| **Provider** | OpenRouter |
| **Cost (input)** | $2.00/1M tokens |
| **Cost (output)** | $8.00/1M tokens |
| **Avg tokens per company** | 3,600 |
| **Cost per company** | ~$0.0108 |
| **Avg latency** | 8 seconds |

---

## Input: 8 Pillar Scores

```
company-fit-agent:     { score: 78, confidence: 0.85, weight: 0.10 }
move-intent-agent:     { score: 74, confidence: 0.82, weight: 0.35 }
growth-agent:          { score: 81, confidence: 0.79, weight: 0.15 }
financial-agent:       { score: 72, confidence: 0.81, weight: 0.12 }
decision-maker-agent:  { score: 83, confidence: 0.88, weight: 0.10 }
network-agent:         { score: 72, confidence: 0.85, weight: 0.08 }
opportunity-agent:     { score: 82, confidence: 0.90, weight: 0.05 }
evidence-agent:        { score: 78, confidence: 0.92, weight: 0.05 }
evidence_modifier:     0.90
```

---

## Weighted Aggregation

The consensus score is computed as:

```
total_score = Σ(agency_score × agency_weight × evidence_modifier) / Σ(agency_weight)
```

Where `evidence_modifier` (from the Evidence Agent) is applied to the confidence of all other pillars. If the modifier is 0.90, all pillar scores are effectively multiplied by 0.90 before weighting.

### Example Calculation

| Agent | Score | Weight | Evidence Mod | Weighted Contribution |
|-------|-------|--------|-------------|----------------------|
| Company Fit | 78 | 0.10 | 0.90 | 7.02 |
| Move Intent | 74 | 0.35 | 0.90 | 23.31 |
| Growth | 81 | 0.15 | 0.90 | 10.94 |
| Financial | 72 | 0.12 | 0.90 | 7.78 |
| Decision Maker | 83 | 0.10 | 0.90 | 7.47 |
| Network | 72 | 0.08 | 0.90 | 5.18 |
| Opportunity | 82 | 0.05 | 0.90 | 3.69 |
| Evidence | 78 | 0.05 | 1.00 | 3.90 |

**Weighted sum**: 69.29  **Total weight**: 1.00  **Consensus score**: **69.3**

---

## Disagreement Detection

The agent detects disagreement using two metrics:

### 1. Standard Deviation Threshold

If the standard deviation of scores across agents exceeds **15 points**, a disagreement is flagged.

```
σ = sqrt(Σ(score_i − mean)² / n)
Flag if σ > 15
```

### 2. Outlier Detection

Any agent whose score deviates from the weighted mean by more than **25 points** is flagged as an outlier. The outlier's score is reviewed and potentially down-weighted by 50%.

---

## Disagreement Resolution

When disagreement is detected, the Consensus Agent performs structured arbitration:

1. **Identify outliers**: Which agents disagree with the consensus?
2. **Examine evidence strength**: Are outliers using stronger or weaker evidence?
3. **Apply resolution rule**:
   - Outlier with stronger evidence → shift consensus toward outlier
   - Outlier with weaker evidence → down-weight or discard outlier
4. **Log the resolution** for audit and Reflection Agent

---

## Confidence Calibration

After aggregation, the consensus confidence is calibrated:

```
calibrated_confidence = mean_agent_confidence × inter_agreement_ratio × evidence_modifier
```

Where:
- `mean_agent_confidence` = average confidence across all 8 agents
- `inter_agreement_ratio` = fraction of agent pairs within 15 points of each other
- `evidence_modifier` = from the Evidence Agent

---

## Output

```json
{
  "agent": "consensus-agent",
  "company_id": "uuid",
  "consensus_score": 69.3,
  "confidence": 0.82,
  "score_interpretation": "moderate_quality",
  "per_pillar_scores": [
    { "pillar": 1, "name": "company_fit", "score": 78, "weight_used": 0.10 },
    { "pillar": 2, "name": "move_intent", "score": 74, "weight_used": 0.35 },
    { "pillar": 3, "name": "growth", "score": 81, "weight_used": 0.15 },
    { "pillar": 4, "name": "financial", "score": 72, "weight_used": 0.12 },
    { "pillar": 5, "name": "decision_maker", "score": 83, "weight_used": 0.10 },
    { "pillar": 6, "name": "network", "score": 72, "weight_used": 0.08 },
    { "pillar": 7, "name": "opportunity", "score": 82, "weight_used": 0.05 },
    { "pillar": 8, "name": "evidence", "score": 78, "weight_used": 0.05 }
  ],
  "agreement_stats": {
    "mean_score": 77.5,
    "std_dev": 4.6,
    "min_score": 72,
    "max_score": 83,
    "agreement_ratio": 0.94
  },
  "outliers": [],
  "evidence_modifier_applied": 0.90,
  "gate_decision": "pass",
  "gate_threshold": 60,
  "rationale": "Consensus score of 69.3 passes the cost gate threshold of 60. Move Intent (35% weight) and Growth (15% weight) drive majority of score. No significant disagreement detected (σ = 4.6). Evidence quality is strong."
}
```

---

## Score Interpretation

| Range | Label | Gate Decision |
|-------|-------|---------------|
| 85–100 | Excellent | Priority queue — immediate enrichment |
| 70–84 | Strong | Standard enrichment path |
| 60–69 | Moderate | Pass gate, standard enrichment |
| 40–59 | Below threshold | Weekly digest for manual review |
| 0–39 | Low | Return to pool with cooldown |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Processing time | 8s per company | < 15s |
| Agreement (σ < 15) | 88% | > 80% |
| Outlier rate | 12% | < 15% |
| Gate pass rate (score ≥ 60) | 22% | 20–30% |
| Calibration accuracy | 84% | > 80% |
