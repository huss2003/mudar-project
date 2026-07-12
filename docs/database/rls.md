# Row Level Security

> RLS policies for the Jasfo Supabase database. Currently configured for single-user operation with a design path toward multi-user.

## Current State: Single-User Mode

All tables currently have **RLS enabled but with a single permissive policy**. This reflects the Lazy-First principle — the platform has exactly one broker, so access control is minimal. The service role key used by Make.com and Edge Functions bypasses RLS entirely.

```sql
-- Single-user policy: all authenticated users can read/write everything
CREATE POLICY "single_user_full_access"
    ON companies
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');
```

This policy is applied uniformly across all tables. It checks only that the request comes from an authenticated Supabase user — it does not filter by `user_id` because no `user_id` column exists. In practice, all production access goes through the service role key, which bypasses RLS. The authenticated-user policy exists primarily to support future Supabase Studio access and ad-hoc queries from authenticated sessions.

## Future State: Multi-User Design

When the platform expands to multiple brokers (each with their own territory or client portfolio), the schema and RLS policies will be updated as follows:

### Schema Changes

Each table will gain a `user_id` column:

```sql
ALTER TABLE companies ADD COLUMN user_id uuid REFERENCES auth.users(id);
ALTER TABLE leads ADD COLUMN user_id uuid REFERENCES auth.users(id);
ALTER TABLE evidence_claims ADD COLUMN user_id uuid REFERENCES auth.users(id);
-- etc.
```

Existing rows will be assigned to the default broker's user ID via a migration script. New rows inserted by Make.com will include the target `user_id`.

### RLS Policies

```sql
-- Per-broker isolation
CREATE POLICY "user_isolated_companies"
    ON companies
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Global read for admin roles
CREATE POLICY "admin_read_companies"
    ON companies
    FOR SELECT
    USING (auth.jwt() ->> 'role' = 'admin');
```

### Policy Categories

| Policy | Scope | Effect |
|--------|-------|--------|
| `user_isolated_*` | ALL tables with user_id | Broker can only see their own data |
| `admin_read_*` | Read-only on all tables | Admin can audit any broker's data |
| `shared_watchlists` | leads table | Brokers in same team can see shared watchlists |
| `evidence_cross_reference` | evidence_sources | Read-only access to other brokers' sources (for dedup) |

### Service Role Exception

Make.com and Edge Functions will continue to use the service role key, bypassing RLS. The `user_id` column will be set explicitly by the pipeline based on the broker assignment for each lead cycle. This means the pipeline is responsible for data isolation — it must write to the correct `user_id` — while RLS enforces isolation at the query layer.

## Policy Definitions (Multi-User)

When multi-user mode is activated, the following policies will replace the current permissive policy:

### `companies`

```sql
-- Broker can manage their own companies
CREATE POLICY "broker_manage_companies"
    ON companies FOR ALL
    USING (user_id = auth.uid());

-- Admin can read all
CREATE POLICY "admin_read_companies"
    ON companies FOR SELECT
    USING (auth.jwt() ->> 'role' = 'admin');
```

### `leads`

```sql
-- Broker can manage their own leads
CREATE POLICY "broker_manage_leads"
    ON leads FOR ALL
    USING (user_id = auth.uid());

-- Shared watchlists visible to team
CREATE POLICY "team_shared_watchlists"
    ON leads FOR SELECT
    USING (
        is_watchlisted = true
        AND user_id IN (
            SELECT team_member_id FROM broker_teams
            WHERE broker_id = auth.uid()
        )
    );
```

### `evidence_claims` and `evidence_sources`

```sql
-- Broker can read their own evidence
CREATE POLICY "broker_evidence_access"
    ON evidence_claims FOR ALL
    USING (user_id = auth.uid());

-- Cross-reference read for deduplication
CREATE POLICY "cross_reference_sources"
    ON evidence_sources FOR SELECT
    USING (true);
```

## Implementation Checklist

When multi-user support is activated:

1. Add `user_id` columns to all data tables
2. Backfill existing rows with the default broker's UUID
3. Migrate RLS from single permissive policy to per-user policies
4. Update Make.com scenarios to set `user_id` on insert
5. Add `broker_teams` junction table for team-based sharing
6. Add `auth.jwt()` role-checking for admin functions

Until then, the single permissive policy and service-role-only access pattern keep the security surface small and simple.
