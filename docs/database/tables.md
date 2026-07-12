# Detailed Table Documentation

> Column-level reference for every table in the public schema.

---

## `companies`

Core company profile. Populated by Layer 1 (Discovery) and enriched by Layer 7 (Enrichment). This is the central entity — most other tables reference it.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `company_name` | `text` | `NOT NULL` | Legal business name |
| `domain` | `text` | `UNIQUE NOT NULL` | Primary website domain |
| `industry` | `text` | | Normalized industry classification |
| `employee_range` | `text` | | e.g. "51-200" |
| `revenue_range` | `text` | | e.g. "$10M-$50M" |
| `headquarters_city` | `text` | | City from company location |
| `headquarters_country` | `text` | `DEFAULT 'India'` | Country |
| `founded_year` | `integer` | | Four-digit year |
| `management_team` | `jsonb` | `DEFAULT '[]'` | `[{name, title, linkedin_url}]` |
| `tech_stack` | `jsonb` | `DEFAULT '[]'` | `[{technology, category}]` |
| `description` | `text` | | Company description from website |
| `firecrawl_source_url` | `text` | | Original scrape entry URL |
| `discovered_at` | `timestamptz` | `DEFAULT now()` | When first discovered |
| `created_at` | `timestamptz` | `DEFAULT now()` | Row creation timestamp |
| `updated_at` | `timestamptz` | `DEFAULT now()` | Row update timestamp |

**Indexes**: `idx_companies_domain` (unique), `idx_companies_industry`, `idx_companies_created_at`.

**Example row:**
```json
{
  "id": "a1b2c3d4-...",
  "company_name": "TechNova Solutions",
  "domain": "technova.in",
  "industry": "Information Technology",
  "employee_range": "201-500",
  "revenue_range": "$50M-$100M",
  "headquarters_city": "Pune",
  "headquarters_country": "India",
  "founded_year": 2015,
  "management_team": [{"name": "Priya Sharma", "title": "CEO", "linkedin_url": "https://linkedin.com/in/..."}],
  "tech_stack": [{"technology": "React", "category": "Frontend"}],
  "description": "Enterprise SaaS platform for supply chain optimization.",
  "discovered_at": "2026-07-10T00:00:00Z",
  "created_at": "2026-07-10T00:00:00Z",
  "updated_at": "2026-07-10T00:00:00Z"
}
```

---

## `companies_scores`

Per-cycle scoring records. Each weekly pipeline run inserts new scores; historical records support trend analysis.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `company_id` | `uuid` | `FK → companies.id NOT NULL` | Referenced company |
| `growth_score` | `integer` | `CHECK 0-100` | Headcount + revenue trajectory |
| `space_need_score` | `integer` | `CHECK 0-100` | Lease expiration, office listings |
| `financial_health_score` | `integer` | `CHECK 0-100` | Funding, profitability signals |
| `industry_trend_score` | `integer` | `CHECK 0-100` | Sector tailwinds |
| `decision_maker_access_score` | `integer` | `CHECK 0-100` | Contact findability |
| `digital_footprint_score` | `integer` | `CHECK 0-100` | Website + social media activity |
| `funding_activity_score` | `integer` | `CHECK 0-100` | Recent funding rounds |
| `regulatory_exposure_score` | `integer` | `CHECK 0-100` | Compliance-driven moves |
| `total_score` | `integer` | `CHECK 0-800` | Sum of all pillars |
| `confidence_score` | `integer` | `CHECK 0-100` | Evidence confidence aggregate |
| `score_version` | `text` | `DEFAULT 'v1'` | Scoring algorithm version |
| `scored_at` | `timestamptz` | `DEFAULT now()` | When scoring completed |

**Indexes**: `idx_scores_company_scored` on `(company_id, scored_at DESC)`, `idx_scores_total` on `total_score DESC`.

---

## `companies_snapshots`

Weekly SHA-256 snapshots of all company signals. Used for change detection between pipeline runs.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `company_id` | `uuid` | `FK → companies.id NOT NULL` | Referenced company |
| `sha256_hash` | `text` | `NOT NULL` | Hash of canonical signal fields |
| `snapshot_data` | `jsonb` | `NOT NULL` | Full signal payload |
| `captured_at` | `timestamptz` | `DEFAULT now()` | Snapshot timestamp |

**Indexes**: `idx_snapshots_company_hash` on `(company_id, sha256_hash)`, `idx_snapshots_captured` on `captured_at`.

---

## `leads`

