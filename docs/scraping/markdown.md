# Markdown Extraction

Markdown extraction converts scraped HTML pages into clean, structured markdown for AI processing. This is the primary content format fed to the analysis pipeline.

---

## Conversion Pipeline

`mermaid
flowchart LR
    A[Raw HTML] --> B[Parse DOM]
    B --> C[Remove Non-Content]
    C --> D[Normalize Structure]
    D --> E[Convert to Markdown]
    E --> F[Post-Process]
    F --> G[Clean Markdown]
`

### Step 1: Parse DOM

The HTML is parsed into a DOM tree. The parser identifies:
- Main content areas (<main>, <article>, <div role="main">)
- Navigation elements (to be removed)
- Sidebars and footers (to be removed)
- Headings, paragraphs, lists, tables

### Step 2: Remove Non-Content

The following elements are stripped:
- Navigation bars, menus, breadcrumbs
- Footers and site-wide sidebars
- Cookie consent banners
- Popups and overlays (detected by CSS classes, IDs)
- Script and style tags
- Hidden elements (display: none, isibility: hidden)
- Comments and embedded JSON-LD

### Step 3: Normalize Structure

Headings are checked for proper hierarchy (h1 → h2 → h3). Skipped levels are corrected. List nesting is inferred from HTML structure.

### Step 4: Convert to Markdown

The clean HTML is converted to GitHub-flavored markdown:
- Tables → markdown tables
- Lists → bulleted or numbered lists
- Links → [text](url) format
- Images → ![alt](src) format
- Code blocks → fenced code blocks with language tags

### Step 5: Post-Process

`python
def post_process_markdown(text):
    text = remove_empty_lines(text)
    text = normalize_headings(text)
    text = truncate_long_lines(text, max_length=2000)
    text = add_section_breaks(text)
    return text.strip()
`

---

## Firecrawl Configuration

`json
{
  "formats": ["markdown"],
  "onlyMainContent": true,
  "includeTags": ["h1", "h2", "h3", "h4", "h5", "h6", "p", "li", "table", "a", "img"],
  "excludeTags": ["nav", "footer", "header", "script", "style", "noscript"],
  "waitFor": 0,
  "timeout": 30000
}
`

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| ormats | ["markdown"] | Output formats requested |
| onlyMainContent | 	rue | Strip navigation, sidebars, footers |
| includeTags | — | Only include these HTML tags |
| excludeTags | — | Always remove these HTML tags |
| waitFor | 0 | Milliseconds to wait for JS render |
| 	imeout | 30000 | Page load timeout in milliseconds |

---

## Output Quality

### Typical Output Size

| Page Type | Raw HTML | Clean Markdown | Ratio |
|-----------|----------|----------------|-------|
| Landing page | ~150 KB | ~5 KB | 30:1 |
| About page | ~80 KB | ~3 KB | 26:1 |
| Blog post | ~100 KB | ~8 KB | 12:1 |
| Documentation | ~200 KB | ~15 KB | 13:1 |
| Pricing page | ~60 KB | ~4 KB | 15:1 |

### Quality Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Content retention | > 80% | % of meaningful content preserved |
| Noise removal | > 95% | % of navigation/sidebar removed |
| Heading accuracy | > 90% | Correct hierarchy preservation |
| Link preservation | > 85% | All links converted correctly |

---

## Post-Processing Rules

After Firecrawl returns the markdown, the Make.com pipeline applies additional rules:

### 1. Section Markers

`markdown
=== START PAGE: https://acme.com/about ===
[content]
=== END PAGE: https://acme.com/about ===
`

Section markers are added around each page's content when multiple pages are combined.

### 2. Empty Section Handling

If a page produces fewer than 200 characters of meaningful text, it is flagged:

`markdown
=== PAGE: https://acme.com/gallery ===
WARNING: Page produced insufficient content (45 chars). Skipping.
`

### 3. URL Resolution

All relative URLs in the markdown are resolved to absolute URLs:

`markdown
<!-- Before -->
[Learn more](/about)

<!-- After -->
[Learn more](https://acme.com/about)
`

### 4. Table Normalization

Tables are checked for consistent column counts. Malformed tables are converted to lists.

---

## AI Processing Format

The cleaned markdown is passed to the AI pipeline as-is. The AI model receives the raw markdown text in the extracted_markdown field of the user prompt (see user-prompts.md).

`json
{
  "extracted_markdown": "# About Acme Corp\n\nAcme Corp was founded in 2015...\n\n## Products\n\n- Product A: Description\n- Product B: Description\n\n## Team\n\n| Name | Title |\n|------|-------|\n| Jane Smith | CEO |\n| John Doe | CTO |"
}
`

---

## Debugging Markdown Issues

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| Empty markdown | SPA without server-side rendering | Enable waitFor parameter |
| Navigation in output | onlyMainContent not effective | Add excludeTags |
| Truncated content | Page timed out | Increase 	imeout |
| Character encoding issues | Non-UTF-8 page | Set Accept-Charset header |
| Missing images | Relative URLs not resolved | Run URL resolution post-process |

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-07-01 | Initial markdown extraction documentation |
