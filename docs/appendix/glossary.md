# Appendix: Glossary

> Full reference of platform-specific terminology. Every term used across the 14-layer pipeline, documentation, and AI agent prompts is defined here.

---

### Apify

A web scraping and automation platform used as the secondary data source when Firecrawl cannot retrieve required information. Apify handles LinkedIn company profile scraping, Google Maps business listings, and Crunchbase lookups via pre-built Actors. It is never invoked directly by Make.com; instead, an OpenCode GO agent evaluates whether Firecrawl returned sufficient data and falls back to Apify only when gaps exist. This preserves the Firecrawl-first philosophy while ensuring complete coverage for high-value leads that pass the Cost Gate.

---

### Claude Judge

The fourteenth and final pipeline layer, powered by Claude Sonnet 4 via OpenRouter. The Judge receives the complete Evidence Package from all preceding layers, evaluates every signal, applies scoring weights, performs a final hallucination check, and produces the definitive Move Probability Score. It has authority to downgrade or discard leads that fail its scrutiny. The Judge is the only component that uses Claude Sonnet 4, reserved exclusively for this role because of its superior reasoning, instruction-following, and refusal to hallucinate. All preceding layers use cheaper models (DeepSeek V4 Flash, MiMo V2.5). The Judge enforces the 2-Source Rule, verifies every Evidence Engine citation, and rejects any claim that lacks a verifiable source URL.

---

### Claude Sonnet 4

Anthropic's frontier reasoning model used exclusively as the Judge in the 14-layer pipeline. Chosen for superior reasoning depth, adherence to complex multi-part instructions, and statistically lower hallucination rates compared to alternatives at its price point. At approximately $8/1M input tokens, it costs roughly 40× more than DeepSeek V4 Flash and 10× more than MiMo V2.5, which is why it is strictly gated to the final evaluation of only 20–30 pre-qualified leads per week. The model is accessed via OpenRouter, which provides prompt caching to reduce effective cost on repeated system prompts.

---

### Consensus

The sixth pipeline layer where outputs from all eight pillar-scoring agents are compared. The Consensus engine (powered by MiMo V2.5) receives eight independent pillar scores and their supporting evidence texts. If agents disagree on a company's likelihood to move, the engine flags the disagreement, identifies which specific signals caused the divergence, and requests additional evidence from the disagreeing agents. It produces a unified score range with confidence intervals rather than a single number when consensus is weak. Companies with low inter-agent consensus (high variance across pillars) are deprioritized regardless of their mean score, because high variance indicates unreliable data.

---

### Cooldown

A state applied to a company after it has been scored and delivered. Companies enter a 14-day active cooldown during which they are excluded from the weekly pipeline. After 30 days without detected change, the company enters deep cooldown with a 90-day recycle cycle. Cooldown prevents redundant processing of recently evaluated companies and controls API costs. When a company is in cooldown, its snapshot is still compared against new data from Firecrawl's crawl endpoint, but no AI agents are invoked unless the change detection layer (layer 12) reports a significant delta. Cooldown dates are tracked in the `decisions` table via `cooldown_until` and state columns.

---

### Cost Gate

The tenth pipeline layer. A hard cost check before any paid API is called. If a company's combined pillar scores do not meet a configurable threshold (default: 350 of 800), it is either routed to a cheaper model or dropped from further processing. The gate evaluates total score, individual pillar lows, and inter-agent consensus variance. This ensures approximately 80% of the pipeline's paid-model budget is concentrated on the top 20% of candidates. The Cost Gate is implemented as a conditional branch in Make.com that checks the `total_score` field from `lead_scores` before triggering any Firecrawl credit, Apify actor, or Claude call. Companies below the gate are logged for reporting but the pipeline does not proceed to contact enrichment or the Judge.

---

### DeepSeek V4 Flash

A cost-efficient AI model used for the majority of pipeline layers: discovery, normalization, feature engineering, all eight pillar-scoring agents, and contact enrichment. It delivers approximately 90% of Claude's accuracy at 10% of the cost for structured output tasks. Priced at approximately $0.20/1M input tokens, it is the workhorse of the platform. Approximately 60% of all AI calls use DeepSeek V4 Flash. The model is accessed via OpenCode GO, which provides an OpenAI-compatible API. It is particularly effective for classification, extraction, and summarization tasks where JSON structure is well-defined.

---

### Evidence Engine

