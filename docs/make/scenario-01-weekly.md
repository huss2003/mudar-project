# Scenario 01: Weekly Master

The Master Weekly Scenario is the entry point for the Jasfo Lead Intelligence Platform's batch processing pipeline. It runs every Monday at 9:00 AM UTC and orchestrates all downstream scenarios.

---

## Trigger

**Schedule**: Every Monday 09:00 UTC

`	ext
0 9 * * 1
`

**Manual trigger**: The scenario can also be invoked manually with a custom CSV attachment for on-demand runs.

---

## Scenario Flow

`mermaid
flowchart TD
    A[Cron: Mon 9AM UTC] --> B[Load Company CSV]
    B --> C[Validate Companies]
    C --> D{Valid?}
    D -->|Yes| E[Clear Previous Queue]
    D -->|No| F[Log Validation Error]
    F --> G[Skip Company]
    G --> E
    E --> H[Enqueue Companies]
    H --> I[Send Start Notification]
    I --> J[Wait for Completion]
    J --> K[Collect Results]
    K --> L[Generate Summary]
    L --> M[Send Telegram Report]
`

---

## Modules

### Module 1: Cron Trigger

`json
{
  "module": "Schedule / Cron",
  "config": {
    "expression": "0 9 * * 1",
    "timezone": "UTC"
  }
}
`

### Module 2: Load Company CSV

The company list is loaded from a Supabase-stored CSV file:

`csv
company_name,domain,industry,priority
Acme Corp,acme.com,SaaS,high
Beta Inc,betainc.io,Fintech,medium
`

`json
{
  "module": "Supabase / Select Rows",
  "config": {
    "table": "company_queue",
    "filter": { "status": "pending", "scheduled_week": "{{formatDate(now, 'YYYY-WW')}}" }
  }
}
`

### Module 3: Validate Companies

Each company entry is validated before processing:

`json
{
  "module": "Flow Control / Router",
  "config": {
    "conditions": [
      { "field": "company_name", "operator": "exists" },
      { "field": "company_name", "operator": "length_greater_than", "value": 1 }
    ]
  }
}
`

Validation rules:
- Company name is required (min 2 characters).
- Domain is optional but validated for URL format if present.
- Industry is optional.
- Priority defaults to standard if not set.

### Module 4: Clear Queue

`json
{
  "module": "Supabase / Delete Rows",
  "config": {
    "table": "scenario_queue",
    "filter": { "run_id": "{{previous_run_id}}" }
  }
}
`

### Module 5: Enqueue Companies

Each validated company is inserted into the queue:

`json
{
  "module": "Supabase / Insert Row",
  "config": {
    "table": "scenario_queue",
    "columns": {
      "run_id": "{{uuid}}",
      "company_name": "{{company.company_name}}",
      "company_domain": "{{company.domain}}",
      "scenario_step": "discovery",
      "status": "pending"
    }
  }
}
`

Companies are inserted in parallel batches of 10 to improve throughput.

### Module 6: Send Start Notification

`json
{
  "module": "Telegram / Send Message",
  "config": {
    "chat_id": "{{secrets.TELEGRAM_CHANNEL_ID}}",
    "text": "📊 *Weekly Lead Intelligence Run Started*\n\nCompanies: {{company_count}}\nRun ID: {{run_id}}\nStarted: {{formatDate(now, 'YYYY-MM-DD HH:mm:ss')}} UTC\n\n⏳ Estimated completion: 90 minutes"
  }
}
`

### Module 7: Wait for Completion

The scenario polls the queue until all companies reach a terminal state:

`json
{
  "module": "Flow Control / Repeat",
  "config": {
    "max_iterations": 180,
    "interval_seconds": 30
  }
}
`

Terminal states: completed, ailed, skipped.

### Module 8: Collect Results

`json
{
  "module": "Supabase / Select Rows",
  "config": {
    "table": "scenario_queue",
    "filter": { "run_id": "{{run_id}}" },
    "sort": [{ "field": "company_name", "direction": "asc" }]
  }
}
`

### Module 9: Generate Summary

`json
{
  "module": "Tools / Aggregate",
  "config": {
    "summary_fields": [
      { "field": "status", "aggregate": "count_by_value" },
      { "field": "composite_score", "aggregate": "average" },
      { "field": "processing_time_ms", "aggregate": "sum" }
    ]
  }
}
`

### Module 10: Send Telegram Report

`json
{
  "module": "Telegram / Send Message",
  "config": {
    "chat_id": "{{secrets.TELEGRAM_CHANNEL_ID}}",
    "text": "✅ *Weekly Run Complete*\n\nCompleted: {{completed_count}} / {{total_count}}\nFailed: {{failed_count}}\nAvg Score: {{avg_score}}/100\nDuration: {{duration_minutes}} min\n\nRun ID: {{run_id}}"
  }
}
`

---

## Data Flow

`mermaid
sequenceDiagram
    participant C as Cron
    participant M as Master Scenario
    participant Q as Supabase Queue
    participant S as Sub-Scenarios
    participant T as Telegram

    C->>M: Trigger Monday 9AM
    M->>M: Load and validate companies
    M->>Q: Enqueue 250 companies
    M->>T: Start notification
    loop Every 30s
        M->>Q: Check progress
        Q-->>M: { completed: 120, total: 250 }
    end
    Q->>S: Process pipeline
    S-->>Q: Update status
    M->>Q: Final status query
    M->>T: Weekly summary report
`

---

## Error Handling

| Error | Action |
|-------|--------|
| CSV parse error | Log error, skip row, continue |
| Empty company list | Send warning, halt scenario |
| Queue write failure | Retry 3x, then halt |
| Sub-scenario timeout | Mark as failed, continue |

---

## Monitoring Output

`json
{
  "run_id": "run-2026-07-14-001",
  "triggered_at": "2026-07-14T09:00:00Z",
  "completed_at": "2026-07-14T10:25:00Z",
  "total_companies": 250,
  "completed": 235,
  "failed": 12,
  "skipped": 3,
  "avg_composite_score": 47,
  "total_processing_time_ms": 5100000,
  "credits_consumed": 515
}
`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial Master Scenario documentation |
