# Data Models Reference

All JSON records include a `_schema_v` field for schema versioning.

**Schema versioning rules:**
- Every record MUST include `_schema_v` (integer)
- Readers MUST handle older versions by applying missing-field defaults
- Writers MUST write the current version number
- When adding fields: increment `_schema_v`, define default for new field

---

## NewsItem

Each news item collected from a source.

```json
{
  "id": "string (SHA256(normalized_url)[:16])",
  "title": "string",
  "url": "string (original URL)",
  "normalized_url": "string (tracking params stripped, https, no www, lowercase host, no trailing slash)",
  "source_id": "string (e.g., src-36kr)",
  "content_summary": "string (LLM-generated 2-3 sentence Chinese summary, null if unprocessed)",
  "categories": {
    "primary": "string (one of 12 category IDs from config/categories.json)",
    "secondary": ["string (additional category IDs)"],
    "tags": ["string (kebab-case fine-grained tags, 2-5 per item)"]
  },
  "importance_score": 0.0,
  "event_id": null,
  "fetched_at": "ISO8601",
  "published_at": "ISO8601 or null",
  "form_type": "news|analysis|opinion|announcement|other",
  "language": "zh|en",
  "dedup_status": "unique|url_dup",
  "content_hash": "string (SHA256(normalized_content)[:16])",
  "processing_status": "raw|partial|complete",
  "duplicate_of": null,
  "_schema_v": 2
}
```

**Field notes:**
- `id`: Deterministic from URL -- same URL always produces same ID
- `normalized_url`: Strip `utm_*` params, force `https`, remove `www.` prefix, lowercase hostname, remove trailing `/`
- `processing_status`: `raw` = just fetched, `partial` = classification or summary failed, `complete` = fully processed
- `form_type`: Content format -- `news` (factual report), `analysis` (in-depth analysis), `opinion` (editorial/opinion piece), `announcement` (official release/announcement), `other` (uncategorized)
- `categories.primary`: Must be one of the 12 IDs defined in `config/categories.json`
- `duplicate_of`: If `dedup_status` is `url_dup`, contains the `id` of the original item

**Defaults for missing fields (older schema versions):**
- `content_hash`: `null`
- `processing_status`: `"raw"`
- `duplicate_of`: `null`
- `categories.secondary`: `[]`
- `event_id`: `null`

---

## Source

Source definition as stored in `config/sources.json`.

```json
{
  "id": "string (src-{name})",
  "name": "string (display name)",
  "type": "rss | github | search | official | community | ranking",
  "url": "string (feed URL, API URL, page URL, or empty for search type)",
  "weight": 1.0,
  "credibility": 0.8,
  "topics": ["string (expected topic category IDs)"],
  "enabled": true,
  "fetch_config": {},
  "stats": {
    "total_fetched": 0,
    "last_fetch": "ISO8601 or null",
    "last_hit_count": 0,
    "avg_daily_items": 0,
    "consecutive_failures": 0,
    "last_error": "string or null",
    "quality_score": 0.5,
    "dedup_rate": 0.0,
    "selection_rate": 0.0
  },
  "status": "active|paused|degraded"
}
```

**Field notes:**
- `type`: Source type determines fetch strategy. See `references/collection-instructions.md` for per-type collection steps.
- `weight`: Source weight multiplier for scoring (default 1.0)
- `credibility`: Base trust score for this source (0.0-1.0). New sources default to 0.5.
- `stats.quality_score`: Rolling quality assessment (0.0-1.0), initialized at 0.5. Recomputed after each pipeline run per collection-instructions.md Section 11.
- `stats.dedup_rate`: Fraction of fetched items that are duplicates
- `stats.selection_rate`: Fraction of fetched items selected for output

**`fetch_config` variants by type:**

