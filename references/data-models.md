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
  "type": "rss",
  "url": "string (feed URL)",
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
- `weight`: Source weight multiplier for scoring (default 1.0)
- `credibility`: Base trust score for this source (0.0-1.0)
- `stats.quality_score`: Rolling quality assessment (0.0-1.0), initialized at 0.5
- `stats.dedup_rate`: Fraction of fetched items that are duplicates
- `stats.selection_rate`: Fraction of fetched items selected for output

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
