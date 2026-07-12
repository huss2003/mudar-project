# Reasoning Patterns

Across the 14-layer AI pipeline, four core reasoning patterns are used depending on task complexity, required accuracy, and cost budget. This document describes each pattern and when it is applied.

## Pattern Overview

| Pattern | Used By | Cost Level | Accuracy | Latency |
|---------|---------|------------|----------|---------|
| Chain-of-Thought | MiMo V2.5 agents (Verification, Consensus, Reflection) | Medium | High | Moderate |
| Structured Output | All agents | Low–Medium | Very High | Low |
| Few-Shot | DeepSeek V4 Flash agents (Discovery, Normalisation, Scoring) | Low | High | Low |
| Evidence Citation | All agents, enforced by system prompt | Low | Critical | Low |

## 1. Chain-of-Thought (CoT)

Used when the agent must reason through complex multi-step problems.

### When Applied

- **Verification**: The agent must cross-reference multiple data points to determine if a claim is supported
- **Consensus**: The agent must weigh conflicting evidence from other agents
- **Reflection**: The agent must critique its own reasoning chain
- **Intent Prediction**: The agent must infer future behavior from current signals

### Pattern

```
Step 1: Identify the key claim to evaluate.
Step 2: List all available evidence for the claim.
Step 3: For each piece of evidence, assess: Is it direct or indirect? Current or stale? Authoritative or anecdotal?
Step 4: If multiple sources conflict, determine which is most credible and why.
Step 5: Arrive at a conclusion. State confidence level.
```

### Implementation

CoT is implemented as an explicit step structure in the system prompt. The MiMo V2.5 model is chosen for these tasks because it demonstrates stronger step-following behaviour than DeepSeek V4 Flash. Each step must produce intermediate output before proceeding to the next, which allows the orchestrator to inspect partial reasoning if a timeout occurs.

## 2. Structured Output

All agent outputs follow a JSON schema. This is the most important reasoning pattern because it makes outputs machine-parseable, testable, and cacheable.

### Schema Enforcement

Every agent prompt includes a **required JSON output schema**:

```json
{
  "type": "object",
  "properties": {
    "score": { "type": "integer", "minimum": 0, "maximum": 100 },
    "confidence": { "type": "integer", "minimum": 0, "maximum": 100 },
    "evidence": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "claim": { "type": "string" },
          "source": { "type": "string", "format": "uri" },
          "source_date": { "type": "string", "format": "date" },
          "evidence_type": { "type": "string", "enum": ["primary", "secondary", "inferred"] }
        },
        "required": ["claim", "source", "evidence_type"]
      }
    },
    "reasoning_summary": { "type": "string", "maxLength": 500 }
  },
  "required": ["score", "confidence", "evidence", "reasoning_summary"]
}
```

### Parsing and Validation

All outputs are parsed by a Make.com JSON module. Outputs that fail JSON validation are retried once. If the retry also fails, the agent output for that lead is marked as **degraded** and uses a fallback score of 50 with confidence 10.

## 3. Few-Shot

Used when the agent needs to learn a pattern from examples rather than from instructions alone.

### When Applied

- **Discovery**: Extracting company information from raw web text — few-shot examples teach the model what fields to extract and how to handle missing data
- **Normalisation**: Standardising varied input formats (e.g., "5M", "$5,000,000", "5 million" → 5000000) — examples cover all common formats
- **Scoring**: Applying a rubric — examples show the model what a 90 vs 50 vs 10 score looks like for each dimension

### Example Count

| Task | Examples | Notes |
|------|----------|-------|
| Company name extraction | 5 | Covers edge cases (subsidiaries, DBAs, misspellings) |
| Revenue normalisation | 8 | Covers all common formats and currencies |
| Employee count extraction | 4 | Covers ranges, exact numbers, and fuzzy text |
| Market relevance scoring | 5 | One example per quintile |
| Tech stack detection | 6 | Covers common and uncommon patterns |

### Pattern

```
Task: [task description]

Example 1:
Input: [input]
Output: [correct output]

Example 2:
Input: [input]
Output: [correct output]

...

Now process the following:
Input: [actual input]
Output:
```

## 4. Evidence Citation

Every factual claim in the pipeline must be anchored to a source. This is enforced at the system prompt level and validated by the evidence integrity check in the Judge.

### Citation Rules

| Rule | Description | Enforcement |
|------|-------------|-------------|
| Every claim has a source | No claim without a corresponding URL or doc ID | Validated by output schema (required `evidence` array) |
| Source is accessible | URL must be a working web page or known database | Checked at ingestion |
| Evidence type labelled | `primary` (official), `secondary` (reported), or `inferred` (derived) | Required field in schema |
| No source = no claim | If evidence cannot be produced, the claim is omitted | Stringent enforcement — no exceptions |
| Confidence reflects source quality | Primary sources → higher allowed confidence; inferred → capped at 60 | Enforced by system prompt |

### Contradiction Handling

When an agent encounters contradictory evidence:

1. **Flag both sources** with their confidence scores
2. **Identify which is stronger** based on authority, recency, and directness
3. **Default to the stronger source** but log the contradiction in the output
4. **Reduce overall confidence** by 15 points when contradiction exists

### Why This Matters

Evidence citation is the primary defence against hallucination. By forcing every claim to reference a specific source, the system ensures that:

- Human reviewers can verify any claim in seconds
- The Judge's evidence integrity check has a concrete target
- Confidence scores are grounded in source quality rather than model certainty
- The system degrades gracefully when data is scarce (confidence drops, but no hallucinated "filler" claims are generated)
