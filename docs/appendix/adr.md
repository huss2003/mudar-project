# Appendix: Architecture Decision Records (ADR)

> Index of all Architecture Decision Records for the Jasfo Lead Intelligence Platform. Each ADR follows the format: Title, Status, Context, Decision, Consequences. Full ADR documents are stored in `docs/architecture/adr/`.

---

## ADR-001: Make.com as Primary Workflow Orchestrator
**Status:** Accepted | **Date:** 2025-01-15

**Context.** The platform needed an orchestrator to chain scraping, AI processing, database operations, and notifications into a weekly batch pipeline. Options included Apache Airflow, n8n, custom Python scripts on Railway, and Make.com.

**Decision.** Use Make.com for all pipeline orchestration. Its visual workflow builder enables rapid iteration without code deployments. Built-in error handling, retry logic, scheduling, and 1,000+ integrations meet platform needs without the operational overhead of Airflow. Cost ($9/month) is an order of magnitude lower than self-hosted alternatives.

**Consequences.** Pipeline development velocity increased significantly — scenarios can be modified in minutes without deployments. The visual editor makes pipeline logic accessible to non-developers. Negative: Make.com's 30-day execution history retention limits debugging of historical failures. No local development environment — testing requires the live Make.com instance. Vendor lock-in risk: migrating to another orchestrator would require rebuilding all scenarios.

---

## ADR-002: Supabase as the Single Database
**Status:** Accepted | **Date:** 2025-01-15

**Context.** Data needed to be stored for companies, scores, evidence, decisions, outreach history, cost logs, and audit trails. Options included separate systems (PostgreSQL for data, Redis for cache, SQS for queues) versus a single platform.

**Decision.** Use Supabase (PostgreSQL 16) as the sole database. Supabase's free tier covers current data volume (~1M rows across 18 tables). JSONB columns provide schema flexibility for variable scraped data. Real-time subscriptions via `pg_notify` handle live updates without a separate message queue. Row-Level Security provides a migration path to multi-user if needed.

**Consequences.** Single-platform reduces operational complexity and cost. All data relationships are enforceable via foreign keys. Negative: Supabase's free tier has a 500MB database limit — snapshot data may require cleanup after 6+ months of weekly runs. No built-in message queue — the platform relies on PostgreSQL LISTEN/NOTIFY for real-time channels, which has limited throughput.

---

## ADR-003: 14-Layer Sequential Pipeline Architecture
**Status:** Accepted | **Date:** 2025-01-20

**Context.** The pipeline needed to process 10,000 companies per week through multiple stages: collection, normalization, verification, scoring, enrichment, and evaluation. A monolithic process would be hard to debug; microservices would introduce network overhead.

**Decision.** Implement a sequential 14-layer pipeline where each layer completes before the next begins. Within scoring layers (5-9), all eight pillar agents run in parallel. The pipeline is idempotent — re-running from any layer produces consistent results because each layer reads from and writes to the database.

**Consequences.** Each layer can be independently tested, upgraded, and debugged. Progressive elimination ensures API costs are concentrated on high-potential companies. Negative: total runtime is 4-6 hours (sequential bottleneck). A failure in layer 10 can stall layers 5-9's outputs until recovery. The layered architecture makes pipeline tracing straightforward — each log entry includes the layer number.

---

## ADR-004: DeepSeek V4 Flash as Default AI Model
**Status:** Accepted | **Date:** 2025-01-20

**Context.** The platform's budget constraint (<$50/month) required a cost-efficient default AI model for high-volume processing: classification, extraction, summarization, and scoring across 10,000 companies per week.

**Decision.** Assign DeepSeek V4 Flash as the default AI model for all layers except the Judge. It provides roughly 90% of Claude-quality output for structured tasks at approximately 2-3% of the cost ($0.20/1M tokens vs $8/1M for Claude). Approximately 60% of all AI calls use DeepSeek.

**Consequences.** Monthly AI costs stay under $50 even at full pipeline throughput. Structured output tasks (JSON mode) work reliably with DeepSeek. Negative: DeepSeek occasionally produces lower-quality reasoning on ambiguous data — the system compensates by routing ambiguous cases to MiMo V2.5. DeepSeek API availability has occasional latency spikes during peak hours in Asian markets.

---

## ADR-005: Reserve Claude Sonnet 4 for Judge Layer Only
**Status:** Accepted | **Date:** 2025-01-20

