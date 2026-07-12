# MiMo V2.5

MiMo V2.5 is the **reasoning engine** in the Jasfo Lead Intelligence Platform. It handles approximately **20% of all AI tasks** — those requiring multi-step reasoning, verification, consensus building, and strategic analysis.

## Role in the Pipeline

| Layer | Task | Why MiMo |
|-------|------|----------|
| 3 — Verification | Cross-reference claims against sources | Strong fact-checking ability |
| 4 — Consensus | Aggregate 8 agent scores | Weighted reasoning with disagreement handling |
| 5 — Reflection | Self-critique and score adjustment | Ability to re-evaluate own reasoning |
| 10 — Intent Prediction | Predict buying intent from signals | Multi-signal pattern analysis |
| 11 — Engagement Strategy | Recommend outreach approach | Strategic reasoning |
| 13 — Confidence Calibration | Tune confidence scores | Decision-making under uncertainty |

## Model Details

| Property | Value |
|----------|-------|
| **Model ID** | `mimo/mimo-v2.5` |
| **Provider** | MiMo (via OpenRouter) |
| **Cost (input)** | $2.00 per 1M tokens |
| **Cost (output)** | $8.00 per 1M tokens |
| **Context window** | 128K tokens |
| **Avg latency** | 5–10 seconds |
| **Max output tokens** | 16,384 |
| **Task suitability** | Reasoning, analysis, verification |

## Strengths

- **Multi-step reasoning**: Maintains coherence across 5+ reasoning steps without losing context
- **Structured thinking**: Follows chain-of-thought patterns reliably — each step builds on the previous
- **Evidence weighing**: Can compare multiple sources and determine which is more credible, even when sources conflict
- **Calibrated confidence**: Self-assessed confidence scores align well with actual accuracy in testing
- **Contradiction detection**: Identifies logical inconsistencies in its own and others' reasoning

## Limitations

| Limitation | Impact | Mitigation |
|-----------|--------|-----------|
| Higher cost | 4× more expensive than DeepSeek V4 Flash | Only used when reasoning is required |
| Slower latency | 5–10s average | Parallelise independent MiMo calls |
| Lower throughput | Fewer concurrent calls due to OpenRouter limits | Priority queuing for MiMo tasks |
| Over-analysis | May overthink simple tasks | Route simple verification to DeepSeek |

## Multi-Step Reasoning Capability

MiMo V2.5 is selected specifically for tasks that require **visible reasoning chains**. The output includes intermediate steps that can be inspected, logged, and audited:

```
Step 1: Identify the claim being verified.
Step 2: Locate relevant source data.
Step 3: Compare claim against source.
  - Claim: "Acme Corp raised $50M Series B"
  - Source: Crunchbase (secondary)
  - Source date: 2025-11-15
  - Cross-reference: Press release from Acme Corp confirms $50M on 2025-11-01
Step 4: Determine match quality.
  - Round name matches: YES
  - Amount matches: YES
  - Date discrepancy: 14 days (acceptable range)
  - Source authority: Primary (press release) > Secondary (Crunchbase)
Step 5: Confidence assessment.
  - Two corroborating sources: +10 confidence
  - Minor date discrepancy: -2 confidence
  - Overall confidence: 88
```

## Verification Prompt Pattern

```
You are verifying the following claim about a company:

CLAIM: [claim]
CITED SOURCE: [source_url]
CITED TEXT: [source_excerpt]

AVAILABLE DATA:
[additional_sources]

TASK:
1. Does the source directly support the claim? (YES/NO/PARTIALLY)
2. Rate source authority (PRIMARY/SECONDARY/INFERRED)
3. Is there any contradictory evidence?
4. Confidence in claim accuracy (0-100):
   - If PARTIALLY or NO, set confidence < 50
5. Reasoning:
```

## Consensus Prompt Pattern

```
You are one of 8 specialist agents assessing this lead.

YOUR ROLE: [role]
YOUR DIMENSION: [dimension]

LEAD DATA: [lead_summary]

OTHER AGENT SCORES:
[other_agent_scores]

ASSIGNMENT:
1. Independently score this lead on your dimension (0-100)
2. State your confidence (0-100)
3. Cite evidence for your score
4. If you disagree with other agents, explain why
```

## Performance Metrics

| Metric | Value | Target |
|--------|-------|--------|
| Avg task latency | 7.2s | < 10s |
| P95 latency | 12.4s | < 20s |
| Error rate | 1.2% | < 3% |
| Reasoning accuracy | 91.4% | > 88% |
| Contradiction detection rate | 87% | > 80% |
| Cache hit rate | 12% | N/A (fewer repeated tasks) |

## When NOT to Use

Do not route to MiMo V2.5 for:

- **High-volume extraction** — use DeepSeek V4 Flash (4× cheaper, 3× faster)
- **Deterministic transformations** — use DeepSeek V4 Flash
- **Final judgment gate** — use Claude Sonnet 4 (higher nuance)
- **Simple classification** — use DeepSeek V4 Flash
