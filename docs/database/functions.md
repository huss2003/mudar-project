# Postgres Functions

> Server-side functions for scoring computation, change detection hashing, and maintenance operations. All functions are defined as `LANGUAGE plpgsql` and created via migration files.

---

## Scoring Functions

### `calculate_total_score()`

Aggregates the eight pillar scores into a total and applies the confidence multiplier. Called after all individual pillar scores have been inserted.

```sql
CREATE OR REPLACE FUNCTION calculate_total_score(p_score_id uuid)
RETURNS integer AS $$
DECLARE
    v_total integer;
    v_confidence integer;
BEGIN
    SELECT
        COALESCE(growth_score, 0) +
        COALESCE(space_need_score, 0) +
        COALESCE(financial_health_score, 0) +
        COALESCE(industry_trend_score, 0) +
        COALESCE(decision_maker_access_score, 0) +
        COALESCE(digital_footprint_score, 0) +
        COALESCE(funding_activity_score, 0) +
        COALESCE(regulatory_exposure_score, 0),
        confidence_score
    INTO v_total, v_confidence
    FROM companies_scores
    WHERE id = p_score_id;

    UPDATE companies_scores
    SET total_score = v_total
    WHERE id = p_score_id;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql;
```

**Usage**: Called by the scoring layer after all eight pillar scores have been written. The function is idempotent — calling it multiple times with the same score ID produces the same result.

---

## Change Detection Functions

### `compute_company_hash()`

Generates a SHA-256 hash of a company's canonical signal fields. Used by the change detection system to determine whether a company's profile has changed between pipeline runs.

```sql
CREATE OR REPLACE FUNCTION compute_company_hash(p_company_id uuid)
RETURNS text AS $$
DECLARE
    v_hash text;
BEGIN
    SELECT ENCODE(
        HMAC(
            COALESCE(c.employee_range, '') ||
            COALESCE(c.revenue_range, '') ||
            COALESCE(c.description, '') ||
            COALESCE(c.tech_stack::text, '') ||
            COALESCE(c.management_team::text, ''),
            c.id::text,
            'SHA256'
        ),
        'hex'
    )
    INTO v_hash
    FROM companies c
    WHERE c.id = p_company_id;

    RETURN v_hash;
END;
$$ LANGUAGE plpgsql;
```

**Usage**: Called before and after each pipeline run. The hash is stored in `companies_snapshots.sha256_hash`. If the hash differs from the previous snapshot, the company has changed and needs re-scoring. Only signal-relevant fields are included in the hash — metadata fields like `updated_at` and `discovered_at` are excluded to avoid false positives.

### `detect_changes()`

Compares a company's current hash against its most recent snapshot and returns a delta structure.

```sql
CREATE OR REPLACE FUNCTION detect_changes(p_company_id uuid)
RETURNS TABLE (
    has_changed boolean,
    previous_hash text,
    current_hash text,
    previous_snapshot jsonb,
    current_snapshot jsonb
) AS $$
DECLARE
    v_previous_hash text;
    v_current_hash text;
    v_prev_snapshot jsonb;
    v_curr_snapshot jsonb;
BEGIN
    -- Get previous snapshot
    SELECT cs.sha256_hash, cs.snapshot_data
    INTO v_previous_hash, v_prev_snapshot
    FROM companies_snapshots cs
    WHERE cs.company_id = p_company_id
    ORDER BY cs.captured_at DESC
    LIMIT 1;

    -- Compute current hash
    v_current_hash := compute_company_hash(p_company_id);

    -- Get current data as JSON
    SELECT row_to_json(c.*)::jsonb
    INTO v_curr_snapshot
    FROM companies c
    WHERE c.id = p_company_id;

    RETURN QUERY
    SELECT
        COALESCE(v_previous_hash != v_current_hash, true) AS has_changed,
        v_previous_hash,
        v_current_hash,
        v_prev_snapshot,
        v_curr_snapshot;
END;
$$ LANGUAGE plpgsql;
```

**Usage**: Called by the change-detection layer to decide whether a company needs re-scoring. If `has_changed` is false and the company is in cooldown, it is skipped. If changed, the delta is computed by comparing individual JSON fields.

---

## Maintenance Functions

### `prune_old_snapshots()`

Removes snapshot records older than 180 days, keeping at most one per week for archival purposes. Runs monthly.

```sql
CREATE OR REPLACE FUNCTION prune_old_snapshots()
RETURNS integer AS $$
DECLARE
    v_deleted integer;
BEGIN
    DELETE FROM companies_snapshots
    WHERE id IN (
        SELECT id FROM (
            SELECT id,
                   row_number() OVER (
                       PARTITION BY company_id, date_trunc('week', captured_at)
                       ORDER BY captured_at DESC
                   ) AS rn
            FROM companies_snapshots
            WHERE captured_at < now() - interval '180 days'
        ) sub
        WHERE rn > 1
    );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;
```

**Usage**: Called by `pg_cron` on the first day of each month. Reduces storage for the `companies_snapshots` table by collapsing old snapshots to one per week. The most recent 180 days of data are preserved at full granularity for change detection accuracy.

### `expire_cooldowns()`

Activates leads whose cooldown period has expired. Returns the number of leads re-activated.

```sql
CREATE OR REPLACE FUNCTION expire_cooldowns()
RETURNS TABLE (
    lead_id uuid,
    company_name text,
    cooldown_was_until timestamptz
) AS $$
BEGIN
    RETURN QUERY
    UPDATE leads l
    SET cooldown_until = NULL,
        updated_at = now()
    FROM companies c
    WHERE l.company_id = c.id
      AND l.cooldown_until IS NOT NULL
      AND l.cooldown_until < now()
      AND l.state NOT IN ('lost', 'archived')
    RETURNING l.id, c.company_name, l.cooldown_until;
END;
$$ LANGUAGE plpgsql;
```

**Usage**: Called at the start of each weekly pipeline run. Ensures leads whose cooldown has expired are eligible for re-scoring. Returns the affected leads so the orchestrator can log the activation events.
