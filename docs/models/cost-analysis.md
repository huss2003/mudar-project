# Cost Analysis

This document provides a detailed breakdown of AI API costs for the Jasfo Lead Intelligence Platform, including cost per task, monthly projections, and optimisation strategies.

## Cost Per Model

| Model | Cost per 1M Input Tokens | Cost per 1M Output Tokens | Avg Tokens per Task | Avg Cost per Task |
|-------|--------------------------|---------------------------|--------------------|--------------------|
| DeepSeek V4 Flash | $0.50 | $2.00 | 850 | $0.00085 |
| MiMo V2.5 | $2.00 | $8.00 | 2,400 | $0.00720 |
| Claude Sonnet 4 | $15.00 | $75.00 | 7,500 | $0.05200 |

## Cost Per Layer

Estimated cost per lead for each layer:

| Layer | Model | Avg Input Tokens | Avg Output Tokens | Cost per Lead |
|-------|-------|-------------------|-------------------|---------------|
| 1 — Discovery | DeepSeek V4 Flash | 400 | 150 | $0.00050 |
| 2 — Normalisation | DeepSeek V4 Flash | 200 | 100 | $0.00030 |
| 3 — Verification | MiMo V2.5 | 1,200 | 400 | $0.00560 |
| 4 — Consensus | MiMo V2.5 | 3,000 | 600 | $0.01080 |
| 5 — Reflection | MiMo V2.5 | 1,800 | 500 | $0.00760 |
| 6 — Judge | Claude Sonnet 4 | 7,500 | 1,000 | $0.05200 |
| 7 — Enrichment | DeepSeek V4 Flash | 500 | 200 | $0.00065 |
| 8 — Scoring | DeepSeek V4 Flash | 600 | 100 | $0.00050 |
| 9 — Prioritisation | DeepSeek V4 Flash | 300 | 100 | $0.00035 |
| 10 — Intent Prediction | MiMo V2.5 | 1,000 | 300 | $0.00440 |
| 11 — Engagement Strategy | MiMo V2.5 | 800 | 400 | $0.00480 |
| 12 — Summary Generation | DeepSeek V4 Flash | 500 | 300 | $0.00085 |
| 13 — Confidence Calibration | MiMo V2.5 | 700 | 200 | $0.00300 |
| 14 — Output Assembly | DeepSeek V4 Flash | 400 | 200 | $0.00060 |

**Total per lead (full pipeline): ~$0.092**

## Monthly Cost Projection

| Volume | DeepSeek V4 Flash | MiMo V2.5 | Claude Sonnet 4 | **Total** |
|--------|-------------------|-----------|----------------|-----------|
| 500 leads/month | $1.58 | $15.12 | $15.60 | **$32.30** |
| 1,000 leads/month | $3.15 | $30.24 | $31.20 | **$64.59** |
| 5,000 leads/month | $15.75 | $151.20 | $156.00 | **$322.95** |
| 10,000 leads/month | $31.50 | $302.40 | $312.00 | **$645.90** |

*Note: Assumes every lead goes through the full pipeline. In practice, only ~10% of leads reach the Judge layer, reducing Claude costs by ~90%.*

## Realistic Monthly Cost

Based on current pipeline flow where only qualified leads reach the Judge:

| Stage | % of Leads | Cost per Lead | Monthly Cost (1K leads) |
|-------|-----------|---------------|----------------------|
| Layers 1–2 (all leads) | 100% | $0.00080 | $0.80 |
| Layers 3–5 (all leads) | 100% | $0.02400 | $24.00 |
| Layer 6 (top 10%) | 10% | $0.05200 | $5.20 |
| Layers 7–14 (all leads) | 100% | $0.01575 | $15.75 |
| **Total** | | **$0.093** | **$45.75** |

**Estimated realistic monthly cost for 1,000 leads: ~$46**

## Cost Optimisation Strategies

### 1. Cache Optimisation (saves ~30%)

Target higher cache hit rates by identifying repeated patterns:

| Strategy | Est. Savings | Implementation |
|----------|-------------|---------------|
| Extend TTL for stable fields | $4/month | Increase company name/industry TTL to 60 days |
| Normalisation caching | $3/month | Cache normalised outputs for re-processing |
| Deduplication before AI call | $2/month | Identify exact duplicate leads before API call |

### 2. Prompt Optimisation (saves ~15%)

| Strategy | Est. Savings | Implementation |
|----------|-------------|---------------|
| Shorter system prompts | $3/month | Remove redundant instructions |
| Fewer few-shot examples | $2/month | Use 3 examples instead of 5 where accuracy holds |
| Reduced output tokens | $2/month | Request concise output where possible |

### 3. Routing Optimisation (saves ~10%)

| Strategy | Est. Savings | Implementation |
|----------|-------------|---------------|
| Downgrade low-confidence leads | $3/month | Route low-quality leads through DeepSeek only |
| Skip Judge for clear pass/fail | $2/month | If consensus is unanimous (σ < 5), skip Judge |

### 4. Batch Optimisation (saves ~5%)

| Strategy | Est. Savings | Implementation |
|----------|-------------|---------------|
| Larger batches | $1/month | 1,000 leads/batch instead of 500 |
| Off-peak processing | $1/month | Schedule batches during off-peak OpenRouter hours |

## Cost Monitoring

All costs are tracked per lead, per layer, and per model in the cost-tracking data store. Weekly reports show:

- **Cost per lead** — Average and P95
- **Cost per layer** — Identify expensive layers
- **Cost per model** — Track each model's contribution
- **Cost trend** — Week-over-week change

Alerts fire when:

- Cost per lead exceeds $0.50 (5× the target)
- Monthly spend exceeds 120% of budget
- A single model accounts for > 50% of total spend
- Cache hit rate drops below 20%

## Budget Allocation

| Category | Monthly Budget | % of Total |
|----------|---------------|------------|
| DeepSeek V4 Flash | $30 | 50% |
| MiMo V2.5 | $20 | 33% |
| Claude Sonnet 4 | $10 | 17% |
| **Total** | **$60** | **100%** |

The budget is reviewed monthly. If actual spend consistently falls below budget, the surplus is allocated to processing more leads. If spend exceeds budget, optimisation strategies are applied before reducing volume.
