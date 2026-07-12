# Network Agent

> **Pillar 6 — Scores warm intro path: mutual connections with broker. Weight: 8%.**

---

## Purpose

The Network Agent evaluates the strength of the connection path between the broker and the target company's decision-maker. A warm introduction dramatically increases the likelihood of a response — cold emails convert at 1–3%, while warm intros convert at 20–40%. This agent analyzes mutual connections, overlapping vendor relationships, shared events, and past broker interactions to score how easily the broker can reach the decision-maker through a trusted channel.

Even though this agent carries only 8% weight in the composite score, it is a **multiplier** on outreach effectiveness: a high network score makes a medium-fit lead more actionable than a perfect-fit lead with no connection path.

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

## Input Features

| Feature | Type | Description |
|---------|------|-------------|
| `mutual_connection_count` | int | Overlapping LinkedIn connections with broker |
| `mutual_connection_seniority` | int (0–5) | Max seniority rank of mutual connection |
| `past_broker_interaction` | binary | Previously contacted by this broker? |
| `vendor_relationship_flag` | binary | Company is vendor/client of broker's network? |
| `decision_maker_title` | string | Used to determine intro path targeting |
| `pune_presence` | string | Used for geographic connection matching |

---

## Connection Tier System

The agent assigns the lead to a connection tier:

| Tier | Score Range | Definition | Expected Open Rate |
|------|-------------|------------|-------------------|
| **Tier 1 — Direct** | 90–100 | Broker has direct relationship with decision-maker (past deal, colleague) | 50%+ |
| **Tier 2 — Strong Intro** | 70–89 | Mutual connection can make a warm intro; connection is senior | 30–50% |
| **Tier 3 — Weak Intro** | 40–69 | Mutual connection exists but is junior or distant | 15–30% |
| **Tier 4 — Cold** | 10–39 | No mutual connections but some common ground (industry, school, past employer) | 3–10% |
| **Tier 5 — Unknown** | 0–9 | No connection path identified at all | 1–3% |

---

## Scoring Rubric

| Sub-dimension | Weight | 0–20 | 21–40 | 41–60 | 61–80 | 81–100 |
|--------------|--------|-------|-------|-------|-------|--------|
| **Mutual Connections** | 40% | 0 connections | 1 connection | 2 connections | 3–5 connections | 5+ connections |
| **Connection Seniority** | 30% | No connection | Junior (< 5 yrs exp) | Mid-level | Senior (Director+) | C-level |
| **Relationship History** | 20% | No history | Past cold outreach | Event attendee | Past client/vendor | Active relationship |
| **Contextual Overlap** | 10% | No overlap | Same industry | Same submarket | Shared alma mater | Shared board/association |

---

## Intro Path Recommendation

Based on the analysis, the agent recommends the optimal approach:

| Scenario | Recommended Approach | Example |
|----------|---------------------|---------|
| Tier 1–2 | Direct warm intro via mutual connection | "Raj (VP Eng) offered to introduce me to Jane (CEO)" |
| Tier 3 | Reference mutual connection in cold email | "I work closely with Raj Patel, who mentioned you" |
| Tier 4 | Use common ground as connection bridge | "We both serve on the NASSCOM Pune chapter board" |
| Tier 5 | Pure cold outreach | No intro reference — lead with company signal |

---

## Output

```json
{
  "agent": "network-agent",
  "company_id": "uuid",
  "pillar": 6,
  "weight": 0.08,
  "score": 72,
  "confidence": 0.85,
  "connection_tier": "Tier 3 — Weak Intro",
  "mutual_connections": [
    {
      "name": "Raj Patel",
      "title": "VP Engineering at Acme Corp",
      "connection_strength": "first_degree",
      "intro_willingness": "likely_yes"
    }
  ],
  "sub_dimensions": {
    "mutual_connections": { "score": 50, "weight": 0.40, "rationale": "1 mutual connection confirmed" },
    "connection_seniority": { "score": 80, "weight": 0.30, "rationale": "Mutual is VP Engineering at target company" },
    "relationship_history": { "score": 60, "weight": 0.20, "rationale": "Broker has worked with mutual connection before" },
    "contextual_overlap": { "score": 70, "weight": 0.10, "rationale": "Both in Pune tech ecosystem, shared submarket" }
  },
  "recommended_approach": "warm_intro_via_connection",
  "intro_template": "Raj (VP Engineering) and I have worked together on office solutions for his team. He mentioned Acme Corp is growing and suggested I reach out.",
  "strengths": ["VP Engineering at target company is a direct mutual connection", "Connection has prior working relationship with broker"],
  "weaknesses": ["Only 1 mutual connection — weak if connection is unwilling"],
  "rationale": "One strong mutual connection via Raj Patel, VP Engineering at Acme Corp. Raj has worked with the broker before and is likely to make the introduction. This is a Tier 3 warm path with good conversion probability."
}
```

---

## Broker Network Graph

The Network Agent maintains a persistent graph of the broker's connections in Supabase:

```
broker_connections:
  - connection_id (PK)
  - connection_name
  - company (current employer)
  - title
  - relationship_strength (1-5)
  - past_intro_success_rate (0-100)
  - last_interaction_date
  - notes
```

The graph is updated manually by the broker or via periodic LinkedIn sync. A lean graph (< 50 connections) produces lower network scores across all leads — this is expected and improves as the broker uses the platform longer.

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| No mutual connections found | Score defaults to 20, recommend cold outreach |
| Mutual connection is at target but not decision-maker | Still score as Tier 3 if connection is willing to intro |
| Multiple mutual connections | Score based on highest-ranked connection, note total count |
| Broker graph empty (new user) | Score all leads at 15, add note to build connection graph |
| Mutual connection is competitor | Exclude from scoring, flag `competitor_conflict` |

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Leads with Tier 1–2 connection | 8% | > 10% (grows with broker network) |
| Leads with any mutual connection | 34% | > 30% |
| Warm intro recommendation accuracy | 92% (from feedback) | > 85% |
| Avg network score | 41 | N/A (depends on broker network size) |
| Processing time | 1.1s per company | < 3s |
