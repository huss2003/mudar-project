# Getting Started

## Prerequisites

Before setting up the Jasfo platform, ensure you have the following:

- **Python 3.10+.** The documentation toolchain and utility scripts require Python 3.10 or higher. Verify with `python --version`.
- **MkDocs Material.** The documentation site is built using MkDocs with the Material theme. Install it as part of the dependency step below.
- **Git.** Required for cloning the repository and managing version-controlled documentation and configurations.
- **Repository Access.** You need read access to the Jasfo repository. Clone it with `git clone <repo-url>`.
- **API Keys.** Supabase URL and service key, Firecrawl API key, Apify API token, OpenCode GO endpoint, and Anthropic API key (for Claude Sonnet 4). These are configured in a `.env` file at the project root.
- **Make.com Account.** A free or Professional plan account for deploying automation scenarios.

## Setup

Clone the repository and navigate to the project root:

```bash
git clone <repo-url>
cd jasfo
```

Install Python dependencies for the documentation and utility toolchain:

```bash
pip install -r requirements.txt
```

This installs MkDocs, the Material theme, and supporting libraries. If you encounter permission issues, use `pip install --user` or create a virtual environment.

Configure environment variables by copying the template:

```bash
cp .env.example .env
```

Edit `.env` with your API keys and credentials. Refer to `docs/architecture/technology-stack.md` for which keys are required and how to obtain them.

Serve the documentation locally:

```bash
mkdocs serve
```

Open `http://127.0.0.1:8000` in your browser to view the full documentation site.

To deploy Make.com scenarios, navigate to the `/make` directory and import each scenario JSON file into your Make.com account. Each scenario file includes a header comment describing its purpose, trigger, and required webhook URLs.

## Documentation Structure

The documentation is organized into the following sections:

| Section | Path | Contents |
|---------|------|----------|
| Vision | `docs/vision/` | Business goals, problem statement, mission, success metrics, personas |
| Architecture | `docs/architecture/` | 14-layer pipeline, system design, technology stack, design principles |
| AI | `docs/ai/` | Model routing, prompt library, specialist agents, consensus, reflection |
| Firecrawl | `docs/scraping/` | Primary scraping strategy, optimization, fallback rules |
| Make.com | `docs/make/` | Automation scenarios, routers, filters, retry logic, scheduling |
| Database | `docs/database/` | Supabase schema, tables, RLS policies, SQL migrations |
| Lead Engine | `docs/lead-engine/` | Scoring algorithm, memory, cooldowns, change detection |
| Evidence | `docs/evidence/` | Evidence engine, verification rules, explainability |
| Exports | `docs/exports/` | CSV, Excel, JSON, and PDF specifications and formats |
| APIs | `docs/api/` | External integration specs and usage policies |
| Deployment | `docs/deployment/` | Railway hosting, Supabase setup, Cloudflare config |
| Testing | `docs/testing/` | Prompt evaluation, regression tests, golden datasets |
| Security | `docs/security/` | Authentication, RLS policies, data handling |
| Appendix | `docs/appendix/` | Additional references and supplementary material |

## Quick Links

- [Vision Overview](vision/overview.md) — business context and platform purpose
- [Architecture Overview](architecture/overview.md) — the 14-layer pipeline explained
- [Technology Stack](architecture/technology-stack.md) — every technology and why it was chosen
- [System Overview](architecture/system-overview.md) — end-to-end data flow
- [FAQ](faq.md) — common questions answered
- [Glossary](glossary.md) — key terms defined

## Next Steps

1. Read the [Vision Overview](vision/overview.md) to understand the business problem.
2. Review the [Architecture Overview](architecture/overview.md) for the system design.
3. Follow the [System Overview](architecture/system-overview.md) for data flow details.
4. Set up your Supabase instance using the schema in `docs/database/`.
5. Deploy Make.com scenarios from the `/make` directory.
6. Run your first weekly pipeline using the instructions in `docs/make/weekly-pipeline.md`.