Active lead state machine records. One row per qualified lead.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `company_id` | `uuid` | `FK → companies.id UNIQUE NOT NULL` | Referenced company |
| `state` | `text` | `NOT NULL DEFAULT 'new'` | Current state: new, qualified, contacted, meeting_booked, deal, lost, dormant, archived |
| `priority_band` | `integer` | `CHECK 1-5` | 1=Critical, 2=Hot, 3=Warm, 4=Cool, 5=Cold |
| `entered_state_at` | `timestamptz` | `DEFAULT now()` | When current state was entered |
| `cooldown_until` | `timestamptz` | | When cooldown expires (nullable) |
| `is_watchlisted` | `boolean` | `DEFAULT false` | Flagged for monitoring |
| `created_at` | `timestamptz` | `DEFAULT now()` | Row creation |
| `updated_at` | `timestamptz` | `DEFAULT now()` | Row update |

**Indexes**: `idx_leads_state` on `state`, `idx_leads_priority` on `priority_band`, `idx_leads_cooldown` on `cooldown_until`.

---

## `leads_events`

Immutable event log for every lead state transition and touchpoint.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `lead_id` | `uuid` | `FK → leads.id NOT NULL` | Referenced lead |
| `event_type` | `text` | `NOT NULL` | e.g. state_changed, contacted, note_added |
| `old_state` | `text` | | Previous state (null for creation) |
| `new_state` | `text` | | New state |
| `metadata` | `jsonb` | `DEFAULT '{}'` | Arbitrary event payload |
| `occurred_at` | `timestamptz` | `DEFAULT now()` | When event happened |

**Indexes**: `idx_events_lead` on `lead_id`, `idx_events_type` on `event_type`, `idx_events_occurred` on `occurred_at DESC`.

---

## `evidence_claims`

Individual factual claims extracted by Agent analysis. Each claim must be traceable to one or more source URLs.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `company_id` | `uuid` | `FK → companies.id NOT NULL` | Referenced company |
| `claim_text` | `text` | `NOT NULL` | The factual statement |
| `claim_category` | `text` | `NOT NULL` | growth, space, financial, team, etc. |
| `confidence_score` | `integer` | `CHECK 0-100 DEFAULT 0` | Claim-level confidence |
| `source_count` | `integer` | `DEFAULT 0` | Number of supporting sources |
| `is_verified` | `boolean` | `DEFAULT false` | 2+ sources confirmed? |
| `created_at` | `timestamptz` | `DEFAULT now()` | Row creation |

**Indexes**: `idx_claims_company` on `company_id`, `idx_claims_verified` on `is_verified`, `idx_claims_category` on `claim_category`.

---

## `evidence_sources`

Source URLs backing each claim. One claim may have multiple sources; one source belongs to exactly one claim.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `claim_id` | `uuid` | `FK → evidence_claims.id NOT NULL` | Referenced claim |
| `source_url` | `text` | `NOT NULL` | Full URL to source |
| `source_type` | `text` | `NOT NULL` | website, news, linkedin, crunchbase, etc. |
| `reliability_tier` | `integer` | `CHECK 1-5 DEFAULT 3` | 1=highest, 5=lowest |
| `extracted_content` | `text` | | Full-text extraction |
| `captured_at` | `timestamptz` | `DEFAULT now()` | When source was captured |

**Indexes**: `idx_sources_claim` on `claim_id`, `idx_sources_url` on `source_url`.

---

## `evidence_snapshots`

Immutable timestamped bundles of all evidence for a company at pipeline completion time. Enables audit and explainability.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `company_id` | `uuid` | `FK → companies.id NOT NULL` | Referenced company |
| `bundle` | `jsonb` | `NOT NULL` | Complete evidence payload |
| `sha256_hash` | `text` | `NOT NULL` | Integrity hash |
| `captured_at` | `timestamptz` | `DEFAULT now()` | Snapshot timestamp |

**Indexes**: `idx_ev_snapshots_company` on `company_id`, `idx_ev_snapshots_hash` on `sha256_hash UNIQUE`.

---

## `audit_log`

Append-only log of all data changes across tracked tables.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | `uuid` | `PK DEFAULT gen_random_uuid()` | Unique identifier |
| `table_name` | `text` | `NOT NULL` | Affected table |
| `record_id` | `text` | `NOT NULL` | Affected record UUID as text |
| `operation` | `text` | `NOT NULL` | INSERT, UPDATE, DELETE |
| `old_data` | `jsonb` | | Pre-change values |
| `new_data` | `jsonb` | | Post-change values |
| `changed_by` | `text` | `DEFAULT 'system'` | Pipeline component identifier |
| `changed_at` | `timestamptz` | `DEFAULT now()` | Change timestamp |

**Indexes**: `idx_audit_table` on `table_name`, `idx_audit_record` on `record_id`, `idx_audit_changed` on `changed_at DESC`.