**Context.** Claude Sonnet 4 offers superior reasoning but costs 40× more than DeepSeek. Using it for bulk processing would exhaust the monthly budget within the first 1,000 companies.

**Decision.** Restrict Claude Sonnet 4 exclusively to the final Judge layer (layer 14) where it evaluates only 20-30 pre-qualified leads per week. All preceding layers use DeepSeek or MiMo. The Judge receives the complete Evidence Package and produces the final Move Probability Score with full source verification.

**Consequences.** Claude costs stay at $5-10/month, within budget. The Judge's superior reasoning ensures only high-quality leads are delivered. Negative: if the Cost Gate threshold is too low, too many companies reach the Judge and Claude costs spike. The Judge's system prompt must be meticulously maintained because any errors there affect all final outputs — and Claude's instruction adherence means errors are faithfully executed.

---

## ADR-006: Cost-Gating Between Free and Paid Layers
**Status:** Accepted | **Date:** 2025-01-25

**Context.** The pipeline has free layers (Firecrawl scraping, DeepSeek processing) and paid layers (Apify fallback, contact enrichment APIs, Claude Judge). Without a gate, the platform could spend its entire budget on low-quality companies.

**Decision.** Implement a hard Cost Gate at layer 10 between the free scoring layers and the paid enrichment/evaluation layers. Companies must meet a minimum combined pillar score (default: 350/800) to proceed. The gate also checks individual pillar minimums and inter-agent consensus variance.

**Consequences.** Approximately 80% of paid-layer budget is concentrated on the top 20% of candidates. The gate prevents runaway costs during pipeline misconfigurations. Negative: the gate introduces a threshold-tuning problem — set too high, it misses good leads; set too low, it wastes budget. The Reflection cycle (30-day) adjusts the threshold based on actual outcomes.

---

## ADR-007: Firecrawl as Primary Scraper with Apify Fallback
**Status:** Accepted | **Date:** 2025-01-25

**Context.** The platform needed a web scraping solution for company website analysis, tech stack detection, news monitoring, and career page analysis. Options included Firecrawl, Apify, ScrapingBee, and custom Playwright scripts.

**Decision.** Use Firecrawl as the primary scraping engine. Firecrawl handles 90%+ of scraping needs with structured output, reliable crawling, and an existing paid plan. Apify serves as a fallback — invoked only when Firecrawl fails or cannot handle a specific target (LinkedIn company profiles, Google Maps listings, Crunchbase lookups).

**Consequences.** Scraping costs are roughly one-third of what Apify-as-primary would cost. Firecrawl's structured output endpoints reduce normalization complexity. Negative: Firecrawl has limited LinkedIn and Google Maps support, requiring Apify fallback for those sources. Firecrawl rate limits (10 req/s free tier) require throttling in Make.com scenarios.

---

## ADR-008: Evidence Engine Requires Source URLs for Every Claim
**Status:** Accepted | **Date:** 2025-02-01

**Context.** Early testing revealed that AI agents occasionally produced plausible-sounding claims about companies that were not supported by scraped data. Brokers need to trust every statement in a lead report.

**Decision.** Implement an Evidence Engine that requires every AI-generated claim to include at least one verifiable source URL. Claims without sources are discarded before they reach the scoring layers. The 2-Source Rule requires two independent sources for high-confidence claims. Source URLs are stored in `evidence_sources` and linked to claims in `evidence_claims`.

**Consequences.** Broker trust in lead quality increased significantly — every delivered claim is traceable to its source. The Evidence Engine eliminated hallucinated data from pipeline outputs. Negative: claim verification adds approximately 30 minutes to pipeline runtime. Some legitimate signals (e.g., inferred from multiple weak signals) cannot be backed by a single source URL and are marked as low-confidence rather than discarded.

---

## ADR-009: Single-User Architecture
**Status:** Accepted | **Date:** 2025-02-01

**Context.** The platform serves a single broker operator. Multi-tenant features (user tables, authentication, Row-Level Security, team workflows) would add development time without providing near-term value.

**Decision.** Build for single-user operation. No `user_id` columns. No authentication beyond API keys. No team or collaboration features. The Supabase client uses the service role key for all operations. Row-Level Security is not enabled.

