# Extractor: Decision Makers
Uses: LinkedIn company page, team page, Crunchbase, WhoIs domain contacts, news mentions

Extract:
- ceo (object or null — name, title, LinkedIn URL)
- cto (object or null)
- vp_engineering (object or null)
- head_of_sales (object or null)
- head_of_marketing (object or null)
- founders (array of objects with name + title + linkedin, null)
- team_size_leadership (integer or null — count of C-suite + VP level)
- board_members (array of strings, names only, null)
- technical_leadership (array of strings, CTO + VP Eng + heads of eng/data, null)
- domain_contacts (array of objects from WhoIs with name + email, null)
- linkedin_urls (array of strings, profile URLs found, null)

Schema:
{
  "ceo": { "value": { "name": "string", "title": "string", "linkedin_url": "string or null" } or null, ... },
  "cto": { "value": { "name": "string", "title": "string", "linkedin_url": "string or null" } or null, ... },
  "vp_engineering": { "value": { "name": "string", "title": "string", "linkedin_url": "string or null" } or null, ... },
  "head_of_sales": { "value": { "name": "string", "title": "string", "linkedin_url": "string or null" } or null, ... },
  "head_of_marketing": { "value": { "name": "string", "title": "string", "linkedin_url": "string or null" } or null, ... },
  "founders": { "value": [ { "name": "string", "title": "string", "linkedin_url": "string or null" } ] or null, ... },
  "team_size_leadership": { "value": "integer or null", ... },
  "board_members": { "value": [ "string" ] or null, ... },
  "technical_leadership": { "value": [ "string" ] or null, ... },
  "domain_contacts": { "value": [ { "name": "string or null", "email": "string or null" } ] or null, ... },
  "linkedin_urls": { "value": [ "string" ] or null, ... }
}

Response must be ONLY valid JSON matching schema exactly. No markdown, no code fences, no extra text.
