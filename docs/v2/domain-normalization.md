# Domain Normalization & Duplicate Detection

> **Status:** Draft  
> **Version:** 2.0  
> **Last Updated:** 2026-07-12  
> **Owner:** Pipeline Engineering

---

## Table of Contents

1. [Domain Normalization](#1-domain-normalization)
2. [Company Name Normalization](#2-company-name-normalization)
3. [Fuzzy Matching (Levenshtein)](#3-fuzzy-matching-levenshtein)
4. [Name Similarity](#4-name-similarity)
5. [Domain Similarity](#5-domain-similarity)
6. [Duplicate Detection](#6-duplicate-detection)
7. [Parked Domain Detection](#7-parked-domain-detection)
8. [Rejectable Domain Patterns](#8-rejectable-domain-patterns)
9. [Initial Qualification Scoring](#9-initial-qualification-scoring)
10. [Confidence Scoring Formulas](#10-confidence-scoring-formulas)
11. [Appendix: Integration into n8n](#11-appendix-integration-into-n8n)

---

## 1. Domain Normalization

Transforms raw URL strings into a canonical domain for comparison, storage, and deduplication.

### Normalization Pipeline

```
Raw URL → Lowercase → Strip protocol → Strip www →
Strip trailing slash → Strip path → Strip port →
Strip query params → Strip fragment → Return canonical domain
```

### Algorithm

| Step | Input | Operation | Output |
|------|-------|-----------|--------|
| 1 | `HTTPS://www.Example.COM:8080/path?q=1#frag` | Lowercase | `https://www.example.com:8080/path?q=1#frag` |
| 2 | — | Strip `https://` | `www.example.com:8080/path?q=1#frag` |
| 3 | — | Strip `http://` (if present) | `www.example.com:8080/path?q=1#frag` |
| 4 | — | Strip `www.` prefix | `example.com:8080/path?q=1#frag` |
| 5 | — | Strip trailing slash | `example.com:8080/path?q=1#frag` |
| 6 | — | Strip `/path` onward | `example.com:8080` |
| 7 | — | Strip `:8080` port | `example.com` |
| 8 | — | Strip `?q=1` | `example.com` |
| 9 | — | Strip `#frag` | `example.com` |

### Normalization Table

| Raw Input | Normalized |
|-----------|------------|
| `https://www.Acme-Corp.com/` | `acme-corp.com` |
| `HTTP://ACME-CORP.COM:8080/index.html` | `acme-corp.com` |
| `https://blog.acme-corp.com/` | `blog.acme-corp.com` |
| `www.acme-corp.co.uk/index.php?id=1` | `acme-corp.co.uk` |
| `https://acme-corp.com#about` | `acme-corp.com` |
| `Acme-Corp.com/contact/` | `acme-corp.com` |
| `http://www.Example.com/` | `example.com` |

### JavaScript Implementation

```javascript
// n8n Code Node: Normalize Domain
// Input: $input.first().json.url (string or null)
// Output: { normalized: string | null, original: string | null }

function normalizeDomain(url) {
  if (!url) return null;
  
  let d = url.toLowerCase().trim();
  
  // Step 1: Strip protocol (https:// or http://)
  d = d.replace(/^https?:\/\//, '');
  
  // Step 2: Strip www and common subdomain variants
  d = d.replace(/^www\d*\./, '');
  
  // Step 3: Strip trailing slash
  d = d.replace(/\/+$/, '');
  
  // Step 4: Strip everything after first / (path, query, fragment)
  d = d.split('/')[0];
  
  // Step 5: Strip port number
  d = d.replace(/:\d+$/, '');
  
  // Step 6: Strip trailing dots (occurs in some edge cases)
  d = d.replace(/\.+$/, '');
  
  return d || null;
}

const rawUrl = $input.first().json.url || '';
const normalized = normalizeDomain(rawUrl);

return [{
  json: {
    original: rawUrl,
    normalized: normalized,
    normalized_domain: normalized,
    valid: normalized !== null && normalized.includes('.')
  }
}];
```

### Edge Cases

| Input | Behavior |
|-------|----------|
| `null` / empty string | Return `null` |
| `localhost` | Return `localhost` (no TLD check) |
| `192.168.1.1` | Return IP as-is |
| `example.com.` | Strip trailing dot |
| `https://` (protocol only) | Return `null` |

---

## 2. Company Name Normalization

Strips legal suffixes, punctuation, and filler words so names can be compared structurally.

### Normalization Pipeline

```
Raw name → Lowercase → Strip legal suffixes →
Strip punctuation → Collapse whitespace →
Strip common prefixes → Return canonical name
```

### Removed Legal Suffixes

| Pattern | Matches |
|---------|---------|
| `\b(inc|incorporated)\b\.?` | `Inc`, `Inc.`, `Incorporated` |
| `\b(llc|limited liability company)\b\.?` | `LLC`, `Limited Liability Company` |
| `\b(ltd|limited)\b\.?` | `Ltd`, `Ltd.`, `Limited` |
| `\b(corp|corp\.|corporation)\b` | `Corp`, `Corp.`, `Corporation` |
| `\b(gmbh|ag|sa|plc|nv|bv|pty)\b` | `GmbH`, `AG`, `SA`, `PLC` |
| `\b(pvt|private)\b\.?` | `Pvt`, `Pvt.`, `Private` |
| `\b(co|company)\b\.?` | `Co`, `Co.`, `Company` |
| `\b(group|holdings|enterprises?|ventures)\b` | `Group`, `Holdings`, `Enterprises` |
| `\b(solutions|technologies?|tech|industri(es|y)|international|intl)\b\.?` | Common filler words |

### Normalization Table

| Raw Name | Normalized |
|----------|------------|
| `Acme Corporation Inc.` | `acme corporation` |
| `Acme Corp` | `acme` |
| `The Acme Group LLC` | `acme group` |
| `Acme Technologies Private Limited` | `acme technologies` |
| `Acme International Ltd.` | `acme international` |
| `Acme Software Solutions Pvt. Ltd.` | `acme software solutions` |
| `Acme, Inc.` | `acme` |
| `Acme Company` | `acme` |

### JavaScript Implementation

```javascript
// n8n Code Node: Normalize Company Name
// Input: $input.first().json.name (string)
// Output: { original: string, normalized: string }

function normalizeCompanyName(name) {
  if (!name) return '';
  
  let n = name.toLowerCase().trim();
  
  // Step 1: Remove legal suffixes
  const legalSuffixes = [
    /\b(inc|incorporated|corporation|corp|corp\.)\b\.?/g,
    /\b(llc|limited liability company)\b\.?/g,
    /\b(ltd|limited)\b\.?/g,
    /\b(gmbh|ag|sa|plc|nv|bv|pty|sdn|bhd)\b\.?/g,
    /\b(pvt|private)\b\.?/g,
    /\b(co|company)\b\.?/g,
    /\b(group|holdings?|enterprises?|ventures?)\b\.?/g,
    /\b(solutions?|technologies?|tech|industri(es|y)|international|intl)\b\.?/g
  ];
  
  for (const pattern of legalSuffixes) {
    n = n.replace(pattern, '');
  }
  
  // Step 2: Remove punctuation (keep spaces for word separation)
  n = n.replace(/[^a-z0-9\s]/g, ' ');
  
  // Step 3: Collapse whitespace
  n = n.replace(/\s+/g, ' ').trim();
  
  // Step 4: Remove common leading articles
  n = n.replace(/^(the|a|an)\s+/i, '');
  
  return n;
}

const rawName = $input.first().json.name || '';
const normalized = normalizeCompanyName(rawName);

return [{
  json: {
    original: rawName,
    normalized: normalized,
    normalized_length: normalized.length,
    valid: normalized.length > 0
  }
}];
```

### Edge Cases

| Input | Behavior |
|-------|----------|
| `null` / empty | Return `''` |
| `Acme` (no suffix) | Return `acme` unchanged |
| `A` (single letter) | Return `a` |
| `The Company` (all filler) | Return `''` (all words removed) |
| `Acme/Smith Corp.` (slash) | Strip slash → `acme smith` |

---

## 3. Fuzzy Matching (Levenshtein)

Standard Levenshtein distance implementation for comparing normalized strings. Used as the foundation for name and domain similarity scoring.

### Algorithm

```
levenshtein(a, b):
  create matrix of size (b.length+1) × (a.length+1)
  initialize first row and column with indices
  for each cell:
    cost = 0 if a[j-1] == b[i-1] else 1
    matrix[i][j] = min(
      matrix[i-1][j] + 1,    # deletion
      matrix[i][j-1] + 1,    # insertion
      matrix[i-1][j-1] + cost  # substitution
    )
  return matrix[b.length][a.length]
```

### Visualization

Example: `"acme"` vs `"akme"` (distance = 1)

```
        ""   a   c   m   e
  ""  [ 0,  1,  2,  3,  4 ]
   a  [ 1,  0,  1,  2,  3 ]
   k  [ 2,  1,  1,  2,  3 ]
   m  [ 3,  2,  2,  1,  2 ]
   e  [ 4,  3,  3,  2,  1 ]
```

### Distance Interpretation

| Distance | Interpretation | Example Pair |
|----------|---------------|-------------|
| 0 | Exact match | `acme` vs `acme` |
| 1 | Single character difference | `acme` vs `akme` |
| 2 | Two character differences | `acme` vs `acmes` |
| 3-4 | Moderate difference | `acme` vs `acmer` |
| 5+ | Significant difference | `acme` vs `example` |

### JavaScript Implementation

```javascript
// n8n Code Node: Levenshtein Distance
// Pure function — no external dependencies
// Input from upstream node: { string_a, string_b }

function levenshteinDistance(a, b) {
  const aLen = a.length;
  const bLen = b.length;
  
  // Handle empty string edge cases
  if (aLen === 0) return bLen;
  if (bLen === 0) return aLen;
  
  // Initialize matrix
  const matrix = [];
  
  for (let i = 0; i <= bLen; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= aLen; j++) {
    matrix[0][j] = j;
  }
  
  // Fill matrix
  for (let i = 1; i <= bLen; i++) {
    for (let j = 1; j <= aLen; j++) {
      const cost = a[j - 1] === b[i - 1] ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,      // deletion
        matrix[i][j - 1] + 1,      // insertion
        matrix[i - 1][j - 1] + cost // substitution
      );
    }
  }
  
  return matrix[bLen][aLen];
}

// Test
const strA = $input.first().json.string_a || '';
const strB = $input.first().json.string_b || '';
const distance = levenshteinDistance(strA, strB);
const maxLen = Math.max(strA.length, strB.length);
const similarity = maxLen > 0 ? Math.round((1 - distance / maxLen) * 100) : 100;

return [{
  json: {
    string_a: strA,
    string_b: strB,
    distance: distance,
    max_length: maxLen,
    similarity_pct: similarity,
    is_exact: distance === 0,
    is_close: similarity >= 80
  }
}];
```

### Performance Characteristics

| String Length | Operations | Runtime (V8) |
|--------------|------------|--------------|
| 10 × 10 | 100 | < 0.01ms |
| 50 × 50 | 2,500 | ~0.05ms |
| 100 × 100 | 10,000 | ~0.2ms |
| 500 × 500 | 250,000 | ~5ms |

---

## 4. Name Similarity

Combines normalization and Levenshtein distance to produce a 0-100 similarity score for company name pairs.

### Scoring Pipeline

```
Name A → Normalize → Normalized A ─┐
                                   ├─→ Levenshtein → Similarity %
Name B → Normalize → Normalized B ─┘
```

### Scoring Rules

| Condition | Score | Example |
|-----------|-------|---------|
| Exact match after normalization | 100 | `Acme Corp` vs `Acme Corp` |
| One name fully contains the other | 90 | `Acme` vs `Acme Technologies` |
| Levenshtein similarity >= 80 | `1 - (dist/maxLen) * 100` | `Acme` vs `Akme` → 75% (dist=1, len=4) |
| Levenshtein similarity < 80 | Score as computed | Unlikely match |

### JavaScript Implementation

```javascript
// n8n Code Node: Name Similarity
// Input: { name_a: string, name_b: string }
// Output: { similarity: 0-100, match_type: string }

function normalizeCompanyName(name) {
  if (!name) return '';
  let n = name.toLowerCase().trim();
  const legalSuffixes = [
    /\b(inc|incorporated|corporation|corp|corp\.)\b\.?/g,
    /\b(llc|limited liability company)\b\.?/g,
    /\b(ltd|limited)\b\.?/g,
    /\b(gmbh|ag|sa|plc|nv|bv|pty|sdn|bhd)\b\.?/g,
    /\b(pvt|private)\b\.?/g,
    /\b(co|company)\b\.?/g,
    /\b(group|holdings?|enterprises?|ventures?)\b\.?/g,
    /\b(solutions?|technologies?|tech|industri(es|y)|international|intl)\b\.?/g
  ];
  for (const pat of legalSuffixes) n = n.replace(pat, '');
  n = n.replace(/[^a-z0-9\s]/g, ' ');
  n = n.replace(/\s+/g, ' ').trim();
  return n;
}

function levenshteinDistance(a, b) {
  const aLen = a.length, bLen = b.length;
  if (aLen === 0) return bLen;
  if (bLen === 0) return aLen;
  const matrix = [];
  for (let i = 0; i <= bLen; i++) matrix[i] = [i];
  for (let j = 0; j <= aLen; j++) matrix[0][j] = j;
  for (let i = 1; i <= bLen; i++) {
    for (let j = 1; j <= aLen; j++) {
      const cost = a[j - 1] === b[i - 1] ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost
      );
    }
  }
  return matrix[bLen][aLen];
}

function nameSimilarity(name1, name2) {
  const n1 = normalizeCompanyName(name1);
  const n2 = normalizeCompanyName(name2);
  
  if (!n1 || !n2) return 0;
  if (n1 === n2) return 100;
  if (n1.includes(n2) || n2.includes(n1)) return 90;
  
  const dist = levenshteinDistance(n1, n2);
  const maxLen = Math.max(n1.length, n2.length);
  return Math.round((1 - dist / maxLen) * 100);
}

const nameA = $input.first().json.name_a || '';
const nameB = $input.first().json.name_b || '';
const sim = nameSimilarity(nameA, nameB);

let matchType = 'none';
if (sim >= 100) matchType = 'exact';
else if (sim >= 90) matchType = 'substring';
else if (sim >= 80) matchType = 'fuzzy_strong';
else if (sim >= 60) matchType = 'fuzzy_weak';
else matchType = 'none';

return [{
  json: {
    name_a: nameA,
    name_b: nameB,
    normalized_a: normalizeCompanyName(nameA),
    normalized_b: normalizeCompanyName(nameB),
    similarity: sim,
    match_type: matchType,
    is_duplicate: sim >= 80
  }
}];
```

---

## 5. Domain Similarity

Compares two normalized domains to detect different TLD variants of the same brand.

### Scoring Rules

| Condition | Score | Example |
|-----------|-------|---------|
| Exact match after normalization | 100 | `example.com` vs `example.com` |
| Same SLD (second-level domain), different TLD | 85 | `example.com` vs `example.co.uk` |
| Subdomain of same domain | 80 | `www.example.com` vs `blog.example.com` |
| No match | 0 | `example.com` vs `other.com` |

### Domain Parts Reference

```
example.com → SLD = example, TLD = com
blog.example.co.uk → SLD = example, TLD = co.uk (public suffix)
```

### JavaScript Implementation

```javascript
// n8n Code Node: Domain Similarity
// Input: { domain_a: string, domain_b: string }
// Output: { similarity: 0-100, match_type: string }

function normalizeDomain(url) {
  if (!url) return null;
  let d = url.toLowerCase().trim();
  d = d.replace(/^https?:\/\//, '');
  d = d.replace(/^www\d*\./, '');
  d = d.split('/')[0];
  d = d.replace(/:\d+$/, '');
  d = d.replace(/\.+$/, '');
  return d || null;
}

function domainSimilarity(domain1, domain2) {
  const d1 = normalizeDomain(domain1);
  const d2 = normalizeDomain(domain2);
  
  if (!d1 || !d2) return 0;
  if (d1 === d2) return 100;
  
  // Check subdomain variants: same SLD, different TLD
  const parts1 = d1.split('.');
  const parts2 = d2.split('.');
  
  // Extract SLD (second-level domain, typically the company name)
  // For simple TLDs (.com, .io): sld = parts[0]
  // For compound TLDs (.co.uk): SLD extraction requires public suffix list
  // Simplified: use first dot-separated part as SLD
  const sld1 = parts1.length >= 2 ? parts1[parts1.length - 2] : null;
  const sld2 = parts2.length >= 2 ? parts2[parts2.length - 2] : null;
  
  if (sld1 && sld2 && sld1 === sld2) {
    // Same brand, different TLD — high similarity
    return 85;
  }
  
  // Check if one is subdomain of the other
  if (d1.endsWith('.' + d2) || d2.endsWith('.' + d1)) {
    return 80;
  }
  
  return 0;
}

const domA = $input.first().json.domain_a || '';
const domB = $input.first().json.domain_b || '';
const sim = domainSimilarity(domA, domB);

let matchType = 'none';
if (sim >= 100) matchType = 'exact';
else if (sim >= 85) matchType = 'tld_variant';
else if (sim >= 80) matchType = 'subdomain';
else matchType = 'none';

return [{
  json: {
    domain_a: domA,
    domain_b: domB,
    normalized_a: normalizeDomain(domA),
    normalized_b: normalizeDomain(domB),
    similarity: sim,
    match_type: matchType,
    is_duplicate: sim >= 80
  }
}];
```

---

## 6. Duplicate Detection

Combines domain similarity and name similarity to identify duplicate companies across the database.

### Detection Flow

```
Input Company → Normalize domain → Normalize name
       │
       ▼
For each existing company:
  ├─ Domain similarity >= 80? ──→ DUPLICATE (domain match)
  └─ Name similarity >= 80? ────→ DUPLICATE (name match)
  
If duplicate found:
  → Score = max(domain_sim, name_sim)
  → Match type = whichever scored higher
  → Confidence = score
```

### Decision Matrix

| Domain Sim | Name Sim | Verdict | Confidence |
|------------|----------|---------|------------|
| 100 | ≥ 80 | Exact domain match | 100 |
| ≥ 80 | Any | Domain variant match | 80-85 |
| < 80 | 100 | Exact name match | 100 |
| < 80 | ≥ 90 | Substring name match | 90 |
| < 80 | ≥ 80 | Fuzzy name match | 80-89 |
| < 80 | < 80 | No match | — |

### JavaScript Implementation

```javascript
// n8n Code Node: Duplicate Detection
// Input: { company: { name, domain }, existing: [{ name, domain }] }
// Output: { is_duplicate, duplicates[], max_score }

function normalizeDomain(url) {
  if (!url) return null;
  let d = url.toLowerCase().trim();
  d = d.replace(/^https?:\/\//, '');
  d = d.replace(/^www\d*\./, '');
  d = d.split('/')[0];
  d = d.replace(/:\d+$/, '');
  return d || null;
}

function normalizeCompanyName(name) {
  if (!name) return '';
  let n = name.toLowerCase().trim();
  const suffixes = [
    /\b(inc|incorporated|corporation|corp|corp\.)\b\.?/g,
    /\b(llc|limited liability company)\b\.?/g,
    /\b(ltd|limited)\b\.?/g,
    /\b(gmbh|ag|sa|plc|nv|bv|pty|sdn|bhd)\b\.?/g,
    /\b(pvt|private)\b\.?/g,
    /\b(co|company)\b\.?/g,
    /\b(group|holdings?|enterprises?|ventures?)\b\.?/g,
    /\b(solutions?|technologies?|tech|industri(es|y)|international|intl)\b\.?/g
  ];
  for (const pat of suffixes) n = n.replace(pat, '');
  n = n.replace(/[^a-z0-9\s]/g, ' ');
  n = n.replace(/\s+/g, ' ').trim();
  return n;
}

function levenshteinDistance(a, b) {
  const aLen = a.length, bLen = b.length;
  if (aLen === 0) return bLen;
  if (bLen === 0) return aLen;
  const m = [];
  for (let i = 0; i <= bLen; i++) m[i] = [i];
  for (let j = 0; j <= aLen; j++) m[0][j] = j;
  for (let i = 1; i <= bLen; i++)
    for (let j = 1; j <= aLen; j++)
      m[i][j] = Math.min(
        m[i-1][j] + 1,
        m[i][j-1] + 1,
        m[i-1][j-1] + (a[j-1] === b[i-1] ? 0 : 1)
      );
  return m[bLen][aLen];
}

function nameSimilarity(name1, name2) {
  const n1 = normalizeCompanyName(name1);
  const n2 = normalizeCompanyName(name2);
  if (!n1 || !n2) return 0;
  if (n1 === n2) return 100;
  if (n1.includes(n2) || n2.includes(n1)) return 90;
  const dist = levenshteinDistance(n1, n2);
  const maxLen = Math.max(n1.length, n2.length);
  return Math.round((1 - dist / maxLen) * 100);
}

function domainSimilarity(domain1, domain2) {
  const d1 = normalizeDomain(domain1);
  const d2 = normalizeDomain(domain2);
  if (!d1 || !d2) return 0;
  if (d1 === d2) return 100;
  const p1 = d1.split('.');
  const p2 = d2.split('.');
  const sld1 = p1.length >= 2 ? p1[p1.length - 2] : null;
  const sld2 = p2.length >= 2 ? p2[p2.length - 2] : null;
  if (sld1 && sld2 && sld1 === sld2) return 85;
  return 0;
}

// Main detection logic
const company = $input.first().json.company || {};
const existingList = $input.first().json.existing || [];

const results = [];
for (const existing of existingList) {
  const domainSim = domainSimilarity(company.domain, existing.domain);
  const nameSim = nameSimilarity(company.name, existing.name);
  const maxSim = Math.max(domainSim, nameSim);
  
  if (maxSim >= 80) {
    const matchType = domainSim >= nameSim ? 'domain' : 'name';
    results.push({
      existing_name: existing.name,
      existing_domain: existing.domain,
      similarity: maxSim,
      domain_similarity: domainSim,
      name_similarity: nameSim,
      match_type: matchType,
      confidence: maxSim
    });
  }
}

results.sort((a, b) => b.similarity - a.similarity);

return [{
  json: {
    company_name: company.name,
    company_domain: company.domain,
    is_duplicate: results.length > 0,
    duplicate_count: results.length,
    max_similarity: results.length > 0 ? results[0].similarity : 0,
    duplicates: results.slice(0, 10) // Top 10 matches
  }
}];
```

### Performance Optimization

For large databases (10K+ companies), pre-cache normalized domains and names:

```sql
-- Pre-computed normalization columns
ALTER TABLE companies ADD COLUMN normalized_domain TEXT;
ALTER TABLE companies ADD COLUMN normalized_name TEXT;
CREATE INDEX idx_companies_normalized_domain ON companies(normalized_domain);
CREATE INDEX idx_companies_normalized_name ON companies(normalized_name);
```

Then query by exact normalized match before running fuzzy comparison:

```javascript
// Optimized: first try exact match on normalized values
const normDomain = normalizeDomain(company.domain);
const normName = normalizeCompanyName(company.name);

// These are fast index lookups (no fuzzy needed)
const exactDomainMatch = existingList.filter(e =>
  normalizeDomain(e.domain) === normDomain
);
const exactNameMatch = existingList.filter(e =>
  normalizeCompanyName(e.name) === normName
);
```

---

## 7. Parked Domain Detection

Identifies domains that are parked (not actively hosting a real company site).

### Detection Signals

| Signal | Source | Weight |
|--------|--------|--------|
| Page title contains parking keywords | HTTP fetch | High |
| Response body contains parking keywords | HTTP fetch | High |
| Known parking service in HTML | HTTP fetch | Medium |
| DNS points to parking IP range | DNS lookup | Medium |
| No MX record (no email) + generic page | DNS + HTTP | Low |

### Parking Keywords

```
"this domain is parked"
"domain is for sale"
"buy this domain"
"coming soon"
"this website is under construction"
"domain parking"
"hostgator.com/parking"
"sedoparking.com"
"bodis.com"
"domainname.com"
"parking-page"
```

### Known Parking IP Blocks

| Provider | IP Range |
|----------|----------|
| Sedo | `91.195.240.*` |
| GoDaddy | `184.168.*.*` |
| BODIS | `162.210.196.*` |
| ParkingCrew | `104.28.*.*` |

### JavaScript Implementation

```javascript
// n8n Code Node: Parked Domain Detection
// Input: { url, response_text, page_title, response_headers }
// Output: { is_parked: boolean, confidence: 0-100, signals_found: string[] }

function isParkedDomain(responseText, title, html) {
  const combined = ((responseText || '') + ' ' + (title || '') + ' ' + (html || '')).toLowerCase();
  
  const parkedSignals = [
    'this domain is parked',
    'domain is for sale',
    'buy this domain',
    'coming soon',
    'this website is under construction',
    'domain parking',
    'parked page',
    'hostgator.com/parking',
    'godaddy.com/parking',
    'sedoparking.com',
    'bodis.com',
    'domainname.com/parking',
    'parking-crew.com',
    'domain may be for sale',
    'this domain name has been registered',
    'website is not active'
  ];
  
  const found = [];
  for (const signal of parkedSignals) {
    if (combined.includes(signal)) {
      found.push(signal);
    }
  }
  
  return {
    is_parked: found.length > 0,
    confidence: Math.min(50 + found.length * 15, 100),
    signals_found: found,
    signal_count: found.length
  };
}

const responseText = $input.first().json.response_text || '';
const pageTitle = $input.first().json.page_title || '';
const pageHtml = $input.first().json.raw_html || '';
const result = isParkedDomain(responseText, pageTitle, pageHtml);

return [{
  json: {
    url: $input.first().json.url || '',
    is_parked: result.is_parked,
    confidence: result.confidence,
    signals_found: result.signals_found,
    signal_count: result.signal_count,
    verdict: result.is_parked ? 'PARKED' : 'ACTIVE'
  }
}];
```

---

## 8. Rejectable Domain Patterns

Domains that are never valid company destinations — social media, marketplaces, free hosting, email providers.

### Rejection Categories

| Category | Examples | Reason |
|----------|----------|--------|
| Social Media | `facebook.com`, `linkedin.com`, `twitter.com`, `x.com`, `instagram.com`, `youtube.com` | Personal/social, not company |
| Marketplaces | `amazon.in`, `flipkart.com`, `indiamart.com` (non-company listing), `justdial.com` (non-company listing) | Product pages, not company sites |
| Free Hosting | `blogspot.com`, `wordpress.com`, `wixsite.com`, `weebly.com`, `squarespace.com`, `myshopify.com`, `shopify.com`, `godaddysites.com`, `webflow.io` | Template sites, not company domains |
| Email Providers | `gmail.com`, `outlook.com`, `yahoo.com`, `protonmail.com`, `aol.com`, `zoho.com`, `mail.com` | Personal email, not business |
| Disposable TLDs | `.tk`, `.ml`, `.ga`, `.cf`, `.gq`, `.xyz`, `.top`, `.loan` | High churn/phishing risk |

### JavaScript Implementation

```javascript
// n8n Code Node: Rejectable Domain Filter
// Input: { domain: string }
// Output: { is_rejectable: boolean, reason: string | null, category: string | null }

function isRejectableDomain(domain) {
  if (!domain) return { is_rejectable: true, reason: 'No domain', category: 'missing' };
  
  const d = domain.toLowerCase().trim();
  
  // Social media platforms
  const socialPatterns = [
    /^facebook\.com(\/|$)/, /^instagram\.com(\/|$)/,
    /^linkedin\.com(\/|$)/, /^twitter\.com(\/|$)/,
    /^x\.com(\/|$)/, /^youtube\.com(\/|$)/,
    /^tiktok\.com(\/|$)/, /^pinterest\.com(\/|$)/,
    /^snapchat\.com(\/|$)/, /^reddit\.com(\/|$)/,
    /^tumblr\.com(\/|$)/, /^medium\.com(\/|$)/,
    /^quora\.com(\/|$)/
  ];
  
  for (const p of socialPatterns) {
    if (p.test(d)) return { is_rejectable: true, reason: 'Social media domain', category: 'social' };
  }
  
  // Marketplaces (exact domain match, not subdomain)
  const marketplacePatterns = [
    /^amazon\.(com|in|co\.uk|de|fr|it|es|ca|com\.au|jp)(\/|$)/,
    /^flipkart\.com(\/|$)/, /^ebay\.com(\/|$)/,
    /^indiamart\.com(\/|$)/, /^justdial\.com(\/|$)/,
    /^alibaba\.com(\/|$)/, /^aliexpress\.com(\/|$)/
  ];
  
  for (const p of marketplacePatterns) {
    if (p.test(d)) return { is_rejectable: true, reason: 'Marketplace domain', category: 'marketplace' };
  }
  
  // Free hosting / website builders
  const hostingPatterns = [
    /\.blogspot\.com$/, /\.wordpress\.com$/,
    /\.wixsite\.com$/, /\.wix\.com$/,
    /\.weebly\.com$/, /\.squarespace\.com$/,
    /\.myshopify\.com$/, /\.shopify\.com$/,
    /\.godaddysites\.com$/, /\.webflow\.io$/,
    /\.yolasite\.com$/, /\. jimdo\.com$/,
    /\.strikingly\.com$/, /\.ucraft\.com$/,
    /\.imcreator\.com$/, /\.site123\.com$/,
    /\.carrd\.co$/, /\.pages\.dev$/,
    /\.github\.io$/, /\.gitlab\.io$/,
    /\.netlify\.app$/, /\.vercel\.app$/
  ];
  
  for (const p of hostingPatterns) {
    if (p.test(d)) return { is_rejectable: true, reason: 'Free hosting platform', category: 'hosting' };
  }
  
  // Email providers (used as fake "website")
  const emailPatterns = [
    /^gmail\.com$/, /^outlook\.com$/, /^hotmail\.com$/,
    /^yahoo\.com$/, /^protonmail\.com$/, /^aol\.com$/,
    /^zoho\.com$/, /^mail\.com$/, /^yandex\.com$/,
    /^icloud\.com$/, /^gmx\.com$/
  ];
  
  for (const p of emailPatterns) {
    if (p.test(d)) return { is_rejectable: true, reason: 'Email provider domain', category: 'email' };
  }
  
  // Disposable TLDs
  const disposableTLDs = [
    '.tk', '.ml', '.ga', '.cf', '.gq',
    '.xyz', '.top', '.loan', '.click', '.download',
    '.review', '.work', '.date', '.men', '.win',
    '.bid', '.trade', '.webcam', '.science', '.stream'
  ];
  
  for (const tld of disposableTLDs) {
    if (d.endsWith(tld)) {
      return { is_rejectable: true, reason: `Disposable TLD: ${tld}`, category: 'disposable_tld' };
    }
  }
  
  return { is_rejectable: false, reason: null, category: null };
}

const domain = $input.first().json.domain || '';
const result = isRejectableDomain(domain);

return [{
  json: {
    domain: domain,
    is_rejectable: result.is_rejectable,
    rejection_reason: result.reason,
    rejection_category: result.category,
    verdict: result.is_rejectable ? 'REJECT' : 'ACCEPT'
  }
}];
```

---

## 9. Initial Qualification Scoring

A lightweight scoring pass applied before full enrichment to avoid wasting resources on poor records.

### Criteria & Weights

| Criterion | Weight | Score Function |
|-----------|--------|---------------|
| Website exists & real | 0.25 | 100 if not parked and not social and has website; 0 otherwise |
| HTTPS enabled | 0.10 | 100 if HTTPS works; 30 if HTTP only |
| Domain age | 0.15 | >365d → 100; >180d → 70; >30d → 40; else 10 |
| Description available | 0.15 | 100 if meta/og description found; 20 otherwise |
| Industry match | 0.20 | exact → 100; partial → 60; none → 20 |
| Contact info | 0.15 | 100 if email or phone found; 30 otherwise |

### Thresholds

| Score | Verdict | Action |
|-------|---------|--------|
| >= 60 | PASS | Proceed to full enrichment + scoring |
| 40-59 | BORDERLINE | Partial enrichment (core fields only) |
| < 40 | REJECT | Skip — insufficient data |

### JavaScript Implementation

```javascript
// n8n Code Node: Initial Qualification
// Input: { validation: { has_website, has_https, domain_age_days,
//         has_contact, has_description, industry_match, is_parked, is_social } }
// Output: { score, breakdown, passed, verdict }

function calculateInitialScore(company) {
  const v = company.validation || {};
  
  // Website existence and legitimacy
  const websiteScore = (!v.is_parked && !v.is_social && v.has_website) ? 100 : 0;
  
  // HTTPS
  const httpsScore = v.has_https ? 100 : 30;
  
  // Domain age
  let ageScore = 10;
  if (v.domain_age_days > 365) ageScore = 100;
  else if (v.domain_age_days > 180) ageScore = 70;
  else if (v.domain_age_days > 30) ageScore = 40;
  
  // Description
  const descScore = v.has_description ? 100 : 20;
  
  // Industry match
  let industryScore = 20;
  if (v.industry_match === 'exact') industryScore = 100;
  else if (v.industry_match === 'partial') industryScore = 60;
  
  // Contact info
  const contactScore = v.has_contact ? 100 : 30;
  
  // Weighted total
  const weighted =
    websiteScore * 0.25 +
    httpsScore * 0.10 +
    ageScore * 0.15 +
    descScore * 0.15 +
    industryScore * 0.20 +
    contactScore * 0.15;
  
  return {
    score: Math.round(weighted),
    breakdown: {
      website_score: websiteScore,
      https_score: httpsScore,
      age_score: ageScore,
      description_score: descScore,
      industry_score: industryScore,
      contact_score: contactScore
    },
    passed: weighted >= 60,
    verdict: weighted >= 60 ? 'PASS' :
             weighted >= 40 ? 'BORDERLINE' : 'REJECT'
  };
}

const company = $input.first().json;
const result = calculateInitialScore(company);

return [{
  json: {
    company_name: company.name,
    company_domain: company.domain,
    initial_qualification: result,
    next_action: result.verdict === 'PASS' ? 'enrich_full' :
                  result.verdict === 'BORDERLINE' ? 'enrich_partial' : 'skip'
  }
}];
```

### Scoring Examples

| Company Profile | Website | HTTPS | Age | Desc | Industry | Contact | Score | Verdict |
|-----------------|---------|-------|-----|------|----------|---------|-------|---------|
| Established SaaS | 100 | 100 | 100 | 100 | 100 | 100 | **100** | PASS |
| Young startup | 100 | 100 | 40 | 20 | 60 | 30 | **62** | PASS |
| No description | 100 | 100 | 100 | 20 | 60 | 100 | **80** | PASS |
| Parked domain | 0 | 30 | 100 | 20 | 20 | 30 | **24** | REJECT |
| Social page only | 0 | 100 | 40 | 100 | 60 | 100 | **52** | BORDERLINE |

---

## 10. Confidence Scoring Formulas

The qualification pass feeds into a broader confidence score used across the pipeline.

### Composite Confidence

```
composite_confidence = Σ(factor_score_i × factor_weight_i) / Σ(factor_weights)
```

### Factors

| Factor | Weight | Description |
|--------|--------|-------------|
| `source_reliability` | 0.25 | Quality/authority of the source that provided the data |
| `evidence_count` | 0.20 | How many independent evidence items exist |
| `freshness` | 0.15 | How recently the data was last verified |
| `ai_agreement` | 0.20 | Agreement between extraction and verification models |
| `completeness` | 0.10 | % of required fields that have evidence |
| `validation_success` | 0.10 | Did schema/regex validation pass? |

### Source Reliability Weights

| Source | Weight | Rationale |
|--------|--------|-----------|
| Official website | 95 | Primary, company-controlled |
| Government registry | 95 | Verified by regulatory authority |
| Schema.org JSON-LD | 95 | Machine-readable, on official site |
| LinkedIn Company | 90 | Company-verified profile |
| GitHub | 85 | Development activity is hard to fake |
| Press release | 80 | Journalist-vetted |
| crt.sh | 85 | Cryptographic proof of domain |
| WHOIS/RDAP | 80 | Registry-verified domain data |
| News article (major) | 70 | Professional journalism |
| Business directory | 60 | User-contributed, may be stale |
| RSS feed | 50 | Automated aggregation |
| Blog | 40 | Self-published, may be marketing |
| Social media | 30 | Unverified, potentially marketing |
| Unknown | 20 | No source provenance |

### Freshness Multiplier

| Age | Multiplier |
|-----|-----------|
| < 7 days | 1.0 |
| 7-30 days | 0.9 |
| 30-90 days | 0.7 |
| > 90 days | 0.4 |

### Confidence Thresholds

| Score | Label | Meaning |
|-------|-------|---------|
| >= 80 | HIGH | Trust the data — proceed without human review |
| 60-79 | MEDIUM | Usable — verify critical fields before acting |
| 40-59 | LOW | Flag for manual review — significant gaps |
| < 40 | INSUFFICIENT | Reject or re-acquire from a different source |

### Independence Bonus

| Condition | Bonus |
|-----------|-------|
| Same value confirmed by 2+ independent sources | +10 |
| Same value confirmed by 3+ independent sources | +15 (cumulative, total +25) |

### JavaScript Implementation

```javascript
// n8n Code Node: Confidence Score
// Input: { factors: { source_reliability, evidence_count, freshness,
//         ai_agreement, completeness, validation_success, independent_sources } }
// Output: { confidence: 0-100, label: string }

function calculateConfidence(factors) {
  const weights = {
    source_reliability: 0.25,
    evidence_count: 0.20,
    freshness: 0.15,
    ai_agreement: 0.20,
    completeness: 0.10,
    validation_success: 0.10
  };
  
  let total = 0;
  let weightSum = 0;
  
  for (const [factor, score] of Object.entries(factors)) {
    if (score !== null && score !== undefined && weights[factor] !== undefined) {
      total += score * weights[factor];
      weightSum += weights[factor];
    }
  }
  
  let confidence = weightSum > 0 ? total / weightSum : 0;
  
  // Independence bonus
  const indSources = factors.independent_sources || 0;
  if (indSources >= 3) confidence += 15;
  else if (indSources >= 2) confidence += 10;
  
  // Clamp to 0-100
  confidence = Math.max(0, Math.min(100, Math.round(confidence)));
  
  // Label
  let label = 'INSUFFICIENT';
  if (confidence >= 80) label = 'HIGH';
  else if (confidence >= 60) label = 'MEDIUM';
  else if (confidence >= 40) label = 'LOW';
  
  return {
    confidence: confidence,
    label: label,
    breakdown: {
      source_reliability: factors.source_reliability,
      evidence_count: factors.evidence_count,
      freshness: factors.freshness,
      ai_agreement: factors.ai_agreement,
      completeness: factors.completeness,
      validation_success: factors.validation_success,
      independent_sources: indSources,
      independence_bonus: indSources >= 3 ? 15 : indSources >= 2 ? 10 : 0
    }
  };
}

const factors = $input.first().json.factors || {};
const result = calculateConfidence(factors);

return [{
  json: {
    confidence: result.confidence,
    label: result.label,
    breakdown: result.breakdown,
    verdict: result.confidence >= 60 ? 'TRUST' : 'REVIEW'
  }
}];
```

---

## 11. Appendix: Integration into n8n

### Workflow Structure

```
[Webhook Trigger]
  → [Code Node: Normalize Domain]
  → [Code Node: Normalize Company Name]
  → [Code Node: Rejectable Domain Filter] ← reject if social/marketplace/etc.
  → [Code Node: Parked Domain Detection]  ← reject if parked
  → [Postgres Node: Check existing companies]
  → [Code Node: Duplicate Detection]      ← compare against DB
  → [Switch Node: Duplicate?]
      ├─ Yes → [Postgres Node: Merge into existing record]
      └─ No  → [Code Node: Initial Qualification]
               → [Switch Node: Qualified?]
                   ├─ PASS → [Postgres Node: Insert company] → Enrichment pipeline
                   ├─ BORDERLINE → [Postgres Node: Insert with flag] → Partial enrich
                   └─ REJECT → [Postgres Node: Log skip] → Discard
```

### Evidence Envelope Integration

All normalization steps feed into the evidence system:

```json
{
  "field": "domain",
  "value": "acme-corp.com",
  "confidence": 100,
  "source": "rule_engine",
  "evidence": "Normalized from https://www.Acme-Corp.com/",
  "source_url": "https://www.Acme-Corp.com/",
  "retrieved_at": "2026-07-12T14:30:00.000Z"
}
```

### Database Schema Additions

```sql
-- Store normalized values for fast duplicate lookup
ALTER TABLE companies ADD COLUMN normalized_domain TEXT;
ALTER TABLE companies ADD COLUMN normalized_name TEXT;

-- Track qualification results
ALTER TABLE companies ADD COLUMN qualification_score INTEGER;
ALTER TABLE companies ADD COLUMN qualification_verdict TEXT; -- PASS/BORDERLINE/REJECT

-- Index for fast duplicate detection
CREATE INDEX idx_companies_norm_domain ON companies(normalized_domain);
CREATE INDEX idx_companies_norm_name ON companies(normalized_name);

-- Qualification log for observability
CREATE TABLE qualification_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID REFERENCES companies(id),
  score INTEGER NOT NULL,
  verdict TEXT NOT NULL,
  breakdown JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### Error Recovery

| Scenario | Behavior |
|----------|----------|
| Domain normalization produces `null` | Log warning, skip company, continue |
| All existing companies filtered (0 candidates returned) | Assume first entry, no duplicate check |
| Phone numbers as company names | Normalization reduces to digits — minimal collision risk |
| Internationalized domain names (IDN) | Convert to Punycode before normalization |
| Empty company name | Reject — no basis for matching |
| Database connection failure | Cache companies locally, retry on next run |

---

*End of Document — Domain Normalization & Duplicate Detection v2.0*
