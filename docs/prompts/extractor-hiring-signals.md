# Extractor: Hiring Signals
Uses: careers page, LinkedIn jobs, job boards, company blog

Extract:
- total_open_roles (integer or null)
- roles_this_month (integer, jobs posted in last 30 days, null)
- departments_hiring (array of strings, e.g. ["Engineering", "Sales"])
- remote_policy (enum: remote, hybrid, on-site, null)
- key_hires (array of strings, notable recent hires/titles, null)
- hiring_velocity (enum: rapid, moderate, slow, null — based on ratio of open roles to total employees)
- growth_roles (array of strings, roles indicating expansion: e.g. ["VP of Sales", "Head of Marketing"])
- engineering_ratio (number or null — percentage of open roles that are engineering)

Schema:
{
  "total_open_roles": { "value": "integer or null", ... },
  "roles_this_month": { "value": "integer or null", ... },
  "departments_hiring": { "value": [ "string" ] or null, ... },
  "remote_policy": { "value": "enum or null", ... },
  "key_hires": { "value": [ "string" ] or null, ... },
  "hiring_velocity": { "value": "enum or null", ... },
  "growth_roles": { "value": [ "string" ] or null, ... },
  "engineering_ratio": { "value": "number or null", ... }
}

Response must be ONLY valid JSON matching schema exactly. No markdown, no code fences, no extra text.
