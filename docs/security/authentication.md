# Authentication

## Overview

Authentication on the Jasfo platform operates at two levels: **user authentication** for the web dashboard (Supabase Auth) and **API authentication** for programmatic access (API keys). The platform uses a single-user broker model, so there is one primary authenticated identity. All external service authentication (Apollo, Hunter, etc.) is handled by the platform on behalf of the broker and does not require the broker to manage individual service credentials.

Authentication events are logged with timestamps, IP addresses, and user agent information. Failed authentication attempts trigger immediate alerts.

---

## User Authentication (Web Dashboard)

### Supabase Auth

The web dashboard authenticates users via Supabase Auth with email/password authentication.

```mermaid
sequenceDiagram
    participant User
    participant App as Web App
    participant Supabase as Supabase Auth
    participant DB as Supabase DB

    User->>App: Enter email + password
    App->>Supabase: POST /auth/v1/token?grant_type=password
    Supabase->>Supabase: Verify credentials
    Supabase-->>App: Return access_token + refresh_token
    App->>App: Store tokens in httpOnly cookie
    App-->>User: Dashboard loaded
    Note over User,DB: All subsequent requests include JWT
    App->>Supabase: Request with Authorization: Bearer <JWT>
    Supabase->>App: Validated session
    App->>DB: RLS-enforced query
    DB-->>App: Filtered results
```

### Session Management

| Parameter | Value |
|-----------|-------|
| Session duration | 24 hours |
| Refresh token expiry | 60 days |
| Password requirements | Min 12 chars, mixed case, number, symbol |
| Failed login lockout | 5 attempts → 15 min cooldown |
| Session storage | httpOnly, SameSite=Strict cookie |
| MFA | Not required (single-user model) |

### Password Hashing

Supabase Auth uses **bcrypt** with a cost factor of 12 for password hashing. The platform never receives or stores plaintext passwords.

---

## API Key Authentication (Programmatic)

For programmatic access, the platform supports Bearer token authentication via API keys.

### API Key Format

```
Authorization: Bearer jf_abc123def456ghi789jkl012
```

API keys are prefixed with `jf_` for identification and contain at least 32 characters of entropy.

### Key Validation

```
POST /api/leads/search
Authorization: Bearer jf_abc123...
```

The platform validates the key by:

1. Hashing the key with SHA-256
2. Comparing against stored hash in Supabase (never stores plaintext keys)
3. Checking expiry and permissions
4. Logging the authenticated request

---

## External Service Authentication

The platform authenticates to external services on behalf of the broker. The broker never needs to manage these credentials directly.

```mermaid
flowchart LR
    A[Platform<br>Make.com / OpenCode] --> B[Supabase Vault]
    B --> C[Apollo API Key]
    B --> D[Hunter API Key]
    B --> E[Snov OAuth Token]
    B --> F[Firebase API Key]
    B --> G[Telegram Bot Token]
    B --> H[OpenRouter API Key]
    C --> I[Apollo API]
    D --> J[Hunter API]
    E --> K[Snov API]
    F --> L[Firebase API]
    G --> M[Telegram API]
    H --> N[OpenRouter API]
```

Each external API key is scoped to the minimum set of permissions required for the platform to function. Keys are never shared with the broker or exposed through the web UI.

---

## Token Types

| Token | Purpose | Lifetime | Storage |
|-------|---------|----------|---------|
| Supabase JWT (access) | Web dashboard auth | 24 hours | httpOnly cookie |
| Supabase JWT (refresh) | Session renewal | 60 days | httpOnly cookie |
| Platform API key | Programmatic access | Per-key config | SHA-256 hash in DB |
| Service role key | Server-to-server DB | Permanent | Supabase Vault |
| External API keys | Third-party services | Per-service | Supabase Vault |

---

## Authentication Error Handling

| Error | User Impact | System Action |
|-------|-------------|--------------|
| Invalid password | Login denied | Log attempt, increment counter |
| Expired session | Re-login required | Clear cookie, redirect to login |
| Revoked API key | API returns 401 | Log, alert admin |
| Invalid external key | Enrichment paused | Switch to fallback, alert admin |
| Brute force detection | Temporary IP ban | Block for 15 min, log source |

---

## Security Headers

All authenticated responses include:

| Header | Value |
|--------|-------|
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Content-Security-Policy` | Restricted to platform origin |
| `Set-Cookie` (auth) | `HttpOnly; Secure; SameSite=Strict; Path=/` |
