# Architecture Decision Records (ADR) Index

Architecture Decision Records capture significant architectural decisions made during the Jasfo platform's development. Each ADR documents the context, options considered, decision rationale, and consequences. The ADRs are stored in `docs/architecture/adr/` and follow the now-decision-now-context format.

## Active ADRs

| ID | Title | Date | Status |
|----|-------|------|--------|
| ADR-001 | [Use Make.com as the Primary Workflow Orchestrator](adr/ADR-001.md) | 2025-01-15 | Accepted |
| ADR-002 | [Use Supabase as the Single Database](adr/ADR-002.md) | 2025-01-15 | Accepted |
| ADR-003 | [Adopt 14-Layer Sequential Pipeline Architecture](adr/ADR-003.md) | 2025-01-20 | Accepted |
| ADR-004 | [Assign DeepSeek V4 Flash as Default AI Model](adr/ADR-004.md) | 2025-01-20 | Accepted |
| ADR-005 | [Reserve Claude Sonnet 4 for Judge Layer Only](adr/ADR-005.md) | 2025-01-20 | Accepted |
| ADR-006 | [Implement Cost-Gating Between Free and Paid Layers](adr/ADR-006.md) | 2025-01-25 | Accepted |
| ADR-007 | [Firecrawl as Primary Scraper with Apify Fallback](adr/ADR-007.md) | 2025-01-25 | Accepted |
| ADR-008 | [Evidence Engine Requires Source URL for Every Claim](adr/ADR-008.md) | 2025-02-01 | Accepted |
| ADR-009 | [Single-User Architecture (No Multi-Tenant)](adr/ADR-009.md) | 2025-02-01 | Accepted |
| ADR-010 | [Telegram as Primary Notification Channel](adr/ADR-010.md) | 2025-02-05 | Accepted |
| ADR-011 | [Reflection Cadence: 30-Day Cycles](adr/ADR-011.md) | 2025-02-10 | Accepted |
| ADR-012 | [Cooldown Strategy: 14-Day Active, 90-Day Deep](adr/ADR-012.md) | 2025-02-10 | Accepted |
| ADR-013 | [Weekly Pipeline Schedule: Monday 00:00 IST](adr/ADR-013.md) | 2025-02-15 | Accepted |
| ADR-014 | [Export Format: CSV Primary, Excel Secondary, PDF on Demand](adr/ADR-014.md) | 2025-02-15 | Accepted |

## ADR Summaries

### ADR-001: Make.com as Primary Workflow Orchestrator
**Decision.** Use Make.com for all pipeline orchestration instead of Apache Airflow, n8n, or custom Python scripts.
**Rationale.** Make.com's visual workflow builder enables rapid iteration without code deployments. Its error handling, retry logic, and scheduling capabilities meet platform needs without the operational overhead of Airflow. Cost ($0–9/month) is significantly lower than alternatives.

### ADR-002: Supabase as the Single Database
**Decision.** Use Supabase (PostgreSQL) as the sole database, avoiding separate systems for logs, cache, or queues.
**Rationale.** Supabase's free tier covers current data volume. PostgreSQL provides JSON support for flexible schema, real-time subscriptions for live updates, and Row-Level Security for future multi-user scenarios. Avoiding multiple database systems reduces operational complexity and cost.

### ADR-003: 14-Layer Sequential Pipeline Architecture
**Decision.** Implement the lead intelligence pipeline as 14 sequential layers rather than a monolithic process or microservices.
**Rationale.** Sequential layering enables independent testing, upgrading, and debugging of each layer. Progressive elimination ensures cost is concentrated on high-potential companies. The trade-off (increased total runtime) is acceptable for a weekly batch process.

### ADR-004: DeepSeek V4 Flash as Default AI Model
**Decision.** Use DeepSeek V4 Flash for all high-volume pipeline layers, reserving more expensive models for specialized tasks.
**Rationale.** DeepSeek V4 Flash provides approximately 90% of frontier-model capability at 10% of the cost for structured output tasks. The platform's cost constraints (under $50/month) require a cost-efficient default model.

