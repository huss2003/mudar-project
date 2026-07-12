# System Overview

The Jasfo platform is an end-to-end lead intelligence system that transforms raw company data into verified, scored, broker-ready opportunities. This document describes the system at a level above individual pipeline layers — focusing on the major subsystems, their interactions, and the overall data flow from input to output.

## System Boundaries

**Input:** A list of approximately 10,000 Pune-registered companies maintained in a Supabase table. This list is the universe of companies the platform monitors. It is seeded from business registries, industry associations, and IT park tenant lists, and is updated quarterly as new companies register or existing ones shut down.

**Output:** A weekly evidence package delivered via Telegram and CSV/Excel export. The package contains 20–30 companies with Move Probability Scores of 70+, complete evidence for each signal, decision-maker contact information, and commercial strategy recommendations.

**Constraints:** The system operates within a $50/month budget, completes each weekly run within 6 hours, and requires no more than 3 hours of broker time per week for lead review and outreach.

## Major Subsystems

### Data Collection Subsystem

The collection subsystem consists of Firecrawl (primary), Apify (secondary), and Free APIs (supplementary). Firecrawl handles bulk website scraping with configurable rate limiting and crawl depth. Apify provides LinkedIn company profile data, Google Maps business listings, and Crunchbase enrichment through pre-built Actors. Free APIs include SerpAPI for search results, MCA/GST registries for company verification, and RSS feeds for news monitoring.

The collection subsystem is designed for resilience. If Firecrawl returns a 429 rate limit or empty response, the company is automatically retried through Apify. If both scrapers fail, the company is marked as `scrape_blocked` and queued for a retry on the next pipeline run. Approximately 5–8% of companies encounter scraping issues in a typical run.

### Normalization and Verification Subsystem

Raw scraper output is inconsistent. One company's data might have a full website scrape, LinkedIn profile, and three news articles. Another might have only a website scrape with sparse content. The normalization subsystem (Layer 2) standardizes this data into a consistent schema: company name, industry classification (using a custom Pune-adapted taxonomy), employee count range, location, website status, and data freshness indicators.

The verification subsystem (Layer 3) then cross-checks every data point. Company size claims from LinkedIn are compared against career page headcount. Industry classifications are confirmed against business registry entries. News signals are verified against the original article source. Claims that cannot be verified to at least one independent source are discarded before reaching the scoring layers.

### AI Analysis Subsystem

This is the core reasoning engine, spanning Layers 4–10. Feature Engineering (Layer 4) extracts structured signals from the normalized data: hiring velocity, news sentiment, technology stack, organizational structure, and financial indicators. Five Specialist Agents (Layers 5–9) then analyze specific dimensions:

- **Growth Agent.** Analyzes hiring patterns, funding, expansion announcements, and revenue signals.
- **Space Agent.** Analyzes lease events, layout changes, capacity utilization, and facility management signals.
- **Financial Agent.** Analyzes revenue trends, profitability, investment activity, and credit events.
- **Industry Agent.** Analyzes sector trends, regulatory changes, competitive dynamics, and market positioning.
- **Decision Agent.** Analyzes organizational structure, key personnel changes, authority mapping, and decision-making processes.

Each agent produces independent findings. The Consensus engine (Layer 10) unifies these findings, resolving disagreements through weighted voting and requesting additional evidence when confidence is low.

### Lead Memory and Change Detection Subsystem

Lead Memory (Layer 11) is a persistent database that stores every company's history: all previous scores, detected signals, evidence packages, and broker interactions. This enables the Change Detection layer (Layer 12) to compare current signals against historical baselines.

Change detection is the primary mechanism for identifying emerging opportunities. A company that was stable for six months but suddenly posts 20 job openings has undergone a material change. A company that shows consistent gradual growth is less interesting. The change detection layer computes a delta score for each company — a measure of how significantly its profile has changed since the last evaluation.

### Cost Gate and Enrichment Subsystem

The Cost Gate (Layer 13) is a hard conditional check. Before any paid API is called, the system evaluates: the company's current score, the expected value of enrichment, and the remaining budget for the run. Companies below the score threshold are dropped. Companies above the threshold proceed to Contact Enrichment (Layer 14).

Contact Enrichment identifies decision-makers at qualified companies. The system targets specific roles: CEO, CFO, Head of Operations, Facilities Manager, and HR Head. Contacts are found through public sources: company website leadership pages, LinkedIn profiles, professional networking sites, and conference speaker lists. No purchased or scraped contact databases are used.

### Commercial Strategy and Judge Subsystem

The Commercial Strategy layer (Layer 15) produces a tailored outreach recommendation for each qualified lead. It considers: the company's space requirements (inferred from signals), the broker's current property inventory, market comparables, and timing considerations. The output is a specific outreach strategy: who to contact, what to say, what properties to highlight, and what questions to ask.

The Judge (Layer 16) is the final quality gate. Claude Sonnet 4 reviews the complete evidence package, evaluates every claim, applies the scoring rubric, and produces the definitive Move Probability Score. The Judge has authority to downgrade or discard leads that fail its scrutiny. This is the only layer that uses frontier AI, and it is deliberately positioned as the final step to maximize the value of each expensive API call.

### Subscription and Notification Subsystem

The delivery subsystem produces the final outputs. An evidence package summarizing the top leads and their signals is sent via Telegram. A CSV file with all scored leads and their evidence can be exported to Excel for broker review. PDF reports can be generated for specific high-value leads to share with clients. The Telegram notification includes a summary of pipeline performance metrics: companies processed, leads scored, top signals, and cost incurred.

## Information Flow Summary

```
Company List (10,000)
  → Scraped Data (Firecrawl + Apify)
  → Normalized Records
  → Verified Claims
  → Feature Vectors
  → Specialist Analysis (5 parallel agents)
  → Consensus Scores
  → Memory Store (historical comparison)
  → Change Deltas
  → Cost Gate (qualify for spend)
  → Enriched Contacts
  → Strategy Recommendations
  → Judge Scores (Claude Sonnet 4)
  → Evidence Package (20–30 leads)
  → Broker
```
