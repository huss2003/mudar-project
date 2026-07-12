# Success Metrics

The Jasfo platform is evaluated against a set of quantitative and qualitative metrics that span the full pipeline from data collection to deal closure. These metrics are reviewed weekly, monthly, and quarterly to assess platform performance, identify degradation, and guide improvement.

## Pipeline Metrics

**Leads Scored.** The total number of companies that complete the full 14-layer pipeline and receive a Move Probability Score. Target: 500–1,000 per week from an input of 10,000. This metric indicates the platform's ability to qualify companies beyond initial scraping and verification.

**Evidence Quality Score.** The percentage of delivered leads that have at least two independently verified signals, with at least one being a direct space-need indicator. Target: above 80%. This is the primary quality gate and the most important metric for assessing the Evidence Engine's effectiveness.

**Cost per Lead Scored.** The fully loaded cost of moving one company from input to scored lead, including all scraper credits, AI inference, and platform overhead. Target: under $0.05 per lead scored, under $2 per delivered lead.

## Outreach Metrics

**Emails Sent.** The number of personalized outreach emails sent to decision-makers at qualified companies. Target: 20–40 per week. The broker sends individual, context-rich emails — not bulk campaigns. Each email references specific signals identified by the platform.

**Meetings Booked.** Introductory calls or meetings confirmed with qualified leads. Target: 10–20 per month. This is the critical conversion metric between platform output and broker action. If meetings are below target, either the lead quality is insufficient or the outreach strategy needs adjustment.

**Meetings per 100 Leads Delivered.** A normalized efficiency metric. Target: 12–20 meetings per 100 leads delivered. This adjusts for variations in weekly lead volume and provides a consistent quality benchmark.

## Deal Metrics

**Site Visits Completed.** Physical property tours conducted with qualified prospects. Target: 2–4 per month. Site visits represent serious intent — the prospect has confirmed budget, timeline, and decision-making authority.

**Deals Closed.** Commercial lease transactions facilitated. Target: at least 1 per quarter, 4–6 per year. This is the ultimate revenue metric and the platform's reason for existence. A single closed deal typically generates more value than a year of platform operating costs.

**Average Deal Size (INR).** The total contract value of closed leases measured in monthly rent. Tracked to ensure the platform is attracting quality leads rather than small-space inquiries. Updated quarterly.

## Cost Metrics

**Monthly Platform Cost.** The total operating cost of all services: Make.com, Apify, AI inference, hosting, and any third-party APIs. Target: under $50/month. This is a hard constraint with a weekly monitoring alert in Telegram.

**Cost per Meeting.** Monthly platform cost divided by meetings booked. Target: under $5/meeting. If this rises above $10, the pipeline efficiency or lead quality needs investigation.

**Cost per Closed Deal.** Annual platform cost divided by deals closed. Target: under $600/deal (one year of platform costs per deal). At current targets of 4–6 deals per year, the cost per deal should be $100–150.

## Quality Metrics

**Hallucination Rate.** The percentage of claims in delivered evidence packages that cannot be verified by a source. Target: 0%. Any hallucination triggers an immediate audit of the Verification layer and Evidence Engine.

**Lead Accuracy Rate.** The percentage of delivered leads that, when contacted by the broker, confirm the signals detected by the platform. Target: above 70%. This is measured through broker feedback recorded after each introductory call.

**Broker Time Spent.** Hours per week the broker spends on pipeline-related activities excluding client meetings and site visits. Target: 2–3 hours. If this exceeds 4 hours, the platform's automation is insufficient and requires optimization.
