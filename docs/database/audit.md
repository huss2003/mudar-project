# Audit Logging

> Immutable change-tracking system for the Jasfo database. Every INSERT, UPDATE, and DELETE on tracked tables is recorded with before/after values, a timestamp, and the pipeline component that made the change.

## Why Audit

The audit log serves three purposes:

1. **Debugging pipeline failures**: When a company's score changes unexpectedly, the audit log shows exactly which UPDATE statement caused the change, the old and new values, and which pipeline component was responsible.
2. **Evidence provenance**: The broker can trace any value in the Lead Intelligence Report back to its creation or modification event. This supports the Evidence First principle — every number has a verifiable history.
3. **Recovery**: If a pipeline run corrupts data, the audit log provides the old values needed to roll back. While automated rollback is not implemented, the audit log makes manual recovery feasible.

## Audit Table Schema

```sql
CREATE TABLE audit_log (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name  text NOT NULL,
    record_id   text NOT NULL,
    operation   text NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data    jsonb DEFAULT '{}',
    new_data    jsonb DEFAULT '{}',
    changed_by  text NOT NULL DEFAULT 'system',
    changed_at  timestamptz NOT NULL DEFAULT now()
);
```

The `table_name` and `record_id` columns store identifiers as text rather than as foreign keys. This keeps the audit table schema-independent — it does not need to be updated when tables are added or renamed. The `old_data` and `new_data` columns store complete row snapshots as JSONB, enabling full reconstruction of any record's state at any point in time.

## Trigger-Based Logging

The audit trigger is defined in `docs/database/triggers.md`. In summary, a single `audit_trigger()` function handles all tables by inspecting `TG_TABLE_NAME` and `TG_OP`. The trigger fires `AFTER INSERT OR UPDATE OR DELETE` on:

| Table | Audit Coverage | Rationale |
|-------|---------------|-----------|
| `companies` | Full | Core entity; track all profile changes |
| `companies_scores` | Full | Score changes affect lead priority |
| `leads` | Full | State transitions are critical |
| `leads_events` | Insert only | Events are append-only; no updates/deletes |
| `evidence_claims` | Full | Claim verification status is sensitive |
| `evidence_snapshots` | Insert only | Snapshots are immutable once written |
| `companies_snapshots` | Insert only | Snapshots are immutable once written |

Tables that are insert-only (events, snapshots) have audit triggers on INSERT only — there should never be an UPDATE or DELETE on these tables. If one occurs, the audit log captures it as an anomaly to investigate.

## Querying the Audit Log

### Get all changes for a specific record

```sql
SELECT changed_at, operation, changed_by,
       old_data - 'id' AS old_values,
       new_data - 'id' AS new_values
FROM audit_log
WHERE table_name = 'companies'
  AND record_id = 'a1b2c3d4-...'
ORDER BY changed_at DESC;
```

### Find what changed in the last pipeline run

```sql
SELECT table_name, record_id, operation, new_data, changed_by
FROM audit_log
WHERE changed_at > '2026-07-10T00:00:00Z'
  AND changed_by = 'make.com/weekly-scoring-scenario'
ORDER BY changed_at;
```

### Detect unexpected changes

```sql
SELECT table_name, record_id, operation, changed_by, changed_at
FROM audit_log
WHERE changed_by NOT IN ('system', 'make.com/weekly-scoring-scenario')
  AND changed_at > now() - interval '7 days'
ORDER BY changed_at DESC;
```

This query surfaces any manual changes made through Supabase Studio or ad-hoc SQL — useful for detecting unintended modifications.

## Setting the `changed_by` Context

Pipeline components identify themselves by setting the `app.changed_by` session variable before making changes:

**Make.com HTTP module:**
```
Content-Type: application/json
Prefer: params=app.changed_by=make.com/weekly-scoring-scenario
```

**Edge Function (JavaScript):**
```javascript
const { data, error } = await supabase.rpc('set_config', {
  name: 'app.changed_by',
  value: 'edge-function/change-detection'
});
```

**Direct SQL:**
```sql
SET app.changed_by = 'manual/broker-name';
```

If the variable is not set, the trigger defaults to `'system'`. This catch-all value indicates a change that came from an unidentified source — a signal worth investigating.

## Retention and Pruning

The audit log is append-only and grows without bound. Monthly pruning removes records older than 365 days:

```sql
CREATE OR REPLACE FUNCTION prune_audit_log()
RETURNS integer AS $$
DECLARE
    v_deleted integer;
BEGIN
    DELETE FROM audit_log
    WHERE changed_at < now() - interval '365 days';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;
```

Called via `pg_cron`:
```sql
SELECT cron.schedule('monthly-audit-prune', '0 3 1 * *',
  'SELECT prune_audit_log();'
);
```

**Justification for 365-day retention**: The audit log is the sole mechanism for tracing evidence provenance. A broker may need to verify a claim's history up to 12 months after the fact (e.g., during a portfolio review). Beyond 365 days, the storage cost (~300 MB/year) exceeds the value of the data, and old records are pruned.

## Limitations

- **No automated rollback**: The audit log captures old values but does not provide a rollback function. Recovery is a manual SQL process: query old_data, construct an UPDATE statement.
- **No cross-table transactions**: The audit log records changes per row, not per transaction. If a single pipeline run updates 100 companies, there are 100 audit log rows but no transaction ID to group them.
- **No DDL tracking**: Schema changes (ALTER TABLE, CREATE INDEX) are not captured. These are tracked through the migration files in `supabase/migrations/`.
