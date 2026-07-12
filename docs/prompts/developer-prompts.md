# Developer Prompts

Developer prompts are the instruction templates passed from the orchestration layer to each agent. They carry context, formatted data, and specific task instructions. These prompts are constructed programmatically by the Master Orchestrator or by Make.com scenarios.

---

## Context Injection Pattern

Every developer prompt follows a standard structure:

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

### Context Variable Reference

| Variable | Source | Format | Example |
|----------|--------|--------|---------|
| `{company_name}` | User input or CSV | String | "Acme Corp" |
| `{domain}` | Firecrawl search or user input | URL | "acme.com" |
| `{depth}` | Scenario configuration | `basic\|standard\|deep` | "standard" |
| `{json_summary}` | Previous agent output | JSON | `{"name": "Acme Corp", ...}` |
| `{schema_name}` | Schema registry | PascalCase | "CompanyData" |

---

## PROMPT-DEV-001: Discovery Instruction

```yaml
---
id: PROMPT-DEV-001
version: 2.0.0
last_modified: 2026-07-08
used_by: Make scenario-02-discovery
---
```

```
You are acting as the Discovery Agent.

CONTEXT:
Company: {company_name}
Domain: {domain}
Research depth: {depth}
Crawl results available: {crawl_summary}

TASK:
Using the Research Framework defined in your system prompt, collect
and organize all available company data from the provided sources.

SPECIFIC INSTRUCTIONS:
1. If crawl results contain structured data, extract and normalize it.
2. If crawl results are empty or insufficient, note which dimensions
   lack data and assign confidence score 0.0 to those fields.
3. For each data point, attach the source URL from the crawl metadata.
4. Prioritize recent data (within last 12 months) over older data.
5. Flag any pricing or financial data as "may be outdated" if the
   source timestamp exceeds 6 months.

DATA FROM PREVIOUS CRAWL:
{crawl_data_json}

OUTPUT:
Respond with a JSON object conforming to the CompanyData schema.
```

---

## PROMPT-DEV-002: Scoring Instruction

```yaml
---
id: PROMPT-DEV-002
version: 2.2.0
last_modified: 2026-07-11
used_by: Make scenario-05-scoring
---
```

```
You are acting as the Scoring Agent.

CONTEXT:
Company: {company_name}
Domain: {domain}
Discovered data: {company_data_summary}

TASK:
Evaluate this company across all 8 scoring pillars.

SPECIFIC INSTRUCTIONS:
1. Score each pillar independently. Justify each score in 1–3 sentences.
2. Reference specific data points from the discovery phase.
3. If a pillar has zero data to support it, score it as 0 and note
   "Insufficient data" in the justification.
4. Apply the weights as specified in your system prompt.
5. After scoring all pillars, review your scores for consistency.
   Flag any contradictions between pillar scores.
6. If the composite score exceeds 70, add a paragraph explaining
   why this company is a strong lead.

DISCOVERED DATA SUMMARY:
{company_data_json}

OUTPUT:
Respond with a JSON object conforming to the ScoreCard schema.
```

---

## PROMPT-DEV-003: Export Formatting

```yaml
---
id: PROMPT-DEV-003
version: 1.2.0
last_modified: 2026-07-05
used_by: Make scenario-06-export
---
```

```
You are acting as the Export Agent.

CONTEXT:
Company: {company_name}
Score card: {score_json}
Full report: {report_json}
Requested format: {export_format}

TASK:
Format the completed lead intelligence data for delivery.

SPECIFIC INSTRUCTIONS:
1. Convert the full report to the requested format.
2. Include the scorecard prominently at the top.
3. Append a summary paragraph with the composite score and key takeaway.
4. If the requested format is Telegram, truncate to 4000 characters.
5. Ensure all monetary values include USD currency prefix.
6. If any fields are empty or confidence is below 0.3, omit them
   from summary outputs (keep in full data exports).

OUTPUT:
Deliver the formatted output through the {delivery_channel} channel.
Return a JSON object with fields: {format, content, delivery_status}.
```

---

## PROMPT-DEV-004: Reflection Instruction

```yaml
---
id: PROMPT-DEV-004
version: 1.1.0
last_modified: 2026-07-09
used_by: Make scenario-05-scoring (post-scoring)
---
```

```
You are acting as the Reflection Agent.

CONTEXT:
Company: {company_name}
Score card to review: {score_json}
Source data: {source_data_summary}

TASK:
Review the agent outputs for quality, consistency, and hallucination.

SPECIFIC INSTRUCTIONS:
1. Verify every cited source URL against the provided source data.
2. Check that scoring justifications match the referenced data points.
3. Flag any numerical inconsistencies (e.g., totals that don't add up).
4. Check for fabricated company information (wrong CEO name, fake
   funding rounds, non-existent products).
5. Assign a severity level to each finding.
6. Provide a pass/fail verdict.

OUTPUT:
Respond with a JSON object conforming to the ReflectionReport schema.
```

---

## Data Formatting Conventions

When injecting data into developer prompts, the following formatting rules apply:

### Dates
```json
{"founded_year": 2015, "founded_date": "2015-03-01"}
```

### Monetary Values
```json
{"amount": 50000000, "currency": "USD", "round": "Series B"}
```

### URLs
```json
{
  "source_url": "https://acme.com/about",
  "confidence": 0.95,
  "accessed_at": "2026-07-10T14:30:00Z"
}
```

### Confidence Scores
```json
{
  "field": "funding_total",
  "value": 50000000,
  "confidence": 0.85,
  "reason": "Confirmed by Crunchbase and PitchBook"
}
```

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 2.0.0 | 2026-07-08 | PROMPT-DEV-001: Added crawl data injection; depth parameter |
| 2.2.0 | 2026-07-11 | PROMPT-DEV-002: Added consistency review instruction |
| 1.2.0 | 2026-07-05 | PROMPT-DEV-003: Added Telegram truncation rule |
| 1.1.0 | 2026-07-09 | PROMPT-DEV-004: Initial reflection instruction |
