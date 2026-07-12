# Free Data Enrichment Module

> All enrichment sources used by Jasfo v2 to gather intelligence on target companies without paid APIs. Each source is called on-demand by the AI Planner, parsed in an n8n Code node, and cached in `source_cache` with evidence written to `evidence_store`.

---

## 1. GitHub API

Retrieves public repository data, languages, contributors, and code search results.

| Property | Value |
|----------|-------|
| **Endpoint** | `https://api.github.com` |
| **Auth** | Optional (free GitHub token) |
| **Rate Limit** | 60 req/hr (unauthenticated), 5,000 req/hr (with token) |

### Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /orgs/{org}` | Organization metadata (name, location, website, members) |
| `GET /orgs/{org}/repos` | All public repos with languages, topics, stars |
| `GET /orgs/{org}/members` | Public member list |
| `GET /search/code?q={query}+org:{org}` | Code search within an org |

### Example Call

```
GET https://api.github.com/orgs/acme-corp
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://api.github.com/orgs/{{ $json.orgName }}
  Authentication: None
  Headers:
    Accept: application/vnd.github.v3+json
  (Optional) Headers with token:
    Authorization: token {{ $credentials.githubToken.apiToken }}
```

### Code Node (Post-Process)

```javascript
const orgData = $input.first().json;
return {
  name: orgData.name || orgData.login,
  description: orgData.description,
  location: orgData.location,
  website: orgData.blog,
  publicRepos: orgData.public_repos,
  followers: orgData.followers,
  createdAt: orgData.created_at,
  avatarUrl: orgData.avatar_url
};
```

---

## 2. WHOIS / RDAP

Confirms domain age, registrant details, and legitimacy — critical for early-stage companies with short track records.

| Property | Value |
|----------|-------|
| **Endpoint** | `https://rdap.org/domain/{domain}` |
| **Auth** | None |
| **Rate Limit** | Generous (no documented limit) |

### Example Call

```
GET https://rdap.org/domain/acme.com
```

### Response Data

```json
{
  "events": [
    { "eventAction": "registration", "eventDate": "2010-03-15T..." },
    { "eventAction": "expiration", "eventDate": "2030-03-15T..." }
  ],
  "entities": [{ "vcardArray": ["vcard", [["fn", {}, "text", "Acme Inc"]]] }],
  "status": ["client transfer prohibited"]
}
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://rdap.org/domain/{{ $json.domain }}
  Authentication: None
```

### Code Node (Post-Process)

```javascript
const data = $input.first().json;
const events = {};
for (const e of data.events || []) {
  events[e.eventAction] = e.eventDate;
}
const entity = (data.entities || [])[0];
const name = entity?.vcardArray?.[1]?.find(v => v[0] === 'fn')?.[3] || null;
return {
  domainAgeDays: events.registration
    ? Math.floor((Date.now() - new Date(events.registration)) / 86400000)
    : null,
  registrantName: name,
  createdDate: events.registration,
  expiryDate: events.expiration,
  registrar: entity?.remarks?.[0]?.description?.[0] || null,
  status: data.status || []
};
```

---

## 3. crt.sh (Certificate Transparency)

Discovers subdomains by querying SSL certificate logs. Essential for finding hidden engineering blogs, career portals, and product surfaces.

| Property | Value |
|----------|-------|
| **Endpoint** | `https://crt.sh` |
| **Auth** | None |
| **Rate Limit** | 10 req/min (be reasonable) |

### Example Call

```
GET https://crt.sh/?q=example.com&output=json
```

### Response Data

```json
[
  {
    "issuer_ca_id": 1234,
    "name_value": "*.example.com\nexample.com\nengineering.example.com",
    "not_before": "2024-01-01T00:00:00",
    "not_after": "2025-01-01T00:00:00"
  }
]
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://crt.sh/?q={{ $json.domain }}&output=json
  Authentication: None
  Headers:
    Accept: application/json
```

### Code Node (Post-Process)

```javascript
const items = $input.first().json;
const subdomains = new Set();
for (const cert of items) {
  for (const name of (cert.name_value || '').split('\n')) {
    const trimmed = name.trim();
    if (trimmed.endsWith('.' + domain) || trimmed === domain) {
      subdomains.add(trimmed);
    }
  }
}
return {
  subdomains: [...subdomains].sort(),
  totalSubdomains: subdomains.size,
  sampleSubdomains: [...subdomains].slice(0, 20)
};
```

---

## 4. Google News RSS

Tracks recent news, funding announcements, product launches, and hiring news for any company — all without a Google News API key.

| Property | Value |
|----------|-------|
| **Endpoint** | `https://news.google.com/rss/search` |
| **Auth** | None |
| **Rate Limit** | 10 req/min (unofficial) |

### Example Call

