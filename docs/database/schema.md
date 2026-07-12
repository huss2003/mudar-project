# Database Schema

> Complete entity-relationship model for the Jasfo platform. All tables live in the `public` schema.

## Entity Relationship Diagram

```mermaid
erDiagram
    COMPANIES {
        uuid id PK
        text company_name
        text domain
        text industry
        text employee_range
        text revenue_range
        text headquarters_city
        text headquarters_country
        int founded_year
        jsonb management_team
        jsonb tech_stack
        text description
        text firecrawl_source_url
        timestamptz discovered_at
        timestamptz created_at
        timestamptz updated_at
    }

    COMPANIES_SCORES {
        uuid id PK
        uuid company_id FK
        int growth_score
        int space_need_score
        int financial_health_score
        int industry_trend_score
        int decision_maker_access_score
        int digital_footprint_score
        int funding_activity_score
        int regulatory_exposure_score
        int total_score
        int confidence_score
        text score_version
        timestamptz scored_at
    }

    COMPANIES_SNAPSHOTS {
        uuid id PK
        uuid company_id FK
        text sha256_hash
        jsonb snapshot_data
        timestamptz captured_at
    }

    LEADS {
        uuid id PK
        uuid company_id FK
        text state
        int priority_band
        timestamptz entered_state_at
        timestamptz cooldown_until
        boolean is_watchlisted
        timestamptz created_at
        timestamptz updated_at
    }

    LEADS_EVENTS {
        uuid id PK
        uuid lead_id FK
        text event_type
        text old_state
        text new_state
        jsonb metadata
        timestamptz occurred_at
    }

    EVIDENCE_CLAIMS {
        uuid id PK
        uuid company_id FK
        text claim_text
        text claim_category
        int confidence_score
        int source_count
        boolean is_verified
        timestamptz created_at
    }

    EVIDENCE_SOURCES {
        uuid id PK
        uuid claim_id FK
        text source_url
        text source_type
        int reliability_tier
        text extracted_content
        timestamptz captured_at
    }

    EVIDENCE_SNAPSHOTS {
        uuid id PK
        uuid company_id FK
        jsonb bundle
        text sha256_hash
        timestamptz captured_at
    }

    AUDIT_LOG {
        uuid id PK
        text table_name
        text record_id
        text operation
        jsonb old_data
        jsonb new_data
        text changed_by
        timestamptz changed_at
    }

    COMPANIES ||--o{ COMPANIES_SCORES : scores
    COMPANIES ||--o{ COMPANIES_SNAPSHOTS : snapshots
    COMPANIES ||--o{ LEADS : leads
    LEADS ||--o{ LEADS_EVENTS : events
    COMPANIES ||--o{ EVIDENCE_CLAIMS : claims
    EVIDENCE_CLAIMS ||--o{ EVIDENCE_SOURCES : sources
    COMPANIES ||--o{ EVIDENCE_SNAPSHOTS : evidence_snapshots
```

## Table Reference

| Table | Rows (Est.) | Size | Purpose |
|-------|-------------|------|---------|
| `companies` | 50,000 | ~50 MB | Core company profiles |
| `companies_scores` | 200,000 | ~80 MB | Scoring history per cycle |
| `companies_snapshots` | 200,000 | ~2 GB | Change detection snapshots |
| `leads` | 5,000 | ~5 MB | Active lead records |
| `leads_events` | 100,000 | ~50 MB | State transition history |
| `evidence_claims` | 500,000 | ~200 MB | Per-company evidence claims |
| `evidence_sources` | 1,000,000 | ~500 MB | Source URLs + extracted content |
| `evidence_snapshots` | 50,000 | ~1 GB | Immutable evidence bundles |
| `audit_log` | 1,000,000 | ~300 MB | Change audit trail |

## Key Relationships

- **companies → companies_scores**: One-to-many. Each weekly scoring cycle produces a new score record. The latest record per company is resolved by `DISTINCT ON (company_id) ORDER BY scored_at DESC`.
- **companies → leads**: One-to-one (active leads). A company has at most one active lead record. Historical lead records are soft-deleted via state transitions.
- **evidence_claims → evidence_sources**: One-to-many. Each claim must have at least one source record. The 2-source verification rule is enforced at the application layer, not the database layer, to allow partial evidence during pipeline execution.
- **audit_log**: Standalone. References `table_name` and `record_id` as text fields rather than foreign keys, keeping the audit system decoupled from table schemas.

## Type Conventions

| Pattern | Used For | Example |
|---------|----------|---------|
| `uuid` | Primary keys, foreign keys | `id uuid DEFAULT gen_random_uuid()` |
| `text` | Names, URLs, descriptions | `company_name text NOT NULL` |
| `integer` | Scores (0–100), years | `growth_score integer CHECK (growth_score >= 0 AND growth_score <= 100)` |
| `jsonb` | Dynamic / nested data | `management_team jsonb DEFAULT '[]'` |
| `timestamptz` | All timestamps | `created_at timestamptz DEFAULT now()` |
| `boolean` | Flags | `is_verified boolean DEFAULT false` |
