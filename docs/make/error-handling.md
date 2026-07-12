# Error Handling

All Make.com scenarios implement a standardized error handling framework covering retry logic, error classification, notification, and rollback procedures.

---

## Error Classification

Errors are classified into four categories with distinct handling strategies:

| Category | Examples | Retry | Notify | Halt Scenario |
|----------|----------|-------|--------|---------------|
| **Transient** | HTTP 429, 502, 503, 504, timeout | Yes (3x) | No | No |
| **Auth** | HTTP 401, 403, API key invalid | No | Yes (critical) | Yes |
| **Data** | Invalid JSON, missing field, schema error | No | Yes (warning) | No |
| **Infra** | Database unreachable, disk full | Yes (2x) | Yes (critical) | Yes |

---

## Error Handling Architecture

`mermaid
flowchart TD
    A[Module Error] --> B[Error Router]
    B --> C{Error Type}
    C -->|Transient| D[Retry with Backoff]
    D --> E{Success?}
    E -->|Yes| F[Continue]
    E -->|No| G[Log & Skip]
    C -->|Auth| H[Halt Scenario]
    C -->|Data| I[Log Warning]
    I --> J[Skip Module]
    J --> K[Continue]
    C -->|Infra| H
    H --> L[Send Critical Alert]
    G --> M[Send Warning]
`

---

## Transient Error Retry

### Configuration

`json
{
  "retry_config": {
    "max_retries": 3,
    "initial_delay_ms": 1000,
    "backoff_factor": 2,
    "max_delay_ms": 30000,
    "retry_on_status": [429, 500, 502, 503, 504],
    "retry_on_errors": ["ECONNRESET", "ETIMEDOUT", "ENOTFOUND"]
  }
}
`

### Implementation

`json
{
  "module": "Flow Control / Repeater",
  "config": {
    "max_iterations": 3,
    "break_early": true
  },
  "modules": [
    {
      "module": "HTTP / Make a Request",
      "config": { "...": "..." }
    },
    {
      "module": "Flow Control / Router",
      "config": {
        "conditions": [
          { "label": "Transient", "condition": { "field": "http.status_code", "operator": "in_array", "value": [429, 500, 502, 503, 504] } },
          { "label": "Success", "condition": { "field": "http.status_code", "operator": "equals", "value": 200 } },
          { "label": "Non-Retryable", "condition": {} }
        ]
      }
    },
    {
      "module": "Flow Control / Sleep",
      "config": {
        "duration_ms": "{{calculate_delay(iteration)}}"
      }
    }
  ]
}
`

---

## Error Notification Templates

### Warning Message (Transient Errors Exhausted)

`json
{
  "module": "Telegram / Send Message",
  "config": {
    "chat_id": "{{secrets.TELEGRAM_ADMIN_CHAT_ID}}",
    "text": "⚠️ *Scraping Warning*\n\nCompany: {{company_domain}}\nModule: {{module_name}}\nError: {{error_message}}\nRetries exhausted ({{attempts}})\nAction: Company skipped\n\nRun ID: {{run_id}}"
  }
}
`

### Critical Alert (Auth/Infra Failure)

`json
{
  "module": "Telegram / Send Message",
  "config": {
    "chat_id": "{{secrets.TELEGRAM_ADMIN_CHAT_ID}}",
    "text": "🚨 *Critical Error — Scenario Halted*\n\nScenario: {{scenario_name}}\nModule: {{module_name}}\nError: {{error_message}}\n\nAction: Scenario halted. Manual intervention required.\n\nRun ID: {{run_id}}"
  }
}
`

---

## Data Error Handling

When the AI pipeline returns invalid data:

### Invalid JSON

`json
{
  "module": "Flow Control / Router",
  "config": {
    "conditions": [
      {
        "label": "Valid JSON",
        "condition": {
          "field": "parse_result",
          "operator": "exists"
        }
      },
      {
        "label": "Invalid JSON",
        "condition": {}
      }
    ]
  }
}
`

Invalid JSON triggers a repair attempt via a cheaper AI model. If repair fails twice, the company is marked as failed.

### Schema Validation Failure

When validated JSON does not match the expected schema:

`json
{
  "label": "Schema Error",
  "condition": {
    "field": "validation_result.valid",
    "operator": "equals",
    "value": false
  }
}
`

Schema errors are logged and the company is flagged for manual review. The raw data is preserved in the archive.

### Empty Response

If the AI returns an empty or nonsensical response:

1. Log the raw response for debugging.
2. Re-prompt with a simplified instruction.
3. If failure persists, mark as failed with reason "AI returned empty response."

---

## Scenario-Level Error Handling

### Rollback Procedures

If a scenario fails mid-batch:

1. **Mark remaining queue items as failed**: Prevents them from being processed with partial data.
2. **Log the error with full context**: Includes which company, module, and the error message.
3. **Send a critical notification**: Alerts the admin via Telegram.
4. **Preserve partial data**: Any completed items are kept and archived.

### Company-Level Errors

If a single company fails:

1. Mark that company's queue item as ailed.
2. Log the error with company and module context.
3. Move to the next company in the queue.
4. If consecutive failures exceed 5, send a warning notification.

### Recovery From Partial Failure

When a scenario resumes after failure:

1. Query the queue for items still in pending status.
2. Process remaining items normally.
3. Send a summary of failed items at completion.

`sql
SELECT COUNT(*) FROM scenario_queue
WHERE run_id = '{{run_id}}'
  AND status = 'pending';
`

---

## Error Logging

All errors are logged to the scenario_errors table:

`sql
CREATE TABLE scenario_errors (
  id SERIAL PRIMARY KEY,
  run_id UUID NOT NULL,
  scenario_name TEXT NOT NULL,
  company_domain TEXT,
  module_name TEXT,
  error_category TEXT NOT NULL,
  error_message TEXT,
  error_detail JSONB,
  status_code INTEGER,
  attempt_number INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial error handling documentation |