A subsystem that requires every AI-generated claim to cite its source URL with full-text extraction. Claims without verifiable sources are discarded. The Evidence Engine operates across layers 3 (Verification) through 14 (Judge) and maintains its own database tables: `evidence_claims` (each factual assertion), `evidence_sources` (the URLs backing each claim), and `evidence_snapshots` (immutable bundles per weekly cycle). The engine exposes a REST API endpoint for agents to submit claims and receive validation responses. It enforces the 2-Source Rule by checking that each claim has at least two independent source URLs before marking it as verified.

---

### Evidence Package

The final deliverable for each qualified lead. Contains company profile, verified signals of intent across all eight pillars, decision-maker contacts (name, title, email, confidence score), commercial strategy recommendation, Move Probability Score, and source URLs for every claim. The package is assembled by the Judge layer and stored as a JSONB blob in `evidence_snapshots`. It is exported as part of the weekly CSV/Excel deliverable and also available via the REST API. The Evidence Package is immutable once delivered; any corrections produce a new version with a `supersedes` reference to the previous version.

---

### Firecrawl

An AI-native web scraping API that serves as the primary intelligence engine for the platform. Firecrawl handles company website crawling, blog monitoring, news detection, career page analysis, and technology stack detection. It was chosen over Apify as the primary scraper because of its superior structured output, existing paid plan, and lower per-request cost. Firecrawl endpoints used: `POST /v1/crawl` for full site scraping, `POST /v1/extract` for structured data extraction, `POST /v1/search` for intent signal discovery, and `POST /v1/map` for site topology mapping. All Firecrawl responses are cached in Redis with a 24-hour TTL to avoid redundant requests during pipeline error recovery.

---

### Lead Intelligence Report

The comprehensive document produced for each qualified lead that passes the Judge layer. It includes company overview, growth signals, space-need indicators, decision-maker profiles, competitive positioning, commercial strategy recommendations, and full source attribution. The report is generated programmatically as a structured JSON document and then formatted for the broker's preferred output (CSV row, Excel sheet, or PDF). Unlike the Evidence Package (which is raw evidence), the Lead Intelligence Report includes the broker-facing narrative, commercial reasoning, and recommended next steps. It is the artifact the broker reads and acts upon.

---

### Lead Memory

A persistent store in Supabase that maintains the history of every company ever processed through the pipeline. It stores all previous pillar scores, detected changes, evidence packages, and broker interactions. Lead Memory enables the Change Detection layer (layer 12) to compare this week's signals to previous cycles and identify significant deltas in headcount, website content, news mentions, or technology stack. It also prevents redundant processing by tracking cooldown states. The data lives across `lead_scores`, `decisions`, `lead_events`, and `companies_snapshots` tables, linked by `company_id`.

---

### Leading vs Lagging Indicators

A classification system applied to the eight pillar scores. Leading indicators predict future behavior: growth_score, space_need_score, decision_maker_access_score, and funding_activity_score. These are weighted more heavily in the Move Probability Score calculation because they signal imminent decisions. Lagging indicators reflect established conditions: financial_health_score, industry_trend_score, digital_footprint_score, and regulatory_exposure_score. They provide context but do not predict timing. The Judge layer applies a 70/30 weight split favoring leading indicators. This weighting is periodically recalibrated during the Reflection cycle based on actual outcome data.

---

### MiMo V2.5

A mid-cost AI model used for verification, consensus, and commercial strategy layers. Priced at approximately $0.75/1M input tokens, it provides higher accuracy than DeepSeek V4 Flash for reasoning and analytical tasks at roughly 4× the cost but still 10× cheaper than Claude Sonnet 4. MiMo V2.5 is used when DeepSeek confidence is insufficient but Claude is not yet justified. In practice, it handles approximately 20% of all AI calls. It is accessed via OpenCode GO alongside DeepSeek, allowing the pipeline to route individual agent tasks to the appropriate model based on complexity requirements.

---

### Move Probability Score (MPS)

A 0–100 score representing the likelihood that a company will relocate, expand, or lease commercial space within 90 days. The score is computed by the Judge layer based on weighted signals: growth indicators (40%), space-need triggers (30%), financial health (15%), industry trends (10%), and decision-maker accessibility (5%). Companies scoring 70+ qualify as broker-ready leads. The score is stored in `lead_scores.total_score` as an integer and accompanied by individual pillar scores (0-100 each, summed to 0-800) and confidence intervals from the Consensus engine. MPS is recalculated each weekly cycle and compared against historical scores for trend analysis.

---

### OpenCode GO

The AI model gateway that provides OpenAI-compatible API access to DeepSeek V4 Flash and MiMo V2.5. OpenCode GO handles model routing internally, allowing the pipeline to select the optimal model per task without changing API call patterns. It provides cost tracking, rate limiting, and error handling that would otherwise need to be built into each Make.com scenario. All pipeline layers except the Judge route through OpenCode GO. It is the primary cost-control mechanism, ensuring that cheaper models handle bulk processing while premium models are reserved for high-value evaluations.

