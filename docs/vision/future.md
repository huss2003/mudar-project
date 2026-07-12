# Future Vision

The Jasfo platform is built for the present but designed for the future. This document outlines the planned evolution beyond the initial Pune-focused, solo-broker implementation. These are directional — they define where the platform is heading, not commitments to specific timelines.

## Near-Term (6–12 Months)

**Custom dashboard for lead review.** The initial implementation delivers leads via Telegram and CSV/Excel export. The near-term vision includes a lightweight web dashboard where the broker can review leads, filter by score or signal type, view evidence packages in-browser, and mark leads as actioned, qualified, or discarded. This dashboard will be built as a simple static site backed by Supabase — no server-side framework needed.

**Refined scoring through reflection.** After 6 months of operation, the platform will have sufficient historical data to begin meaningful Reflection cycles. The system will compare its predicted move probabilities against actual outcomes: which companies leased space, which renewed, which never acted. These insights will recalibrate scoring weights and improve prediction accuracy over time. Early reflection cycles may identify that certain signals (e.g., job postings for specific roles) are stronger predictors than initially assumed.

**Automated broker feedback loop.** A lightweight mechanism for the broker to provide feedback on delivered leads: "this lead was accurate — they ARE looking for space" or "this lead was wrong — they just renewed their lease." This feedback will feed into the Reflection process and improve the scoring model without requiring the broker to spend significant time on data entry.

## Medium-Term (12–24 Months)

**AI chat interface for natural language queries.** Rather than waiting for the weekly pipeline run, the broker will be able to ask questions in natural language: "Which companies in Hinjewadi hired more than 50 people last quarter?" or "Show me all leads with lease expirations in the next 3 months." The chat interface will query the Lead Memory and evidence databases directly, providing instant answers. This transforms the platform from a batch reporting system into an always-available intelligence partner.

**Custom dashboard suite.** Beyond the basic review dashboard, a full analytics suite will provide pipeline visualizations, conversion funnel metrics, lead quality trends, and cost tracking. The broker will see at a glance how the platform is performing and where to focus attention. This dashboard will be mobile-responsive for on-the-go review between client meetings.

**Multi-broker support (limited).** Controlled expansion to 2–3 additional brokers in Pune, each with their own pipeline, lead assignments, and evidence packages. This is not a full multi-tenant SaaS — it is a limited expansion to test whether the platform's intelligence generalizes across different brokers' working styles and client relationships. Multi-broker support requires adding user context to the database schema and implementing basic lead assignment logic.

## Long-Term (24+ Months)

**Multi-city expansion.** The platform's architecture is market-agnostic at the pipeline level but market-specific at the data layer. Expanding to Mumbai, Bangalore, or Delhi NCR requires: configuring industry taxonomies for the new market, setting up market-specific scraper configurations, calibrating scoring weights based on local market dynamics, and adapting commercial strategy prompts. Each city is a separate deployment with shared infrastructure but independent configurations.

**Mobile application.** A native or cross-platform mobile app that delivers push notifications for high-scoring leads, enables quick lead review on-the-go, and provides one-tap access to evidence packages. The mobile app will be particularly valuable for brokers who spend significant time traveling between client meetings and site visits.

**Integration ecosystem.** While the platform will never become a CRM, it will offer integrations for exporting leads to common CRM platforms (Salesforce, HubSpot, Zoho) and calendar tools (Google Calendar, Calendly). These integrations will be one-way exports — intelligence flows out of Jasfo into the broker's existing workflow tools.

**Predictive market intelligence.** Beyond individual company predictions, the platform could identify micro-market trends before they become apparent: which IT parks are seeing concentrated hiring, which submarkets are experiencing lease-up, which industries are expanding or contracting in Pune. This market-level intelligence would be a natural byproduct of the company-level monitoring and could become a valuable additional output for the broker's client advisory conversations.
