# Technology Stack

The Jasfo platform is built on a carefully selected stack of technologies chosen for cost efficiency, reliability, and integration simplicity. Every technology choice is justified against the platform's constraints: under $50/month operating cost, solo-broker operation, and Pune market focus.

## Core Technologies

| Category | Technology | Cost | Selection Rationale |
|----------|-----------|------|---------------------|
| Workflow Automation | Make.com | $0–9/mo | Visual workflow builder enables rapid prototyping without code. Extensive HTTP, JSON, and webhook modules. Error handling and retry built-in. Far cheaper than Zapier at scale. |
| Database | Supabase | Free | Open-source Firebase alternative with PostgreSQL, real-time subscriptions, and REST API. Generous free tier covers current data volume. RL-compatible for future multi-broker support. |
| Primary Scraper | Firecrawl | Existing plan | AI-native scraping API with structured output, JavaScript rendering, and rate limiting. Handles 90% of scraping needs. Existing account means no additional cost. |
| Secondary Scraper | Apify | $20–30/mo | Pre-built Actors for LinkedIn, Google Maps, Crunchbase. Proxy rotation for blocked targets. Pay-as-you-go credits align cost with usage. |
| AI Workers | OpenCode GO | ~$5/mo | Unified API for multiple AI models. Routes to DeepSeek V4 Flash and MiMo V2.5. Cost-efficient compared to direct API calls. |
| Final Judge | Anthropic Direct API | ~$5–10/mo | Claude Sonnet 4 access for the critical Judge layer. Pay-per-token, only used for final evaluation. |
| Notifications | Telegram | Free | Bot API for pipeline notifications. Free, reliable, push-enabled. Simple JSON API. |
| Email | SMTP | Free | Standard SMTP for broker's personal email outreach. No email marketing platform needed. |
| Hosting | Railway | ~$5/mo | Simple deployment for lightweight web services. GitHub integration. Generous free tier with affordable scaling. |
| CDN | Cloudflare | Free | Free CDN, DNS, and DDoS protection. Simple setup with Railway. |

## Make.com ($0–9/month)

Make.com is the orchestration backbone. Every pipeline layer is implemented as a Make.com scenario with HTTP modules calling Firecrawl, AI model APIs, and Supabase. The visual workflow builder enables rapid iteration — scenarios can be modified, tested, and deployed without code deployments. Webhook triggers and scheduled runs handle pipeline timing. Error handlers on each module capture failures and route them to a dedicated error table in Supabase.

Make.com's pricing is usage-based. The free tier covers 1,000 operations per month, which is insufficient for processing 10,000 companies through 14+ layers each. The Professional plan ($9/month) provides 10,000 operations and multiple active scenarios. This is the only Make.com plan needed for the current scale.

## Supabase (Free)

Supabase is the single source of truth for all platform data. The database stores company profiles, scraped raw data, normalized records, verification results, feature vectors, agent outputs, consensus scores, lead memory, cooldown states, pipeline logs, error records, and export history. Row-Level Security is configured for single-user access with the service role key.

The free tier provides 500 MB of database space, 2 GB of bandwidth, and 50,000 monthly active rows. Current data volume — approximately 10,000 companies with full history — fits comfortably within these limits. If the database exceeds free tier limits, the $25/month Pro plan provides 8 GB database space and 250 GB bandwidth.

## Firecrawl (Existing Plan)

Firecrawl is the primary intelligence engine. It handles bulk website scraping with configurable crawl depth, rate limiting, and JavaScript rendering. The platform uses Firecrawl's map endpoint for sitemap discovery and scrape endpoint for full-page extraction. Excluded paths (/admin, /login, /cdn) and crawl limits are configured per-run to control costs.

The existing plan covers the platform's current needs. No additional Firecrawl cost is incurred.

## Apify ($20–30/month)

Apify serves as the secondary scraper for targets Firecrawl cannot handle: LinkedIn company profiles (which require logged-in sessions), Google Maps business listings (which require geolocation parameters), and Crunchbase enrichment. The platform uses pre-built Apify Actors with configurable inputs and JSON outputs.

Apify credits cost approximately $20–30/month. LinkedIn scraping is the primary cost driver at approximately $0.50–1.00 per 100 profiles. The cost gate ensures Apify is only used for the 500–1,000 companies that survive the first eight layers.

## AI Models

**OpenCode GO (~$5/month).** OpenCode GO provides a unified API for multiple AI models with transparent pricing per 1M tokens. It routes DeepSeek V4 Flash for bulk processing and MiMo V2.5 for mid-complexity reasoning tasks. OpenCode GO's aggregated billing simplifies cost tracking compared to managing separate API keys for each model provider.

**DeepSeek V4 Flash.** Used for all high-volume, low-complexity tasks: normalization, feature extraction, specialist agents, and contact enrichment. Cost is approximately $0.15–0.30 per 1M tokens. Provides approximately 90% of Claude's accuracy at 10% of the cost for structured output tasks.

**MiMo V2.5.** Used for verification, consensus, and commercial strategy layers where reasoning depth matters but Claude-level frontier capability is not yet required. Cost is approximately $0.50–1.00 per 1M tokens.

**Claude Sonnet 4 (~$5–10/month).** Used exclusively for the Judge layer. Cost is approximately $3–15 per 1M tokens depending on caching tier. The platform uses prompt caching to reduce costs on repeated evaluation patterns. Total Judge cost is approximately $5–10/month for 20–30 leads per week.

## Railway (~$5/month)

Railway hosts lightweight web services: a simple API for broker lead review and any utility scripts. Deployment is GitHub-integrated — pushing to main triggers automatic deployment. The $5/month developer plan provides 512 MB RAM and 1 GB storage, which is more than sufficient for the platform's current needs.
