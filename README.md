# 🏢 Jasfo Lead Intelligence Platform

> **AI-Powered Commercial Real Estate Intelligence Platform**
>
> Transform 10,000 companies into **20–30 evidence-backed, high-confidence commercial real estate opportunities every week.**

---

# Vision

Jasfo is an AI-native Commercial Real Estate Intelligence Platform designed to help brokers discover companies that are most likely to relocate, expand, consolidate, or lease new office space.

Instead of relying on static lead databases, Jasfo continuously analyzes public signals, verifies evidence, applies multi-agent reasoning, and delivers only the highest-confidence opportunities.

The platform is designed around three principles:

- **Evidence over assumptions**
- **Automation over manual research**
- **Quality over quantity**

---

# Core Objectives

- Scan approximately **10,000 companies weekly**
- Deliver only **20–30 highly qualified opportunities**
- Never recommend the same company twice unless meaningful changes occur
- Keep recurring operational costs low
- Produce explainable, evidence-backed recommendations
- Minimize hallucinations through verification and consensus

---

# High-Level Architecture

```
                    10,000 Companies
                           │
                           ▼
               Free Data Collection Layer
                           │
                           ▼
                  Data Verification Layer
                           │
                           ▼
                  Business Signal Engine
                           │
                           ▼
                Multi-Agent Reasoning Engine
                           │
                           ▼
                Consensus & Judge System
                           │
                           ▼
                 Cost Optimization Gate
                           │
                           ▼
                  Contact Enrichment Layer
                           │
                           ▼
                 Commercial Strategy Engine
                           │
                           ▼
                 Claude Sonnet 4 Judge
                           │
                           ▼
              Evidence Package & Lead Report
```

---

# Technology Stack

## AI

- OpenCode GO
- DeepSeek V4 Flash
- MiMo V2.5
- Claude Sonnet 4 (OpenRouter)

## Automation

- Make.com

## Database

- Supabase

## Scraping

Primary

- Firecrawl

Fallback

- Apify (Only if required)

## Enrichment

- Apollo Free
- Hunter Free
- Snov Free
- SMTP Verification

---

# Repository Structure

```
jasfo-docs/

README.md

mkdocs.yml

docs/

assets/

diagrams/

sql/

schemas/

prompts/

examples/

make/

scripts/

.github/
```

---

# Documentation Structure

```
docs/

Vision

Architecture

AI

Models

Agents

Database

Lead Engine

Memory

Evidence

Firecrawl

Make

Exports

API

Security

Testing

Deployment

Roadmap
```

---

# Design Principles

## Firecrawl First

Firecrawl is the primary data collection engine.

Paid scraping services are used only when Firecrawl cannot retrieve the required information.

---

## Free APIs First

Always consume free tiers before paid APIs.

Priority:

1. Company Website
2. Firecrawl
3. Google
4. LinkedIn Company
5. Hunter Free
6. Apollo Free
7. Snov Free
8. Apify (Fallback)

---

## AI First

Every important decision is made by AI.

Human intervention occurs only after the Final Judge approves the lead.

---

## Evidence Driven

Every important field must contain:

- Confidence Score
- Primary Source
- Secondary Source
- Verification URL
- Collection Timestamp

No unsupported claims are allowed.

---

## Cost Optimization

Premium models are reserved for the final stage.

Approximately:

- 95% of AI work is performed by OpenCode GO models.
- Claude Sonnet 4 reviews only the final 20–30 companies.

---

# Documentation Standards

Every page follows the same structure.

- Overview
- Purpose
- Business Problem
- Architecture
- Workflow
- Inputs
- Outputs
- AI Model
- Prompt
- JSON Schema
- Database
- API
- Caching
- Retry Logic
- Cost
- Testing
- Future Improvements
- Architecture Decision Record (ADR)

---

# AI Coding Agent Support

This repository is designed for:

- Claude Code
- OpenAI Codex
- Cursor
- OpenCode GO
- GitHub Copilot

Every document is written to be machine-readable and implementation-focused.

---

# Status

Current Version

```
Master PRD v4.0
```

Status

```
In Development
```

---

# License

Private Internal Documentation

© Jasfo
