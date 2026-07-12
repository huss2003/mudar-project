# Layer 5: Specialist Agents

> **Purpose**: 8 parallel specialist agents each score a single dimension of company quality. Each agent = 1 pillar.
>
> **Model**: DeepSeek V4 Flash (majority) + MiMo V2.5 (2 agents requiring multimodal analysis)
>
> **Input**: Feature vectors from Layer 4
>
> **Output**: 8 pillar scores per company (0–100 each)

## Overview

Layer 5 deploys 8 independent specialist agents, each responsible for scoring exactly one pillar. Agents operate in parallel — one company is scored by all 8 agents simultaneously. Each agent receives the full feature vector but is prompted to attend only to features relevant to its pillar. This architecture prevents cross-pillar contamination and allows each agent to develop expertise in its dimension without distraction.

Seven agents use DeepSeek V4 Flash (cheap, fast, effective for text-only scoring). One agent — Digital Presence — uses MiMo V2.5 because it may need to evaluate visual elements (screenshot of the company website for design quality, social media post engagement screenshots). Each agent returns a score (0–100), a confidence level (0.0–1.0), and a free-text rationale (max 200 characters) explaining the score.

```mermaid
flowchart LR
    A[Feature Vector] --> B[Agent 1<br/>Financial Health<br/>DeepSeek]
    A --> C[Agent 2<br/>Digital Presence<br/>MiMo V2.5]
    A --> D[Agent 3<br/>Growth Trajectory<br/>DeepSeek]
    A --> E[Agent 4<br/>Team Strength<br/>DeepSeek]
    A --> F[Agent 5<br/>Market Fit<br/>DeepSeek]
    A --> G[Agent 6<br/>Tech Stack<br/>DeepSeek]
    A --> H[Agent 7<br/>Regulatory Exposure<br/>DeepSeek]
    A --> I[Agent 8<br/>Commercial Readiness<br/>DeepSeek]
    B --> J[Score Set<br/>8 × {score, conf, reason}]
    C --> J
    D --> J
    E --> J
    F --> J
    G --> J
    H --> J
    I --> J
    J --> K{Confidence<br/>Thresholds Met?}
    K -->|Yes| L[Pass to Layer 6]
    K -->|No| M[Re-score<br/>max 2 retries]
    M --> B
```

## Agent Specifications

| # | Agent | Model | Key Input Features | Output Range | Weight |
|---|-------|-------|-------------------|-------------|--------|
| 1 | Financial Health | DeepSeek V4 Flash | revenue_per_employee, rent_to_revenue, funding_count, growth_stage | 0–100 | 0.20 |
| 2 | Digital Presence | MiMo V2.5 | digital_presence_score, social_media_quality, website_screenshot | 0–100 | 0.15 |
| 3 | Growth Trajectory | DeepSeek V4 Flash | employee_growth_rate, revenue_trend, founded_year, industry_growth | 0–100 | 0.15 |
| 4 | Team Strength | DeepSeek V4 Flash | management_completeness, team_size, avg_tenure, linkedin_staff_quality | 0–100 | 0.10 |
| 5 | Market Fit | DeepSeek V4 Flash | micromarket_alignment, competitor_density, market_size | 0–100 | 0.15 |
| 6 | Tech Stack | DeepSeek V4 Flash | tech_stack_maturity, cloud_adoption, security_tools | 0–100 | 0.05 |
| 7 | Regulatory Exposure | DeepSeek V4 Flash | regulatory_exposure_score, compliance_signals, industry_risk_index | 0–100 | 0.10 |
| 8 | Commercial Readiness | DeepSeek V4 Flash | commercial_readiness, funding_recency, sales_team_presence | 0–100 | 0.10 |

Weights sum to 1.0. The consensus engine (Layer 6) uses these as initial weights but may adjust them based on per-agent confidence.

## Agent Prompt Structure

Each agent receives the same base prompt with a pillar-specific section:

```
You are the {Pillar Name} specialist agent. Score this company on a scale of 0-100.

Relevant features: {list of features}
Feature values: {feature values}

Scoring rubric:
- 0-20: Critical deficiency
- 21-40: Below average
- 41-60: Average
- 61-80: Above average
- 81-100: Excellent

Return: {"score": int, "confidence": float, "rationale": "string (max 200 chars)"}
```

The prompt includes concrete anchor examples for each score range to calibrate scores across agents. For example, Financial Health's rubric for 81–100 includes "Revenue-per-employee > $150K, 3+ funding rounds, rent-to-revenue < 5%." This cross-calibration ensures that a score of 75 from Financial Health means roughly the same level of quality as a score of 75 from Team Strength.

## Performance & Cost

Scoring 5,000 companies through all 8 agents costs approximately 7.5M input tokens (1,500 companies × 8 agents × ~625 tokens per prompt) and produces ~600K output tokens. DeepSeek V4 Flash handles this at approximately $0.60 total. The Digital Presence agent (MiMo V2.5) adds approximately $2.00 for visual analysis. Total Layer 5 cost per full run: ~$3.00. Runtime: approximately 45 minutes with full parallelism.
