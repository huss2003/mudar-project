# Rule Engine

The Rule Engine runs **BEFORE** any AI extraction. It uses regex and parsers to extract deterministic data from raw website content. This eliminates hallucinations for well-structured data — rules catch what they can, and AI only fills gaps.

## Pipeline

```
Raw HTML → Parse → Extract → Validate → Store in rule_engine_results
```

| Stage | Description |
|-------|-------------|
| **Parse** | Receive raw HTML and extracted markdown/text from the scraper |
| **Extract** | Run all rule-based extractors in parallel (email, phone, social, schema, meta, tech stack, employee count) |
| **Validate** | Filter false positives, normalize formats, deduplicate |
| **Store** | Write structured results into `rule_engine_results` with confidence scores |

## Performance Characteristics

| Metric | Value |
|--------|-------|
| Runtime per company | ~500ms |
| API calls | Zero |
| Cost | Zero |
| Extraction coverage | 40–60% of all fields |
| AI fallback | Fills remaining gaps |

---

## 1. Email Extraction

Standard regex plus domain denylisting and role-based classification.

```javascript
// n8n Code node — Email Extractor
const html = $input.first().json.raw_html || '';
const text = $input.first().json.markdown || '';
const url = $input.first().json.url || '';

const emailRegex = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g;
const rawEmails = text.match(emailRegex) || [];
const emails = [...new Set(rawEmails)];

const denylist = [
  'example.com', 'domain.com', 'yourdomain.com', 'domain.net',
  'yourcompany.com', 'test.com', 'sample.com', 'email.com',
  'acme.com', 'company.com', 'yourname.com', '@yours',
  'mysite.com', 'website.com', 'yoursite.com', '@yourdomain'
];

const filtered = emails.filter(e => {
  const domain = e.split('@')[1].toLowerCase();
  for (const block of denylist) {
    if (domain === block || domain.endsWith('.' + block)) return false;
  }
  if (e.endsWith('.png') || e.endsWith('.jpg') ||
      e.endsWith('.jpeg') || e.endsWith('.gif') ||
      e.endsWith('.svg') || e.endsWith('.webp')) return false;
  return true;
});

const classifyEmail = (email) => {
  const local = email.split('@')[0].toLowerCase();
  const domain = email.split('@')[1].toLowerCase();
  if (/^(hello|hi|hey|contact|info|support|help|team|office|mail|enquire)/.test(local)) return 'general';
  if (/^(sales|sell|billing|accounts|pay)/.test(local)) return 'sales';
  if (/^(jobs|careers|hr|hiring|recruit|talent|people)/.test(local)) return 'careers';
  if (/^(press|media|pr|news|public|relations)/.test(local)) return 'press';
  if (/^(support|help|service|cs|care|customer)/.test(local)) return 'support';
  if (/^(admin|webmaster|postmaster|hostmaster|abuse|security|noc)/.test(local)) return 'admin';
  if (/^(legal|compliance|privacy|dpo|gdpr)/.test(local)) return 'legal';
  if (/^(founder|ceo|cto|boss|director|partner)/.test(local)) return 'executive';
  return 'unknown';
};

const result = {
  extractor: 'email',
  items: filtered.map(e => ({
    value: e,
    confidence: 95,
    source: 'website',
    evidence: e,
    source_url: url,
    category: classifyEmail(e)
  })),
  count: filtered.length
};

return [{ json: result }];
```

---

## 2. Phone Number Extraction

Patterns for international, US, and common variations. Results are normalized to E.164 where possible.

