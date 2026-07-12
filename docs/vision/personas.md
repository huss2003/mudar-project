# Personas

The Jasfo platform is designed with specific users in mind. Understanding these personas clarifies design decisions, prioritization, and the platform's interaction model.

## Primary Persona: Jasfo (The Broker)

**Role.** Solo commercial real estate broker operating in Pune. Ten-plus years of experience in the market. Deep relationships with landlords, property managers, and corporate tenants. Currently capturing leads through network referrals, repeat business, and manual market monitoring.

**Pain Points.** Jasfo knows the Pune market intimately but cannot scale personal coverage beyond approximately 200 key relationships. Institutional competitors with dedicated research teams identify opportunities faster and pitch more credibly. The broker's time is split between client-facing work and manual research — and the research always loses.

**Needs.** A systematic intelligence feed that identifies companies likely to need space before they publicly enter the market. Quality over quantity — Jasfo would rather have 20 verified leads per week than 10,000 unqualified company names. Evidence-backed insights that enable informed, credible outreach. Low cost — the platform must be self-funding from brokerage commissions.

**Working Style.** Jasfo works from leads, not lists. Each Monday, the platform delivers the evidence package. Jasfo reviews the top leads, makes calls, books meetings, and closes deals. The platform disappears into the background between Monday morning and the next pipeline run. Jasfo is not a power user of software tools and has no interest in dashboards, configuration, or system administration.

**Success Looks Like.** A Monday morning inbox with 20–30 leads, each containing specific, verified reasons the company might need space and who to contact. Jasfo makes 10–15 calls, books 3–4 meetings, and closes 1 deal per quarter. The platform's operating cost is invisible next to commission income.

## Secondary Persona: AI Coding Agents

**Role.** Autonomous AI agents tasked with implementing, modifying, or debugging the Jasfo platform. These agents read the documentation as their source of truth before making any code changes.

**Needs.** Precise, unambiguous specifications. Complete schema definitions. Clear architectural boundaries — what each layer does and what it does not do. ADRs for understanding why decisions were made. The documentation must be complete enough that an agent can implement a feature without asking clarifying questions.

**Working Style.** Agents read documentation file-by-file, verify understanding against related files, and follow the exact specifications. They do not infer, assume, or invent. If the documentation is ambiguous, the agent either asks for clarification or follows the most conservative interpretation.

**Success Looks Like.** An agent reads the Architecture Overview, the relevant ADR, the database schema definition, and the Make.com scenario spec, then implements the feature correctly on the first attempt without human intervention.

## Tertiary Persona: Future Hires

**Role.** Engineers, AI specialists, or operations staff who join the project in the future. These individuals need to understand the system design, architectural decisions, and operational procedures without requiring extensive handover from the original builder.

**Needs.** Comprehensive onboarding documentation. Clear rationale for architectural decisions. Operational runbooks for pipeline management. Understanding of why specific technologies were chosen and what the failure modes are.

**Working Style.** Future hires will read the documentation sequentially — starting with Vision and Architecture, then diving into specific subsystems. They will rely on the ADRs to understand decisions and the operational documentation to manage the system.

**Success Looks Like.** A new engineer can read the documentation and understand the full system within one day. They can identify where to make changes, understand the impact of those changes, and know which ADRs constrain their options.
