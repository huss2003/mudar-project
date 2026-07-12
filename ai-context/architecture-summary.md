# Architecture Summary

> One-page reference for the 14-layer pipeline, data flow, and key decisions. Optimized for AI agent context.

## The 14-Layer Pipeline

| # | Layer | Model | Cost | Input -> Output |
|---|-------|-------|------|-----------------|
| 1 | Collection | Firecrawl | Free | Company list -> Raw scraped data |
| 2 | Normalization | DeepSeek V4 Flash | Free | Raw data -> Structured records |
| 3 | Verification | MiMo V2.5 | Free | Records -> Verified claims |
| 4 | Feature Engineering | DeepSeek V4 Flash | Free | Claims -> Feature vectors |
| 5-9 | Specialist Agents (5) | DeepSeek + MiMo | Free | Vectors -> Multi-dim analysis |
| 10 | Consensus | MiMo V2.5 | Free | Agent outputs -> Unified scores |
| 11 | Lead Memory | — | Free | Scores -> Historical comparison |
| 12 | Change Detection | DeepSeek V4 Flash | Free | Current vs historical delta |
| 13 | Cost Gate | — | Gate | Score check -> Qualified candidates |
| 14 | Contact Enrichment | DeepSeek V4 Flash | Paid | Candidates -> Decision-maker contacts |
| 15 | Commercial Strategy | MiMo V2.5 | Paid | Contacts -> Outreach strategy |
| 16 | Judge | Claude Sonnet 4 | Paid | Strategy + Evidence -> Final scores |

## Data Flow (Company Counts)

```
10,000 -> 9,500 -> 8,000 -> 5,000 -> 2,000 -> 1,000 -> 500 -> 200 -> 20-30
(Input)                                                      (Gate) (Output)
```

## Key Design Decisions

1. **Model assignment:** DeepSeek V4 Flash handles 60% (~$0.20/1M tokens), MiMo 30% (~$0.75/1M), Claude Sonnet 4 only Judge layer (~$8/1M).
2. **Cost-gating:** 80% of budget on top 20% of companies. Cost Gate enforces minimum score threshold before paid processing.
3. **Single-user:** No user_id columns, no multi-tenant RLS, no auth workflows beyond API keys.
4. **Sequential pipeline:** Layers execute in order. Trade-off: 4-6 hr runtime, but simple debugging.
5. **Parallel fan-out:** All 8 pillar-scoring agents run in parallel against same feature vector.
6. **Sequential pipeline:** Layers run in order. Preceding layer must complete before next begins.

## Critical Numbers

| Metric | Target |
|--------|--------|
| Companies processed/week | 10,000 |
| Qualified leads delivered | 20-30 |
| Monthly cost | < $50 |
| Pipeline runtime | < 6 hrs |
| Broker time/week | 2-3 hrs |
| Score threshold | 70+ |
| Cost per lead | < $2 |

## Source Priority Chain

Company Website -> Firecrawl -> Google -> LinkedIn Company -> Hunter Free -> Apollo Free -> Snov Free -> Apify (fallback)