```javascript
// n8n Code node — Phone Extractor
const text = $input.first().json.markdown || '';
const html = $input.first().json.raw_html || '';
const combined = text + ' ' + html.replace(/<[^>]+>/g, ' ');

const phonePatterns = [
  // International — +1 555 123 4567 or +44 20 7946 0958
  /\+\d{1,3}[\s\-.]?\(?\d{1,4}\)?[\s\-.]?\d{1,4}[\s\-.]?\d{1,4}[\s\-.]?\d{1,4}/g,
  // US — (555) 123-4567 or 555-123-4567
  /\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}/g,
  // UK — 020 7946 0958 or 01632 960 001
  /0\d{2,4}[\s\-.]?\d{3,4}[\s\-.]?\d{3,4}/g,
  // Australia — 02 5551 2345 or +61 2 5551 2345
  /0[23478]\d{1}[\s\-.]?\d{4}[\s\-.]?\d{4}/g,
  // Germany — 030 12345-67 or +49 30 12345-67
  /0\d{2,4}[\s\-.]?\d{2,8}[\s\-.]?\d{1,4}/g
];

const rawPhones = [];
for (const pattern of phonePatterns) {
  const matches = combined.match(pattern) || [];
  rawPhones.push(...matches);
}

const normalizePhone = (phone) => {
  let p = phone.trim();
  // Strip non-digit except leading +
  const hasPlus = p.startsWith('+');
  p = p.replace(/[^\d]/g, '');
  if (hasPlus) p = '+' + p;
  return p;
};

const phones = [...new Set(rawPhones.map(normalizePhone))].filter(p => {
  const digits = p.replace(/\D/g, '');
  return digits.length >= 7 && digits.length <= 15;
});

const result = {
  extractor: 'phone',
  items: phones.map(p => ({
    value: p,
    confidence: 90,
    source: 'website',
    evidence: p,
    source_url: $input.first().json.url,
    normalized: p.startsWith('+') ? p : (p.length === 10 ? '+1' + p : p)
  })),
  count: phones.length
};

return [{ json: result }];
```

---

## 3. Social Link Detection

Detect LinkedIn, Twitter/X, GitHub, Crunchbase, and AngelList links from `href` attributes and visible text.

```javascript
// n8n Code node — Social Link Extractor
const html = $input.first().json.raw_html || '';
const url = $input.first().json.url || '';

const socialPatterns = {
  linkedin: /https?:\/\/(?:www\.)?linkedin\.com\/(?:company|in|school)\/[A-Za-z0-9_-]+/gi,
  twitter: /https?:\/\/(?:www\.)?(?:twitter\.com|x\.com)\/[A-Za-z0-9_]+/gi,
  github: /https?:\/\/(?:www\.)?github\.com\/[A-Za-z0-9_.-]+/gi,
  crunchbase: /https?:\/\/(?:www\.)?crunchbase\.com\/(?:organization|company|person)\/[A-Za-z0-9_-]+/gi,
  angelist: /https?:\/\/(?:www\.)?(?:angel\.co|angellist\.com)\/[A-Za-z0-9_-]+/gi,
  youtube: /https?:\/\/(?:www\.)?youtube\.com\/(?:@|channel\/|c\/|user\/)[A-Za-z0-9_-]+/gi,
  facebook: /https?:\/\/(?:www\.)?facebook\.com\/[A-Za-z0-9.]+/gi,
  instagram: /https?:\/\/(?:www\.)?instagram\.com\/[A-Za-z0-9_.]+/gi,
  tiktok: /https?:\/\/(?:www\.)?tiktok\.com\/@[A-Za-z0-9_.]+/gi
};

const allLinks = html.match(/<a[^>]*href="([^"]*)"[^>]*>/gi) || [];
const extracted = {};

for (const [platform, pattern] of Object.entries(socialPatterns)) {
  const matches = html.match(pattern) || [];
  // Also scan href attributes
  for (const link of allLinks) {
    const href = link.match(/href="([^"]*)"/i);
    if (href) {
      const m = href[1].match(pattern);
      if (m) matches.push(m[0]);
    }
  }
  if (matches.length > 0) {
    extracted[platform] = [...new Set(matches.map(u => u.replace(/\/$/, '')))];
  }
}

const result = {
  extractor: 'social',
  value: extracted,
  confidence: 92,
  source: 'website',
  evidence: JSON.stringify(extracted),
  source_url: url,
  platforms_found: Object.keys(extracted).length
};

return [{ json: result }];
```

---

## 4. Schema.org / JSON-LD Parser

Extract structured data from JSON-LD blocks embedded in the page.