```
GET https://news.google.com/rss/search?q=acme+corp&hl=en-US&gl=US&ceid=US:en
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://news.google.com/rss/search?q={{ $json.companyName }}&hl=en-US&gl=US&ceid=US:en
  Authentication: None
  Headers:
    Accept: application/rss+xml
```

### Code Node (Parse RSS XML)

```javascript
const xml = $input.first().json;
const items = [];
// Simple RSS item extraction
const itemRegex = /<item>([\s\S]*?)<\/item>/g;
const titleRegex = /<title>(.*?)<\/title>/;
const linkRegex = /<link>(.*?)<\/link>/;
const pubDateRegex = /<pubDate>(.*?)<\/pubDate>/;
const sourceRegex = /<source>(.*?)<\/source>/;

let match;
while ((match = itemRegex.exec(xml)) !== null) {
  const item = match[1];
  const title = (titleRegex.exec(item) || [])[1] || '';
  const link = (linkRegex.exec(item) || [])[1] || '';
  const pubDate = (pubDateRegex.exec(item) || [])[1] || '';
  const source = (sourceRegex.exec(item) || [])[1] || '';
  items.push({ title, link, pubDate, source });
}
return {
  articles: items.slice(0, 20),
  totalArticles: items.length,
  keyTopics: extractKeywords(items.map(i => i.title))
};
```

---

## 5. robots.txt

Returns the crawling rules for any domain. Reveals hidden development subdomains, staging environments, and sitemap locations.

| Property | Value |
|----------|-------|
| **URL** | `https://{domain}/robots.txt` |
| **Auth** | None |
| **Rate Limit** | None (your own request) |

### Example Call

```
GET https://example.com/robots.txt
```

### Response (Example)

```
User-agent: *
Disallow: /admin/
Disallow: /internal/
Allow: /blog/
Sitemap: https://example.com/sitemap.xml
Sitemap: https://example.com/sitemap-2.xml
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://{{ $json.domain }}/robots.txt
  Authentication: None
  Options:
    Timeout: 10000
    Retry: 1
  Conditional: Continue on error (404 is common)
```

### Code Node (Post-Process)

```javascript
const text = $input.first().json;
const sitemaps = [];
const disallowed = [];
for (const line of (text || '').split('\n')) {
  const sitemapMatch = line.match(/^Sitemap:\s*(.+)/i);
  if (sitemapMatch) sitemaps.push(sitemapMatch[1].trim());
  const disallowMatch = line.match(/^Disallow:\s*(.+)/i);
  if (disallowMatch && disallowMatch[1].trim() !== '') disallowed.push(disallowMatch[1].trim());
}
return {
  hasRobotsTxt: true,
  sitemapUrls: sitemaps,
  disallowedPaths: disallowed,
  crawlDelay: (text.match(/Crawl-delay:\s*(\d+)/i) || [])[1] || null
};
```

---

## 6. sitemap.xml

Finds every publicly listed page on a target site. URLs often reveal technology stack, team pages, and product surfaces.

| Property | Value |
|----------|-------|
| **URL** | `https://{domain}/sitemap.xml` (or from robots.txt) |
| **Auth** | None |
| **Rate Limit** | None (your own request) |

### Example Call

```
GET https://example.com/sitemap.xml
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://{{ $json.domain }}/sitemap.xml
  Authentication: None
  Options:
    Timeout: 15000
    Retry: 1
```

### Code Node (Parse XML Sitemap)

```javascript
const xml = $input.first().json;
const urls = [];
const locRegex = /<loc>(.*?)<\/loc>/g;
let match;
while ((match = locRegex.exec(xml)) !== null) {
  urls.push(match[1]);
}
return {
  totalPages: urls.length,
  pages: urls.slice(0, 100),
  pageCategories: urls.some(u => u.includes('/blog/')),
  hasCareerPages: urls.some(u => u.includes('/career') || u.includes('/jobs')),
  hasEngineeringPages: urls.some(u => u.includes('/engineering') || u.includes('/tech'))
};
```

---

## 7. Internet Archive (Wayback Machine)

Checks historical snapshots of a domain. Useful for verifying past branding, old leadership pages, and company evolution.

| Property | Value |
|----------|-------|
| **Endpoint** | `https://archive.org/wayback/available` |
| **Auth** | None |
| **Rate Limit** | 10 req/sec (generous) |

### Example Call

```
GET https://archive.org/wayback/available?url=example.com
```

### Response Data

```json
{
  "archived_snapshots": {
    "closest": {
      "available": true,
      "url": "http://web.archive.org/web/20200101000000/example.com",
      "timestamp": "20200101000000",
      "status": "200"
    }
  }
}
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://archive.org/wayback/available?url={{ $json.domain }}
  Authentication: None
```

### Code Node (Post-Process)

