# Agent Summary

> 21 AI agents organized across 5 layers. All communicate through Supabase (no direct agent-to-agent calls).

## Layer 1: Data Pipeline (4 agents)

| # | Agent | Model | Input | Output | Cost/Lead |
|---|-------|-------|-------|--------|-----------|
| 1 | Discovery Agent | Firecrawl | URLs, keywords | Raw company JSON | ~$0.0001 |
| 2 | Normalization Agent | DeepSeek V4 Flash | Raw scraped text | Structured records | ~$0.0003 |
| 3 | Verification Agent | MiMo V2.5 | Normalized records | Cross-verified claims | ~$0.0056 |
| 4 | Feature Agent | DeepSeek V4 Flash | Verified records | 40+ numeric features | ~$0.0005 |

## Layer 2: Pillar Scoring (8 agents, parallel)

| # | Agent | Model | Weight | Output |
|---|-------|-------|--------|--------|
| 5 | Company Fit Agent | DeepSeek V4 Flash | 10% | Score 0-100 |
| 6 | Move Intent Agent | DeepSeek V4 Flash | 35% | Score 0-100 |
| 7 | Growth Agent | DeepSeek V4 Flash | 15% | Score 0-100 |
| 8 | Financial Agent | DeepSeek V4 Flash | 12% | Score 0-100 |
| 9 | Decision Maker Agent | DeepSeek V4 Flash | 10% | Score 0-100 |
| 10 | Network Agent | DeepSeek V4 Flash | 8% | Score 0-100 |
| 11 | Opportunity Agent | DeepSeek V4 Flash | 5% | Score 0-100 |
| 12 | Evidence Agent | DeepSeek V4 Flash | 5% | Score 0-100 |

## Layer 3: Consensus & Review (3 agents)

| # | Agent | Model | Input | Output | Cost/Lead |
|---|-------|-------|-------|--------|-----------|
| 13 | Consensus Agent | MiMo V2.5 | 8 pillar scores | Weighted total 0-100 | ~$0.0108 |
| 14 | Reflection Agent | MiMo V2.5 | Consensus output | Adjusted scores + critique | ~$0.0076 |
| 15 | Judge Agent | Claude Sonnet 4 | Top 20-30 leads | Approve/reject + ranking | ~$0.0520 |

## Layer 4: Memory & Change (2 agents)

| # | Agent | Model | Input | Output | Cost/Lead |
|---|-------|-------|-------|--------|-----------|
| 16 | Memory Agent | Hash (no LLM) | Company records | Cooldown-filtered list | ~$0.00001 |
| 17 | Change Agent | DeepSeek V4 Flash | Old + new hashes | Change classification delta | ~$0.0003 |

## Layer 5: Delivery & Learning (4 agents)

| # | Agent | Model | Input | Output | Cost/Lead |
|---|-------|-------|-------|--------|-----------|
| 18 | Strategy Agent | MiMo V2.5 | Profile + property inventory | Commercial strategy brief | ~$0.0048 |
| 19 | Outreach Agent | DeepSeek V4 Flash | Strategy + contact | Email draft <=120 words | ~$0.0001 |
| 20 | QA Agent | DeepSeek V4 Flash | Full lead packet | Validation report + anomaly flags | ~$0.0005 |
| 21 | Learning Agent | DeepSeek V4 Flash | Broker feedback | Prompt update recommendations | ~$0.0005 |

## Communication Patterns

1. **Sequential Pipeline (Layer 1):** Discovery -> Normalization -> Verification -> Feature Engineering
2. **Parallel Fan-Out (Layer 2):** All 8 pillar agents run simultaneously against same feature vector
3. **Weighted Voting (Layer 3):** Consensus -> Reflection -> Judge (catches individual agent biases)

## Key Design Decisions

- Cheap models first, premium last (95% DeepSeek, 5% Claude)
- No direct agent-to-agent communication (all through Supabase)
- Evidence quality is a continuous score (1-5), not a boolean
- Change detection overrides cooldown when meaningful delta found