| Type | `fetch_config` Fields | Description |
|------|----------------------|-------------|
| `rss` | `{}` | No extra config needed |
| `github` | `{ owner, repo, endpoint, per_page, token? }` | `owner`: GitHub org/user. `repo`: repository name. `endpoint`: "releases" or "commits". `per_page`: items per request (default 10). `token`: optional GitHub PAT for higher rate limits. |
| `search` | `{ keywords, max_results }` | `keywords`: array of search query strings. `max_results`: max results per keyword (default 10). |
| `official` | `{ prefer_browser }` | `prefer_browser`: boolean (default false). If true, skip web_fetch and use browser directly. |
| `community` | `{ max_items }` | `max_items`: max items to extract per page (default 15). |
| `ranking` | `{ prefer_browser, max_items }` | `prefer_browser`: boolean (default false). `max_items`: max items to extract (default 20). |

---

## DedupIndex

Stored at `data/news/dedup-index.json`. Maps URL hashes to item references for fast dedup lookup.

```json
{
  "{url_hash}": {
    "news_id": "string (NewsItem.id)",
    "source_id": "string",
    "fetched_at": "ISO8601"
  }
}
```

**Notes:**
- `{url_hash}` is `SHA256(normalized_url)[:16]` -- same as `NewsItem.id`
- Index should cover only the last 7 days of data
- Rebuild from JSONL files using `scripts/dedup-index-rebuild.sh`

---

## CacheEntry

Cache files for LLM result deduplication. Stored at `data/cache/classify-cache.json` and `data/cache/summary-cache.json`.

JSON object keyed by `url_sha` (`SHA256(normalized_url)[:16]` -- same hash as NewsItem.id and DedupIndex keys).

### Classify Cache Entry Value

```json
{
  "_schema_v": 1,
  "primary": "category_id",
  "tags": ["tag1", "tag2"],
  "importance_score": 0.0,
  "form_type": "news|analysis|opinion|announcement|other",
  "cached_at": "ISO8601"
}
```

**Field notes:**
- `primary`: One of the 12 category IDs from `config/categories.json`
- `importance_score`: Range 0.0-1.0
- `cached_at`: Timestamp of when this entry was cached; entries older than 7 days are evicted during cleanup

### Summary Cache Entry Value

```json
{
  "_schema_v": 1,
  "summary": "2-3 sentence Chinese summary text",
  "cached_at": "ISO8601"
}
```

**TTL:** 7 days from `cached_at`. Stale entries are deleted during cache cleanup at the start of each pipeline run (see `references/processing-instructions.md` Section 0B).

---

## FeedbackEntry

Each feedback signal from the user, stored in `data/feedback/log.jsonl` (one JSON object per line).

```json
{
  "_schema_v": 1,
  "timestamp": "ISO8601",
  "type": "more|less|trust_source|distrust_source|like|dislike|block_pattern|adjust_style",
  "target": "topic_id | source_id | item_url | pattern_string | style_field",
  "context": "optional - the digest item or source that triggered this feedback",
  "status": "applied | pending_confirmation | skipped",
  "run_id": "which pipeline run processed this entry (null if unprocessed)"
}
```

**Field notes:**
- `type`: One of the 8 feedback types defined in `references/feedback-rules.md`
- `target`: The resolved reference after disambiguation (see feedback-rules.md Disambiguation section)
- `context`: Optional audit trail -- the full item title, source name, or digest sequence number that the user referenced
- `status`: Processing state -- `applied` (change made), `pending_confirmation` (escalated, awaiting user confirm), `skipped` (cumulative cap hit or user rejected)
- `run_id`: Set when the entry is processed by the feedback update procedure. `null` means unprocessed.

**Defaults for missing fields (older schema versions):**
- `context`: `null`
- `status`: `"applied"`
- `run_id`: `null`

---

## DailyMetrics

Stored at `data/metrics/daily-YYYY-MM-DD.json`. One file per day.

```json
{
  "date": "YYYY-MM-DD",
  "run_id": "run-YYYYMMDD-HHmmss-XXXX",
  "sources": {
    "total": 1,
    "success": 0,
    "failed": 0,
    "degraded": 0
  },
  "items": {
    "fetched": 0,
    "url_deduped": 0,
    "title_deduped": 0,
    "classified": 0,
    "partial": 0,
    "selected_for_output": 0
  },
  "llm": {
    "calls": 0,
    "tokens_input": 0,
    "tokens_output": 0,
    "cache_hits": 0,
    "failures": 0
  },
  "output": {
    "type": "daily_digest",
    "item_count": 0,
    "generated": false
  }
}
```