**Consequences.** Development velocity is higher — no authentication flows to build or test. Database queries are simpler without user-scoping WHERE clauses. Negative: expanding to multi-user later will require adding user tables, migrating existing data, implementing RLS policies, and refactoring all queries. The migration effort is estimated at 2-3 weeks. This is an accepted trade-off: the platform may never need multi-user, and if it does, the business case will justify the migration cost.

---

## ADR-010: Telegram as Primary Notification Channel
**Status:** Accepted | **Date:** 2025-02-05

**Context.** The broker needed real-time notifications for pipeline failures, weekly lead delivery, and high-value lead alerts. Options included email, Slack, SMS, and Telegram.

**Decision.** Use Telegram Bot API as the sole notification channel. Telegram provides free push notifications, a simple JSON API, MarkdownV2 formatting for structured messages, and file uploads for lead exports. The broker already uses Telegram daily, creating zero adoption friction.

**Consequences.** Notifications arrive within seconds of pipeline events. File delivery works natively — CSV/Excel exports are sent as Telegram documents. Negative: Telegram's 4,096-character message limit requires splitting long reports. MarkdownV2 escaping rules are strict — unescaped special characters cause silent send failures. No delivery receipts: Telegram does not confirm message read status.

---

## ADR-011: 30-Day Reflection Cycles
**Status:** Accepted | **Date:** 2025-02-10

**Context.** The pipeline's scoring weights and model routing rules were initially set based on domain expertise. Without outcome-based feedback, the system could not systematically improve its predictions over time.

**Decision.** Run a Reflection process every 30 days. The Reflection agent compares predicted Move Probability Scores against actual outcomes detected: leases signed, renewals spotted, relocations announced, or broker feedback entered. Scoring weights are adjusted when systematic bias is detected. Results are logged and can trigger ADR updates.

**Consequences.** Monthly cycles provide 80-120 data points per reflection (sufficient for statistical significance). Weight adjustments have measurably improved prediction accuracy over three cycles. Negative: the Reflection process requires manual broker feedback to validate outcomes — if the broker does not report outcomes, the Reflection loop has no signal. Monthly cadence means scoring errors persist for up to 30 days before correction.

---

## ADR-012: 14-Day Active Cooldown, 90-Day Deep Cooldown
**Status:** Accepted | **Date:** 2025-02-10

**Context.** Without cooldown, every company would be re-processed every weekly cycle, consuming pipeline capacity on recently scored companies unlikely to have changed meaningfully.

**Decision.** Implement a two-tier cooldown: 14-day active cooldown after any scoring, followed by 90-day deep cooldown if no significant change is detected. Companies in active cooldown bypass AI processing but still receive snapshot comparisons. Companies in deep cooldown are not processed at all until their next normal cycle date.

**Consequences.** Pipeline capacity is freed for new companies — roughly 60% of the 10,000-company weekly list is recycled from cooldown. API costs are reduced proportionally. Negative: a company might sign a lease during its cooldown window and the platform would not detect it until cooldown expires. The Change Detection layer partially mitigates this by monitoring Firecrawl's crawl endpoint for critical signals even during cooldown.

---

## ADR-013: Weekly Pipeline Schedule Monday 00:00 IST
**Status:** Accepted | **Date:** 2025-02-15

**Context.** The pipeline runs weekly and needs to complete before the broker begins work. Timing must account for API rate limits (daytime hours in US/EU) and Make.com scheduler constraints.

**Decision.** Schedule pipeline start at Monday 00:00 IST (Sunday 18:30 UTC). The 4-6 hour runtime completes before Monday morning in all Indian time zones. Overnight processing avoids competing with office-hour API traffic from other users of shared services.

**Consequences.** The broker has fresh leads every Monday morning. API rate limit issues are rare during the pipeline window. Negative: if the pipeline fails, recovery must happen during Monday daytime, which competes with the broker's meeting schedule. Tuesday is designated as the buffer day for failed pipeline re-runs.

---

## ADR-014: CSV Primary Export with Excel and PDF Options
**Status:** Accepted | **Date:** 2025-02-15

**Context.** The broker needs lead data in a format they can import into CRM tools, review on screen, and share with clients. Multiple output formats were evaluated for production cost and broker utility.

**Decision.** Deliver leads primarily as CSV for CRM import, with Excel formatting for broker review, and PDF generation on demand for client-facing presentations. CSV is the canonical export format — it is universally readable, trivial to generate, and importable into any CRM or spreadsheet tool. Excel adds visual formatting (conditional coloring, column widths) for broker review. PDF is reserved for high-value leads requiring formal presentation.

