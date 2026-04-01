# Collection Instructions

Detailed reference for the Collection Phase of the news digest pipeline. SKILL.md's Collection Phase steps expand on this document.

---

## Section 1: RSS Feed Collection

### Primary Method: web_fetch

Use `web_fetch` with `extractMode: "text"` to fetch RSS XML feeds:

```
web_fetch(url=source.url, extractMode="text")
```

This returns the raw text content of the RSS feed, preserving XML structure.

### Parsing RSS XML

From the fetched XML text, extract the following fields for each `<item>` (or `<entry>` in Atom feeds):

| RSS Field | NewsItem Field | Notes |
|-----------|---------------|-------|
| `<title>` | `title` | Strip CDATA wrapper if present |
| `<link>` | `url` | Original URL before normalization |
| `<description>` | `content_snippet` | Strip HTML tags, truncate to ~500 chars |
| `<pubDate>` | `published_at` | Parse to ISO8601; if missing, use `fetched_at` |
| `<dc:creator>` or `<author>` | _(not stored in MVP)_ | Optional, for future use |

### Handling RSS Quirks

- **CDATA wrapping**: `<![CDATA[content]]>` -- strip the CDATA markers, keep inner content
- **Missing pubDate**: Use `fetched_at` (current ISO8601 timestamp) as fallback
- **HTML in description**: Strip all HTML tags to produce plain text `content_snippet`
- **Encoded entities**: Decode `&amp;`, `&lt;`, `&gt;`, `&quot;` to their character equivalents
- **Atom feeds**: Map `<entry>` to item, `<link href="...">` to url, `<summary>` or `<content>` to description

### Fallback Method: exec + feedparser

If `web_fetch` text mode returns mangled content (XML tags stripped, items merged into single block):

```bash
python3 -c "
import feedparser, json, sys
feed = feedparser.parse(sys.argv[1])
items = []
for entry in feed.entries:
    items.append({
        'title': entry.get('title', ''),
        'url': entry.get('link', ''),
        'description': entry.get('summary', ''),
        'published': entry.get('published', '')
    })
print(json.dumps(items, ensure_ascii=False))
" "FEED_URL"
```

Use `exec` to run this command. Parse the JSON output to get structured items.

### Language Detection

- If the feed's `<language>` tag is present, use it (map `zh-cn`, `zh-tw` to `zh`; `en-us`, `en-gb` to `en`)
- If absent, infer from content: if majority of title characters are CJK (Unicode range 4E00-9FFF), set `language: "zh"`; otherwise `"en"`

---

## Section 2: URL Normalization Rules

Apply these rules **in order** to every collected URL before computing its hash:

### Rule 1: Strip Tracking Parameters

Remove query parameters that are tracking-related:
- `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`
- Any parameter starting with `utm_`
- `fbclid`, `gclid`
- `ref`, `source` (when the URL has other identifying path components)

**Implementation**: Parse query string, filter out matching parameter names, reconstruct URL. If no query parameters remain, remove the `?` entirely.

### Rule 2: Normalize Protocol

Convert `http://` to `https://`.

### Rule 3: Remove www Prefix

`www.example.com` becomes `example.com`.

### Rule 4: Remove Trailing Slash

`https://example.com/path/` becomes `https://example.com/path`.

Exception: Root URL `https://example.com/` keeps the trailing slash (it IS the path).

### Rule 5: Lowercase Hostname

`EXAMPLE.COM/Path` becomes `example.com/Path`.

Only the hostname is lowercased. Path components preserve their original case.

### Rule 6: Compute Hashes

After normalization:
- **URL hash (used as item `id`)**: `SHA256(normalized_url)[:16]` -- first 16 hex characters
- **Content hash**: `SHA256(title + stripped_description)[:16]` -- for future content-level dedup

**Example**:
```
Original:    http://WWW.Example.com/article/123/?utm_source=rss&utm_medium=feed&ref=homepage
Normalized:  https://example.com/article/123
URL hash:    SHA256("https://example.com/article/123")[:16]
```

---

## Section 3: Link-Level Dedup

### Dedup Index

The dedup index is stored at `data/news/dedup-index.json`. It maps URL hashes to item metadata:

```json
{
  "a1b2c3d4e5f6a7b8": {
    "news_id": "a1b2c3d4e5f6a7b8",
    "source_id": "src-36kr",
    "fetched_at": "2026-04-01T08:00:00Z"
  }
}
```

### Dedup Procedure

For each new item from RSS:

1. Normalize the URL (Section 2 rules)
2. Compute `url_hash = SHA256(normalized_url)[:16]`
3. Read `data/news/dedup-index.json`
4. **If `url_hash` exists in dedup-index**: Skip this item entirely. Do NOT write to JSONL. Increment `items.url_deduped` counter in metrics.
5. **If `url_hash` NOT found**: This is a new unique item. Proceed to write.

### Updating the Dedup Index

After all items are processed for a source:

1. Read current `dedup-index.json`
2. Add new entries: `url_hash -> { news_id, source_id, fetched_at }`
3. Write updated index atomically (write to `.tmp.{run_id}`, then rename)

### Index Maintenance

- The dedup index should cover approximately the last 7 days
- For recovery or periodic cleanup, use `scripts/dedup-index-rebuild.sh` to rebuild from JSONL files
- Manual rebuild is acceptable for MVP; automated weekly rebuild comes in Phase 2

---

## Section 4: JSONL Write Format

### File Path Convention

```
data/news/YYYY-MM-DD.jsonl
```

One file per day, based on the `fetched_at` date (not `published_at`).

### Record Format

Each line is one complete NewsItem JSON object, following the schema in `references/data-models.md`:

```json
{"id":"a1b2c3d4e5f6a7b8","title":"Example Title","url":"https://example.com/article","normalized_url":"https://example.com/article","source_id":"src-36kr","content_summary":null,"categories":{"primary":null,"secondary":[],"tags":[]},"importance_score":0.0,"event_id":null,"fetched_at":"2026-04-01T08:00:00Z","published_at":"2026-04-01T06:30:00Z","form_type":null,"language":"zh","dedup_status":"unique","content_hash":"b2c3d4e5f6a7b8c9","processing_status":"raw","duplicate_of":null,"_schema_v":2}
```

### Key Points

- New items start with `processing_status: "raw"`
- `categories.primary`, `content_summary`, and `form_type` are `null` until processing
- `importance_score` defaults to `0.0` until classification
- `dedup_status` is `"unique"` for items that pass dedup check

### Atomic Write Procedure

1. Determine target path: `data/news/YYYY-MM-DD.jsonl`
2. If target file exists, read existing content
3. Append new items to content
4. Write to temporary file: `data/news/YYYY-MM-DD.jsonl.tmp.{run_id}`
5. Rename temporary file to target path
6. On crash: temp files older than 15 minutes are cleaned up on next run (per SKILL.md Operational Rules)
