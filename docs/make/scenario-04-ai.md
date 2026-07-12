# Scenario 04: AI Analysis

The AI Analysis Scenario sends scraped company data to OpenAI/Anthropic models for entity extraction, relationship mapping, and natural language understanding.

---

## Trigger

**Trigger Type**: Queue entry with scenario_step = "ai"

Triggered after Firecrawl scenario completes for a company.

---

## Scenario Flow

`mermaid
flowchart TD
    A[Receive Queue Item] --> B[Prepare AI Context]
    B --> C[Call AI Model]
    C --> D{Success?}
    D -->|Yes| E[Parse Response]
    D -->|No| F[Retry Logic]
    F --> C
    E --> G[Validate JSON]
    G --> H{Valid?}
    H -->|Yes| I[Store Results]
    H -->|No| J[Repair JSON]
    J --> G
    I --> K[Update Queue Status]
`

---

## Modules

### Module 1: Prepare AI Context

The scraped data is assembled into a structured prompt:

`json
{
  "module": "Tools / Compose String",
  "config": {
    "text": "Company: {{company_name}}\nDomain: {{company_domain}}\n\n=== WEBSITE CONTENT ===\n{{crawl_data.combined_markdown}}\n\n=== SEARCH RESULTS ===\n{{search_results}}\n\n=== INSTRUCTIONS ===\nExtract the following data: company identity, products, pricing, technology, funding, leadership, and market context.\n\nOutput as JSON conforming to the CompanyData schema."
  }
}
`

### Module 2: Call AI Model

#### OpenAI GPT-4o Configuration

`json
{
  "module": "OpenAI / Create Completion",
  "config": {
    "model": "gpt-4o-2026-05-13",
    "messages": [
      { "role": "system", "content": "{{system_prompt_discovery}}" },
      { "role": "user", "content": "{{prepared_context}}" }
    ],
    "response_format": { "type": "json_object" },
    "temperature": 0.1,
    "max_tokens": 4000
  }
}
`

#### Anthropic Claude Configuration

`json
{
  "module": "HTTP / Make a Request",
  "config": {
    "url": "https://api.anthropic.com/v1/messages",
    "method": "POST",
    "headers": {
      "x-api-key": "{{secrets.ANTHROPIC_API_KEY}}",
      "anthropic-version": "2023-06-01",
      "content-type": "application/json"
    },
    "body": {
      "model": "claude-sonnet-4-20250514",
      "max_tokens": 4000,
      "temperature": 0.1,
      "system": "{{system_prompt_discovery}}",
      "messages": [{ "role": "user", "content": "{{prepared_context}}" }]
    }
  }
}
`

### Module 3: Parse Response

`json
{
  "module": "Tools / Parse JSON",
  "config": {
    "data": "{{ai.response.choices[0].message.content}}"
  }
}
`

### Module 4: Validate JSON

`json
{
  "module": "HTTP / Make a Request",
  "config": {
    "url": "https://api.example.com/validate-json",
    "method": "POST",
    "body": {
      "schema": "CompanyData",
      "data": "{{parsed_response}}"
    }
  }
}
`

### Module 5: Repair JSON (if invalid)

If the JSON is malformed, a repair attempt is made:

`json
{
  "module": "OpenAI / Create Completion",
  "config": {
    "model": "gpt-4o-mini",
    "messages": [
      { "role": "system", "content": "Fix this JSON to match the CompanyData schema. Return only the corrected JSON." },
      { "role": "user", "content": "{{raw_response}}" }
    ],
    "temperature": 0,
    "max_tokens": 4000
  }
}
`

### Module 6: Store Results

`json
{
  "module": "Supabase / Insert Row",
  "config": {
    "table": "ai_extractions",
    "columns": {
      "run_id": "{{run_id}}",
      "company_domain": "{{company_domain}}",
      "company_data": "{{validated_json}}",
      "confidence_scores": "{{extract_confidence(validated_json)}}",
      "model_used": "gpt-4o-2026-05-13",
      "processing_time_ms": "{{ai.response.headers['x-request-id'].elapsed}}"
    }
  }
}
`

### Module 7: Update Queue Status

`json
{
  "module": "Supabase / Update Row",
  "config": {
    "table": "scenario_queue",
    "filter": { "id": "{{queue.id}}" },
    "columns": {
      "status": "completed",
      "output_data": "{{validated_json}}",
      "updated_at": "{{now}}"
    }
  }
}
`

---

## Batch Processing

Companies are processed in batches of 5 to:

1. Respect AI API rate limits.
2. Enable parallel processing of the queue.
3. Keep each scenario execution under 30 minutes.

### Batch Logic

`python
def create_batches(companies, batch_size=5):
    for i in range(0, len(companies), batch_size):
        yield companies[i:i+batch_size]
`

Each batch runs sequentially. Within a batch, companies are processed one at a time to manage token usage and cost.

---

## Token Management

| Model | Input Context | Max Output | Cost per 1K Tokens |
|-------|--------------|------------|-------------------|
| GPT-4o | 128K | 16K | .50 / .00 |
| Claude Sonnet 4 | 200K | 8K | .00 / .00 |

The platform uses GPT-4o by default. Claude is used as a fallback when OpenAI rate limits are hit or when the input context exceeds 100K tokens.

### Cost Per Company

| Operation | Input Tokens | Output Tokens | Estimated Cost |
|-----------|-------------|---------------|----------------|
| Company analysis | ~8,000 | ~2,000 | ~.04 |
| Scoring | ~3,000 | ~1,000 | ~.02 |
| JSON repair (rare) | ~4,000 | ~2,000 | ~.02 |
| **Total per company** | | | **~.06** |

---

## AI Model Router

`mermaid
flowchart TD
    A[AI Request] --> B{Input Length}
    B -->|< 100K tokens| C[GPT-4o]
    B -->|>= 100K tokens| D[Claude Sonnet]
    C --> E{Success?}
    E -->|Yes| F[Parse Output]
    E -->|Rate Limited| D
    E -->|Error| G[Retry 3x]
    G --> C
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial AI Analysis Scenario documentation |
