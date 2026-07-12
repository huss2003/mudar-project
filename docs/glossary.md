# Glossary

## A

**ADR (Architecture Decision Record).** A document that captures an important architectural decision made during the project, including the context, options considered, decision rationale, and consequences. ADRs are stored in `docs/architecture/adr/` and indexed on the ADR Index page.

**Apify.** A web scraping and automation platform used as the secondary data source when Firecrawl cannot retrieve required information. Apify handles LinkedIn company profile scraping, Google Maps business listings, and Crunchbase lookups via pre-built Actors.

## B

**Broker-Ready Opportunity.** A lead that has passed all 14 pipeline layers, received a Move Probability Score of 70+, been verified by at least two independent sources, and includes a complete evidence package with decision-maker contacts. These are the 20–30 companies delivered weekly.

## C

**Claude Sonnet 4.** Anthropic's frontier reasoning model used exclusively as the final Judge in the 14-layer pipeline. It evaluates all evidence, scores the lead, and produces the final Evidence Package. Chosen for superior reasoning, instruction-following, and refusal to hallucinate.

**Consensus.** The sixth pipeline layer where outputs from all five specialist AI agents are compared. If agents disagree on a company's likelihood to move, the Consensus engine flags the disagreement, requests additional evidence from the disagreeing agents, and produces a final unified score with confidence intervals.

**Contact Enrichment.** The eleventh pipeline layer. For companies that pass the cost gate, the platform attempts to identify key decision-makers: CEO, CFO, Head of Operations, and Facilities Manager. Email addresses are sourced from company websites, LinkedIn, and public records. No purchased contact lists are used.

**Cooldown.** A state applied to a company after it has been scored and delivered. Companies enter a 14-day cooldown during which they are not re-scanned. After 30 days without detected change, the company enters deep cooldown (90-day cycle). Cooldown prevents redundant processing and controls costs.

**Cost Gate.** The tenth pipeline layer. A hard cost check before any paid API is called. If a company's predicted value does not justify the cost of enrichment and strategy inference, it is either routed to a cheaper model or dropped. This ensures approximately 80% of spend is on the top 20% of candidates.

## D

**DeepSeek V4 Flash.** A cost-efficient AI model used for the majority of pipeline layers: discovery, normalization, feature engineering, specialist agents, and contact enrichment. It delivers approximately 90% of Claude's accuracy at 10% of the cost for structured output tasks.

## E

**Evidence Engine.** A subsystem that requires every AI-generated claim to cite its source URL with full-text extraction. Claims without verifiable sources are discarded. The Evidence Engine produces the Evidence Package that accompanies every delivered lead.

**Evidence Package.** The final deliverable for each lead. Contains: company profile, verified signals of intent, decision-maker contacts, commercial strategy recommendation, Move Probability Score, and source URLs for every claim. Delivered as part of the weekly CSV/Excel/PDF export.

## F

**Firecrawl.** An AI-native web scraping API that serves as the primary intelligence engine for the platform. Firecrawl handles company website scraping, blog monitoring, news detection, career page analysis, and technology stack detection. Chosen for its reliability, speed, and structured output capabilities.

## J

**Judge.** The fourteenth and final pipeline layer, powered by Claude Sonnet 4. The Judge receives the complete evidence package, evaluates each signal, applies scoring weights, performs a final hallucination check, and produces the definitive Move Probability Score. The Judge has authority to downgrade or discard leads that fail its scrutiny.

## L

**Lead Intelligence Report.** The comprehensive document produced for each qualified lead. It includes company overview, growth signals, space-need indicators, decision-maker profiles, competitive positioning, commercial strategy recommendations, and full source attribution.

**Lead Memory.** A persistent store in Supabase that maintains the history of every company ever processed. It stores all previous scores, detected changes, evidence packages, and broker interactions. Lead Memory enables change detection (comparing this week's signals to last month's) and prevents redundant processing.

## M

**Make.com.** The workflow automation platform that orchestrates the entire 14-layer pipeline. Make.com handles scheduling, API calls, data routing, error handling, retries, and Telegram notifications. Chosen for its visual workflow builder, low cost, and extensive integration library.

**MiMo V2.5.** A mid-cost AI model used for verification, consensus, and strategy layers. MiMo provides higher accuracy than DeepSeek for reasoning tasks at a fraction of Claude's cost. Used when DeepSeek confidence is insufficient but Claude is not yet justified.

**Move Probability Score (MPS).** A 0–100 score representing the likelihood that a company will relocate, expand, or lease commercial space within 90 days. The score is computed by the Judge layer based on weighted signals: growth indicators (40%), space-need triggers (30%), financial health (15%), industry trends (10%), and decision-maker accessibility (5%).

## N

**Normalization.** The second pipeline layer. Raw company data from scrapers is normalized into a consistent schema: standardized company names, industry classifications (using a custom Pune-adapted industry taxonomy), employee count ranges, and location formats. Inconsistent or incomplete records are flagged for verification.

## P

**Pillar.** One of the five specialist AI agent domains: Growth Agent (funding, hiring, expansion), Space Agent (lease expirations, layout changes, capacity), Financial Agent (revenue trends, profitability, investment), Industry Agent (sector trends, regulatory changes, competitive moves), and Decision Agent (organizational structure, key personnel changes, authority mapping). Each pillar produces independent findings that feed into the Consensus engine.

## R

**Reflection.** A post-consensus process where the platform reviews its own scoring history. Every 30 days, the system compares predicted move likelihoods against actual outcomes (leases signed, renewals, relocations). These reflections are used to recalibrate scoring weights and improve future predictions.

## S

**Specialist AI Agents.** A set of five parallel AI agents, each responsible for analyzing a specific dimension of a company. Each agent runs independently on DeepSeek V4 Flash or MiMo V2.5 depending on the complexity required. Their outputs are unified by the Consensus engine.

**Supabase.** The open-source Firebase alternative used as the primary database. Stores company profiles, lead scores, evidence packages, lead memory, cooldown states, pipeline logs, and error records. The free tier covers the platform's current data volume.

## V

**Verification.** The third pipeline layer. Each data point from normalization is cross-checked against at least two independent sources. Company size claims are verified against career pages and LinkedIn. Industry classifications are confirmed against business registries. Any unsupported claim is discarded before reaching the scoring layers.
