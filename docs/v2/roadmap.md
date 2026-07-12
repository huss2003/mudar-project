# Jasfo v2.0 — Implementation Roadmap

## Current State Assessment

### Existing n8n Workflows (5 active)
| # | Name | Purpose | Active |
|---|------|---------|--------|
| 1 | Jasfo Weekly Master | Enqueue companies from company_queue | ✅ |
| 2 | Jasfo Discovery Processor | Firecrawl scrape → ai_ready | ✅ |
| 3 | JASFO AI Processor | DeepSeek extraction → scoring_ready | ✅ |
| 4 | JASFO Scoring Processor | 8-pillar scoring → export_ready | ✅ |
| 5 | JASFO Export Processor | Telegram delivery | ✅ |

### Existing Tables (current schema.sql)
18 tables: companies, profiles, lead_scores, cost_log, audit_log, evidence_*, etc.

### v2 Work Already Completed
- Architecture design doc (`docs/v2/architecture.md`)
- Enrichment module (`docs/v2/enrichment-module.md`)
- Rule engine (`docs/v2/rule-engine.md`)
- 10 prompt files in `docs/prompts/`
- v2 SQL schema (`sql/v2/001-schema.sql` — 11 tables for evidence system)

### Missing for v2 Complete
- Layer 0 Autonomous Lead Acquisition Engine
- Explainable Multi-Signal Scoring Engine design
- Learning system for scoring weights
- All v2 n8n workflows (rebuild from scratch)
- Integration tests
- MCP deployment

---

## Implementation Phases

### Phase 0: Architecture & Design
- [x] v2 architecture document
- [x] Evidence extraction system design
- [x] Rule engine design
- [x] Enrichment module design  
- [ ] Layer 0 acquisition engine design
- [ ] Explainable scoring engine design
- [ ] Learning system design
- [ ] Workflow architecture design

### Phase 1: Schema & Database
- [ ] Layer 0 schema (icp_profiles, discovery tables)
- [ ] Scoring schema (signal_groups, weights, learning)
- [ ] Combined migration script
- [ ] Safe migration validation

### Phase 2: Prompts & Logic
- [ ] Layer 0 planner prompt
- [ ] Search query generator prompt
- [ ] Domain validation logic
- [ ] Duplicate detection algorithm
- [ ] Initial qualification algorithm
- [ ] Confidence scoring formula
- [ ] Evidence extraction prompts (done)
- [ ] Scoring engine prompts

### Phase 3: Build n8n Workflows (v2)
- [ ] WF-01: Layer 0 ICP Manager
- [ ] WF-02: Layer 0 Discovery Planner
- [ ] WF-03: Layer 0 Source Executor
- [ ] WF-04: Layer 0 Normalizer + Qualifier
- [ ] WF-05: v2 Evidence Extractor
- [ ] WF-06: v2 AI Planner (autonomous search)
- [ ] WF-07: v2 Explainable Scorer
- [ ] WF-08: v2 Export + Delivery
- [ ] WF-09: Learning System
- [ ] WF-10: Cost Monitor

### Phase 4: Testing
- [ ] Unit tests for each module
- [ ] Integration tests for workflow chains
- [ ] End-to-end test: ICP → discovered → scored → exported
- [ ] Performance benchmark vs v1

### Phase 5: MCP Deployment
- [ ] Read existing workflows
- [ ] Archive old v1 workflows
- [ ] Upload v2 workflows
- [ ] Validate all nodes/connections
- [ ] Test execution
- [ ] Activate
- [ ] Final validation

---

## Total Work Items
- ~8 new prompts
- ~10 new n8n workflows  
- ~15 new SQL tables
- ~5 algorithmic modules
- ~1000+ lines of generated workflow JSON
