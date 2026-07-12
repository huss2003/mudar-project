# Appendix: AI Context Pack Reference

> How AI coding agents should use the `ai-context/` directory. This pack is the single source of truth for agent context — it contains distilled, cross-referenced summaries of every subsystem in the Jasfo platform.

---

## Directory Structure

The `ai-context/` directory at the project root contains 11 markdown files:

```
ai-context/
├── README.md                     # Entry point and loading instructions
├── project-summary.md            # One-paragraph overview, tech stack, core philosophy
├── architecture-summary.md       # 14-layer pipeline, data flow, critical numbers
├── database-summary.md           # Table groups, schemas, relationships, indexes
├── api-summary.md                # All external API configurations with costs
├── prompt-summary.md             # System prompt patterns for all AI agents
├── implementation-guide.md       # Step-by-step build order and status
├── coding-checklist.md           # Pre-commit verification checklist
├── coding-rules.md               # Mandatory coding rules (never invent APIs, etc.)
├── agent-summary.md              # All specialist agent definitions and responsibilities
└── folder-structure.md           # Complete project directory tree
```

Each file is optimized for AI consumption: concise, structured, and cross-referenced. They are not human-friendly documentation — they are context-injection payloads designed to rapidly bring an AI agent up to speed on a specific subsystem.

---

## Loading Order

When beginning work on the Jasfo codebase, AI agents should load the context pack in the following order:

1. **project-summary.md** — Start here. This file establishes the project's identity, constraints (budget <$50/month, single-user, weekly batch), and core philosophy (evidence-first, AI-first, lazy-first). Every subsequent file assumes this context.

2. **architecture-summary.md** — Load second. This file describes the 14-layer pipeline, data flow with company counts per layer, model assignments, and critical numbers (10K companies/week, 20-30 leads delivered, 6-hour runtime). Most engineering decisions reference this architecture.

3. **database-summary.md** — Load third. This file lists all 18 tables, their relationships, naming conventions, the 8-pillar scoring model, lead states, and index strategy. Any database work requires this file. The schema is the source of truth — never invent columns.

4. **api-summary.md** — Load fourth when doing API integration work. This file documents every external API: Firecrawl, Apollo, Hunter, Snov, SMTP verification, Telegram, Supabase, OpenRouter, and OpenCode GO. Each entry includes base URL, auth method, cost, rate limits, and caching strategy.

5. **coding-rules.md** — Load fifth before writing any code. The 10 mandatory rules (never invent APIs, never invent DB fields, evidence-first output, cost awareness, test-first, idempotent SQL, lazy-first, no hallucinated data, follow naming conventions, commit checklist) prevent the most common AI coding errors.

6. **prompt-summary.md** — Load when working on or debugging AI agent prompts. This file documents the system prompt structure, output schema patterns, evidence chain format, and each agent's scoring rubric.

7. **agent-summary.md** — Load when implementing or modifying specialist agents. This file defines each of the eight pillar agents, their inputs, evaluation criteria, and output format.

8. **coding-checklist.md** — Load before committing changes. This file is the pre-commit verification checklist — run through each item before creating a pull request.

9. **implementation-guide.md** — Load when determining what to work on next. This file tracks build order and completion status.

10. **folder-structure.md** — Load when navigating the codebase for the first time. This file maps the entire directory tree.

---

## Per-Task Context Selection

Not every task requires loading the entire context pack. Select files based on task type:

| Task Type | Files to Load |
|-----------|---------------|
| Database schema changes (new table, column, index) | `database-summary.md`, `coding-rules.md`, `folder-structure.md` |
| API integration (new scraper, email source) | `api-summary.md`, `architecture-summary.md`, `coding-rules.md` |
| AI agent prompt work (new agent, prompt fix) | `prompt-summary.md`, `agent-summary.md`, `architecture-summary.md`, `coding-rules.md` |
| Pipeline debugging (why did a lead fail?) | `architecture-summary.md`, `database-summary.md`, `prompt-summary.md` |
| Export format (new CSV column, Excel sheet) | `database-summary.md`, `api-summary.md`, `coding-rules.md` |
| Cost investigation (budget spike) | `architecture-summary.md`, `api-summary.md`, `database-summary.md` |
| Adding a new feature | `project-summary.md`, `architecture-summary.md`, `database-summary.md`, `coding-rules.md`, `implementation-guide.md` |
| Pre-commit review | `coding-checklist.md`, `coding-rules.md` |
| Full codebase onboarding | All 11 files in the loading order above |

When in doubt, load `project-summary.md` + `coding-rules.md` as the minimum viable context — these establish project identity and guardrails. If a task involves any of the specific categories above, load the corresponding files from the table.

---

## How AI Agents Should Use the Pack

1. **Read, do not skim.** Each file is designed to be compact enough to read in full. Skimming misses the cross-references between files.

2. **Verify before trusting.** After reading a context file, verify key facts against the actual source files (`sql/schema.sql`, `docs/api/`, `prompts/`). Context files are summaries and may be slightly out of date if a change was not propagated.

3. **Cross-reference.** The context pack is designed with explicit cross-references. When `database-summary.md` mentions a table, check `architecture-summary.md` for how that table is populated. When `api-summary.md` mentions a cost, check `project-summary.md` for budget constraints.

4. **Update context when making changes.** After adding a database field, update `database-summary.md`. After adding a new API, update `api-summary.md`. The context pack must remain the source of truth — if it becomes stale, AI agents will produce incorrect code.

5. **Cite context files in responses.** When making a recommendation based on the context pack, reference the specific file: "Per `architecture-summary.md`, the pipeline processes 10,000 companies per week, so this index will handle the expected volume."

---

## Relationship to Other Documentation

The `ai-context/` directory is one of three documentation layers in the Jasfo platform:

| Layer | Directory | Purpose | Audience |
|-------|-----------|---------|----------|
| AI Context | `ai-context/` | Distilled summaries for rapid AI agent onboarding | AI coding agents |
| Human Docs | `docs/` | Full documentation with explanations and rationale | Human developers and the broker |
| Source of Truth | `sql/`, `schemas/`, `prompts/` | Canonical definitions that all docs derive from | CI/CD pipelines and validation |

Changes flow from source of truth → human docs → AI context. When updating the platform, always update the source of truth first, then propagate to `docs/`, then to `ai-context/`. The context pack is automatically regeneratable from the source files — if you are unsure whether a summary is current, regenerate it rather than trusting a stale file.

---

## Maintenance

The context pack must be updated whenever the relevant subsystem changes. Specifically:

- **New database table or column:** Update `database-summary.md`
- **New API integration:** Update `api-summary.md`
- **New pipeline layer or model reassignment:** Update `architecture-summary.md`
- **New AI agent or prompt change:** Update `agent-summary.md` and `prompt-summary.md`
- **New folder or file convention change:** Update `folder-structure.md`
- **New architecture decision:** Update `coding-rules.md` and add ADR
- **Any change:** Verify `coding-checklist.md` and `coding-rules.md` still reflect current practices

AI agents should flag inconsistencies between the context pack and the source files as part of every task. If a discrepancy is found, the agent should note it and suggest a context pack update.
