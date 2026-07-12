# JSON Export Specification

## Overview

The JSON export provides a structured, machine-readable representation of lead intelligence data designed for API consumption, webhook delivery, and programmatic ingestion. Each export produces an array of lead objects — called a **Lead Packet** — containing the full 150-field payload with embedded evidence metadata. The format is designed to be self-describing: every value carries its provenance, confidence, and verification trail.

JSON exports are the native format for the platform's webhook integrations and REST API responses. When a consumer calls `GET /api/leads/export?format=json` or receives a webhook payload, the response body conforms to the Lead Packet schema defined below. The format supports incremental, filtered, and paginated exports with consistent envelope structure.

---

## Lead Packet Schema

### Envelope

```json
{
  "schema_version": "1.0.0",
  "exported_at": "2026-07-12T10:30:00Z",
  "batch_id": "0194f1c0-1234-5678-9abc-def012345678",
  "total_leads": 2,
  "leads": [ ... ],
  "metadata": {
    "export_type": "filtered",
    "filters_applied": {
      "intent_score_min": 0.7,
      "industry": ["Software", "FinTech"],
      "created_after": "2026-06-01T00:00:00Z"
    },
    "generated_by": "system",
    "processing_time_ms": 1234
  }
}
```

### Lead Object (Single Record)

```json
{
  "lead_id": "0194f1c0-1234-5678-9abc-def012345678",
  "identity": {
    "first_name": {
      "value": "John",
      "confidence": 0.99,
      "primary_source": "Apollo.io",
      "secondary_source": "LinkedIn",
      "source_url": "https://apollo.io/people/...",
      "verification_url": "https://linkedin.com/in/...",
      "verified_at": "2026-07-11T14:30:00Z"
    },
    "last_name": { ... },
    "email": {
      "value": "john@acme.com",
      "confidence": 0.95,
      "primary_source": "Apollo.io",
      "secondary_source": "Hunter.io",
      "source_url": "https://apollo.io/...",
      "verification_url": "https://hunter.io/verify/...",
      "verified_at": "2026-07-12T08:15:00Z"
    },
    "phone": { ... },
    "linkedin_url": { ... },
    "job_title": { ... }
  },
  "company": {
    "name": { ... },
    "domain": { ... },
    "industry": { ... },
    "size": { ... },
    "revenue": { ... },
    "funding": { ... },
    "technologies": { ... }
  },
  "intelligence": {
    "intent_score": 0.82,
    "engagement_score": 0.74,
    "seniority_level": "Director",
    "decision_making_power": "Influencer",
    "budget_estimate": "$50K-$100K",
    "pain_points": [
      "Scaling sales outreach",
      "Low email reply rates"
    ],
    "competitor_usage": ["Salesforce", "HubSpot"],
    "last_updated": "2026-07-12T10:00:00Z"
  },
  "verification": {
    "email_verified": true,
    "email_quality_score": 0.92,
    "email_deliverable": "Deliverable",
    "email_catch_all": false,
    "email_disposable": false,
    "phone_verified": true,
    "phone_active": true,
    "phone_carrier": "Verizon"
  },
  "metadata": {
    "created_at": "2026-07-10T09:00:00Z",
    "updated_at": "2026-07-12T10:00:00Z",
    "source_campaign": "saas-q3-2026",
    "lead_status": "new",
    "tags": ["saas", "high-intent", "north-america"]
  }
}
```

### Evidence Bundle Schema

Every value field in the `identity` and `company` objects follows the **EvidenceValue** contract:

```json
{
  "value": "<any>",
  "confidence": 0.0..1.0,
  "primary_source": "string",
  "secondary_source": "string | null",
  "source_url": "string | null",
  "verification_url": "string | null",
  "verified_at": "ISO8601 | null"
}
```

### JSON Schema (Draft 2020-12)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "schema_version": { "type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$" },
    "exported_at": { "type": "string", "format": "date-time" },
    "batch_id": { "type": "string", "format": "uuid" },
    "total_leads": { "type": "integer", "minimum": 0 },
    "leads": {
      "type": "array",
      "items": { "$ref": "#/$defs/Lead" }
    },
    "metadata": { "$ref": "#/$defs/ExportMetadata" }
  },
  "required": ["schema_version", "exported_at", "leads"],
  "$defs": {
    "EvidenceValue": {
      "type": "object",
      "properties": {
        "value": {},
        "confidence": { "type": "number", "minimum": 0, "maximum": 1 },
        "primary_source": { "type": "string" },
        "secondary_source": { "type": ["string", "null"] },
        "source_url": { "type": ["string", "null"], "format": "uri" },
        "verification_url": { "type": ["string", "null"], "format": "uri" },
        "verified_at": { "type": ["string", "null"], "format": "date-time" }
      },
      "required": ["value", "confidence", "primary_source"]
    },
    "Lead": {
      "type": "object",
      "properties": {
        "lead_id": { "type": "string", "format": "uuid" },
        "identity": { "type": "object" },
        "company": { "type": "object" },
        "intelligence": { "type": "object" },
        "verification": { "type": "object" },
        "metadata": { "type": "object" }
      },
      "required": ["lead_id", "identity", "metadata"]
    }
  }
}
```

---

## Pagination

For large datasets, the API returns paginated results:

```json
{
  "schema_version": "1.0.0",
  "exported_at": "2026-07-12T10:30:00Z",
  "batch_id": "...",
  "total_leads": 12500,
  "leads": [ ... 100 leads ... ],
  "pagination": {
    "page": 1,
    "per_page": 100,
    "total_pages": 125,
    "next_page": "/api/leads/export?format=json&page=2&per_page=100",
    "previous_page": null
  },
  "metadata": { ... }
}
```

---

## Compression

| Content-Type | Encoding | Typical Size (10K leads) |
|-------------|----------|------------------------|
| `application/json` | None | ~25 MB |
| `application/json` | gzip | ~3 MB |
| `application/x-ndjson` | gzip | ~2.5 MB |

Large exports (>100K leads) are automatically delivered as gzipped NDJSON (newline-delimited JSON) streams to minimize memory overhead on both server and consumer.

---

## Webhook Delivery

When JSON export is configured for webhook delivery, the platform POSTs the Lead Packet to the configured endpoint URL:

```
POST /webhooks/leads HTTP/1.1
Content-Type: application/json
X-Jasfo-Signature: t=1720773000,v1=abc123...
X-Jasfo-Batch-Id: 0194f1c0-...
```

The `X-Jasfo-Signature` header contains a HMAC-SHA256 signature of the request body using the shared webhook secret. Consumers **must** verify this signature before processing.
