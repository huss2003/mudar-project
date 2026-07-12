# API Summary

## Firecrawl (Primary Scraper)

| Detail | Value |
|--------|-------|
| Base URL | `https://api.firecrawl.dev/v1` |
| Auth | Bearer token (`X-API-KEY`) |
| Free tier | 10 req/s, 500 daily credits |
| Key endpoints | `POST /v1/crawl`, `POST /v1/extract`, `POST /v1/search`, `POST /v1/map` |
| Caching | Redis, 24h TTL, key: `firecrawl:{md5(url)}:{prompt_hash}` |
| Usage | Company website crawling, tech stack detection, intent signal discovery |

## Apollo.io (Primary Enrichment)

| Detail | Value |
|--------|-------|
| Base URL | `https://api.apollo.io/api/v1` |
| Auth | Bearer token (`X-API-Key` header) |
| Free tier | 1,000 credits/mo, 10 req/min |
| Key endpoints | `POST /mixed_people/search`, `POST /people/match`, `POST /organizations/enrich` |
| Caching | Redis, 7d TTL |
| Usage | Person/company enrichment, email finding |

## Hunter.io (Secondary Email)

| Detail | Value |
|--------|-------|
| Base URL | `https://api.hunter.io/v2` |
| Auth | Query param `api_key` |
| Free tier | 25 req/mo, 50 verifications, 10 req/min |
| Key endpoints | `GET /email-finder`, `GET /email-verifier`, `GET /email-count` |
| Caching | Redis, 7d TTL |
| Usage | Secondary email source, primary email verification |

## Snov.io (Tertiary Email)

| Detail | Value |
|--------|-------|
| Base URL | `https://api.snov.io/v1` |
| Auth | OAuth2 client_credentials (ID + Secret), token expires 1hr |
| Free tier | 50 credits/mo, 100 req/day |
| Key endpoints | `POST /v2/domain-emails-with-name`, `POST /v1/email-verifier/by-email` |
| Caching | Redis, 7d TTL |
| Usage | Fallback when Apollo + Hunter fail |

## SMTP Verification

| Detail | Value |
|--------|-------|
| Protocol | SMTP on port 25, opportunistic STARTTLS |
| Cost | Free (no per-check cost) |
| Limits | 2 concurrent/MX, 100ms min delay, 5,000/day |
| Key checks | MX lookup -> EHLO -> MAIL FROM -> RCPT TO -> QUIT |
| Catch-all detection | Test random invalid address first |
| Confidence | 250 + not catch-all = 0.95; catch-all = 0.50 |

## Telegram Bot

| Detail | Value |
|--------|-------|
| Base URL | `https://api.telegram.org/bot<token>/` |
| Auth | Bot token in URL |
| Key methods | `sendMessage`, `sendDocument`, `editMessageText` |
| Parse mode | MarkdownV2 (must escape special chars with `\`) |
| Limits | 4,096 chars/message, ~30 msg/s per chat |

## Supabase

| Detail | Value |
|--------|-------|
| REST API | `https://<project>.supabase.co/rest/v1/` |
| Auth | `apikey` header + `Authorization: Bearer <key>` |
| Client | `@supabase/supabase-js` |
| Real-time | `pg_notify` channels: `lead_state_changes`, `high_value_leads`, `jasfo_notifications` |
| Storage | Buckets: `exports` (signed URLs, 30d), `reports` (signed URLs, 90d), `assets` (public) |
| Vault | `vault.create_secret()`, `vault.decrypted_secrets` |

## OpenRouter (Claude Sonnet 4)

| Detail | Value |
|--------|-------|
| Base URL | `https://openrouter.ai/api/v1` |
| Auth | Bearer token |
| Model | `anthropic/claude-sonnet-4` |
| Cost | ~$8/1M tokens input, ~$40/1M tokens output |
| Usage | Judge layer ONLY (final 20-30 leads) |
| Caching | Prompt caching enabled |

## OpenAI-like APIs (OpenCode GO)

| Detail | Value |
|--------|-------|
| Models | DeepSeek V4 Flash (~$0.20/1M), MiMo V2.5 (~$0.75/1M) |
| Usage | All pipeline layers except Judge |
| Routing | OpenCode GO handles model routing internally |
