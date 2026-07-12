# Design Principles

The Jasfo platform is built on seven core design principles. These principles guide every architectural decision, from model selection to prompt design to error handling. When there is ambiguity about how to implement something, the principles provide the answer.

## 1. Evidence First

Every AI-generated conclusion must cite its source. Claims without verifiable sources are discarded. The Evidence Engine enforces this by requiring full-text extraction for any claim used in scoring.

**How this shapes the architecture.** The Verification layer cross-checks every data point against at least two independent sources. The Specialist Agents are prompted to produce source URLs alongside every finding. The Judge penalizes leads with uncorroborated claims. If a source cannot be produced, the claim is treated as hallucination and discarded.

**Trade-off.** Evidence verification adds cost and complexity. Every claim requires at least one additional API call to retrieve the source content. This increases pipeline runtime and inference costs. The principle accepts this cost because unverified claims undermine broker trust and lead quality.

## 2. AI First

Every decision should be made by AI before human review. The pipeline operates autonomously from company intake to final scoring. The broker reviews outputs, not inputs.

**How this shapes the architecture.** There are no manual steps in the pipeline. No human-in-the-loop gates. No broker approval required before proceeding to the next layer. The AI agents make all decisions: which signals are relevant, which companies qualify, which contacts to target. The broker's role begins when the evidence package is delivered.

**Trade-off.** Fully autonomous operation means the platform can make mistakes without human catch. A systematic error in an AI agent's prompt could affect hundreds of companies before it is detected. The principle accepts this risk in exchange for the scalability of fully automated operation, mitigated by the Reflection process that catches systematic errors post-hoc.

## 3. Firecrawl First

Firecrawl is the default intelligence engine. Apify is used only when Firecrawl cannot retrieve required information. Free APIs come before paid APIs.

**How this shapes the architecture.** The Collection layer always tries Firecrawl first. Only if Firecrawl returns a 429, empty response, or explicitly unsupported target does the pipeline fall back to Apify. The source priority chain is: Firecrawl → Free APIs (SerpAPI, RSS) → Apify → Paid APIs. The cost gate enforces this hierarchy at every layer.

**Trade-off.** Firecrawl may miss data that a specialized tool (Crunchbase API, LinkedIn Sales Navigator) could provide. The principle accepts lower data density for free in exchange for never spending money on data that might not be useful.

## 4. Free APIs First

Paid APIs are reserved exclusively for companies that have demonstrated potential through the free pipeline layers. No company receives paid processing until it has passed verification, feature engineering, and initial specialist analysis.

**How this shapes the architecture.** The Cost Gate is the enforcement mechanism. Before any paid API call — Apify Actor execution, paid AI model inference, or third-party data lookup — the gate checks: has this company scored above threshold? Is the remaining budget sufficient? Would this spend be justified by the company's predicted value? If any check fails, the company is dropped or routed to a free alternative.

**Trade-off.** Some companies that would score highly after enrichment will be dropped at the cost gate because their pre-enrichment score was insufficient. The principle accepts these false negatives because the alternative — processing every company through paid APIs — would blow the budget.

## 5. Quality Over Quantity

Twenty verified opportunities are more valuable than ten thousand unqualified company names. The platform optimizes for lead quality, confidence, and broker productivity, not for database size or pipeline volume.

**How this shapes the architecture.** Every layer is designed to filter, not accumulate. The Verification layer drops companies with insufficient data. The Consensus engine requires multi-agent agreement before high confidence scores. The Judge has explicit authority to discard leads that meet scoring thresholds but fail its broader quality review. The broker receives 20–30 leads per week, not 500.

**Trade-off.** The platform will miss some genuine opportunities — companies that would have engaged if they had been included in the final batch. The principle accepts these misses because a broker with 100% recall but low lead quality would waste time on poor opportunities and miss good ones through distraction.

## 6. Cost Optimization

Every architectural decision is measured against the $50/month budget. If a feature cannot be implemented within this constraint, it is either deferred, simplified, or dropped.

**How this shapes the architecture.** The layered pipeline with progressive elimination is the primary cost optimization strategy. Cheap layers process all 10,000 companies; expensive layers process only the top 200. Model routing assigns each task to the cheapest capable model. Prompt caching and batching reduce per-token costs. The Reflection process identifies cost optimization opportunities.

**Trade-off.** Cost optimization sometimes means using a weaker model than ideal for a task. The principle accepts lower accuracy in non-critical layers in exchange for staying within budget. If the budget increases in the future, model quality can be upgraded.

## 7. Lazy-First Development

Build the simplest version that works. Do not build for scale that does not exist yet. Do not add features until they are needed. Do not optimize until there is evidence of a bottleneck.

**How this shapes the architecture.** The database schema has no user_id fields because there is only one user. The Make.com scenarios have simple linear flow because there is no need for complex branching. The AI prompts are direct and specific rather than generalized. Multi-tenant support, multi-city support, and team features are deferred until explicitly needed.

**Trade-off.** When multi-broker support or multi-city expansion is needed, the architecture will require significant refactoring. The principle accepts this future cost because building for scale that may never arrive would waste resources today.