### ADR-005: Claude Sonnet 4 for Judge Layer Only
**Decision.** Restrict Claude Sonnet 4 usage exclusively to the final Judge evaluation layer.
**Rationale.** Claude Sonnet 4's cost ($3–15/1M tokens) is prohibitive for bulk processing. Its superior reasoning and instruction-following are most valuable at the final quality gate, where it evaluates a small number of highly qualified leads.

### ADR-006: Cost-Gating Between Free and Paid Layers
**Decision.** Implement a hard cost gate between layers 12 and 14 that blocks companies from triggering paid APIs unless they meet a minimum score threshold.
**Rationale.** Without a cost gate, the platform would spend its entire budget on the first 1,000 companies processed. The gate ensures budget is distributed across promising candidates and prevents runaway costs during pipeline errors.

### ADR-007: Firecrawl Primary with Apify Fallback
**Decision.** Firecrawl is the primary scraper. Apify is used only when Firecrawl fails or cannot handle the target.
**Rationale.** Firecrawl has an existing paid plan, handles 90%+ of scraping needs, and provides structured output. Apify's proxy rotation and pre-built Actors provide fallback capabilities. Using Apify as primary would triple scraping costs.

### ADR-008: Source URL Requirement for Every Claim
**Decision.** The Evidence Engine requires every AI-generated claim to cite its source URL with full-text extraction.
**Rationale.** Unverifiable claims are indistinguishable from hallucinations. Requiring source URLs creates accountability in AI outputs and enables broker trust. The cost of additional verification API calls is justified by eliminating hallucinated leads.

### ADR-009: Single-User Architecture
**Decision.** Build for a single broker operator without multi-tenant or team features.
**Rationale.** Multi-tenant architecture adds complexity (user tables, authentication, RLS) that would delay delivery without providing near-term value. The platform can be refactored for multi-user support when and if expansion is warranted.

### ADR-010: Telegram as Primary Notification Channel
**Decision.** Use Telegram bot for pipeline notifications instead of email, Slack, or SMS.
**Rationale.** Telegram is free, provides push notifications, has a simple JSON API, and the broker already uses it. Email is too slow for time-sensitive pipeline alerts. Slack requires a paid plan for reliable API access. SMS costs per-message.

### ADR-011: 30-Day Reflection Cycles
**Decision.** Run the Reflection process every 30 days to compare predicted move probabilities against actual outcomes.
**Rationale.** Monthly cycles provide sufficient data volume for meaningful analysis (80–120 leads) while being frequent enough to catch systematic scoring errors. Weekly cycles would have insufficient data; quarterly cycles would be too slow to correct drift.

### ADR-012: 14-Day Active Cooldown, 90-Day Deep Cooldown
**Decision.** Companies enter a 14-day active cooldown after scoring, and a 90-day deep cooldown if no significant change is detected after two refresh cycles.
**Rationale.** The cooldown strategy balances data freshness against processing cost. Active cooldown prevents redundant weekly processing of recently evaluated companies. Deep cooldown ensures companies with no recent activity are not continuously consuming pipeline resources.

### ADR-013: Weekly Pipeline on Monday 00:00 IST
**Decision.** Schedule the weekly pipeline run to start at midnight Monday IST, completing before Monday morning.
**Rationale.** Monday delivery gives the broker the full week to review and act on leads. Overnight processing avoids competing with daytime API rate limits. Weekly cadence matches the broker's workflow rhythm.

### ADR-014: CSV Primary Export Format
**Decision.** Deliver leads primarily as CSV with Excel formatting for review, and PDF on demand for specific high-value leads.
**Rationale.** CSV is universally readable, easy to import into any tool, and simple to generate programmatically. Excel adds formatting for broker review. PDF is reserved for leads requiring client-facing presentation.

---

*For the full text of any ADR, click the link above or navigate to `docs/architecture/adr/ADR-NNN.md`.*