```javascript
const data = $input.first().json;
const snap = data?.archived_snapshots?.closest;
return {
  hasSnapshot: snap?.available || false,
  oldestSnapshotUrl: snap?.url || null,
  oldestSnapshotDate: snap?.timestamp || null,
  snapshotStatus: snap?.status || null,
  // Calculate age of oldest snapshot
  domainAgeYears: snap?.timestamp
    ? Math.floor((Date.now() - new Date(
        snap.timestamp.substring(0, 4) + '-' +
        snap.timestamp.substring(4, 6) + '-' +
        snap.timestamp.substring(6, 8)
      )) / 31536000000)
    : null
};
```

---

## 8. OpenStreetMap (Nominatim)

Geocodes company addresses for location verification and regional intelligence.

| Property | Value |
|----------|-------|
| **Endpoint** | `https://nominatim.openstreetmap.org/search` |
| **Auth** | None |
| **Rate Limit** | 2 req/sec (strict — you must throttle) |

### Example Call

```
GET https://nominatim.openstreetmap.org/search?q=acme+corp+san+francisco&format=json&limit=3
```

**Important:** You must set a `User-Agent` header identifying your application per Nominatim's usage policy.

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://nominatim.openstreetmap.org/search
  Authentication: None
  Query Parameters:
    q: {{ $json.query }}
    format: json
    limit: 3
  Headers:
    User-Agent: Jasfo/2.0 (enrichment-module)
  Options:
    Timeout: 5000
```

### Code Node (Post-Process)

```javascript
const results = $input.first().json;
if (!results || results.length === 0) return { found: false };
const best = results[0];
return {
  found: true,
  displayName: best.display_name,
  lat: best.lat,
  lon: best.lon,
  type: best.type,
  importance: best.importance,
  boundingBox: best.boundingbox,
  osmType: best.osm_type,
  osmId: best.osm_id
};
```

### Throttling in n8n

Add a **Wait node** (1 second) before the HTTP Request to stay within the 2 req/sec limit. For batch jobs, use an **n8n Loop** with a `Wait(0.5s)` between iterations.

---

## 9. HackerNews Search (Algolia)

Taps into the HackerNews community for tech community sentiment, hiring posts, Show HN launches, and founder mentions.

| Property | Value |
|----------|-------|
| **Endpoint** | `https://hn.algolia.com/api/v1/search` |
| **Auth** | None |
| **Rate Limit** | 10 req/min (unofficial, generous) |

### Example Call

```
GET https://hn.algolia.com/api/v1/search?query=acme&tags=story&hitsPerPage=20
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://hn.algolia.com/api/v1/search
  Authentication: None
  Query Parameters:
    query: {{ $json.companyName }}
    tags: story,comment
    hitsPerPage: 20
    restrictSearchableAttributes: title,comment_text
```

### Code Node (Post-Process)

```javascript
const data = $input.first().json;
const hits = data.hits || [];
return {
  totalMentions: data.nbHits || 0,
  mentions: hits.map(h => ({
    title: h.title,
    url: h.url || h.story_url,
    points: h.points,
    numComments: h.num_comments,
    author: h.author,
    createdAt: h.created_at,
    hnUrl: `https://news.ycombinator.com/item?id=${h.objectID}`,
    type: h.tags?.includes('job') ? 'hiring' : 'mention'
  })),
  summary: {
    hiringPosts: hits.filter(h => h.tags?.includes('job')).length,
    topMention: hits.sort((a, b) => (b.points || 0) - (a.points || 0))[0] || null,
    recentMentions: hits.filter(h =>
      Date.now() - new Date(h.created_at).getTime() < 86400000 * 90
    ).length
  }
};
```

---

## 10. Common Crawl Index

Accesses web crawl data from the Common Crawl open corpus. Free and powerful but more complex to query directly.

| Property | Value |
|----------|-------|
| **Endpoint** | `https://index.commoncrawl.org/CC-MAIN-YYYY-WW/` (varies by index) |
| **Auth** | None |
| **Rate Limit** | No documented limit (be reasonable) |

### How It Works

Common Crawl releases monthly indexes (e.g. `CC-MAIN-2025-18`). You first query the index for URLs matching your domain, then retrieve the page text from AWS S3.

### Step 1: Find the Latest Index

```
GET https://index.commoncrawl.org/collinfo.json
```

Returns JSON array of available index IDs. Pick the latest `"id"`.

### Step 2: Query the Index

```
GET https://index.commoncrawl.org/CC-MAIN-2025-18/index?url=example.com&output=json
```

### n8n Configuration

```
HTTP Request Node:
  Method: GET
  URL: https://index.commoncrawl.org/{{ $json.indexId }}/index
  Authentication: None
  Query Parameters:
    url: {{ $json.domain }}
    output: json
    limit: 10
```

### Code Node (Post-Process)

