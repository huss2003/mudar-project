# Learning Agent

> **Layer 5 — Post-cycle learning. Analyzes broker feedback. Updates prompt templates. Tracks accuracy over time.**

---

## Purpose

The Learning Agent closes the feedback loop for the Jasfo platform. After each batch cycle, the broker provides structured feedback on the delivered leads — which were contacted, which responded, which led to meetings, and which closed. The Learning Agent analyzes this feedback, identifies patterns in what the system got right and wrong, and produces actionable recommendations for improving agent prompts, scoring weights, and thresholds for the next cycle.

This agent is what makes the platform self-improving. Without it, the system would continue making the same mistakes cycle after cycle. With it, every batch makes the next batch slightly better.

---

## Implementation

| Property | Value |
|----------|-------|
| **Model** | DeepSeek V4 Flash |
| **Provider** | OpenRouter |
| **Cost (input)** | $0.50/1M tokens |
| **Cost (output)** | $2.00/1M tokens |
| **Avg tokens per analysis** | 400 |
| **Cost per cycle** | ~$0.0005 (one analysis per cycle, not per lead) |
| **Frequency** | Once per batch cycle |
| **Avg latency** | 2 seconds |

---

## Input: Broker Feedback

Broker feedback is collected after each cycle. Schema per lead:

```json
{
  "lead_id": "uuid",
  "action_taken": "email_sent",
  "response": "positive" | "neutral" | "negative" | "no_response",
  "meeting_booked": true | false,
  "deal_value": null | "amount_in_inr",
  "feedback_text": "Free-text notes from broker",
  "rating": 1–5,
  "timestamp": "ISO8601"
}
```

---

## Analysis Dimensions

The Learning Agent analyzes feedback across four dimensions:

### 1. Score Calibration

Compares the consensus score against actual outcomes:

| Outcome | Expected Score | Signal |
|---------|---------------|--------|
| Meeting booked | Should be ≥ 65 | Score < 65 with meeting = scoring too conservative |
| No response | Could be any | No pattern = poor targeting |
| Negative response | Should be < 60 | Score > 60 with negative = scoring too generous |
| Deal closed | Should be ≥ 70 | Score ≥ 70 with deal = correct calibration |

**Output**: Recommendations to adjust pillar weights or thresholds.

### 2. Prompt Weakness Detection

Identifies patterns in what agents systematically miss or over-weigh:

| Pattern | Likely Cause | Recommended Fix |
|---------|-------------|-----------------|
| Move Intent over-scored for bootstrapped companies | Agent over-weighs growth without funding context | Add "bootstrapped" modifier to prompt |
| Financial Agent under-scored VC-backed SaaS | Revenue data missing for pre-revenue startups | Add "total funding" as stronger signal in rubric |
| Evidence Agent misses self-reported data | No distinction between primary and self-reported | Add `self_report_penalty` to source evaluation |
| Network Agent over-scored distant connections | No connection quality weighting | Add `connection_recency` factor |

### 3. Threshold Tuning

Analyzes whether pipeline thresholds are set correctly:

| Signal | Threshold Issue | Adjustment |
|--------|----------------|------------|
| Approval rate > 90% | Cost gate too conservative | Lower cost gate threshold by 2–3 points |
| Approval rate < 40% | Cost gate too generous | Raise cost gate threshold by 2–3 points |
| High false positive rate | Pillar weights need adjustment | Shift weight from under-performing to over-performing pillars |
| Leads with score > 80 get no response | Score inflation | Apply −5 calibration offset to all scores |

### 4. New Signal Detection

Identifies signals that brokers consistently mention in feedback but the agent system does not currently capture:

```
Broker feedback analysis:

Pattern detected: 6 of 15 positive responses mentioned "competitor moved to Pune recently"
Current coverage: Not tracked by any agent
Recommendation: Add "competitor_pune_presence" as a signal for Move Intent Agent

Pattern detected: 4 of 10 negative responses said "we use co-working"
Current coverage: Not distinguished from "no office"
Recommendation: Add "co_working_user" flag with −15 modifier to move intent
```

---

## Prompt Update Recommendations

The Learning Agent produces structured prompt update recommendations:

```json
{
  "agent": "learning-agent",
  "cycle_id": "2026-W28",
  "analysis_date": "2026-07-19",
  "batch_summary": {
    "total_leads_delivered": 27,
    "broker_feedback_received": 22,
    "response_rate": 67%,
    "meeting_rate": 33%,
    "deal_rate": 11%
  },
  "calibration_analysis": {
    "mean_consensus_score_vs_outcome": {
      "meeting_booked": 71.2,
      "no_response": 64.8,
      "negative": 58.3
    },
    "calibration_status": "healthy",
    "adjustment_needed": false
  },
  "prompt_recommendations": [
    {
      "target_agent": "move-intent-agent",
      "change_type": "add_signal",
      "description": "Add 'competitor_pune_presence' as a signal when broker notes indicate competitive pressure",
      "priority": "medium",
      "expected_impact": "+2–3% move intent accuracy for companies in competitive submarkets"
    },
    {
      "target_agent": "financial-agent",
      "change_type": "modify_rubric",
      "description": "Increase weight of 'total_funding_raised' relative to 'revenue' for companies < 5 years old",
      "priority": "high",
      "expected_impact": "+5% financial score accuracy for startups"
    }
  ],
  "threshold_recommendations": {
    "cost_gate": "maintain at 60",
    "judge_confidence_minimum": "maintain at 70",
    "evidence_score_minimum": "consider reducing from 50 to 45 for bootstrapped companies",
    "flux_critical_threshold": "maintain at 10"
  },
  "new_signals_discovered": [
    {
      "signal": "competitor_moved_to_pune",
      "frequency": "6/22 feedback entries",
      "source_agent": "move-intent-agent",
      "implementation": "Add Firecrawl query for 'competitor' + company_name + 'Pune'"
    },
    {
      "signal": "co_working_user",
      "frequency": "4/22 feedback entries",
      "source_agent": "move-intent-agent",
      "implementation": "Add co-working detection to website crawl"
    }
  ],
  "accuracy_trend": {
    "current_accuracy": 0.88,
    "previous_accuracy": 0.86,
    "trend": "improving",
    "three_cycle_avg": 0.87
  },
  "rationale": "Cycle 2026-W28 shows healthy performance. Response rate of 67% and meeting rate of 33% are within targets. Calibration is accurate — mean consensus scores align with outcomes. Two new signal patterns detected from broker feedback. Two prompt recommendations generated for next cycle. Accuracy improved 2 points from previous cycle."
}
```

---

## Accuracy Tracking

The Learning Agent maintains a running accuracy metric over time:

| Metric | Formula | Current | Target |
|--------|---------|---------|--------|
| Score accuracy | Mean absolute error between score and broker rating | ±8.2 points | < ±10 |
| Response prediction | % of leads where response matched prediction | 74% | > 70% |
| Classification accuracy | % of leads correctly classified (hot/warm/cold) | 81% | > 75% |
| Score drift | Change in mean score per cycle | +0.3 points/cycle | < ±1.0 |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Analysis time per cycle | 2 seconds | < 5s |
| Prompt recommendations per cycle | 1.8 avg | 1–3 |
| Recommendation adoption rate | 76% | > 70% |
| New signals discovered per quarter | 4.2 | > 3 |
| Accuracy improvement per cycle | +0.7 points | > 0 |
| Processing time | 2s per analysis | < 5s |
