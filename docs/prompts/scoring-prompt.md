# Lead Scoring — Single Prompt

Company evidence: {full evidence JSON}

Score ALL dimensions 0-100. Each score requires evidence reference.

Dimensions:
- move_intent: Is this company likely to need our service? Score based on growth, hiring, facility changes
- growth: Revenue growth, hiring, expansion signals
- financial: Funding, revenue health (if available)
- company_fit: Does their profile match our ICP?
- decision_access: Can we reach the decision maker?
- network: Any existing relationships or connections?
- timing: Is now the right time to engage?
- evidence_quality: How reliable is our data?

Return format:
{
  "scores": { "move_intent": 0-100, "growth": 0-100, ... },
  "overall": 0-100,
  "confidence": "high|medium|low",
  "key_evidence": ["specific evidence ref 1", "specific evidence ref 2"],
  "risk_factors": ["risk 1", "risk 2"],
  "reasoning": "Concise explanation of scoring logic"
}

Return ONLY valid JSON. No markdown.
