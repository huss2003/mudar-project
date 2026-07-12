# Jasfo Workflow Files

Importable JSON workflows for n8n and Make.com.

## n8n (6 files)

| File | Purpose | Trigger | Nodes |
|------|---------|---------|-------|
| `n8n/jasfo-weekly-master.json` | Weekly orchestrator — cron → queue → poll → report | Cron (Mon 9AM) | 15 |
| `n8n/jasfo-discovery-pipeline.json` | Company discovery + Firecrawl scraping | Webhook | 13 |
| `n8n/jasfo-ai-analysis.json` | AI entity extraction (DeepSeek/MiMo) | Webhook | 14 |
| `n8n/jasfo-scoring-engine.json` | 8-pillar scoring + consensus + reflection | Webhook | 20 |
| `n8n/jasfo-export-delivery.json` | CSV/JSON/MD/Telegram export | Webhook | 15 |
| `n8n/jasfo-cost-monitor.json` | Hourly budget tracking ($20/day cap) | Cron (hourly) | 8 |

**Import:** n8n → Settings → Import Workflow → select JSON file.

**Credentials to configure:**
- `supabase-db-cred` — Postgres (Supabase connection)
- `jasfo-telegram-bot` — Telegram bot token
- `deepseek-api` — DeepSeek V4 Flash API key
- `mimo-api` — MiMo V2.5 API key
- `firecrawl-api` — Firecrawl API key (Bearer auth)

---

## Make.com (6 files)

| File | Purpose | Trigger | Modules |
|------|---------|---------|---------|
| `make/jasfo-weekly-master.json` | Weekly orchestrator | Cron (Mon 9AM) | 11 |
| `make/jasfo-discovery-pipeline.json` | Discovery + Firecrawl | Webhook | 12 |
| `make/jasfo-ai-analysis.json` | AI analysis with fallback | Webhook | 9 |
| `make/jasfo-scoring-engine.json` | 8-pillar scoring + consensus | Webhook | 26 |
| `make/jasfo-export-delivery.json` | Export + Telegram delivery | Webhook | 13 |
| `make/jasfo-cost-monitor.json` | Hourly budget monitor | Cron (hourly) | 8 |

**Import:** Make.com → Scenarios → Add → Import Blueprint → select JSON file.

**Secrets already embedded:**
- Telegram Chat IDs: group=`-5497421027`, admin=`5936648348`
- OpenCode GO API key: `sk-MmeX9RLWQrIFngobzyoLIoVjLx58ObW5ZhUmqYbwhPucZc8Nn46jQbvw4Vuf2yCA`
- Firecrawl API key: `fc-03ee582d75c647c59555df35374d8fa2`
- OpenCode GO endpoint: `https://opencode.ai/zen/go/v1/chat/completions`

**Secrets to configure (via setup-credentials.sh):**
- `SUPABASE_DB_PASSWORD` — in the setup script

---

## Pipeline Architecture

```
Schedule (Mon 9AM) → Master → Discovery → Firecrawl → AI Analysis → Scoring → Export → Telegram
                                          ↘ cache        ↘ fallback    ↘ cost_log
```

- Layers 1-7 (10K→210 leads): **Free tier** (Firecrawl + DeepSeek V4 Flash)
- Layers 8-11 (210→27 leads): **Paid tier** (Hunter/Apollo/Snov + Claude Sonnet 4)
- Cost gate at score ≥ 60 filters before paid layers
- Total weekly cost: ~$16.50
