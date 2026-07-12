# Outreach Agent

> **Layer 5 — Email draft generation. Personalized cold emails ≤120 words. Warm intro path referenced. DeepSeek V4 Flash.**

---

## Purpose

The Outreach Agent generates the actual email that the broker will send to the decision-maker. It takes the commercial strategy brief from the Strategy Agent, the verified contact details from the Decision Maker Agent, and the company profile, and produces a personalized cold email of **no more than 120 words**.

The email is never sent automatically. It is drafted for broker review and approval. The agent enforces strict quality rules: every draft must reference a specific, verifiable signal from the company's recent activity, must mention a warm introduction path if one exists, and must connect to Pune property interest naturally — never sounding like a template.

---

## Model

| Property | Value |
|----------|-------|
| **Model** | DeepSeek V4 Flash |
| **Provider** | OpenRouter |
| **Cost (input)** | $0.50/1M tokens |
| **Cost (output)** | $2.00/1M tokens |
| **Avg tokens per email** | 100 input, 120 output |
| **Cost per email** | ~$0.0001 |
| **Avg latency** | 300ms |
| **Email limit** | 120 words (strict, enforced post-generation) |
| **Batch size** | 50 emails |

---

## Input

| Input | Source |
|-------|--------|
| Decision-maker name, title, email | Decision Maker Agent |
| Company name, industry, recent signals | Feature/Normalization Agents |
| Warm intro path (if any) | Network Agent |
| Recommended property | Strategy Agent |
| Budget range | Strategy Agent |
| Engagement approach (warm vs cold) | Strategy Agent |

---

## Email Structure

Every draft follows a strict three-paragraph structure:

**Paragraph 1 — Signal (2–3 sentences, ~40 words)**
Opens with a specific, relevant signal from the company's recent activity. Must be fact-based and sourced from verified data — never generic flattery. Examples: "Congratulations on your $12M Series A — impressive traction in the manufacturing ERP space." or "I noticed Acme Corp is hiring aggressively for Pune-based engineering roles."

**Paragraph 2 — Connection (2–3 sentences, ~50 words)**
Establishes the warm intro path or relevant context. If a mutual connection exists, it is mentioned by name. If no warm path exists, this paragraph introduces the broker's domain expertise in Pune commercial real estate. Examples: "Raj (VP Engineering) and I have worked together on office solutions. He mentioned Acme Corp is exploring expansion options." or "I've been following Acme Corp's growth trajectory — 22% employee growth in the last year is remarkable."

**Paragraph 3 — Value Proposition (1–2 sentences, ~30 words)**
Connects the company's trajectory to a specific Pune property — without sounding like a sales pitch. Example: "With your Pune team growing rapidly, I'd love to show you a few spaces in Hinjewadi that fit your budget and culture — no obligation, just a conversation."

---

## Personalization Rules

The prompt enforces these checks during generation:

| Rule | Failure Action |
|------|---------------|
| Must reference a specific company signal from verified data | Regenerate |
| Must be ≤ 120 words (measured after generation) | Regenerate |
| Must include warm intro path if one exists | Regenerate |
| No spam trigger phrases ("just checking in", "I wanted to reach out", "I came across your profile") | Regenerate |
| Role-aware tone (CEO = concise/strategic, CTO = technical, Sales = growth-focused) | Adjust tone |
| Property mentioned by type not address | Override to property type |

---

## Warm Intro Priority

If the Network Agent identified a warm intro path, the email must reference it:

| Tier | Email Approach |
|------|----------------|
| Tier 1–2 (strong) | "Raj offered to introduce us — he thought our spaces would be a great fit for Acme Corp's growth plans." |
| Tier 3 (weak) | "I work closely with Raj Patel, who mentioned Acme Corp is expanding." |
| Tier 4–5 (cold) | No intro reference — lead with company signal. |

---

## Output: Draft Emails

```json
{
  "agent": "outreach-agent",
  "company_id": "uuid",
  "drafts": [
    {
      "contact": "Jane Doe, CEO",
      "email": "jane@acmecorp.com",
      "warm_intro_path": "Raj Patel (VP Engineering)",
      "draft_text": "Congratulations on your $12M Series A. Raj Patel and I have worked together on office solutions — he mentioned Acme Corp is growing fast. With your Pune team expanding, I'd love to show you a few spaces in Hinjewadi that match your budget and culture. No obligation — just a conversation.",
      "word_count": 48,
      "personalization_signal": "$12M Series A funding",
      "passes_rules": true
    }
  ],
  "rules_check": {
    "word_count_pass": true,
    "signal_present_pass": true,
    "warm_intro_referenced_pass": true,
    "no_spam_phrases_pass": true,
    "tone_appropriate_pass": true
  },
  "rejected_if_any": []
}
```

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| First-pass acceptance rate | 88% | > 85% |
| Avg word count | 52 | ≤ 120 |
| Warm intro reference rate | 72% (when path exists) | 100% |
| Spam phrase violation rate | 1.2% | < 3% |
| Signal present rate | 100% | 100% |
| Broker edit rate | 18% | < 25% |
| Processing time | 300ms per email | < 1s |