```javascript
// n8n Code node — JSON-LD Extractor
const html = $input.first().json.raw_html || '';
const url = $input.first().json.url || '';

const scripts = html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/gi) || [];
const schema = {
  name: null,
  description: null,
  url: null,
  logo: null,
  sameAs: [],
  address: null,
  telephone: null,
  employeeCount: null,
  foundingDate: null,
  type: null,
  raw: []
};

for (const script of scripts) {
  const jsonMatch = script.replace(/<script[^>]*>/, '').replace(/<\/script>/, '');
  try {
    const data = JSON.parse(jsonMatch.trim());
    schema.raw.push(data);

    // Handle @graph (multiple entities)
    const items = data['@graph'] || [data];
    for (const item of items) {
      const type = (item['@type'] || '').toLowerCase();
      if (!schema.type && type) schema.type = item['@type'];

      if (!schema.name && item.name) schema.name = item.name;
      if (!schema.description && item.description) schema.description = item.description;
      if (!schema.url && item.url) schema.url = item.url;
      if (!schema.logo && item.logo) schema.logo = typeof item.logo === 'string' ? item.logo : (item.logo?.url || null);

      if (item.sameAs) {
        const links = Array.isArray(item.sameAs) ? item.sameAs : [item.sameAs];
        schema.sameAs.push(...links);
      }

      if (!schema.telephone && item.telephone) schema.telephone = item.telephone;
      if (!schema.address && item.address) schema.address = typeof item.address === 'string' ? item.address : JSON.stringify(item.address);
      if (!schema.employeeCount && item.numberOfEmployees) schema.employeeCount = item.numberOfEmployees;
      if (!schema.foundingDate && item.foundingDate) schema.foundingDate = item.foundingDate;
      if (!schema.foundingDate && item.foundingDate) schema.foundingDate = item.foundingDate;
    }
  } catch (e) {
    // Skip invalid JSON blocks
  }
}

schema.sameAs = [...new Set(schema.sameAs)];

const result = {
  extractor: 'schema',
  value: schema,
  confidence: schema.name ? 90 : 0,
  source: 'json-ld',
  evidence: JSON.stringify(schema.raw.length > 0 ? schema.raw[0] : {}),
  source_url: url,
  blocks_found: scripts.length,
  blocks_parsed: schema.raw.length
};

return [{ json: result }];
```

---

## 5. OpenGraph & Meta Tag Extraction

Extract OpenGraph tags, standard meta tags, and Twitter Card metadata.

```javascript
// n8n Code node — Meta Tag Extractor
const html = $input.first().json.raw_html || '';
const url = $input.first().json.url || '';

const extractMeta = (property, attr = 'property') => {
  // Try property="og:..." first, then name="..." pattern
  const regex1 = new RegExp(`<meta[^>]*${attr}="([^"]*${property}[^"]*)"[^>]*content="([^"]*)"`, 'i');
  const regex2 = new RegExp(`<meta[^>]*content="([^"]*)"[^>]*${attr}="([^"]*${property}[^"]*)"`, 'i');
  const m1 = html.match(regex1);
  const m2 = html.match(regex2);
  if (m1) return m1[1].includes(property) ? m1[2] : null;
  if (m2) return m2[2].includes(property) ? m2[1] : null;
  return null;
};

const meta = {
  // OpenGraph
  og_title: extractMeta('og:title') || null,
  og_description: extractMeta('og:description') || null,
  og_image: extractMeta('og:image') || null,
  og_url: extractMeta('og:url') || null,
  og_type: extractMeta('og:type') || null,
  og_site_name: extractMeta('og:site_name') || null,

  // Standard meta
  meta_title: (html.match(/<title>([^<]*)<\/title>/i) || [])[1] || null,
  meta_description: extractMeta('description', 'name') || null,
  meta_keywords: extractMeta('keywords', 'name') || null,
  meta_author: extractMeta('author', 'name') || null,
  meta_robots: extractMeta('robots', 'name') || null,

  // Twitter Card
  twitter_card: extractMeta('twitter:card', 'name') || null,
  twitter_site: extractMeta('twitter:site', 'name') || null,
  twitter_title: extractMeta('twitter:title', 'name') || null,
  twitter_description: extractMeta('twitter:description', 'name') || null,
  twitter_image: extractMeta('twitter:image', 'name') || null,

  // Microsoft / SEO
  canonical: (html.match(/<link[^>]*rel="canonical"[^>]*href="([^"]*)"/i) || [])[1] || null,
  favicon: (html.match(/<link[^>]*rel="icon"[^>]*href="([^"]*)"/i) || [])[1] || null
};

