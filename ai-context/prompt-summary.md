# Prompt Summary

> Every agent prompt follows a standard structure with ROLE HEADER, CONTEXT BLOCK, TASK INSTRUCTION, CONSTRAINT REMINDER, and OUTPUT FORMAT.

## System Prompt Template

Every system prompt includes:
- **Role** definition (who the agent is)
- **Core responsibilities** (what it does)
- **Behavioral constraints** (what it must never do)
- **Output rules** (format, schema, conventions)

## Developer Prompt Template

Every developer prompt follows:

```
[ROLE HEADER]
You are acting as {agent_role}.

[CONTEXT BLOCK]
Company: {company_name}
Domain: {domain}
Research depth: {depth}
Existing data: {json_summary}

[TASK INSTRUCTION]
{task_specific_instructions}

[CONSTRAINT REMINDER]
{role_specific_constraints}

[OUTPUT FORMAT]
Respond with a JSON object conforming to the {schema_name} schema.
```

## Key Prompts

| ID | Agent | Version | Last Modified |
|----|-------|---------|---------------|
| PROMPT-SYS-001 | Master Orchestrator | 2.1.0 | 2026-07-10 |
| PROMPT-SYS-002 | Discovery Agent | 2.0.0 | 2026-07-08 |
| PROMPT-SYS-003 | Scoring Agent | 2.2.0 | 2026-07-11 |
| PROMPT-SYS-004 | Export Agent | 1.3.0 | 2026-07-05 |
| PROMPT-SYS-005 | Reflection Agent | 1.1.0 | 2026-07-09 |
| PROMPT-DEV-001 | Discovery Instruction | 2.0.0 | 2026-07-08 |
| PROMPT-DEV-002 | Scoring Instruction | 2.2.0 | 2026-07-11 |
| PROMPT-DEV-003 | Export Formatting | 1.2.0 | 2026-07-05 |
| PROMPT-DEV-004 | Reflection Instruction | 1.1.0 | 2026-07-09 |

## Output Validation Rules

Every output must pass:
1. **Schema conformance** — Valid JSON matching the expected schema
2. **Confidence scores** — Every data point has 0.0-1.0 confidence
3. **Source URLs** — Every claim has at least one source URL
4. **No hallucinated data** — If unavailable, mark "Not Found"
5. **Date format** — ISO 8601 (YYYY-MM-DD)
6. **Monetary values** — USD with currency code
7. **Risk factors** — Contradictory signals flagged

## Reflection Criteria

| Severity | Threshold | Action |
|----------|-----------|--------|
| CRITICAL | Hallucinated data | Must remove |
| HIGH | Contradictory data | Must resolve |
| MEDIUM | Missing confidence | Should add |
| LOW | Formatting issue | Can defer |

If any CRITICAL or 3+ HIGH findings -> verdict FAIL.
