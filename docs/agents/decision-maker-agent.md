# Decision Maker Agent

> **Pillar 5 — Scores decision-maker confidence: title weight + behavioral evidence. Weight: 10%. LinkedIn analysis.**

---

## Purpose

The Decision Maker Agent evaluates whether the decision-maker at the target company is accessible, engaged, and likely to respond to commercial real estate outreach. A lead with perfect company fit, move intent, and financial health is worthless if the decision-maker is unreachable or has a gatekeeper who blocks cold outreach. This agent scores the confidence that the broker can reach and engage the right person.

The agent analyzes two dimensions: (1) **structural accessibility** — does the decision-maker have a verifiable LinkedIn profile, email, and public presence? and (2) **behavioral engagement** — is the decision-maker active on LinkedIn, recently promoted, or posting about growth/expansion?

---

## Model

| Property | Value |
|----------|-------|
| **Model** | DeepSeek V4 Flash |
| **Provider** | OpenRouter |
| **Cost (input)** | $0.50/1M tokens |
| **Cost (output)** | $2.00/1M tokens |
| **Avg tokens per company** | 800 |
| **Cost per company** | ~$0.00068 |

---

## Target Roles (by priority)

| Rank | Role | Typical Title Keywords | Best For |
|------|------|----------------------|----------|
| 1 | CEO / MD | Chief Executive, Managing Director, Founder | Final authority on real estate decisions |
| 2 | CFO / Finance Head | Chief Financial, Finance Director, Head of Finance | Budget approval for leases |
| 3 | COO / Operations | Chief Operating, Operations Director | Space planning and facilities |
| 4 | VP / Director Admin | VP Administration, Facilities Director | Day-to-day real estate manager |
| 5 | HR Head | Chief People, HR Director | Space planning for headcount growth |

---

## Scoring Rubric

| Sub-dimension | Weight | 0–20 | 21–40 | 41–60 | 61–80 | 81–100 |
|--------------|--------|-------|-------|-------|-------|--------|
| **Title Authority** | 35% | No manager found | Manager/Director | VP level | C-level (CFO/COO) | CEO/MD |
| **LinkedIn Presence** | 30% | No profile found | Incomplete, old | Complete, inactive | Active, engaged | Posting about growth/expansion |
| **Contact Verification** | 20% | No email found | Email unverified | Single source verified | 2+ sources | SMTP verified + multi-source |
| **Engagement Signals** | 15% | Inactive > 1 year | Inactive > 6 mo | Active last 3 mo | Recent promo/new role | Posting about expansion needs |

---

## LinkedIn Analysis Rules

The agent analyzes LinkedIn profiles with the following heuristics:

| Signal | Score Modifier | How Detected |
|--------|---------------|--------------|
| Profile completeness | +0 to +15 | Photo, headline, experience sections filled |
| Recent role change | +10 | New position within 6 months |
| Content posting | +5 per relevant post | Posts about office, growth, team, Pune |
| Shared connections with broker | +10 per connection | Mutual connection count from feature vector |
| Open to work / available | −20 | Not applicable for decision-maker role |
| Profile > 1 year stale | −15 | Last activity > 365 days ago |
| No profile photo | −5 | Reduces trust in authenticity |

---

## Role Authority Scoring

| Title Level | Score | Examples |
|-------------|-------|----------|
| C-suite (CEO, MD, Founder) | 90–100 | Full authority on real estate |
| C-suite (CFO, COO) | 75–85 | Budget authority, may need CEO sign-off |
| VP / Director | 60–75 | Recommends, may not approve |
| Senior Manager | 40–55 | Gathers options, no decision power |
| Manager / None | 0–30 | No real estate authority |

---

## Output

```json
{
  "agent": "decision-maker-agent",
  "company_id": "uuid",
  "pillar": 5,
  "weight": 0.10,
  "score": 83,
  "confidence": 0.88,
  "best_contact": {
    "name": "Jane Doe",
    "title": "CEO",
    "email": "jane@acmecorp.com",
    "linkedin_url": "https://linkedin.com/in/janedoe",
    "email_verification": "smtp_deliverable",
    "provider_agreement": 2
  },
  "alternative_contacts": [
    { "name": "Raj Patel", "title": "VP Engineering", "email": "raj@acmecorp.com" }
  ],
  "sub_dimensions": {
    "title_authority": { "score": 95, "weight": 0.35, "rationale": "CEO — full decision authority" },
    "linkedin_presence": { "score": 78, "weight": 0.30, "rationale": "Complete profile, active weekly, 500+ connections" },
    "contact_verification": { "score": 90, "weight": 0.20, "rationale": "Email found by 2 providers, SMTP verified" },
    "engagement_signals": { "score": 70, "weight": 0.15, "rationale": "Posted about company growth 2 weeks ago" }
  },
  "lindedin_insights": {
    "profile_completeness": "complete",
    "recent_activity": "posted within last 30 days",
    "mutual_connections": 3,
    "recent_role_change": false,
    "connections_count": "500+"
  },
  "strengths": ["CEO is verified and accessible", "SMTP-confirmed email", "LinkedIn active with growth posts"],
  "weaknesses": ["No warm intro path identified yet — see Network Agent"],
  "rationale": "Strong decision-maker profile. CEO Jane Doe is directly reachable with a verified email, has full authority on real estate decisions, and is active on LinkedIn posting about company growth."
}
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Decision-maker not identified | Score reduced to 30, flag as `no_decision_maker` |
| Email verification fails | Drop score by 20, note `email_unverified` |
| LinkedIn profile not found | Score LinkedIn presence as 0, base score entirely on title + email |
| CEO recently joined (< 3 months) | −10 penalty — may not yet be making real estate decisions |
| Multiple decision-makers found | Score based on highest-ranked verified contact |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| CEO/CFO identified rate | 72% | > 65% |
| SMTP-verified email rate | 58% | > 50% |
| LinkedIn profile found rate | 84% | > 75% |
| Avg decision-maker score | 62 | N/A |
| Processing time | 1.8s per company | < 3s |