---

### Pillar (1-8)

One of the five AI agent domains — later expanded to eight scoring dimensions. Each pillar is an independent scoring dimension: (1) growth_score — headcount and revenue trajectory; (2) space_need_score — lease expirations and capacity signals; (3) financial_health_score — funding, profitability, burn rate; (4) industry_trend_score — sector tailwinds and headwinds; (5) decision_maker_access_score — contact findability and org structure; (6) digital_footprint_score — website and social media activity; (7) funding_activity_score — recent funding rounds and investor activity; (8) regulatory_exposure_score — compliance-driven relocation triggers. Each pillar is scored 0–100 by an independent AI agent. The eight scores are summed for a total of 0–800. Pillars are classified as leading or lagging indicators and weighted accordingly by the Judge.

---

### Reflection

A post-consensus process where the platform reviews its own scoring history. Every 30 days, the Reflection agent compares predicted move likelihoods (MPS) against actual outcomes: leases signed, renewals spotted, relocations detected, or broker feedback entered. These reflections are used to recalibrate scoring weights, adjust model routing rules, and identify systematic biases (e.g., consistently over-scoring a particular industry). Results are stored in the audit log and can trigger ADR updates if weight adjustments exceed configurable thresholds. Reflection is an optional layer that runs outside the weekly pipeline on a monthly cycle.

---

### SMTP Verification

A free email verification method used as the final check before adding a contact to the Evidence Package. The platform connects to the target domain's SMTP server on port 25 and performs a multi-step sequence: MX lookup, EHLO handshake, MAIL FROM with a verified sender domain, RCPT TO for the target address, and QUIT. A 250 response from RCPT TO indicates the mailbox exists. Catch-all domains are detected by testing a random invalid address first; if that also receives a 250, the domain is catch-all and verification confidence drops from 0.95 to 0.50. SMTP verification has no per-check cost but is rate-limited to prevent blacklisting: maximum 2 concurrent connections per MX, 100ms minimum delay between checks, and 5,000 checks per day. It is implemented via a custom Node.js script deployed on Railway.

---

### Specialist Agent

A set of eight parallel AI agents, each responsible for scoring a specific pillar of a company's profile. Each agent runs independently on DeepSeek V4 Flash or MiMo V2.5 depending on the complexity of its scoring dimension. Agents are stateless: they receive the current feature vector for a company and produce a score plus supporting evidence. Their outputs are unified by the Consensus engine, which flags disagreements and requests re-evaluation where needed. Swap agents (for alternative analyses) run only when primary agents produce low-confidence scores. Each agent has a dedicated system prompt stored in the prompts directory, defining its evaluation criteria, evidence requirements, and output schema.

---

### 2-Source Rule

A verification policy requiring every factual claim in the pipeline to be corroborated by at least two independent sources before it can influence scoring. For example, a headcount claim must be verified against both the company's LinkedIn page and its career page. If only one source supports a claim, it is marked as "low confidence" and contributes proportionally less to the relevant pillar score. The rule is enforced by the Evidence Engine across all layers from verification through the Judge. It is the primary defense against hallucinated data and single-source errors. Violations are logged in `evidence_claims` with a `confidence` score below 50.

---

### Firecrawl (second entry for completeness)

See Firecrawl above. The primary scraping engine is listed here again because it is referenced across every pipeline layer. All pipeline layers that require external data invoke Firecrawl first, with Apify as a fallback. Firecrawl's `POST /v1/extract` endpoint with structured output schemas is the most-used single endpoint in the platform, responsible for company website analysis, tech stack detection, and intent signal discovery.

---

### OpenCode GO (second entry for completeness)

See OpenCode GO above. Secondary reference covering its role as the model gateway for all non-Judge layers. OpenCode GO provides the routing logic that selects between DeepSeek V4 Flash and MiMo V2.5 per task, based on complexity tags set by the Make.com orchestrator. It also aggregates token usage and cost data across all pipeline runs, feeding the `/cost_log` table for budget tracking.

---

### DeepSeek V4 Flash (second entry for completeness)

See DeepSeek V4 Flash above. Secondary reference covering its specific role in the 14-layer pipeline: layers 1 (Collection normalization), 2 (Normalization), 4 (Feature Engineering), all 8 pillar-scoring agents (layers 5-9), and 11 (Change Detection). DeepSeek handles 60% of all AI calls and approximately 70% of total pipeline token volume. Its structured output capabilities are leveraged through JSON mode with Zod schema validation on the receiving end.