```javascript
const items = $input.first().json;
const records = Array.isArray(items) ? items : [items];
return {
  totalPages: records.length,
  pages: records.map(r => ({
    url: r.url,
    timestamp: r.timestamp,
    status: r.status,
    mimeType: r.mime,
    s3Location: `s3://commoncrawl/${r.filename}`,
    offset: r.offset,
    length: r.length
  })),
  isIndexed: records.length > 0
};
```

### Step 3: Retrieve Page Content (Optional)

Page content is stored on S3 at the path specified in `r.filename`, using `r.offset` and `r.length` to extract the specific record. This is best done in a separate Code node using signed S3 reads.

---

## General n8n Integration Patterns

### Cache Table Schema (`source_cache`)

```sql
CREATE TABLE source_cache (
  id INT AUTO_INCREMENT PRIMARY KEY,
  domain VARCHAR(255) NOT NULL,
  source_name VARCHAR(100) NOT NULL,
  cache_key VARCHAR(500) NOT NULL,
  response_data JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  INDEX idx_domain_source (domain, source_name),
  INDEX idx_cache_key (cache_key)
);
```

### Evidence Store Schema (`evidence_store`)

```sql
CREATE TABLE evidence_store (
  id INT AUTO_INCREMENT PRIMARY KEY,
  enrichment_id INT NOT NULL,
  source_name VARCHAR(100) NOT NULL,
  evidence_type VARCHAR(50) NOT NULL,
  evidence_value TEXT,
  evidence_url TEXT,
  confidence DECIMAL(3,2) DEFAULT 0.80,
  collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (enrichment_id) REFERENCES enrichments(id)
);
```

### Example n8n Workflow Structure

```
[Webhook Trigger]
  → [Switch: Determine enrichment type from plan]
    → [GitHub API Sub-workflow]
    → [Whois Sub-workflow]
    → [crt.sh Sub-workflow]
    → [Google News Sub-workflow]
    → [robots.txt + sitemap Sub-workflow]
    → [Archive.org Sub-workflow]
    → [Nominatim Sub-workflow]
    → [HackerNews Sub-workflow]
    → [Common Crawl Sub-workflow]
  → [Merge: Combine all results]
  → [Code Node: Build enrichment JSON]
  → [Postgres Node: Write to source_cache]
  → [Postgres Node: Write to evidence_store]
  → [Respond to Webhook]
```

### Enrichment Router Code Node

```javascript
const llmPlan = $input.first().json.llmPlan;
const availableSources = llmPlan.sources || []; // e.g. ["github", "crt.sh", "news"]

const routing = [];
for (const source of availableSources) {
  switch (source) {
    case 'github': routing.push({ node: 'GitHub API', params: { orgName: llmPlan.orgName } }); break;
    case 'crt.sh': routing.push({ node: 'crt.sh', params: { domain: llmPlan.domain } }); break;
    case 'whois': routing.push({ node: 'RDAP Whois', params: { domain: llmPlan.domain } }); break;
    case 'news': routing.push({ node: 'Google News', params: { companyName: llmPlan.companyName } }); break;
    case 'robots_txt': routing.push({ node: 'robots.txt', params: { domain: llmPlan.domain } }); break;
    case 'sitemap': routing.push({ node: 'sitemap.xml', params: { domain: llmPlan.domain } }); break;
    case 'wayback': routing.push({ node: 'Internet Archive', params: { domain: llmPlan.domain } }); break;
    case 'geocode': routing.push({ node: 'Nominatim', params: { query: `${llmPlan.companyName} ${llmPlan.city}` } }); break;
    case 'hackernews': routing.push({ node: 'HN Search', params: { companyName: llmPlan.companyName } }); break;
    case 'commoncrawl': routing.push({ node: 'Common Crawl', params: { domain: llmPlan.domain } }); break;
  }
}

return { routing };
```

### Cost Comparison

| Source | API Key Needed | Daily Cost (10K queries) |
|--------|---------------|---------------------------|
| GitHub API | Optional (free) | $0 |
| RDAP / Whois | No | $0 |
| crt.sh | No | $0 |
| Google News RSS | No | $0 |
| robots.txt | No | $0 |
| sitemap.xml | No | $0 |
| Internet Archive | No | $0 |
| OpenStreetMap | No | $0 |
| HackerNews | No | $0 |
| Common Crawl | No | $0 |
| **Total** | **$0** | **$0** |

### Automation Rules

1. **AI Planner** decides which sources to call based on the enrichment goal
2. **Parallel execution**: Independent sources (GitHub, crt.sh, WHOIS) should run in parallel branches if the target domain is the same
3. **Cache hit**: Always check `source_cache` first (cache TTL = 24 hours for most sources, 7 days for WHOIS)
4. **Error tolerance**: A single source failing should not block the full enrichment; use n8n's "Continue on Error" option
5. **Evidence logging**: Every successful API call writes to `evidence_store` with the source name, collected data, and a confidence score
