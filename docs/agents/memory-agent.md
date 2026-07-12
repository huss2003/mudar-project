# Memory Agent

> **Layer 4 — Lead memory management. Tracks which leads have been seen before. Cooldown periods. Hash-based change detection initiator.**

---

## Purpose

The Memory Agent is the platform's persistent memory layer. It maintains a complete history of every company that has ever been evaluated — including all scores, contact history, broker feedback, and profile hashes — in a Supabase-backed database. Before any new batch enters the Discovery Agent, the Memory Agent checks every domain against the historical store to determine: (a) has this company been seen before? (b) is it in a cooldown period? (c) has its profile changed since the last evaluation?

This agent prevents the platform from re-processing companies that were recently evaluated, re-contacting companies that explicitly declined, or spending compute resources on stale leads. It is the system's guard against wasted cycles and broker reputation damage from over-communication.

---

## Implementation

| Property | Value |
|----------|-------|
| **Model** | Hash-based (no LLM) |
| **Storage** | Supabase (PostgreSQL) |
| **Hash algorithm** | SHA-256 |
| **Avg latency per lookup** | < 5ms |
| **Batch throughput** | 15,000 lookups in < 30 seconds |
| **Cooldown default** | 90 days |

---

## Memory Database Schema

```sql
CREATE TABLE leads (
    domain_hash TEXT PRIMARY KEY,
    domain TEXT NOT NULL,
    company_name TEXT,
    first_seen TIMESTAMP,
    last_evaluated TIMESTAMP,
    last_contacted TIMESTAMP,
    evaluation_count INTEGER DEFAULT 1,
    cooldown_until TIMESTAMP,
    status TEXT DEFAULT 'active'
);

CREATE TABLE evaluation_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_hash TEXT NOT NULL,
    run_id TEXT NOT NULL,
    evaluated_at TIMESTAMP NOT NULL,
    consensus_score REAL,
    post_reflection_score REAL,
    pillar_scores TEXT,        -- JSON
    judge_verdict TEXT,
    broker_feedback TEXT,      -- JSON, nullable
    profile_hash TEXT,
    evidence_package_ref TEXT, -- file path
    FOREIGN KEY (domain_hash) REFERENCES leads(domain_hash)
);

CREATE TABLE change_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    domain_hash TEXT NOT NULL,
    detected_at TIMESTAMP NOT NULL,
    change_type TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    triggered_revaluation BOOLEAN DEFAULT 0,
    FOREIGN KEY (domain_hash) REFERENCES leads(domain_hash)
);
```

---

## Cooldown Logic

The Memory Agent enforces cooldown periods based on lead status:

| Status | Cooldown | Rationale |
|--------|----------|-----------|
| Never contacted | 90 days | Standard cycle |
| Contacted — no response | 120 days | Avoid spamming |
| Contacted — negative response | 180 days | Respect explicit disinterest |
| Contacted — meeting booked | 365 days | Active deal in progress |
| Deal closed | Lifetime | Never re-target |
| Deal lost to competitor | 365 days | Revisit after competitive cycle ends |
| Force re-evaluation | 0 days | Change event triggered override |
| Manual pool (40–59 score) | 60 days | Faster recycle for borderline leads |

---

## Profile Hashing

Every company's profile produces a SHA-256 hash at evaluation time:

```
hash_input = concat(
    normalized_company_name,
    micromarket,
    employee_band,
    revenue_band,
    sorted(tech_stack),
    sorted(management_team),
    hq_city,
    pune_presence
)

profile_hash = SHA-256(hash_input)
```

The hash is stored in `evaluation_history`. On subsequent runs, the Memory Agent recomputes the hash from new normalized data and compares. A different hash means the profile has changed.

---

## Output: Filtered Target List

```json
{
  "batch_id": "uuid",
  "total_domains_checked": 12500,
  "new_domains": 8200,
  "existing_domains": 4300,
  "cooldown_active": 1100,
  "cooldown_breakdown": {
    "never_contacted": 420,
    "contacted_no_response": 310,
    "contacted_negative": 80,
    "meeting_booked": 190,
    "deal_lost": 100
  },
  "force_revaluation": 23,
  "change_events_found": 23,
  "change_types": {
    "funding": 5,
    "leadership": 4,
    "growth": 8,
    "website": 6
  },
  "final_target_list_size": 10223,
  "processing_time_ms": 1850
}
```

---

## Broker Feedback Storage

The Memory Agent stores all broker feedback per lead:

```json
{
  "lead_id": "uuid",
  "action_taken": "email_sent",
  "response": "positive",
  "meeting_booked": true,
  "deal_value": null,
  "feedback_text": "CEO was interested but wants to wait until their lease expires in March.",
  "rating": 4,
  "timestamp": "2026-07-14T15:30:00Z"
}
```

Feedback is used by the Learning Agent to calibrate scores and prompts over time.

---

## Maintenance

The memory database is compacted monthly: `evaluation_history` rows older than 2 years are archived to cold storage (compressed JSONL). The `leads` table retains all rows — no company is ever deleted, only status-updated to `archived` after 5 years of inactivity. Database size is approximately 500MB per 100,000 companies evaluated.

---

## Performance

| Metric | Value | Target |
|--------|-------|--------|
| Lookup throughput | 15K domains / 30s | 15K / 60s |
| Cooldown compliance | 100% | 100% |
| False skip rate | 0.2% | < 1% |
| Force re-evaluation rate | 0.18% | 0.1–0.5% |
| Database growth | ~5MB/week | < 10MB/week |
