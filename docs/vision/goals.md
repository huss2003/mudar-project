# Goals

The Jasfo platform operates against a set of quantified weekly, monthly, and operational targets. These goals define success at each stage of the pipeline and are used to evaluate platform performance, calibrate the scoring model, and identify areas for improvement.

## Weekly Targets

**Deliver 15–25 qualified leads every Monday.** The pipeline processes approximately 10,000 companies through the first eight layers. Of these, 500–1,000 reach the cost gate. Of those, roughly 200–300 receive full contact enrichment and commercial strategy analysis. The final Judge layer scores and ranks these, producing 20–30 leads with a Move Probability Score of 70 or higher. The broker receives the evidence package by Monday evening.

**Maintain evidence quality score above 80%.** Every delivered lead must have at least two independently verified signals. At least one signal must be a direct space-need indicator (hiring surge, lease expiration, expansion announcement, restructuring). Companies qualified solely on weak signals (general industry growth, vague news mentions) are excluded. The evidence quality score measures the share of leads meeting this bar.

**Zero hallucinated data points across all delivered leads.** The Verification layer and Evidence Engine are designed to catch and discard unsupported claims before they reach the broker. If the broker identifies an unsupported claim in a delivered lead, it is logged as a critical error and the upstream layers are audited. The target is zero hallucinated data points per weekly batch.

## Monthly Targets

**Book 10–20 introductory meetings.** From the 80–120 qualified leads delivered each month, the broker conducts initial qualification calls with 10–20 companies. These calls confirm space need, establish timeline, and assess budget. The conversion rate from delivered lead to meeting should be 12–20%.

**Conduct 2–4 site visits.** Of the companies that show genuine interest during introductory meetings, 2–4 proceed to physical site visits. At this stage, the broker has confirmed space requirements, budget parameters, and decision-making authority. The conversion rate from meeting to site visit should be 20–25%.

**Close at least 1 transaction per quarter.** The primary revenue goal is to facilitate at least one commercial lease transaction per quarter. This is the minimum threshold for the platform to be self-sustaining. At the target cost structure of under $50/month, the platform requires only 3–5 closed deals per year to deliver a 50–100x ROI.

## Operational Targets

**Keep monthly operating costs under $50.** This is a hard constraint that influences every architectural decision. The cost-gating layer exists specifically to enforce this constraint. Any proposed change that would increase monthly costs above $50 requires a corresponding reduction elsewhere or an exceptional justification.

**Maintain broker time investment at 2–3 hours per week.** The platform is designed for a solo operator. If the broker spends more than 3 hours per week reviewing leads, conducting research, or managing the pipeline, the system has failed its primary purpose. Time spent on client meetings and site visits is excluded from this target.

**Keep pipeline runtime under 6 hours.** The weekly pipeline triggers at 00:00 IST Monday and must complete by 06:00 IST. This ensures the broker has the full day to review leads. If the pipeline runs longer, it may collide with the broker's client-facing hours or cause Monday delivery to slip.
