# Project Summary

**Jasfo** is an AI-native Commercial Real Estate (CRE) Intelligence Platform for Indian brokers. It transforms 10,000 companies into 20-30 evidence-backed, high-confidence leads every week.

## What It Does

- Scans ~10,000 companies weekly via Firecrawl + free APIs
- Runs 21 AI agents across a 14-layer sequential pipeline
- Scores each company on 8 pillars (growth, space need, financial health, etc.)
- Filters to 20-30 broker-ready leads per week
- Brokers spend 2-3 hrs/week acting on leads instead of 20+ hrs researching

## Tech Stack

| Layer | Technology | Cost |
|-------|-----------|------|
| Automation | Make.com | $9/mo |
| Database | Supabase (PostgreSQL 16) | Free |
| Primary Scraper | Firecrawl | Existing plan |
| AI Workers | OpenCode GO (DeepSeek V4 Flash, MiMo V2.5) | ~$5/mo |
| Final Judge | Claude Sonnet 4 via OpenRouter | ~$5-10/mo |
| Notifications | Telegram Bot | Free |
| Hosting | Railway | ~$5/mo |
| CDN | Cloudflare | Free |
| Email Enrichment | Apollo Free + Hunter Free + Snov Free + SMTP | Free |

## Core Philosophy

1. **Evidence First** — Every claim must cite verifiable sources. No unsupported claims.
2. **AI First** — Every decision made by AI before human review. Broker reviews outputs, not inputs.
3. **Firecrawl First** — Free scraping first, paid fallback only when necessary.
4. **Free APIs First** — Paid services only for companies that pass the Cost Gate.
5. **Quality Over Quantity** — 20 verified leads > 10,000 unqualified names.
6. **Cost Optimization** — $50/mo budget. 95% of AI work on cheap models.
7. **Lazy-First** — Single-user schema. No multi-tenant. No premature optimization.

## Key Numbers

| Metric | Target |
|--------|--------|
| Companies processed/week | 10,000 |
| Qualified leads/week | 20-30 |
| Monthly operating cost | < $50 |
| Pipeline runtime | < 6 hours |
| Broker time/week | 2-3 hours |
| Cost per delivered lead | < $2 |
| Move Probability Score threshold | 70+ |

## Status

- **Version:** Master PRD v4.0
- **Status:** In Development
- **License:** Private Internal Documentation
