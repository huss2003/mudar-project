# Judge Agent

> **Layer 3 — Claude Sonnet 4 final review. Contrarian check. Evidence integrity. Strategic soundness. Approve/reject top 20–30 leads.**

---

## Purpose

The Judge Agent is the final quality gate in the Jasfo Lead Intelligence Platform. After 8 pillar-scoring agents have evaluated a company, the Consensus Agent has aggregated their scores, and the Reflection Agent has performed self-critique, the Judge Agent performs a single, high-quality, holistic review using **Claude Sonnet 4** — the most capable and expensive model in the stack.

The Judge processes only the top 20–30 leads per batch (approximately 2% of the original 10,000 companies). It performs three independent checks — contrarian, evidence integrity, and strategic quality — and delivers a final verdict: approve, reject, or flag for human review. No lead reaches the broker without passing the Judge.

---

## Model

| Property | Value |
|----------|-------|
| **Model** | Claude Sonnet 4 |
| **Provider** | OpenRouter |
| **Cost (input)** | $15.00/1M tokens |
| **Cost (output)** | $75.00/1M tokens |
| **Avg tokens per lead** | 7,500 input / 1,000 output |
| **Cost per lead** | ~$0.052 |
| **Leads per batch** | 20–30 |
| **Total cost per batch** | ~$1.50 |
| **Avg latency** | 15–25 seconds |

---

## Three Checks

### 1. Contrarian Check

The Judge is explicitly prompted to argue **against** the consensus score before arguing for it. This prevents groupthink and overconfidence from propagating through the pipeline.

```
You are the Contrarian Reviewer. The consensus score for [LEAD] is [SCORE].

Your job: find reasons this score might be WRONG.

Consider:
- What positive signals might the agents be over-weighting?
- What negative signals might they have missed?
- Is there a base-rate fallacy? (most companies like this fail to convert)
- Would a skeptical broker disagree with this assessment?

Return: contrarian_score (0-100), key_risks, decision (OVERRIDE or UPHOLD)
```

If the Judge's contrarian score differs from the consensus score by more than **20 points**, the lead is flagged for human review.

### 2. Evidence Integrity Check

The Judge audits every cited evidence source for credibility:

| Criteria | Pass | Fail |
|----------|------|------|
| Source verifiability | URL or document ID provided | No source, vague reference |
| Source authority | Official filing, reputable publication | Anonymous blog, unknown domain |
| Recency | Within 6 months | Older than 12 months |
| Direct relevance | Directly supports the claim | Inferred tangentially |
| No hallucination | Claim matches source content | Claim not found in cited source |

Any claim that fails **3 or more** criteria causes the lead to be flagged.

### 3. Strategic Quality Check

The Judge evaluates whether the lead assessment meets the platform's quality bar:

```
STRATEGIC QUALITY CHECKLIST:
[ ] All 8 pillars scored with supporting evidence
[ ] Score is calibrated (not extreme without justification)
[ ] Weaknesses are identified, not hidden
[ ] Recommendation follows logically from the analysis
[ ] Actionable next steps are provided
```

A lead passes only if **all 5 items** are checked. Any unchecked item is noted for the broker.

---

## Approval Criteria

A lead passes the Judge and enters the final output only when:

1. **Contrarian check**: PASS (contrarian score within 20 points of consensus)
2. **Evidence integrity**: PASS (no claim fails 3+ criteria)
3. **Strategic quality**: PASS (all 5 items checked)

If any check fails, the lead is **FLAGGED** and routed to the human review queue.

---

## Output

```json
{
  "agent": "judge-agent",
  "company_id": "uuid",
  "model": "claude-sonnet-4",
  "pre_judge_score": 66.8,
  "judge_verdict": "APPROVED",
  "final_rank": 4,
  "contrarian_check": {
    "pass": true,
    "contrarian_score": 62,
    "consensus_score": 66.8,
    "delta": 4.8,
    "rationale": "Contrarian review finds consensus reasonable. The 4.8-point gap is within tolerance. Main risk: revenue self-reported and not independently verified, but this is noted in reflection."
  },
  "evidence_check": {
    "pass": true,
    "failed_claims": [],
    "total_claims_reviewed": 24,
    "rationale": "All 24 claims have at least one verifiable source. Two claims have secondary-only sources but are non-critical fields."
  },
  "strategic_check": {
    "pass": true,
    "checked_items": [
      "All 8 pillars scored with supporting evidence",
      "Score is calibrated — not extreme without justification",
      "Weaknesses are identified: revenue self-reported, lease age inferred",
      "Recommendation follows logically from analysis",
      "Actionable next steps: warm intro via Raj Patel, lead with Series A signal"
    ],
    "rationale": "All 5 strategic quality criteria met. Lead is ready for broker action."
  },
  "final_verdict": "APPROVED",
  "judge_confidence": 88,
  "broker_notes": "Strong lead. Recommended approach: warm intro via Raj Patel (VP Eng, mutual connection). Lead with Series A signal in outreach. Budget range ₹6.5L–₹7.5L for Panchshil Business Park. Note: revenue is self-reported — verify during conversation.",
  "summary": "Acme Corp (Pune-based, 350 emp, $30M rev, manufacturing ERP) scores 66.8 consensus / 62 contrarian. Strong move intent driven by Series A funding + employee growth. Excellent opportunity match with Panchshil Business Park. Warm intro available via Raj Patel. APPROVED with 88 confidence."
}
```

---

## Cost per Lead

| Component | Tokens (input) | Tokens (output) | Cost |
|-----------|---------------|----------------|------|
| Lead context (all 8 pillars + reflection) | ~4,000 | — | $0.060 |
| Contrarian check prompt + response | ~1,500 | ~300 | $0.045 |
| Evidence integrity check | ~1,500 | ~400 | $0.053 |
| Strategic quality check | ~500 | ~300 | $0.030 |
| **Total** | **~7,500** | **~1,000** | **~$0.19/lead** |

At 25 leads per weekly batch: ~$4.75 per week, ~$247 per year.

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Approval rate | 72% | 65–80% |
| Flag rate (human review) | 18% | 15–25% |
| Rejection rate | 10% | 5–15% |
| Contrarian override rate | 6% | < 10% |
| Evidence integrity fail rate | 3% | < 5% |
| Strategic quality fail rate | 4% | < 5% |
| Avg judge confidence | 84 | > 75 |
