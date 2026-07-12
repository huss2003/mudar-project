# Claude Sonnet 4

Claude Sonnet 4 is the **premium judge model** in the Jasfo Lead Intelligence Platform. It is used exclusively for the final review gate — processing only the top **20–30 leads per batch** that survive all earlier filtering and scoring layers.

## Role in the Pipeline

Claude Sonnet 4 handles exactly **one task**: Layer 6 — **Judge Review**. It receives the complete post-reflection consensus output for a lead and performs three structured checks:

1. **Contrarian check** — Argue against the consensus to catch groupthink
2. **Evidence integrity check** — Audit every cited source for credibility
3. **Strategic quality check** — Evaluate the assessment's completeness and actionability

A lead that passes all three checks is approved for final output. A lead that fails any check is flagged for human review.

## Model Details

| Property | Value |
|----------|-------|
| **Provider** | Anthropic (via OpenRouter) |
| **Access** | OpenRouter API |
| **Cost (input)** | $15.00 per 1M tokens |
| **Cost (output)** | $75.00 per 1M tokens |
| **Context window** | 200K tokens |
| **Avg latency** | 8–15 seconds |
| **Max output tokens** | 8,192 |
| **Task suitability** | Nuanced judgment, quality review |

## Strengths

- **Superior nuance**: Detects subtle logical flaws and qualitative distinctions that smaller models miss
- **Strong instruction adherence**: Follows complex multi-part prompts with high consistency
- **Low hallucination rate**: 0.3% hallucination rate in testing (vs 0.8% for DeepSeek V4 Flash)
- **Calibrated judgment**: Scores correlate well with human expert reviewers (r = 0.92 in validation)
- **Honest uncertainty**: Will state "insufficient evidence" rather than guessing — critical for the integrity check

## Limitations

| Limitation | Impact | Mitigation |
|-----------|--------|-----------|
| Very high cost | ~$0.05/lead for Judge review | Only 5% of leads reach this stage |
| Slow latency | 8–15s per call | Process Judge calls sequentially (only 20–30 leads) |
| OpenRouter dependency | Subject to third-party API availability | Fallback to MiMo V2.5 if unavailable |
| Rate limits | Lower concurrency on OpenRouter | Only 2 concurrent Judge calls |

## Cost Analysis

Claude Sonnet 4 is the most expensive model in the stack, but its use is tightly controlled:

| Metric | Value |
|--------|-------|
| Average tokens per Judge call | ~8,500 (7,500 input + 1,000 output) |
| Average cost per Judge call | $0.052 |
| Maximum leads judged per month | ~780 (1 batch/day × 30 days × ~26 leads) |
| Est. monthly Claude spend | ~$40.56 |
| % of total AI spend | ~19% |

For context, Claude Sonnet 4 processes only **5% of total tasks** but accounts for **19% of total AI API spend**. This is intentional — the highest-value decision (final approval) warrants the highest-quality model.

## Judge Prompt Architecture

The Judge prompt is the most carefully crafted prompt in the system. It consists of four components:

### 1. Lead Context

```
LEAD: [lead_id]
COMPANY: [company_name]
INDUSTRY: [industry]
CONSENSUS SCORE: [score]
CONSENSUS CONFIDENCE: [confidence]
```

### 2. Agent Score Summary

```
DIMENSION SCORES:
- Identity: 92 (conf: 88)
- Market Relevance: 68 (conf: 72)
- Financial Health: 55 (conf: 60)
...
```

### 3. Reflection Summary

```
REFLECTION ADJUSTMENTS:
- Market Fit Agent: -7 points (weak source)
- Financial Agent: -5 points (stale data)
```

### 4. Structured Checks

```
CONTRARIAN CHECK:
...
EVIDENCE INTEGRITY CHECK:
...
STRATEGIC QUALITY CHECK:
...
```

## Fallback Behaviour

If Claude Sonnet 4 is unavailable:

1. **Immediate retry** (up to 3, with exponential backoff)
2. **Fallback to MiMo V2.5** if retries exhausted
3. Lead is tagged `judge_model: "claude-sonnet-4 (fallback: mimo-v2.5)"`
4. Confidence is reduced by 10 points

If MiMo V2.5 also fails, the lead is **queued** for the next batch and retried. After 3 batch failures, the lead is **approved without Judge review** with a confidence penalty of −20 points.

## When to Use and Not Use

| Use Claude Sonnet 4 For | Do NOT Use for |
|------------------------|----------------|
| Final lead approval | Bulk data extraction |
| Evidence integrity audit | Normalisation |
| Contrarian review | Scoring |
| Strategic quality check | Classification |
| Human-review triage | Summarisation |
