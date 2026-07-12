-- ============================================================================
-- Jasfo Lead Intelligence Platform — Postgres Functions
-- Supabase PostgreSQL 16 | LANGUAGE plpgsql
-- ============================================================================
-- All server-side functions for scoring, change detection, maintenance,
-- notifications, and state machine enforcement.
-- ============================================================================

-- 1. TRIGGER HELPERS ---------------------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION set_updated_at() IS 'Shared trigger: sets updated_at on row UPDATE.';

-- 2. SCORING FUNCTIONS -------------------------------------------------------

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
    FROM lead_scores
    WHERE id = p_score_id;

    UPDATE lead_scores
    SET total_score = v_total
    WHERE id = p_score_id;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_total_score(uuid) IS 'Aggregates 8 pillar scores into total (0-800). Idempotent.';

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

COMMENT ON FUNCTION auto_compute_total_score() IS 'Trigger: auto-computes total_score BEFORE INSERT OR UPDATE on lead_scores.';

-- 3. CHANGE DETECTION FUNCTIONS ----------------------------------------------

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

COMMENT ON FUNCTION compute_company_hash(uuid) IS 'SHA-256 hash of canonical signal fields for change detection.';

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
    SELECT cs.sha256_hash, cs.snapshot_data
    INTO v_previous_hash, v_prev_snapshot
    FROM companies_snapshots cs
    WHERE cs.company_id = p_company_id
    ORDER BY cs.captured_at DESC
    LIMIT 1;

    v_current_hash := compute_company_hash(p_company_id);

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

COMMENT ON FUNCTION detect_changes(uuid) IS 'Compares current hash vs most recent snapshot. Returns delta structure.';

-- 4. MAINTENANCE FUNCTIONS ---------------------------------------------------

CREATE OR REPLACE FUNCTION expire_cooldowns()
RETURNS TABLE (
    decision_id uuid,
    company_name text,
    cooldown_was_until timestamptz
) AS $$
BEGIN
    RETURN QUERY
    UPDATE decisions d
    SET cooldown_until = NULL,
        updated_at = now()
    FROM companies c
    WHERE d.company_id = c.id
      AND d.cooldown_until IS NOT NULL
      AND d.cooldown_until < now()
      AND d.state NOT IN ('lost', 'archived')
    RETURNING d.id, c.company_name, d.cooldown_until;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION expire_cooldowns() IS 'Activates leads whose cooldown has expired. Called at weekly pipeline start.';

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

COMMENT ON FUNCTION prune_old_snapshots() IS 'Removes old snapshots (>180d), keeping 1 per week. Runs monthly.';

CREATE OR REPLACE FUNCTION prune_old_evidence_snapshots()
RETURNS integer AS $$
DECLARE
    v_deleted integer;
BEGIN
    DELETE FROM evidence_snapshots
    WHERE captured_at < now() - interval '365 days';
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION prune_old_evidence_snapshots() IS 'Deletes evidence snapshots older than 365 days.';

-- 5. STATE MACHINE FUNCTIONS ------------------------------------------------

CREATE OR REPLACE FUNCTION check_state_transition()
RETURNS trigger AS $$
BEGIN
    IF OLD.state IS DISTINCT FROM NEW.state THEN
        IF NOT EXISTS (
            SELECT 1 FROM (VALUES
                ('new', 'qualified'),
                ('new', 'lost'),
                ('qualified', 'contacted'),
                ('qualified', 'dormant'),
                ('contacted', 'meeting_booked'),
                ('contacted', 'lost'),
                ('meeting_booked', 'deal'),
                ('meeting_booked', 'lost'),
                ('meeting_booked', 'contacted'),
                ('lost', 'dormant'),
                ('dormant', 'qualified'),
                ('dormant', 'archived'),
                ('deal', 'archived')
            ) AS vt(from_state, to_state)
            WHERE from_state = OLD.state AND to_state = NEW.state
        ) THEN
            RAISE EXCEPTION 'Invalid state transition: % → %', OLD.state, NEW.state;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION check_state_transition() IS 'Trigger: enforces valid lead state transitions.';

