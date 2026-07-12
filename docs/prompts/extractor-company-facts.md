# Extractor: Company Facts
Uses: minimal context (homepage + about page + LinkedIn snippet)

Extract:
- company_name (string, required)
- description (string, max 200 chars)
- founded_year (integer or null)
- headquarters (string, city, country)
- employee_count (integer or null)
- industry (string or null)
- company_type (enum: public, private, nonprofit, government, null)
- legal_name (string or null)

Schema:
{
  "company_name": { "value": "string", "confidence": 0-100, ... },
  "description": { "value": "string", ... },
  "founded_year": { "value": "integer or null", ... },
  "headquarters": { "value": "string or null", ... },
  "employee_count": { "value": "integer or null", ... },
  "industry": { "value": "string or null", ... },
  "company_type": { "value": "enum or null", ... },
  "legal_name": { "value": "string or null", ... }
}

Response must be ONLY valid JSON matching schema exactly. No markdown, no code fences, no extra text.
