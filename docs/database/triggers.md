# Triggers

> Database-level triggers enforce data integrity, maintain timestamps, and automate audit logging. All triggers are defined in `supabase/migrations/` and created with `CREATE OR REPLACE FUNCTION` + `CREATE TRIGGER`.

---

## `updated_at` Timestamps

Every table with an `updated_at` column uses a shared trigger function. This ensures consistent timestamp behavior across the schema — no application code needs to remember to set `updated_at`.

```sql
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Applied to each table that has updated_at
CREATE TRIGGER trg_companies_updated_at
    BEFORE UPDATE ON companies
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_leads_updated_at
    BEFORE UPDATE ON leads
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_companies_scores_updated_at
    BEFORE UPDATE ON companies_scores
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();
```

**Design note**: Only UPDATE triggers are needed. INSERT triggers for `created_at` use column-level `DEFAULT now()` instead, which is simpler and avoids trigger overhead on inserts.

---

## Audit Logging Trigger

A single generic trigger function captures changes to all tracked tables. The trigger is added to each table that requires audit coverage.

```sql
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS trigger AS $$
DECLARE
    v_old_data jsonb;
    v_new_data jsonb;
    v_operation text;
BEGIN
    v_operation := TG_OP;

    IF TG_OP = 'DELETE' THEN
        v_old_data := row_to_json(OLD)::jsonb;
        v_new_data := '{}'::jsonb;
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_data := row_to_json(OLD)::jsonb;
        v_new_data := row_to_json(NEW)::jsonb;
    ELSIF TG_OP = 'INSERT' THEN
        v_old_data := '{}'::jsonb;
        v_new_data := row_to_json(NEW)::jsonb;
    END IF;

    INSERT INTO audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
    VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id::text, OLD.id::text),
        v_operation,
        v_old_data,
        v_new_data,
        current_setting('app.changed_by', true)
    );

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Attach to tracked tables
CREATE TRIGGER trg_companies_audit
    AFTER INSERT OR UPDATE OR DELETE ON companies
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER trg_leads_audit
    AFTER INSERT OR UPDATE OR DELETE ON leads
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER trg_leads_events_audit
    AFTER INSERT OR UPDATE OR DELETE ON leads_events
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();
```

The `app.changed_by` session variable is set by the application before making changes:

```sql
SET app.changed_by = 'make.com/weekly-scoring-scenario';
```

If not set, the default `system` value from the `audit_log` table definition is used. This approach avoids hardcoding pipeline stage names in the trigger function and allows any component — Make.com, Edge Functions, or manual SQL — to identify itself.

---

## Notification Triggers

Triggers that notify external systems when specific events occur. These use `pg_notify` for LISTEN/NOTIFY integration with Supabase Realtime or Edge Functions.

### Lead State Change Notification

```sql
CREATE OR REPLACE FUNCTION notify_lead_state_change()
RETURNS trigger AS $$
BEGIN
    IF OLD.state IS DISTINCT FROM NEW.state THEN
        PERFORM pg_notify(
            'lead_state_changes',
            json_build_object(
                'lead_id', NEW.id,
                'company_id', NEW.company_id,
                'old_state', OLD.state,
                'new_state', NEW.state,
                'priority_band', NEW.priority_band
            )::text
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_leads_notify_state
    AFTER UPDATE OF state ON leads
    FOR EACH ROW
    EXECUTE FUNCTION notify_lead_state_change();
```

### High-Value Lead Alert

```sql
CREATE OR REPLACE FUNCTION notify_high_value_lead()
RETURNS trigger AS $$
BEGIN
    IF NEW.total_score >= 500 THEN
        PERFORM pg_notify(
            'high_value_leads',
            json_build_object(
                'company_id', NEW.company_id,
                'total_score', NEW.total_score,
                'scored_at', NEW.scored_at
            )::text
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_scores_notify_high_value
    AFTER INSERT ON companies_scores
    FOR EACH ROW
    EXECUTE FUNCTION notify_high_value_lead();
```

**Supabase Realtime integration**: The `pg_notify` channels are consumed by Supabase Edge Functions that forward alerts to Telegram. The `lead_state_changes` channel triggers a Telegram notification for state transitions to `meeting_booked` or `deal`. The `high_value_leads` channel triggers a daily digest of top-scoring companies.

---

## Score Computation Trigger

Automatically computes `total_score` when all pillar scores are available. This eliminates the need for an explicit scoring step in the pipeline — scores are computed as soon as the data is complete.

```sql
CREATE OR REPLACE FUNCTION auto_compute_total_score()
RETURNS trigger AS $$
BEGIN
    NEW.total_score := COALESCE(NEW.growth_score, 0) +
                       COALESCE(NEW.space_need_score, 0) +
                       COALESCE(NEW.financial_health_score, 0) +
                       COALESCE(NEW.industry_trend_score, 0) +
                       COALESCE(NEW.decision_maker_access_score, 0) +
                       COALESCE(NEW.digital_footprint_score, 0) +
                       COALESCE(NEW.funding_activity_score, 0) +
                       COALESCE(NEW.regulatory_exposure_score, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_scores_auto_total
    BEFORE INSERT OR UPDATE ON companies_scores
    FOR EACH ROW
    EXECUTE FUNCTION auto_compute_total_score();
```

**Why a trigger instead of application logic?**: The pipeline writes pillar scores individually in some scenarios (e.g., partial re-scoring after change detection). This trigger ensures `total_score` is always consistent with individual pillar scores, even if the application layer forgets to compute it. It is a safety net, not a primary computation path — under normal operation, the scoring agent computes total_score explicitly.