CREATE OR REPLACE FUNCTION process_auto_transitions()
RETURNS TABLE (decision_id uuid, old_state text, new_state text) AS $$
BEGIN
    -- qualified -> dormant after 90 days no action
    RETURN QUERY
    UPDATE decisions d
    SET state = 'dormant',
        entered_state_at = now(),
        cooldown_until = now() + interval '90 days',
        updated_at = now()
    WHERE d.state = 'qualified'
      AND d.entered_state_at < now() - interval '90 days'
    RETURNING d.id, 'qualified', 'dormant';

    -- dormant -> archived after 365 days
    RETURN QUERY
    UPDATE decisions d
    SET state = 'archived',
        entered_state_at = now(),
        cooldown_until = NULL,
        updated_at = now()
    WHERE d.state = 'dormant'
      AND d.entered_state_at < now() - interval '365 days'
    RETURNING d.id, 'dormant', 'archived';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION process_auto_transitions() IS 'Weekly maintenance: advances leads through time-based transitions.';

-- 6. NOTIFICATION FUNCTIONS --------------------------------------------------

CREATE OR REPLACE FUNCTION notify_telegram(
    p_message text,
    p_chat_id bigint DEFAULT NULL
)
RETURNS void AS $$
DECLARE
    v_notification jsonb;
BEGIN
    v_notification := jsonb_build_object(
        'type', 'telegram',
        'chat_id', p_chat_id,
        'text', p_message,
        'created_at', now()
    );
    PERFORM pg_notify('jasfo_notifications', v_notification::text);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION notify_telegram(text, bigint) IS 'Sends Telegram notification via pg_notify channel.';

CREATE OR REPLACE FUNCTION notify_lead_state_change()
RETURNS trigger AS $$
BEGIN
    IF OLD.state IS DISTINCT FROM NEW.state THEN
        PERFORM pg_notify(
            'lead_state_changes',
            json_build_object(
                'decision_id', NEW.id,
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

COMMENT ON FUNCTION notify_lead_state_change() IS 'Trigger: notifies on decision state transitions via pg_notify.';

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

COMMENT ON FUNCTION notify_high_value_lead() IS 'Trigger: notifies when a lead scores 500+ (high value).';

-- 7. AUDIT FUNCTION ----------------------------------------------------------

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

COMMENT ON FUNCTION audit_trigger() IS 'Generic trigger: captures row changes to audit_log.';

-- 8. UTILITY FUNCTIONS -------------------------------------------------------

CREATE OR REPLACE FUNCTION should_reprocess(p_company_id uuid)
RETURNS text AS $$
DECLARE
    v_result text;
    v_last_score timestamptz;
    v_cooldown_until timestamptz;
    v_watchlisted boolean;
    v_hash_changed boolean;
BEGIN
    SELECT MAX(scored_at) INTO v_last_score
    FROM lead_scores
    WHERE company_id = p_company_id;

    IF v_last_score IS NULL THEN
        RETURN 'full_processing';
    END IF;

    SELECT d.cooldown_until, d.is_watchlisted
    INTO v_cooldown_until, v_watchlisted
    FROM decisions d
    WHERE d.company_id = p_company_id;

    IF v_cooldown_until IS NOT NULL AND v_cooldown_until > now() THEN
        RETURN 'in_cooldown';
    END IF;

    SELECT (cs1.sha256_hash IS DISTINCT FROM cs2.sha256_hash)
    INTO v_hash_changed
    FROM companies_snapshots cs1
    LEFT JOIN companies_snapshots cs2
        ON cs2.company_id = cs1.company_id
        AND cs2.captured_at < cs1.captured_at
    WHERE cs1.company_id = p_company_id
    ORDER BY cs1.captured_at DESC
    LIMIT 1;

    IF v_hash_changed THEN
        RETURN 'changed_detected';
    ELSIF v_watchlisted THEN
        RETURN 'watchlist_monitor';
    ELSE
        RETURN 'no_change_extend_cooldown';
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION should_reprocess(uuid) IS 'Determines if a company needs re-processing based on memory state.';

-- ============================================================================
-- END OF FUNCTIONS
-- ============================================================================
