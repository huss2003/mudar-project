# Source URLs and Permanence

> How evidence links to its source URLs, the strategy for maintaining URL permanence, and the archive fallback when sources disappear.

## Evidence-to-Source Linkage

Every claim in `evidence_claims` is linked to one or more source URLs through the `evidence_sources` table. The relationship is many-to-many at the logical level (one claim may cite multiple URLs; one URL may support multiple claims) but is implemented as a one-to-many in the current schema (each source row belongs to one claim) for simplicity.

```mermaid
flowchart LR
    subgraph evidence_claims
        C1[Claim: "Hired 200 people<br/>in Q2 2026"]
        C2[Claim: "Lease expires<br/>Dec 2026"]
    end
    subgraph evidence_sources
        S1[Source: linkedin.com/...<br/>Tier 2]
        S2[Source: economictimes.in/...<br/>Tier 3]
        S3[Source: blog.technova.in/...<br/>Tier 1]
        S4[Source: crunchbase.com/...<br/>Tier 2]
    end
    C1 --> S1
    C1 --> S2
    C1 --> S3
    C2 --> S4
```

The `evidence_sources` table stores:

- `source_url`: The full URL to the original source
- `source_type`: Classification (website, news, linkedin, crunchbase, etc.)
- `reliability_tier`: 1–5 classification
- `extracted_content`: Full-text extraction from the URL
- `captured_at`: When the content was captured

The extracted content is critical — if the URL later becomes inaccessible, the extracted text serves as the evidentiary record.

## URL Permanence Strategy

URLs can disappear. Companies restructure their websites. News articles go behind paywalls. LinkedIn profiles change. The platform handles this with a three-layer strategy:

### Layer 1: Immediate Capture

When a source URL is first referenced, the platform immediately extracts the full text content using Firecrawl's `extract` endpoint. The extracted text is stored in `evidence_sources.extracted_content`. This happens synchronously — the pipeline does not proceed until the extraction completes.

```json
{
  "source_url": "https://economictimes.indiatimes.com/...",
  "extracted_content": "TechNova Solutions, a Pune-based SaaS company, has announced...",
  "captured_at": "2026-07-10T14:30:00Z",
  "content_length": 2450
}
```

### Layer 2: Firecrawl Cache

Firecrawl caches extracted content for 30 days. If the same URL is revisited within that window, the cached version is returned — no re-scrape needed. This cache is independent of the database storage.

### Layer 3: Internet Archive Fallback

If a URL is accessed more than 30 days after capture and returns a 404 or 410, the platform falls back to the Internet Archive Wayback Machine:

```sql
-- Check if a stored URL is still accessible
CREATE OR REPLACE FUNCTION check_source_url(p_source_id uuid)
RETURNS text AS $$
DECLARE
    v_url text;
    v_status integer;
BEGIN
    SELECT s.source_url INTO v_url
    FROM evidence_sources s
    WHERE s.id = p_source_id;

    -- Attempt HTTP HEAD request (simplified)
    -- In practice, this calls an Edge Function
    -- If 200: return 'accessible'
    -- If 404/410: return 'dead'
    -- If timeout: return 'unknown'
    
    RETURN 'accessible'; -- placeholder
END;
$$ LANGUAGE plpgsql;
```

When a source URL is dead, the platform appends an archive.org URL to the source record:

```json
{
  "source_url": "https://original.url.com/article",
  "archive_url": "https://web.archive.org/web/20260710/https://original.url.com/article",
  "is_dead": true
}
```

## Evidence Integrity Verification

Every evidence snapshot includes a SHA-256 hash of all source URLs and extracted content. The broker can verify that the evidence has not been tampered with:

```sql
-- Verify evidence snapshot integrity
SELECT
    es.id,
    es.sha256_hash = ENCODE(HMAC(es.bundle::text, 'integrity-key', 'SHA256'), 'hex')
        AS hash_matches,
    es.captured_at
FROM evidence_snapshots es
WHERE es.id = 'snapshot-id';
```

If the hash does not match, the snapshot has been modified since creation. This is a data integrity alarm that should never occur in normal operation.

## Link Display in Broker Output

When evidence is presented to the broker (in the weekly export or Telegram summary), each claim displays its sources as clickable links:

```
Growth Signal (Confidence: 84)
┌─────────────────────────────────────────────────────────┐
│ TechNova Solutions hired 200 employees in Q2 2026        │
│                                                         │
│ Sources:                                                 │
│  ✓ linkedin.com/company/technova (Jul 2026)              │
│  ✓ economictimes.india/.../technova-hiring (Jul 2026)    │
│  ✓ blog.technova.in/expansion (Jul 2026)                 │
│                                                         │
│ Verification: 3 sources from 3 tiers — VERIFIED         │
└─────────────────────────────────────────────────────────┘
```

Each source link includes the capture date so the broker can assess freshness at a glance. The verification status line shows the tier diversity — "3 sources from 3 tiers" is stronger than "2 sources from the same tier."