**Consequences.** CSV generation is free and instantaneous. Excel formatting runs on Railway with a small per-file processing cost. PDF generation is deferred — triggered only when the broker explicitly requests it for a specific lead. Negative: maintaining three export formats increases the testing surface. Format inconsistencies between CSV and Excel (date formatting, number precision) require careful validation.

---

## ADR-015: OpenCode GO as Model Gateway
**Status:** Accepted | **Date:** 2025-02-01

**Context.** The platform uses two AI models (DeepSeek V4 Flash, MiMo V2.5) across multiple pipeline layers. Each model has a different API endpoint, authentication method, and response format. Direct API calls would create tight coupling between pipeline scenarios and model providers.

**Decision.** Route all non-Judge AI calls through OpenCode GO, which provides a unified OpenAI-compatible API. OpenCode GO handles model selection, API key management, request routing, response normalization, and cost tracking. The pipeline sends a single request format regardless of which backend model is selected.

**Consequences.** Changing model providers or adding new models requires zero changes to Make.com scenarios — only OpenCode GO configuration is updated. Cost tracking is centralized, enabling accurate per-pipeline-run budget reporting. Negative: OpenCode GO is a single point of failure — if it goes down, all AI processing stops. OpenCode GO adds approximately 50ms of latency per request for routing and authentication. The platform has no OpenCode GO alternative configured, creating vendor dependency.

---

## ADR-016: 8 Pillars Instead of 5 Specialist Agents
**Status:** Accepted | **Date:** 2025-02-05

**Context.** The initial architecture specified five specialist agents: Growth, Space, Financial, Industry, and Decision. During implementation, it became clear that some dimensions were too broad for a single agent to score effectively.

**Decision.** Expand from five to eight scoring pillars by splitting three agents into more focused dimensions: Decision Agent split into `decision_maker_access_score` and `digital_footprint_score`; Growth Agent split into `growth_score` and `funding_activity_score`; the existing `regulatory_exposure_score` was added as a new standalone pillar. Each pillar has its own dedicated AI agent with a focused system prompt.

**Consequences.** Scoring granularity improved — each agent evaluates a narrower domain, producing more accurate and consistent scores. The expanded set runs in parallel without increasing pipeline runtime. Negative: five additional AI agent prompts to maintain and test. The total score range changed from 0-500 to 0-800, requiring downstream dashboard and threshold updates. The Consensus engine (layer 6) now processes eight inputs instead of five, increasing its complexity.

---

## ADR-017: Source Priority Chain with Cost Escalation
**Status:** Accepted | **Date:** 2025-02-10

**Context.** Multiple data sources are available for company intelligence, each with different costs, coverage, and reliability. The pipeline needed a deterministic source selection order to maintain predictable costs and data quality.

**Decision.** Establish a fixed source priority chain: Company Website → Firecrawl → Google Search → LinkedIn Company Page → Hunter Free → Apollo Free → Snov Free → Apify (paid fallback). Each step is attempted only if the previous step fails to provide sufficient data. The chain escalates from zero-cost sources to paid sources only when necessary.

**Consequences.** Approximately 70% of data is collected from the first three (free) sources. Paid API calls are rare and concentrated on high-value leads that pass the Cost Gate. Negative: low-priority sources (Apify) are rarely tested in production, leading to integration drift — they may fail when finally needed. The chain adds latency for companies requiring deep data (multiple fallback attempts).

---

## ADR-018: Railway for Custom Service Hosting
**Status:** Accepted | **Date:** 2025-02-15

**Context.** Custom services (SMTP verification, export generation, webhook handlers) require a hosting environment. Options included Railway, Render, Fly.io, and AWS Lambda.

**Decision.** Host all custom services on Railway. It provides easy GitHub-integrated deployments, PostgreSQL connection support, environment variable management, and a free tier for low-usage services. Railway's simple scaling and per-second billing align with the platform's variable workload (burst during pipeline, idle between runs).

**Consequences.** Deployment is as simple as pushing to a GitHub branch — no Docker configuration needed for standard Node.js services. Environment variables (API keys) are managed through Railway's dashboard. Negative: Railway's free tier sleeps after 5 minutes of inactivity — cold starts add 2-5 seconds to SMTP verification calls. Railway does not support region selection, so all services run in US-east, adding latency for Indian-targeted operations.
