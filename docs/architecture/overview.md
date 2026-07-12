# Architecture Overview

The Jasfo platform is built on a 14-layer sequential pipeline architecture. Each layer has a specific responsibility, an assigned AI model, a defined cost budget, and known failure modes. The pipeline transforms approximately 10,000 raw companies per week into 20–30 evidence-backed, broker-ready leads through progressive filtering, verification, enrichment, and scoring.

## Pipeline Design Philosophy

**Progressive elimination is the core pattern.** Each layer acts as a filter, removing companies that fail its criteria before passing survivors to the next layer. The first layers are cheap and broad, processing all 10,000 companies with minimal cost per company. The final layers are expensive and narrow, processing only 100–200 highly qualified candidates. This design ensures that approximately 80% of the budget is spent on the top 20% of candidates.

**Layers are independent and swappable.** Each layer communicates only through well-defined data structures in Supabase. No layer calls another layer directly. This means individual layers can be upgraded, replaced, or bypassed without affecting the rest of the pipeline. If a better normalization model emerges next quarter, only the normalization layer changes.

**Failure is expected and handled gracefully.** Every layer has defined failure states. If a scraper returns empty data, the company is retried once with a fallback source. If an AI agent fails to produce a confident prediction, the company continues with a low-confidence flag. If the entire pipeline crashes, Make.com retries from the last checkpoint. No single failure stops the pipeline.

## The 14 Layers

| Layer | Name | Model | Cost | Companies Out |
|-------|------|-------|------|---------------|
| 1 | Collection | — | Free | 10,000 |
| 2 | Normalization | DeepSeek V4 Flash | Low | 9,500 |
| 3 | Verification | MiMo V2.5 | Low | 8,000 |
| 4 | Feature Engineering | DeepSeek V4 Flash | Low | 8,000 |
| 5 | Growth Agent | DeepSeek V4 Flash | Low | 5,000 |
| 6 | Space Agent | DeepSeek V4 Flash | Low | 5,000 |
| 7 | Financial Agent | MiMo V2.5 | Medium | 4,000 |
| 8 | Industry Agent | DeepSeek V4 Flash | Low | 4,000 |
| 9 | Decision Agent | DeepSeek V4 Flash | Low | 4,000 |
| 10 | Consensus | MiMo V2.5 | Low | 2,000 |
| 11 | Lead Memory | — | Free | 2,000 |
| 12 | Change Detection | DeepSeek V4 Flash | Low | 1,000 |
| 13 | Cost Gate | — | Free | 500 |
| 14 | Contact Enrichment | DeepSeek V4 Flash | Medium | 200 |
| 15 | Commercial Strategy | MiMo V2.5 | Medium | 200 |
| 16 | Judge | Claude Sonnet 4 | High | 20–30 |

Note: For documentation purposes, layers 5–9 (Specialist Agents) are counted as one layer, giving the canonical 14-layer architecture: Collection, Normalization, Verification, Feature Engineering, Specialist Agents, Consensus, Lead Memory, Change Detection, Cost Gate, Contact Enrichment, Commercial Strategy, Judge, Evidence Package, Export.

## Data Flow

Data moves through the pipeline asynchronously via Make.com workflows. Each layer reads from a Supabase input table, processes the data, writes results to a Supabase output table, and signals completion. The next layer polls for new records in its input table. This decoupled design means layers can be scaled independently and the pipeline can be paused or restarted at any point.

**Collection Layer** triggers at 00:00 IST Monday. The company list is read from a Supabase table containing Pune-registered companies. Firecrawl processes the list with rate limiting to avoid blocks. Apify handles LinkedIn and Google Maps enrichment as secondary sources.

**AI Layers (2–10, 14–16)** invoke model APIs through OpenCode GO. Each call includes the company data, the layer's system prompt, and any context from previous layers. The response is validated against the expected schema before being written to Supabase. Invalid responses trigger a retry with a different model.

**Cost Gate (Layer 13)** is a simple conditional check. If a company's current score is below threshold, or if its predicted value does not justify the cost of enrichment, the company is either routed to a cheaper model or dropped entirely.

## Cost Allocation

The pipeline's total cost is heavily skewed toward the final layers. Approximate cost distribution: Collection (5%), Normalization (5%), Verification (8%), Feature Engineering (5%), Specialist Agents (15%), Consensus (5%), Memory/Change (2%), Cost Gate (0%), Enrichment (15%), Strategy (10%), Judge (30%). The Judge layer alone costs approximately 30% of the total because it uses Claude Sonnet 4 — the most expensive model — and because it processes the full evidence package for each lead.

## Failure Modes

| Layer | Failure Mode | Handling |
|-------|-------------|----------|
| Collection | Scraper blocked/rate-limited | Fall back to secondary scraper |
| Normalization | Schema validation failure | Flag company, continue with partial data |
| Verification | Source unreachable | Retry once, then mark unverifiable |
| Feature Engineering | Empty feature vector | Drop company from pipeline |
| Specialist Agents | Agent produces inconclusive result | Pass to consensus with low confidence |
| Consensus | Agents disagree | Request additional evidence, re-run |
| Lead Memory | Database write failure | Queue for retry, continue pipeline |
| Change Detection | Comparison timeout | Skip comparison, treat as new company |
| Cost Gate | Gate logic error | Default to conservative (drop company) |
| Contact Enrichment | No contacts found | Deliver lead without contacts, flag for manual |
| Commercial Strategy | Strategy generation failure | Use template strategy |
| Judge | API error | Retry with exponential backoff |