const result = {
  extractor: 'meta',
  value: meta,
  confidence: meta.og_title || meta.meta_title ? 88 : 0,
  source: 'website',
  evidence: JSON.stringify(meta),
  source_url: url,
  fields_found: Object.values(meta).filter(Boolean).length
};

return [{ json: result }];
```

---

## 6. Technology Stack Detection

Identify frameworks, CMS, analytics, CDNs, and cloud platforms from HTML patterns, script sources, and response headers.

```javascript
// n8n Code node — Technology Stack Detector
const html = $input.first().json.raw_html || '';
const headers = $input.first().json.headers || {};
const text = $input.first().json.markdown || '';

const techPatterns = {
  // Frontend frameworks
  'React': /react(?:\.development)?\.(?:min\.)?js|__NEXT_DATA__|reactRoot|createRoot|ReactDOM|react\.js/,
  'Next.js': /__NEXT_DATA__|next\.config|_next\/static|Next\.js|next\.config\.js/,
  'Vue.js': /vue(?:\.min)?\.js|__VUE__|createApp|Vue\.component|nuxt/,
  'Nuxt.js': /nuxt\.js|_nuxt\/|__NUXT__/,
  'Angular': /angular(?:\.min)?\.js|ng-app|ng-controller|ng-repeat|ng-view|angular\.io/,
  'Svelte': /svelte|__SVELTE__/,
  'Gatsby': /gatsby/,
  'Astro': /astro/,
  'Remix': /remix/,
  'Preact': /preact/,

  // CMS
  'WordPress': /wp-content|wp-includes|wordpress|wp-json|wp-admin|wp-login/,
  'Shopify': /shopify\.com|cdn\.shopify|myshopify|Shopify\.sdk/,
  'Wix': /wix\.com|wixstatic|Wix\.js/,
  'Squarespace': /squarespace|static1\.squarespace/,
  'Webflow': /webflow/,
  'Drupal': /drupal|sites\/default\/files/,
  'Joomla': /joomla|com_content/,
  'Magento': /magento|mage\/|Mage_Core/,
  'Ghost': /ghost/,
  'Contentful': /contentful/,

  // Styling
  'Tailwind CSS': /tailwindcss|tailwind/,
  'Bootstrap': /bootstrap(?:\.min)?\.css|bootstrap(?:\.bundle)?(?:\.min)?\.js/,
  'Material UI': /mui|material-ui|@material/,
  'Styled Components': /styled-components|styled\./,

  // Analytics & Marketing
  'Google Analytics': /google-analytics|gtag|ga\(['"]create|analytics\.js|googletagmanager/,
  'Google Tag Manager': /googletagmanager\.com\/gtm\.js|GTM-/,
  'Facebook Pixel': /fbq\(|connect\.facebook\.net\/en_US\/fbevents/,
  'Hotjar': /hotjar|_hjSettings/,
  'Intercom': /intercom/,
  'HubSpot': /hs-script|hubspot|Hutk/,
  'Mixpanel': /mixpanel/,
  'Segment': /segment\.com|analytics\.js/,
  'Amplitude': /amplitude/,
  'FullStory': /fullstory/,
  'Heap': /heap\.app/,
  'Clarity': /clarity\.ms|clarity/,
  'PostHog': /posthog/,

  // CDN & Infrastructure
  'Cloudflare': /cloudflare|cf-ray|cache-cf|__cfduid|cdn-cgi/,
  'AWS CloudFront': /cloudfront\.net/,
  'Akamai': /akamai|akamaiedge/,
  'Fastly': /fastly/,
  'Vercel': /vercel|now\.sh/,
  'Netlify': /netlify/,
  'GitHub Pages': /github\.io/,
  'Heroku': /heroku/,
  'DigitalOcean': /digitalocean/,

  // Payment
  'Stripe': /stripe\.js|stripe\.com|pk_live_|sk_live_/,
  'PayPal': /paypal|paypalobjects/,
  'Braintree': /braintree/,
  'Square': /square\.js|squareup/,

  // Cloud & Backend
  'AWS': /aws|amazonaws\.com|AWS\.|aws-/,
  'Google Cloud': /googleapis|gcloud|cloud\.google/,
  'Azure': /azure|windows\.net|microsoft\.com/,
  'Firebase': /firebase|firestore|firebaseio/,
  'Supabase': /supabase/,
  'Algolia': /algolia/,
  'Elasticsearch': /elastic/,

  // Other
  'jQuery': /jquery(?:\.min)?\.js/,
  'jQuery UI': /jquery-ui/,
  'Lodash': /lodash/,
  'D3.js': /d3\.js|d3\.min/,
  'GSAP': /gsap|TweenMax|TimelineMax/,
  'Three.js': /three\.js|WebGL/,
  'Chart.js': /chart\.js/,
  'Sentry': /sentry|raven\.js/,
  'New Relic': /newrelic|nr-agent/,
  'Datadog': /datadog|dd-trace/,
  'Cookiebot': /cookiebot/,
  'OneTrust': /onetrust|optanon/,
  'Recaptcha': /recaptcha|google\.com\/recaptcha/,
  'Mapbox': /mapbox/,
  'Google Maps': /maps\.googleapis|google\.com\/maps/,
  'Typekit': /typekit/,
  'Google Fonts': /fonts\.googleapis/,
  'Font Awesome': /font-awesome|fontawesome/,
  'Socket.io': /socket\.io/,
  'Pusher': /pusher/,
  'Auth0': /auth0/,
  'Clerk': /clerk/,
  'Torus': /torus/,
  'LangChain': /langchain/,
  'OpenAI': /openai/,
  'Anthropic': /anthropic/
};

const detected = [];
for (const [tech, pattern] of Object.entries(techPatterns)) {
  if (pattern.test(html) || pattern.test(text)) {
    detected.push(tech);
  }
}

// Deduplicate and sort
const unique = [...new Set(detected)].sort();

const result = {
  extractor: 'technologies',
  value: unique,
  confidence: 85,
  source: 'website',
  evidence: unique.join(', '),
  source_url: $input.first().json.url,
  count: unique.length,
  categories: {
    frontend: unique.filter(t => ['React','Vue.js','Angular','Svelte','Preact','Next.js','Nuxt.js','Gatsby','Remix','Astro'].includes(t)),
    cms: unique.filter(t => ['WordPress','Shopify','Wix','Squarespace','Webflow','Drupal','Joomla','Magento','Ghost'].includes(t)),
    analytics: unique.filter(t => ['Google Analytics','Google Tag Manager','Facebook Pixel','Hotjar','Intercom','HubSpot','Mixpanel','Segment','Amplitude','FullStory','Heap','Clarity','PostHog'].includes(t)),
    infrastructure: unique.filter(t => ['Cloudflare','AWS CloudFront','Akamai','Fastly','Vercel','Netlify','GitHub Pages','Heroku','DigitalOcean'].includes(t)),
    payment: unique.filter(t => ['Stripe','PayPal','Braintree','Square'].includes(t)),
    cloud: unique.filter(t => ['AWS','Google Cloud','Azure','Firebase','Supabase'].includes(t))
  }
};

return [{ json: result }];
```

---

## 7. Employee Count Estimation

Estimates company size from multiple signals: careers page presence, team page mentions, LinkedIn meta, and visible employee count strings.

```javascript
// n8n Code node — Employee Count Estimator
const html = $input.first().json.raw_html || '';
const text = $input.first().json.markdown || '';
const links = html.match(/<a[^>]*href="([^"]*)"[^>]*>/gi) || [];

const signals = {
  hasCareersPage: false,
  hasTeamPage: false,
  linkedinMeta: null,
  explicitCount: null,
  teamMentions: [],
  totalScore: 0
};

// Signal 1: Careers page link
for (const link of links) {
  const href = (link.match(/href="([^"]*)"/i) || [])[1] || '';
  const lower = href.toLowerCase();
  if (/career|jobs|join-us|work-with-us|hiring|employment|opportunities/.test(lower)) {
    signals.hasCareersPage = true;
    signals.totalScore += 30;
  }
}

// Signal 2: Team page link
for (const link of links) {
  const href = (link.match(/href="([^"]*)"/i) || [])[1] || '';
  const lower = href.toLowerCase();
  if (/\/team|\/about#team|our-team|meet-the-team|leadership|people\b/.test(lower)) {
    signals.hasTeamPage = true;
    signals.totalScore += 15;
    signals.teamMentions.push(href);
  }
}

// Signal 3: LinkedIn company size in meta
const liSizeMatch = html.match(/<meta[^>]*property="linkedin:employee_count"[^>]*content="(\d+)"/i);
if (liSizeMatch) {
  signals.linkedinMeta = parseInt(liSizeMatch[1]);
  signals.totalScore += 20;
}

// Signal 4: Explicit employee count in text
const countPatterns = [
  /(\d+[,\d]*)\s*(?:employees?|team members?|people|staff|workers?|full-time)/gi,
  /(?:employees?|team members?|people|staff)\s*(?:of|:)?\s*(\d+[,\d]*)/gi,
  /(?:over|more than|~|approx|approximately|about|~)\s*(\d+[,\d]*)\s*(?:employees?|people|staff)/gi,
  /(\d+[,\d]*)\s*(?:-\s*|–\s*)?\s*(\d+[,\d]*)?\s*(?:employees?|people)/gi
];

for (const pattern of countPatterns) {
  const matches = text.matchAll(pattern);
  for (const m of matches) {
    const num = parseInt(m[1].replace(/,/g, ''));
    if (num >= 1 && num <= 1000000) {
      signals.explicitCount = num;
      signals.totalScore += 35;
      break;
    }
  }
  if (signals.explicitCount) break;
}

// Signal 5: Presence of "About Us" may indicate established company
if (/about(?:-us)?\.html|about\b/.test(html.toLowerCase())) {
  signals.totalScore += 5;
}

// Estimate bucket
let estimate = null;
let bucket = null;

if (signals.explicitCount) {
  estimate = signals.explicitCount;
} else if (signals.totalScore >= 50) {
  estimate = '50+ (has careers page + other signals)';
  bucket = 'mid-large';
} else if (signals.totalScore >= 30) {
  estimate = '10-50 (has careers page)';
  bucket = 'mid';
} else if (signals.hasTeamPage) {
  estimate = '2-25 (has team page, no careers)';
  bucket = 'small-mid';
} else {
  estimate = '1-10 (no careers/team signals)';
  bucket = 'small';
}

const result = {
  extractor: 'employee_count',
  estimate: estimate,
  bucket: bucket,
  confidence: signals.explicitCount ? 80 : Math.min(signals.totalScore, 60),
  source: 'website',
  evidence: JSON.stringify(signals),
  source_url: $input.first().json.url,
  signals: signals
};

return [{ json: result }];
```

---

## 8. Duplicate Company Detection

Normalize and compare company names and domains using Levenshtein distance to detect duplicates.

```javascript
// n8n Code node — Duplicate Detection
// Input: array of existing companies + current company
const companies = $input.first().json.existing || [];
const current = {
  name: $input.first().json.company_name || '',
  domain: $input.first().json.domain || ''
};

const levenshteinDistance = (a, b) => {
  const aLen = a.length;
  const bLen = b.length;
  const matrix = [];

  for (let i = 0; i <= bLen; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= aLen; j++) {
    matrix[0][j] = j;
  }
  for (let i = 1; i <= bLen; i++) {
    for (let j = 1; j <= aLen; j++) {
      if (b.charAt(i - 1) === a.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,  // substitution
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j] + 1       // deletion
        );
      }
    }
  }
  return matrix[bLen][aLen];
};

