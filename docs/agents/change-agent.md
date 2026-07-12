# Change Agent

> **Layer 4 — Monitors existing leads for meaningful changes. Compares hashes. Triggers re-scoring if delta found.**

---

## Purpose

The Change Agent watches for meaningful changes in companies that have already been evaluated by the pipeline. A company that scored low on move intent six months ago may have since raised funding, hired a new CEO, or doubled its headcount — all signals that warrant re-evaluation. Rather than waiting for the 90-day cooldown to expire, the Change Agent detects these changes proactively and triggers force re-evaluation.

This agent is the mechanism that prevents missed opportunities. Companies do not stay static — their real estate needs evolve with their business. The Change Agent ensures the pipeline stays responsive to company evolution without requiring full re-scans of the entire market every week.

---

## Implementation

| Property | Value |
|----------|-------|
| **Model** | DeepSeek V4 Flash (for classification only) |
| **Primary detection** | Hash comparison (deterministic, no LLM) |
| **Storage** | Supabase (shared with Memory Agent) |
| **Batch throughput** | 15,000 comparisons in < 30 seconds |

---

## Input: Change Detection

The agent receives two data points per company:

1. **Previous profile hash** — stored in `evaluation_history` from the last run
2. **Current profile hash** — recomputed from the current batch's normalized data (Layer 2)

If the hashes are identical, no changes occurred and the company stays on cooldown.
If the hashes differ, the Change Agent classifies the delta using DeepSeek V4 Flash.

---

## Change Classification

The agent classifies detected changes into categories with associated impact levels:

| Change Type | Impact | Re-evaluation Trigger? | Typical Score Delta |
|-------------|--------|------------------------|-------------------|
| **New funding round** | High | Yes — force re-evaluate | +5 to +20 |
| **CEO/C-suite change** | High | Yes — force re-evaluate | −10 to +15 |
| **Headcount growth > 20%** | High | Yes — force re-evaluate | +5 to +15 |
| **New office / expansion** | High | Yes — force re-evaluate | +10 to +25 |
| **Location change** | High | Yes — force re-evaluate | +0 to +20 |
| **Website redesign** | Low | No — log only | No score change |
| **New tech stack signals** | Medium | Conditional | +0 to +5 |
| **New social profiles** | Low | No — log only | No score change |
| **Revenue band shift** | High | Yes — force re-evaluate | +5 to +20 |
| **Employee band shift** | High | Yes — force re-evaluate | +5 to +15 |

---

## Change Classification Workflow

```
Profile hash differs → Submit old and new profiles to DeepSeek V4 Flash
         ↓
DeepSeek classifies the change type and impact level
         ↓
If impact = HIGH → trigger force re-evaluation
If impact = MEDIUM → trigger if combined with other changes
If impact = LOW → log only, no re-evaluation
         ↓
Store change event in `change_events` table
         ↓
If re-evaluation triggered:
  → Override cooldown
  → Set force_revaluation flag
  → Company enters pipeline at Layer 1
```

---

## Output

```json
{
  "agent": "change-agent",
  "company_id": "uuid",
  "domain": "acmecorp.com",
  "change_detected": true,
  "previous_score": 48,
  "previous_evaluation_date": "2026-04-15",
  "changes": [
    {
      "type": "funding",
      "impact": "high",
      "old_value": "no_funding_data",
      "new_value": "$12M Series A (2026-06)",
      "score_delta_estimate": "+15"
    },
    {
      "type": "growth",
      "impact": "high",
      "old_value": "emp_band: 100-200",
      "new_value": "emp_band: 200-500",
      "score_delta_estimate": "+10"
    },
    {
      "type": "website",
      "impact": "low",
      "old_value": "hash_abc123",
      "new_value": "hash_def456",
      "score_delta_estimate": "0"
    }
  ],
  "trigger_revaluation": true,
  "revaluation_priority": "high",
  "rationale": "Two high-impact changes detected since last evaluation: $12M Series A funding and headcount doubling from 100-200 to 200-500. These significantly change the move intent and financial profiles. Force re-evaluation triggered."
}
```

---

## Change Event Storage

Every detected change is persisted:

```sql
INSERT INTO change_events (
    domain_hash, detected_at, change_type,
    old_value, new_value, triggered_revaluation
) VALUES (
    'abc123', NOW(), 'funding',
    'no_funding_data', '$12M Series A (2026-06)', TRUE
);
```

Companies that trigger re-evaluation enter the pipeline at Layer 1 with a `change_event_id` that propagates through all layers. This `change_event_id` is included in the evidence package so the current scores can be compared against previous scores.

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Hash comparison throughput | 15K / 30s | 15K / 60s |
| Change detection rate | 1.8% of existing leads | 1–3% |
| High-impact change rate | 0.18% | 0.1–0.5% |
| Classification accuracy | 94% | > 90% |
| False positive rate | 2.1% | < 5% |
| Re-evaluation trigger rate | 0.18% | 0.1–0.5% |
