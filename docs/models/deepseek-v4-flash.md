# DeepSeek V4 Flash

DeepSeek V4 Flash is the **primary worker model** in the Jasfo Lead Intelligence Platform. It handles approximately **70% of all AI tasks** — all high-volume, cost-sensitive operations that do not require deep reasoning.

## Role in the Pipeline

| Layer | Task | Why DeepSeek |
|-------|------|-------------|
| 1 — Discovery | Extract company data from URLs | High volume, simple extraction |
| 2 — Normalisation | Standardise formats | Deterministic, rule-based |
| 7 — Enrichment | Look up additional data | Independent API calls |
| 8 — Scoring | Apply rubric to scored dimensions | Numerical, well-defined rubric |
| 12 — Summary Generation | Generate human-readable summaries | Template-based, low complexity |
| 14 — Output Assembly | Final output formatting | Structured data assembly |

## Model Details

| Property | Value |
|----------|-------|
| **Model ID** | `deepseek/deepseek-v4-flash` |
| **Provider** | DeepSeek (via OpenRouter) |
| **Cost (input)** | $0.50 per 1M tokens |
| **Cost (output)** | $2.00 per 1M tokens |
| **Context window** | 128K tokens |
| **Avg latency** | 2–4 seconds |
| **Max output tokens** | 8,192 |
| **Task suitability** | Extraction, classification, transformation |

## Strengths

- **Speed**: Consistently returns in under 4 seconds, enabling high-throughput batch processing
- **Cost**: At $0.50/M input tokens, it is the most cost-effective model in the stack — a typical discovery task costs ~$0.00015
- **Reliability**: High uptime and low error rate on OpenRouter (typically < 1% error rate)
- **Deterministic output**: Strong at following structured output schemas with low variance

## Limitations

| Limitation | Impact | Mitigation |
|-----------|--------|-----------|
| Weak multi-step reasoning | Can skip steps in complex chains | Delegate to MiMo V2.5 |
| Moderate instruction following | May deviate from strict format on complex prompts | Use shorter, more explicit prompts |
| Lower nuance | May miss subtle signals in text | Upgrade to MiMo for nuanced tasks |
| No native JSON guarantee | May occasionally produce invalid JSON | Retry with stricter schema enforcement |

## Prompt Patterns

### Pattern 1: Extraction

```
Extract the following fields from the text below. Return ONLY valid JSON.

Text: [source_text]

Fields to extract:
- company_name
- headquarters_city
- headquarters_country
- employee_count
- revenue_range

JSON output:
```

### Pattern 2: Classification

```
Classify the company described below into exactly one category.
Return: { "category": "..." }

Categories: [list]
Confidence (0-100): int

Company: [description]
```

### Pattern 3: Normalisation

```
Normalise the following values to standard formats:

Input revenue: "5M"
Output: 5000000

Input revenue: "$2.5 billion"
Output: 2500000000

Input employees: "50-100"
Output: { "min": 50, "max": 100 }
```

## Performance Metrics

| Metric | Value | Target |
|--------|-------|--------|
| Avg task latency | 2.8s | < 4s |
| P95 latency | 5.1s | < 8s |
| Error rate | 0.8% | < 2% |
| Output validity | 95.2% | > 93% |
| Cache hit rate | 35% | > 30% |

## When NOT to Use

Do not route to DeepSeek V4 Flash for:

- **Multi-step reasoning tasks** — use MiMo V2.5
- **Final judgment calls** — use Claude Sonnet 4
- **Tasks requiring nuanced domain expertise** — use MiMo or Claude
- **Contradiction resolution** — use MiMo