const normalizeDomain = (domain) => {
  let d = (domain || '').toLowerCase().trim();
  d = d.replace(/^https?:\/\//, '');
  d = d.replace(/\/$/, '');
  d = d.replace(/^www\./, '');
  return d;
};

const normalizeName = (name) => {
  let n = (name || '').toLowerCase().trim();
  n = n.replace(/[^a-z0-9\s]/g, '');
  n = n.replace(/\b(inc|llc|ltd|corp|gmbh|limited|corporation|company|co|plc|sa|ag|nv|bv|pty|sdn|bhd|kk|srl|spa|sas)\b/g, '');
  n = n.replace(/\s+/g, ' ').trim();
  return n;
};

const currentDomain = normalizeDomain(current.domain);
const currentName = normalizeName(current.name);

const duplicates = [];

for (const comp of companies) {
  const candidateDomain = normalizeDomain(comp.domain);
  const candidateName = normalizeName(comp.name);

  // Exact domain match = duplicate
  if (currentDomain && candidateDomain && currentDomain === candidateDomain) {
    duplicates.push({
      match: comp,
      reason: 'domain_exact',
      score: 100
    });
    continue;
  }

  // Domain substring match
  if (currentDomain && candidateDomain) {
    const cd = currentDomain.replace(/\.com|\.io|\.org|\.net|\.app|\.dev/g, '');
    const pd = candidateDomain.replace(/\.com|\.io|\.org|\.net|\.app|\.dev/g, '');
    if (cd === pd || cd.includes(pd) || pd.includes(cd)) {
      duplicates.push({
        match: comp,
        reason: 'domain_similar',
        score: 85
      });
      continue;
    }
  }

  // Name fuzzy match
  if (currentName && candidateName) {
    const dist = levenshteinDistance(currentName, candidateName);
    const maxLen = Math.max(currentName.length, candidateName.length);
    const similarity = maxLen > 0 ? (1 - dist / maxLen) * 100 : 0;

    if (similarity >= 80) {
      duplicates.push({
        match: comp,
        reason: 'name_fuzzy',
        score: Math.round(similarity)
      });
    }
  }
}

const result = {
  extractor: 'duplicate_detection',
  is_duplicate: duplicates.length > 0,
  duplicates: duplicates.sort((a, b) => b.score - a.score),
  max_score: duplicates.length > 0 ? Math.max(...duplicates.map(d => d.score)) : 0,
  source_url: $input.first().json.url
};

return [{ json: result }];
```

---

## 9. Combined Rule Engine Orchestrator

Master node that runs all extractors in sequence and merges results into a single output.

```javascript
// n8n Code node — Rule Engine Orchestrator
const input = $input.first().json;

// Run all extractors (in production these are sub-nodes or parallel branches)
const extractors = {
  emails: extractEmails(input),
  phones: extractPhones(input),
  social: extractSocial(input),
  schema: extractSchema(input),
  meta: extractMeta(input),
  technologies: extractTech(input),
  employeeCount: estimateEmployees(input),
  duplicates: detectDuplicates(input)
};

// Merge and calculate coverage
let totalFields = 0;
let foundFields = 0;

for (const [key, ext] of Object.entries(extractors)) {
  if (ext && ext.value !== null && ext.value !== undefined &&
      !(Array.isArray(ext.value) && ext.value.length === 0) &&
      !(typeof ext.value === 'object' && !Array.isArray(ext.value) && Object.keys(ext.value).length === 0)) {
    foundFields++;
  }
  totalFields++;
}

const coveragePct = totalFields > 0 ? Math.round((foundFields / totalFields) * 100) : 0;

const result = {
  company_id: input.company_id || null,
  domain: input.domain || null,
  url: input.url || null,
  extracted_at: new Date().toISOString(),
  extractions: extractors,
  coverage_pct: coveragePct,
  validation: {
    has_critical_data: !!extractors.emails?.count > 0 || !!extractors.schema?.value?.name,
    requires_ai_fallback: coveragePct < 40,
    ai_prompt: coveragePct < 40
      ? `Rule engine found ${foundFields}/${totalFields} fields. Use AI to fill remaining gaps for ${input.domain}`
      : null
  }
};

return [{ json: result }];

// Helper stubs — actual implementations are in extractor-specific nodes
function extractEmails(input) { /* See Section 1 */ }
function extractPhones(input) { /* See Section 2 */ }
function extractSocial(input) { /* See Section 3 */ }
function extractSchema(input) { /* See Section 4 */ }
function extractMeta(input) { /* See Section 5 */ }
function extractTech(input) { /* See Section 6 */ }
function estimateEmployees(input) { /* See Section 7 */ }
function detectDuplicates(input) { /* See Section 8 */ }
```

---

## Output Format

The rule engine produces a standardized JSON that feeds into the evidence system:

```json
{
  "company_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "domain": "acme-corp.com",
  "url": "https://acme-corp.com",
  "extracted_at": "2026-07-12T14:30:00.000Z",
  "extractions": {
    "emails": {
      "value": ["hello@acme-corp.com", "sales@acme-corp.com"],
      "items": [
        { "value": "hello@acme-corp.com", "confidence": 95, "source": "website", "category": "general" },
        { "value": "sales@acme-corp.com", "confidence": 95, "source": "website", "category": "sales" }
      ],
      "count": 2
    },
    "phones": {
      "value": ["+15551234567"],
      "items": [
        { "value": "+15551234567", "confidence": 90, "source": "website", "normalized": "+15551234567" }
      ],
      "count": 1
    },
    "social": {
      "value": {
        "linkedin": ["https://linkedin.com/company/acme-corp"],
        "twitter": ["https://twitter.com/acmecorp"]
      },
      "confidence": 92,
      "platforms_found": 2
    },
    "schema": {
      "value": {
        "name": "Acme Corp",
        "description": "Leading provider of...",
        "url": "https://acme-corp.com",
        "sameAs": ["https://linkedin.com/company/acme-corp"],
        "telephone": "+15551234567"
      },
      "confidence": 90,
      "blocks_found": 1
    },
    "meta": {
      "value": {
        "og_title": "Acme Corp — Enterprise Solutions",
        "og_description": "Leading provider of enterprise software solutions",
        "meta_title": "Acme Corp | Enterprise Software"
      },
      "confidence": 88,
      "fields_found": 8
    },
    "technologies": {
      "value": ["React", "Next.js", "Tailwind CSS", "Cloudflare", "Stripe"],
      "confidence": 85,
      "count": 5,
      "categories": {
        "frontend": ["React", "Next.js"],
        "analytics": [],
        "infrastructure": ["Cloudflare"],
        "payment": ["Stripe"]
      }
    },
    "employee_count": {
      "estimate": "50+ (has careers page + other signals)",
      "bucket": "mid-large",
      "confidence": 55,
      "signals": {
        "hasCareersPage": true,
        "hasTeamPage": false,
        "explicitCount": null,
        "totalScore": 55
      }
    }
  },
  "coverage_pct": 75,
  "validation": {
    "has_critical_data": true,
    "requires_ai_fallback": false,
    "ai_prompt": null
  }
}
```

---

## Extraction Coverage Map

| Field | Rule Engine | AI Fallback | Priority |
|-------|-------------|-------------|----------|
| Email addresses | ✅ Regex + denylist | ❌ Rarely needed | High |
| Phone numbers | ✅ Regex patterns | ❌ Rarely needed | High |
| Social links | ✅ URL patterns | Only if missing from HTML | Medium |
| Company name | ✅ JSON-LD / OG | ✅ When meta absent | High |
| Description | ✅ OG / meta desc | ✅ When meta absent | High |
| Technology stack | ✅ HTML signatures | Only for obfuscated stacks | Medium |
| Employee count | ✅ Heuristic signals | ✅ For accuracy | Low |
| Funding info | ❌ Not reliable | ✅ Primary source | Low |
| Founding date | ✅ JSON-LD | ✅ When absent | Low |
| Industry | ❌ Not reliable | ✅ Primary source | Medium |
| Duplicate check | ✅ Normalization + Levenshtein | ❌ Never needed | High (pipeline) |

---

## Error States & Edge Cases

| Scenario | Behavior |
|----------|----------|
| No HTML received | Return empty results with `coverage_pct: 0` |
| Malformed JSON-LD | Skip silently, log count to `schema.raw` |
| Regex catastrophic backtracking | All patterns use bounded quantifiers; wrap in try/catch |
| Emails in image filenames | Filtered by extension denylist |
| +1 (555) 123-4567 with spaces | Normalized to E.164 digits |
| Self-referencing social links | Not filtered — company's own social profile is valid |
| International characters in names | `[^a-z0-9\s]` strips accents for comparison only |
| Empty body (SPA with JS render) | Rule engine catches nothing; `requires_ai_fallback: true` |

---

## Integration Points

1. **Scraper output → Rule Engine input**: Raw HTML, markdown text, response headers, URL
2. **Rule Engine → Evidence System**: Structured extractions with confidence scores and source attribution
3. **Rule Engine → AI Extractor**: `requires_ai_fallback: true` triggers secondary AI pass
4. **Rule Engine → Deduplication Pipeline**: `duplicate_detection` result feeds merge logic
