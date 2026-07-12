# Repository Structure

The Jasfo repository (`jasfo-docs/`) contains all platform documentation, configurations, schemas, and workflow definitions. This document maps the directory structure and describes the purpose of each directory and key file.

## Root Directory

```
jasfo-docs/
  .github/            GitHub Actions workflows and CI/CD configurations
  ai-context/         AI agent context files for document indexing
  assets/             Static assets: images, logos, diagrams
  diagrams/           Source diagram files (Draw.io, Excalidraw)
  docs/               All MkDocs documentation source files
  examples/           Example outputs: sample evidence packages, exports
  make/               Make.com scenario JSON exports
  schemas/            JSON Schema definitions for data validation
  scripts/            Utility scripts: data loaders, validation, DB management
  sql/                SQL migrations, RLS policies, and database functions
  mkdocs.yml          MkDocs configuration file (navigation, theme, plugins)
  README.md           Repository overview and quick-start instructions
  CHANGELOG.md        Versioned changelog of platform changes
  CONTRIBUTING.md     Guidelines for contributing (AI agents and humans)
  LICENSE             Open-source license (if applicable)
  requirements.txt    Python dependencies for MkDocs and utility scripts
```

## docs/ Directory Structure

```
docs/
  index.md                    Documentation home page with mission, principles, and architecture overview
  
  /vision/                    Business context and strategic goals
    overview.md               Vision overview — platform purpose and market context
    problem-statement.md      Problem being solved — the intelligence gap in CRE
    business-model.md         Business model and unit economics
    mission.md                Core mission statement and what it means
    goals.md                  Quantified weekly, monthly, and annual targets
    non-goals.md              Explicit exclusions and architectural guardrails
    success-metrics.md        Metrics for evaluating platform performance
    personas.md               Primary and secondary user personas
    competitive-advantage.md  Structural competitive advantages
    future.md                 Near-term, medium-term, and long-term vision
  
  /architecture/              System architecture documentation
    overview.md               14-layer pipeline architecture overview
    system-overview.md        End-to-end system description and subsystems
    technology-stack.md       Technology choices with costs and rationale
    repository-structure.md   This file — repository directory map
    design-principles.md      Core design principles guiding all decisions
    architecture-summary.md   One-page reference summary of the full system
    architecture-decision-records.md  Index of all ADRs with summaries
    high-level-diagrams.md    Mermaid flowcharts for pipeline, routing, costs, data
    sequence-diagrams.md      Mermaid sequence diagrams for key workflows
    deployment-diagrams.md    Mermaid deployment architecture diagram
    adr/                      Individual ADR files (ADR-001.md, ADR-002.md, etc.)
  
  /ai/                        AI model configuration and prompts
    model-routing.md          Model assignment per layer and routing logic
    prompt-library/           Full prompt definitions for each layer
    specialist-agents.md      Five specialist agent specifications
    consensus-engine.md       Consensus algorithm and disagreement resolution
    reflection.md             Reflection process for model improvement
    cost-optimization.md      Prompt caching, batching, and cost strategies
  
  /database/                  Database schema and configuration
    schema.md                 Full table definitions with columns and types
    tables/                   Individual table specifications
    policies.md               Row-Level Security policies
    functions.md              Database functions and triggers
    migrations.md             Migration process and version history
  
  /make/                      Make.com workflow documentation
    scenarios/                Individual scenario specifications
    error-handling.md         Error handling, retry logic, notifications
    scheduling.md             Pipeline scheduling and triggering
  
  /scraping/                  Scraping strategy and configuration
    firecrawl-strategy.md     Firecrawl configuration, rate limiting, crawl rules
    apify-strategy.md         Apify Actors, proxy rotation, fallback rules
    source-priority.md        Source hierarchy and fallback chain
  
  /lead-engine/               Lead scoring and intelligence
    scoring-model.md          Move Probability Score algorithm and weights
    lead-memory.md            Memory store design and lifecycle
    cooldown.md               Cooldown states and refresh cycles
    change-detection.md       Change detection algorithm and thresholds
  
  /evidence/                  Evidence engine documentation
    engine.md                 Evidence Engine architecture and rules
    verification.md           Verification process and source requirements
    explainability.md         Evidence traceability and audit
  
  /exports/                   Export specifications
    csv.md                    CSV export format and fields
    excel.md                  Excel export format and formatting
    pdf.md                    PDF report generation specification
    json.md                   JSON export schema
  
  /apis/                      External API integration documentation
    firecrawl-api.md          Firecrawl API usage policies and limits
    apify-api.md              Apify API usage and Actor configurations
    ai-models-api.md          AI model API rate limits, retries, error handling
  
  /deployment/                Deployment and operations
    railway.md                Railway hosting configuration
    supabase-setup.md         Supabase project setup and configuration
    cloudflare.md             Cloudflare DNS and CDN configuration
    monitoring.md             Pipeline monitoring and alerting
  
  /testing/                   Testing strategy and test definitions
    prompt-eval.md            Prompt evaluation methodology
    regression.md             Regression testing approach
    golden-datasets.md        Golden datasets for scoring validation
  
  /security/                  Security documentation
    authentication.md         API key management and access control
    data-handling.md          Data privacy and handling policies
  
  /appendix/                  Supplementary material
    benchmarks.md             Model cost and performance benchmarks
    references.md             External references and research sources
  
  faq.md                      Frequently asked questions
  glossary.md                 Key terms defined
  getting-started.md          Setup guide and quick-start instructions
```

## Key Configuration Files

**`mkdocs.yml`** specifies the documentation site configuration: theme settings, navigation structure, plugin configuration, site metadata, and Markdown extensions. Changes to this file affect the entire documentation site.

**`make/scenarios/`** contains Make.com scenario JSON exports. Each file follows the naming convention `[layer-number]-[layer-name].json`. These files can be imported directly into a Make.com account.

**`sql/migrations/`** contains versioned SQL migration files following the naming convention `YYYYMMDD_description.sql`. These are applied sequentially to set up and update the Supabase database schema.

**`schemas/`** contains JSON Schema files for validating data structures at each pipeline layer. These schemas ensure AI model outputs conform to expected formats and catch schema drift early.
