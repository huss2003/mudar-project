# Supabase Storage

> Object storage for bulk data uploads — Propstack CSV imports, broker Excel files, and exported evidence packages.

## Bucket Structure

Two storage buckets serve the platform:

| Bucket | Purpose | Visibility | Retention |
|--------|---------|------------|-----------|
| `uploads` | Raw imports (CSV, Excel) | Private | 90 days |
| `exports` | Generated deliverables (CSV, PDF) | Public (signed URLs) | 30 days |

---

## `uploads` Bucket

Used exclusively for bulk data ingestion. Brokers upload Propstack CSV files and broker-provided Excel sheets, which are consumed by the Discovery pipeline layer.

```
uploads/
├── propstack/
│   ├── 2026-07-10_companies.csv
│   └── 2026-07-17_companies.csv
├── broker/
│   ├── 2026-07-10_my-portfolio.xlsx
│   └── 2026-07-17_target-list.xlsx
└── manifests/
    ├── 2026-07-10_import-manifest.json
    └── 2026-07-17_import-manifest.json
```

### Upload Flow

1. Broker uploads CSV/Excel file via a Supabase Storage-signed URL or direct upload through Studio
2. A database trigger on the `uploads` bucket inserts a row into a processing queue
3. The Make.com scenario polls the queue, downloads the file, and processes it
4. After processing, a manifest JSON is written alongside the original file recording row counts, errors, and processing timestamp

### Storage Policies

```sql
-- Only authenticated users can read/write uploads
CREATE POLICY "uploads_authenticated_write"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'uploads'
        AND auth.role() = 'authenticated'
    );

CREATE POLICY "uploads_authenticated_read"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'uploads'
        AND auth.role() = 'authenticated'
    );

-- Automatic cleanup after 90 days
CREATE POLICY "uploads_auto_cleanup"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'uploads'
        AND created_at < now() - interval '90 days'
    );
```

### CSV Schema Contract

Propstack CSV files must include at minimum these columns to be processable:

| Column | Type | Required | Example |
|--------|------|----------|---------|
| `company_name` | text | Yes | "TechNova Solutions" |
| `domain` | text | Yes | "technova.in" |
| `industry` | text | No | "IT Services" |
| `employee_count` | text | No | "201-500" |
| `location` | text | No | "Pune" |
| `revenue` | text | No | "$50M-$100M" |

Broker Excel files have a more flexible schema — the platform attempts to map columns by header name similarity. Unmappable columns are logged but do not block ingestion.

---

## `exports` Bucket

Houses generated deliverables — weekly CSV exports, PDF Lead Intelligence Reports, and evidence packages.

```
exports/
├── weekly/
│   ├── 2026-W28_top-leads.csv
│   ├── 2026-W28_evidence-bundle.json
│   └── 2026-W29_top-leads.csv
├── reports/
│   └── {company_id}/
│       ├── 2026-07-10_lead-report.pdf
│       └── 2026-07-10_evidence-package.json
└── archive/
    └── 2026-06/
        ├── W24_top-leads.csv
        └── W25_top-leads.csv
```

### Signed URL Generation

Export files are served to the broker via time-limited signed URLs. The broker's Telegram bot generates these on demand:

```sql
-- Edge Function generates signed URL for latest export
SELECT storage.create_signed_url(
    'exports',
    'weekly/' || (
        SELECT filename FROM storage.objects
        WHERE bucket_id = 'exports'
          AND name LIKE 'weekly/%'
        ORDER BY created_at DESC
        LIMIT 1
    ),
    3600 -- 1 hour expiry
);
```

### Export Cleanup

Monthly maintenance function removes exports older than 30 days, keeping only the most recent per-week:

```sql
CREATE OR REPLACE FUNCTION prune_exports()
RETURNS integer AS $$
DECLARE
    v_deleted integer;
BEGIN
    DELETE FROM storage.objects
    WHERE bucket_id = 'exports'
      AND created_at < now() - interval '30 days'
      AND name NOT IN (
          SELECT DISTINCT ON (regexp_replace(name, '-\d{4}-W\d{2}', ''))
              name
          FROM storage.objects
          WHERE bucket_id = 'exports'
            AND name LIKE 'weekly/%'
          ORDER BY regexp_replace(name, '-\d{4}-W\d{2}', ''), created_at DESC
      );
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;
```

---

## File Size Limits

| Operation | Limit | Enforcement |
|-----------|-------|-------------|
| Single upload | 50 MB | Supabase Storage config |
| CSV row count | 50,000 | Application layer check |
| Excel sheet size | 20 MB | Application layer check |
| Evidence bundle | 10 MB | Application layer check |

Files exceeding these limits are rejected with a descriptive error message before any processing begins. The 50 MB upload limit covers the largest expected Propstack export (approximately 15,000 companies with full profiles).

---

## Cost Considerations

Supabase Storage costs are driven by two factors: stored data volume and egress. The platform's storage footprint is small:

- **Uploads**: ~100 MB/week (CSV + Excel files, cleaned after 90 days)
- **Exports**: ~5 MB/week (compressed CSV + JSON evidence bundles)
- **Total active storage**: ~500 MB

At Supabase's free tier (1 GB storage, 2 GB bandwidth), storage costs are negligible. If the platform scales to multi-city or multi-broker operation, the primary cost driver would be evidence bundles (projected ~1 GB/month per broker). Retention policy tuning can keep this under control.
