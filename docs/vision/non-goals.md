# Non-Goals

This document explicitly defines what the Jasfo platform is not building. These non-goals serve as guardrails to prevent scope creep, maintain architectural focus, and ensure every engineering decision aligns with the platform's core purpose.

## What Jasfo Is NOT

**Not a CRM.** Jasfo does not store contact histories, manage deal stages, track email sequences, or provide pipeline management. It is a lead intelligence generation system, not a customer relationship management platform. Companies that have been delivered as leads can be exported to a CRM, but Jasfo itself does not manage the sales process. If you need CRM functionality, integrate with Salesforce, HubSpot, or your existing tool.

**Not a cold email blaster.** Jasfo does not send emails, manage campaigns, or automate outreach sequences. It identifies companies and decision-makers, creates evidence packages, and recommends outreach strategies — but the actual communication is executed by the broker. This separation exists because automated cold email at scale degrades sender reputation and because the broker's personal outreach is a competitive advantage.

**Not an Apollo.io or Lusha clone.** The platform does not maintain a purchased contact database, offer B2B contact search, or provide bulk email finding. Contacts are enriched fresh for each qualified lead from public sources. No stale or purchased lists are used. This constraint ensures data freshness and eliminates the cost of contact database subscriptions.

**Not a multi-tenant platform.** Jasfo is built for a single user — the broker. There are no user accounts, role-based access controls, team features, or organization hierarchies. The database schema reflects this: there is no `user_id` on core tables, no multi-tenant RLS policies, and no authentication system beyond the broker's API keys.

**Not multi-city (initially).** The platform is scoped exclusively to Pune. Industry taxonomies, scraper configurations, scoring weights, and commercial strategy prompts are all calibrated for the Pune market. Expanding to another city (Mumbai, Bangalore, Delhi NCR) would require re-calibrating every layer. This expansion is planned but explicitly a non-goal for the initial build.

## Architectural Constraints to Enforce Non-Goals

The database schema omits tables for email campaigns, CRM pipelines, and user management. The Make.com workflows do not include email sending modules. The AI prompts do not include multi-city logic. The export formats are designed for broker review, not for integration with marketing automation platforms. Every architectural decision is tested against the non-goals list: if a feature would serve a non-goal, it is not built.

## What Happens When Non-Goals Are Suggested

When a feature request touches a non-goal area — for example, "can Jasfo send the emails too?" — the answer is no, with a pointer to the appropriate external tool. This discipline keeps the platform focused, the codebase lean, and the operating cost low. Jasfo does one thing well: turning 10,000 companies into 20–30 evidence-backed leads. Everything else is someone else's product.
