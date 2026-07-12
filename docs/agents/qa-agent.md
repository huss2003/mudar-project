# QA Agent

> **Layer 5 — Quality assurance. Validates lead packets. Checks 2-source rule. Verifies confidence thresholds. Flags anomalies.**

---

## Purpose

The QA Agent is the final integrity check before a lead packet reaches the broker. It validates every component of the lead output against the platform's quality standards: the 2-source verification rule, confidence threshold minimums, data completeness requirements, and cross-field consistency checks. Any lead that fails QA is flagged and held back from delivery, with a specific remediation note.

This agent is the system's last line of defense against hallucinated or incomplete data reaching the broker. A broker who receives low-quality leads will lose trust in the platform — the QA Agent ensures every delivered lead meets a minimum quality bar.

---

## Implementation

| Property | Value |
|----------|-------|
| **Model** | DeepSeek V4 Flash |
| **Provider** | OpenRouter |
| **Cost (input)** | $0.50/1M tokens |
| **Cost (output)** | $2.00/1M tokens |
| **Avg tokens per lead** | 500 |
| **Cost per lead** | ~$0.0005 |
| **Avg latency** | 1.5 seconds |
| **Batch size** | 30 leads (post-Judge) |

---

## QA Checks

The agent performs 12 automated checks on each lead packet, organized into three categories:

### Completeness Checks (must pass all 5)

| # | Check | Pass Condition | Fail Action |
|---|-------|---------------|-------------|
| 1 | 8 pillar scores present | All 8 agents contributed a score | Flag `missing_pillar_scores` |
| 2 | 2-source verification | Every critical field has ≥ 2 sources | Flag `verification_gap` |
| 3 | Contact present | ≥ 1 decision-maker with verified email | Flag `no_contact` |
| 4 | Property match | ≥ 1 property recommendation | Flag `no_property_match` |
| 5 | Judge verdict | Judge approved or flagged (not empty) | Flag `missing_judge_verdict` |

### Confidence Checks (must pass all 3)

| # | Check | Pass Condition | Fail Action |
|---|-------|---------------|-------------|
| 6 | Consensus confidence ≥ 60 | consensus.confidence ≥ 0.60 | Flag `low_consensus_confidence` |
| 7 | Evidence score ≥ 50 | evidence_agent.score ≥ 50 | Flag `low_evidence_quality` |
| 8 | Judge confidence ≥ 70 | judge.judge_confidence ≥ 70 | Flag `low_judge_confidence` |

### Anomaly Checks (pass/fail + flag for review)

| # | Check | Anomaly Threshold | Flag |
|---|-------|-------------------|------|
| 9 | Score divergence | Pillar std_dev > 20 | `high_pillar_divergence` |
| 10 | Outlier score | Any pillar ±50 from mean | `pillar_outlier` |
| 11 | Flux too high | Reflection flux > 8 | `high_flux` |
| 12 | Data age | Any critical field source > 18 months | `stale_data` |

---

## Anomaly Classification

When an anomaly is detected, the agent classifies the severity:

| Severity | Impact | Examples | Action |
|----------|--------|----------|--------|
| **Critical** | Lead should not be delivered | Missing pillar scores, no contact, no property match | Block delivery, notify operator |
| **Major** | Lead quality is compromised | Low evidence quality, high flux, stale data | Deliver with warning flags |
| **Minor** | Lead is acceptable but has notes | Single weak claim, moderate pillar divergence | Deliver with notes in evidence package |
| **Pass** | All checks pass | Clean lead | Deliver without restrictions |

---

## Output

```json
{
  "agent": "qa-agent",
  "company_id": "uuid",
  "company_name": "Acme Corp",
  "qa_verdict": "PASS",
  "overall_qa_score": 94,
  "checks_summary": {
    "total_checks": 12,
    "passed": 11,
    "failed": 0,
    "flagged": 1
  },
  "check_results": [
    { "check": "8_pillar_scores_present", "pass": true },
    { "check": "2_source_verification", "pass": true, "details": "22/24 fields verified" },
    { "check": "contact_present", "pass": true },
    { "check": "property_match", "pass": true },
    { "check": "judge_verdict", "pass": true },
    { "check": "consensus_confidence", "pass": true, "value": 0.82 },
    { "check": "evidence_score", "pass": true, "value": 78 },
    { "check": "judge_confidence", "pass": true, "value": 88 },
    { "check": "pillar_divergence", "pass": true, "std_dev": 4.6 },
    { "check": "no_outlier", "pass": true, "max_deviation": 11 },
    { "check": "flux_within_range", "pass": true, "flux": 2.5 },
    { "check": "data_age", "pass": false, "flag": "stale_data", "details": "Revenue source is 14 months old" }
  ],
  "anomalies": [
    {
      "type": "stale_data",
      "severity": "minor",
      "field": "revenue_band",
      "source": "company_website",
      "source_age_months": 14,
      "recommendation": "Revenue data is 14 months old — request updated figures during initial conversation"
    }
  ],
  "blocking_issues": [],
  "warning_notes": [
    "Revenue data is self-reported and 14 months old — verify during outreach"
  ],
  "deliverable": true,
  "rationale": "Lead passes all critical and major checks. One minor warning flagged: revenue data source is 14 months old. This is non-blocking but noted in the evidence package for broker awareness."
}
```

---

## QA Verdicts

| Verdict | Meaning | Action |
|---------|---------|--------|
| **PASS** | All checks pass; lead is deliverable | Include in final broker output |
| **PASS_WITH_WARNINGS** | Minor anomalies found; lead is deliverable with notes | Include with warning flags in evidence package |
| **FLAGGED** | Major issues found; lead needs operator review | Hold for human review, notify operator |
| **BLOCKED** | Critical issues found; lead not deliverable | Exclude from output, log reason |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Overall pass rate | 82% | > 75% |
| Pass with warnings rate | 12% | < 15% |
| Flagged rate | 4% | < 5% |
| Blocked rate | 2% | < 3% |
| Most common flag | stale_data (42% of flags) | — |
| Processing time | 1.5s per lead | < 3s |
