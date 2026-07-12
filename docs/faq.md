# FAQ

## Architecture

**Q: How does the 14-layer pipeline work end-to-end?**

The platform ingests approximately 10,000 companies per week through Firecrawl and Apify scrapers. Each company passes through 14 sequential layers — collection, normalization, verification, feature engineering, five specialist AI agents, consensus, memory, change detection, cost gating, contact enrichment, commercial strategy, and a final Claude Sonnet 4 Judge — before emerging as a scored, evidence-backed lead. Any company failing a verification or scoring threshold is dropped before reaching the next layer, ensuring cost is only spent on promising candidates.

**Q: What happens if a layer fails?**

Each layer has defined failure modes. If a scraper returns an empty response, the pipeline retries once with a fallback source. If an AI agent produces an inconclusive result, the company is passed to the next layer with a low-confidence flag rather than being discarded outright — the final Judge layer accounts for confidence in its scoring. If the entire pipeline fails mid-run, Make.com retries from the last successful checkpoint using its built-in error handler.

**Q: Where does the pipeline run?**

The orchestration layer runs on Make.com. AI inference runs through OpenCode GO (which routes to DeepSeek V4 Flash and MiMo V2.5) and Anthropic Direct API (for Claude Sonnet 4). The database is Supabase. Scraping runs on Firecrawl and Apify cloud services. Everything is hosted on Railway with Cloudflare CDN in front.

## Costs

**Q: What is the monthly operating cost?**

Target operating cost is under $50/month. Make.com is $0–9/month. Supabase free tier covers the database. Firecrawl uses an existing plan. Apify adds $20–30/month for LinkedIn and Google Maps scraping. AI inference averages $5–10/month via OpenCode GO and Anthropic Direct API. Railway hosting is approximately $5/month. Cloudflare is free.

**Q: How is AI cost controlled?**

Cost gates are the primary mechanism. Free APIs (Firecrawl, free AI models) handle the first 80% of companies. Paid AI inference is only triggered for the 500–1,000 companies that pass initial verification and feature engineering. The Judge layer — the most expensive model call — runs only on the final 100–200 candidates. This layered approach ensures 95% of spend is on high-potential leads.

**Q: Why DeepSeek V4 Flash for most layers instead of Claude?**

DeepSeek V4 Flash costs approximately 10x less than Claude Sonnet 4 for equivalent structured output tasks. Bulk operations — normalization, feature extraction, contact enrichment — do not require frontier reasoning. DeepSeek handles these cost-effectively. Claude Sonnet 4 is reserved exclusively for the final Judge role where its superior reasoning and instruction-following are critical.

## Workflow

**Q: How does the weekly pipeline run?**

The pipeline triggers every Monday at 00:00 IST via a Make.com scheduler. It runs asynchronously across all 10,000 companies over approximately 4–6 hours. Telegram notifications are sent at key milestones: pipeline start, first qualified leads identified, evidence packages generated, and final delivery. The broker receives a CSV export and Telegram summary by Monday evening.

**Q: Can I trigger an ad-hoc run?**

Yes. A manual webhook on Make.com accepts a company URL or list of company names to run through the full pipeline on demand. This is useful for same-day research before client meetings. Ad-hoc runs follow the same cost-gating rules, so a single company inquiry costs approximately $0.01–0.03.

**Q: How are companies refreshed?**

Companies in Lead Memory are refreshed every 14 days by default. A company that has been in cooldown for 30+ days is automatically re-scanned for changes. If no significant change is detected after two consecutive refreshes, the company enters deep cooldown (90-day cycle).

## Data Sources

**Q: What data sources does the platform use?**

Firecrawl is the primary engine, scraping company websites, blogs, news pages, and career pages. Apify acts as the secondary source for LinkedIn company profiles, Google Maps business listings, and Crunchbase lookups. Free APIs include SerpAPI (limited tier), public government registries (MCA, GST), and RSS feeds. No purchased data lists are used — every data point is collected fresh each cycle.

**Q: Is LinkedIn data reliable?**

LinkedIn data is treated as a signal, not ground truth. Company size, employee count, and headcount growth are cross-verified against the company's own career page and third-party sources. If LinkedIn says 200 employees but the career page shows 50 open positions across five departments, the Verification layer flags the discrepancy. LinkedIn is never the sole source for any decision.

**Q: How do you handle companies that block scrapers?**

If Firecrawl is blocked (rate-limited, CAPTCHA, IP-banned), the pipeline falls back to Apify's proxy pool. If both scrapers fail, the company is marked as `scrape_blocked` and queued for manual review. Approximately 5–8% of companies in the target set have scrape restrictions.

## Reliability

**Q: How accurate are the Move Probability Scores?**

Move Probability Scores (MPS) are calibrated against historical brokerage data from Jasfo's past 8 years of Pune CRE transactions. The model achieves approximately 78% precision at the Top 30 cutoff, meaning roughly 23–24 of the weekly 30 delivered leads will have genuine space needs within 90 days. False positives are typically companies undergoing restructuring (announced layoffs, acquisition) that the pipeline misinterprets as growth.

**Q: What prevents hallucinated data?**

Every AI output in the pipeline must cite its source URL. The Verification layer cross-checks each claim against at least two independent sources. The Evidence Engine requires full-text extraction for any claim used in scoring. If a source cannot be produced, the claim is discarded. The final Judge layer penalizes any lead whose evidence package contains uncorroborated claims.

**Q: What happens if the Make.com workflow fails mid-run?**

Make.com's error handler captures the failed state, logs the error to a dedicated Supabase errors table, and retries the module up to three times with exponential backoff. After three failures, the pipeline continues with the remaining companies and the failed items are added to a retry queue for the next scheduled run. A Telegram alert is sent for any module that fails all retries.

## Getting Started

**Q: How do I set up the platform?**

Follow the Getting Started guide. Prerequisites are Python 3.10+, MkDocs Material, and repository access. The setup process is: clone the repo, install dependencies with `pip install -r requirements.txt`, configure environment variables for Supabase and API keys, and deploy Make.com scenarios from the `/make` directory.

**Q: Do I need a team to run this?**

No. The platform is designed for a solo broker. Jasfo (the broker) is the sole operator. AI agents handle the research, verification, and scoring. The broker reviews final evidence packages and executes outreach. The entire system requires approximately 2–3 hours of broker time per week.

**Q: Where do I start reading the documentation?**

Start with the Vision Overview to understand business goals, then the 14-Layer Architecture for system design. The Getting Started guide has setup instructions. Each subsystem (AI, Database, Make.com, Scraping, Lead Engine) has dedicated documentation with implementation details.
