# Extractor: Technology Stack
Uses: website footer, job postings, GitHub org, careers page, BuiltWith (via source notes)

Extract:
- primary_stack (array of strings, main tech categories: e.g. ["Python", "React", "AWS"])
- crm (string or null, e.g. "Salesforce", "HubSpot")
- marketing_tools (array of strings, e.g. ["Marketo", "Google Analytics"])
- data_platform (string or null, e.g. "Snowflake", "Databricks")
- hosting (string or null, e.g. "AWS", "GCP", "Azure")
- dev_tools (array of strings, e.g. ["GitHub", "Jira", "Datadog"])
- observed_from_jobs (array of strings, tech mentioned in job postings)
- total_framework_count (integer, count of distinct technologies identified, 0 if none)

Schema:
{
  "primary_stack": { "value": [ "string" ] or null, ... },
  "crm": { "value": "string or null", ... },
  "marketing_tools": { "value": [ "string" ] or null, ... },
  "data_platform": { "value": "string or null", ... },
  "hosting": { "value": "string or null", ... },
  "dev_tools": { "value": [ "string" ] or null, ... },
  "observed_from_jobs": { "value": [ "string" ] or null, ... },
  "total_framework_count": { "value": "integer", ... }
}

Response must be ONLY valid JSON matching schema exactly. No markdown, no code fences, no extra text.
