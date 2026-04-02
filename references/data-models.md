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
  "dedup_status": "unique|url_dup|title_dup|event_merged",
  "content_hash": "string (SHA256(normalized_content)[:16])",
  "processing_status": "raw|partial|complete|noise_filtered",
  "duplicate_of": null,
  "digest_eligible": true,
  "_schema_v": 4
}
```

**Field notes:**
- `id`: Deterministic from URL -- same URL always produces same ID
- `normalized_url`: Strip `utm_*` params, force `https`, remove `www.` prefix, lowercase hostname, remove trailing `/`
- `processing_status`: `raw` = just fetched, `partial` = classification or summary failed, `complete` = fully processed, `noise_filtered` = matched noise pattern, skipped LLM
- `form_type`: Content format -- `news` (factual report), `analysis` (in-depth analysis), `opinion` (editorial/opinion piece), `announcement` (official release/announcement), `other` (uncategorized)
- `categories.primary`: Must be one of the 12 IDs defined in `config/categories.json`
- `language`: Detected during title dedup Stage A (see `references/processing-instructions.md` Section 1A). CJK character majority (>50%) -> `"zh"`, otherwise `"en"`.
- `duplicate_of`: If `dedup_status` is `url_dup` or `title_dup`, contains the `id` of the primary/original item

**Defaults for missing fields (older schema versions):**
- `content_hash`: `null`
- `processing_status`: `"raw"`
- `duplicate_of`: `null`
- `categories.secondary`: `[]`
- `event_id`: `null`
- `dedup_status`: `"unique"` (for records created before title dedup was added)
- `language`: `"zh"` (for records created before language detection was added)
- `digest_eligible`: `true` (items from v3 and earlier are eligible since they passed the old pipeline)

---

## Event

Each event groups related news items about the same real-world occurrence, tracked through a lifecycle with timeline entries.

```json
{
  "id": "string (evt-XXXXXXXX, 8-char random alphanumeric)",
  "title": "string (event title)",
  "summary": "string (current event summary, updated on merge)",
  "first_seen": "ISO8601",
  "last_updated": "ISO8601",
  "status": "active|stable|archived",
  "topic": "string (primary category ID)",
  "importance": 0.0,
  "keywords": ["string (3-5 keywords for matching)"],
  "item_ids": ["string (NewsItem IDs linked to this event)"],
  "timeline": [
    {
      "news_id": "string",
      "relation": "initial|update|correction|analysis|reversal|escalation",
      "timestamp": "ISO8601",
      "brief": "string (one sentence describing this news in event context)"
    }
  ],
  "last_alerted_at": "ISO8601 or null",
  "last_alert_news_id": "string or null",
  "last_alert_brief": "string or null",
  "_schema_v": 3
}
```

**Field notes:**
- `id`: Format `evt-` followed by 8 random alphanumeric characters
- `status`: Lifecycle transitions -- `active` (receiving new items) -> `stable` (3 days no update) -> `archived` (7 days no update, moved to `data/events/archived/YYYY-MM.json`)
- `importance`: Updated to `max(event.importance, item.importance_score)` on each merge
- `keywords`: 3-5 keywords used for Step 2 keyword quick match during event merging (see `references/processing-instructions.md` Section 1C)
- `timeline`: Array of timeline entries, one per merged news item. Relation types: `initial` (first report), `update` (new developments), `correction` (fact corrections), `analysis` (commentary/interpretation), `reversal` (situation reversal), `escalation` (situation escalation/intensification)
- `summary`: Auto-updated when items with relation `update`, `correction`, `reversal`, or `escalation` are merged (not for `analysis`)
- `last_alerted_at`: ISO8601 timestamp of when this event was last used in an alert. Null if never alerted.
- `last_alert_news_id`: The news_id of the item that triggered the last alert for this event. Null if never alerted.
- `last_alert_brief`: One-sentence summary of what the last alert communicated. Used by delta alerts to describe what changed. Null if never alerted.

**Defaults for missing fields (older schema versions):**
- `keywords`: `[]`
- `timeline`: `[]`
- `item_ids`: `[]`
- `last_alerted_at`: `null`
- `last_alert_news_id`: `null`
- `last_alert_brief`: `null`

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
    "selection_rate": 0.0,
    "degraded_since": null,
    "recovery_streak_start": null
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
- `stats.degraded_since`: ISO8601 date or null. Set when quality_score first drops below 0.2 while status is "active". Reset to null when quality recovers (>= 0.2) or when source transitions to degraded. Used for the 14-day demotion countdown.
- `stats.recovery_streak_start`: ISO8601 date or null. Set when quality_score first rises above 0.3 while status is "degraded". Reset to null when quality dips (<= 0.3) or when source recovers to active. Used for the 7-day recovery countdown.

**Defaults for missing fields (older schema):** `degraded_since`: null, `recovery_streak_start`: null.

**`fetch_config` variants by type:**

| Type | `fetch_config` Fields | Description |
|------|----------------------|-------------|
| `rss` | `{}` | No extra config needed |
| `github` | `{ owner, repo, endpoint, per_page, token? }` | `owner`: GitHub org/user. `repo`: repository name. `endpoint`: "releases" or "commits". `per_page`: items per request (default 10). `token`: optional GitHub PAT for higher rate limits. |
| `search` | `{ keywords, max_results }` | `keywords`: array of search query strings. `max_results`: max results per keyword (default 10). |
| `official` | `{ prefer_browser }` | `prefer_browser`: boolean (default false). If true, skip web_fetch and use browser directly. |
| `community` | `{ max_items }` | `max_items`: max items to extract per page (default 15). |
| `ranking` | `{ prefer_browser, max_items }` | `prefer_browser`: boolean (default false). `max_items`: max items to extract (default 20). |

**Common fetch_config fields (all source types):**
- `noise_patterns`: Array of regex strings. Items whose title matches any pattern (case-insensitive) are noise-filtered before LLM classification. Default: `[]` (no filtering).
- `title_discard_patterns`: Array of regex strings. Items whose title exactly matches any pattern (case-insensitive full-match) are discarded. Default: `[]` (no filtering).

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
  "_schema_v": 2,
  "primary": "category_id",
  "tags": ["tag1", "tag2"],
  "importance_score": 0.0,
  "form_type": "news|analysis|opinion|announcement|other",
  "cached_at": "ISO8601",
  "prompt_version": "classify-v1"
}
```

**Field notes:**
- `primary`: One of the 12 category IDs from `config/categories.json`
- `importance_score`: Range 0.0-1.0
- `cached_at`: Timestamp of when this entry was cached; entries older than 7 days are evicted during cleanup
- `prompt_version`: Version string of the prompt used to generate this result. Format: `{prompt-name}-v{N}`. When prompt changes, increment version. Cache lookup treats version mismatch as cache miss.

### Summary Cache Entry Value

```json
{
  "_schema_v": 2,
  "summary": "2-3 sentence Chinese summary text",
  "cached_at": "ISO8601",
  "prompt_version": "summarize-v1"
}
```

**Field notes:**
- `prompt_version`: Same semantics as Classify Cache -- version mismatch forces re-summarization.

**Defaults for missing fields (older schema versions):**
- `prompt_version`: `"legacy"` (entries without this field are treated as legacy; will cache-miss on first run with versioned prompts)

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

## Preferences

User preference state stored at `config/preferences.json`. Drives scoring, quota allocation, summary depth, and feedback processing.

```json
{
  "topic_weights": { "ai-models": 0.5, "...": 0.5 },
  "source_trust": {},
  "form_preference": { "news": 0.0, "...": 0.0 },
  "style": {
    "density": "medium",
    "repetition_tolerance": "low",
    "exploration_appetite": 0.3,
    "rumor_tolerance": "low",
    "last_exploration_increase": null
  },
  "feedback_samples": {
    "liked_items": [],
    "disliked_items": [],
    "trusted_sources": [],
    "distrusted_sources": [],
    "blocked_patterns": []
  },
  "depth_preference": "moderate",
  "judgment_angles": [],
  "version": 3,
  "last_updated": null,
  "last_decay_at": null,
  "total_feedback_count": 0,
  "feedback_processing_enabled": true,
  "_schema_v": 2
}
```

**Field notes:**

| Field | Type | Range/Values | Default | Description |
|-------|------|-------------|---------|-------------|
| `topic_weights.*` | float | [0.0, 1.0] | 0.5 | Per-category interest weight. Higher = more items from this category. |
| `source_trust.*` | float | [-1.0, 1.0] | (absent) | Per-source trust modifier. Absent key = use source base credibility. |
| `form_preference.*` | float | [-1.0, 1.0] | 0.0 | Per-form-type preference. Positive = prefer, negative = avoid. |
| `style.density` | string | "low" / "medium" / "high" | "medium" | Output density level. |
| `style.repetition_tolerance` | string | "low" / "medium" / "high" | "low" | Tolerance for repeated topics. |
| `style.exploration_appetite` | float | [0.0, 1.0] | 0.3 | Controls exploration slot sizing. Auto-incremented by ANTI-05. |
| `style.rumor_tolerance` | string | "low" / "medium" / "high" | "low" | Tolerance for unverified content. |
| `style.last_exploration_increase` | string (ISO8601) or null | - | null | Tracks last ANTI-05 auto-increase. |
| `depth_preference` | string | "brief" / "moderate" / "detailed" / "technical" | "moderate" | Controls summary generation depth. "brief" = 1-sentence summaries, "moderate" = 2-3 sentences (current default), "detailed" = 3-5 sentences with background context, "technical" = adds implementation details where relevant. Wired into summarize prompt, NOT the scoring formula. |
| `judgment_angles` | array of strings | "workflow_impact", "worth_trying", "hype_vs_real", "market_change", "long_term_value", "practical_use" | [] | Perspective tags the user prefers. Wired into weekly report synthesis and summarize prompt to emphasize relevant angles. NOT wired into scoring formula. Cold-start is empty (no angle preference). |
| `last_decay_at` | string (ISO8601) or null | - | null | Timestamp of last decay application. Null means never decayed. See `references/processing-instructions.md` Section 0. |
| `version` | integer | >= 1 | 1 | Incremented on each preference update. |
| `last_updated` | string (ISO8601) or null | - | null | Timestamp of last feedback-driven update. |
| `total_feedback_count` | integer | >= 0 | 0 | Total feedback signals processed. |
| `feedback_processing_enabled` | boolean | true / false | true | Kill switch for feedback processing. See `references/feedback-rules.md`. |
| `_schema_v` | integer | >= 1 | 2 | Schema version. Readers handle v1 (missing `depth_preference`, `judgment_angles`) with defaults: `depth_preference` = "moderate", `judgment_angles` = []. |

**Decay behavior:** `topic_weights` decay toward 0.5, `source_trust` toward 0, `form_preference` toward 0. Fields `style.*`, `feedback_samples`, `depth_preference`, `judgment_angles` do NOT decay. See `references/processing-instructions.md` Section 0.

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
    "selected_for_output": 0,
    "noise_filter_suppressed": 0
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
  },
  "quota_distribution": {
    "core": 0,
    "adjacent": 0,
    "hotspot": 0,
    "explore": 0
  },
  "category_proportions": {
    "ai-models": 0.0,
    "dev-tools": 0.0
  },
  "source_proportions": {
    "src-36kr": 0.0
  },
  "per_source": {
    "src-36kr": {
      "fetched": 12,
      "deduped": 3,
      "title_deduped": 1,
      "selected": 4,
      "status": "success",
      "error": null
    }
  },
  "alerts": [],
  "alerts_sent_today": 0,
  "alerted_urls": []
}
```

**Field notes (quota and proportions):**
- `quota_distribution`: Count of items in each quota group for this digest. Written during output generation (Section 4 Step 8). Used for monitoring quota balance.
- `category_proportions`: Fraction of selected items per `categories.primary` category (0.0-1.0). Only categories with > 0 items are included. Used by ANTI-03 reverse diversity constraints to check 3-day topic concentration history.
- `source_proportions`: Fraction of selected items per `source_id` (0.0-1.0). Only sources with > 0 items are included. Used by ANTI-03 reverse diversity constraints to check 3-day source concentration history.

**Field notes (alerts):**
- `alerts`: Array of `AlertCondition` objects detected during this day's health check. Empty array if no alerts fired. Populated by `scripts/health-check.sh` daily mode.
- `alerts_sent_today`: Integer count of breaking news alerts sent during quick-check runs today. Default 0. Read by quick-check flow to enforce 3-alert daily cap.
- `alerted_urls`: Array of URL strings already alerted today. Default []. Read by quick-check flow for same-URL dedup.

**Field notes (per_source):**
- `per_source`: Per-source-id breakdown of pipeline counters for this run. Keyed by `source_id` string. Each value is an object with:
  - `fetched` (integer): Items fetched from this source in this run
  - `deduped` (integer): Items from this source that were URL-deduped (skipped because hash already in dedup-index)
  - `title_deduped` (integer): Items from this source marked as title duplicates during Stage B/C title dedup
  - `selected` (integer): Items from this source that received a `quota_group` tag (selected for digest output)
  - `status` (string): `"success"` if source fetched >= 1 item, `"failed"` if fetch returned 0 items or encountered an error
  - `error` (string or null): Error message if fetch failed, `null` on success
- Sources not attempted in this run (e.g., disabled sources) are omitted from `per_source`
- Historical metrics files from before Phase 6 will lack `per_source`; consumers MUST use `.get('per_source', {})` for backward compatibility

---

## AlertCondition

Structured alert output from `scripts/health-check.sh`. Can be collected into `DailyMetrics.alerts` array.

```json
{
  "_schema_v": 1,
  "type": "source_failure|budget_warning|budget_exhausted|dedup_inconsistency|source_concentration|empty_digest",
  "severity": "warning|critical",
  "message": "string (human-readable alert message)",
  "details": {},
  "detected_at": "ISO8601"
}
```

**Field notes:**
- `type`: One of 6 alert condition types checked by health-check.sh daily mode
- `severity`: `warning` for threshold breaches (budget at 80%, dedup inconsistency), `critical` for operational failures (all sources failed 2 days, budget exhausted)
- `message`: Human-readable alert text matching the `ALERT:` line from health-check.sh output
- `details`: Optional structured data for the alert (e.g., `{"calls": 45, "limit": 50, "ratio": 0.9}` for budget alerts)
- `detected_at`: ISO8601 timestamp when the alert was detected

**Severity mapping:**

| Type | Severity | Trigger |
|------|----------|---------|
| `source_failure` | `critical` | All sources failed for 2 consecutive days |
| `budget_warning` | `warning` | LLM budget >= 80% of daily limit |
| `budget_exhausted` | `critical` | LLM budget >= 100% (circuit breaker active) |
| `dedup_inconsistency` | `warning` | >10% orphaned entries in dedup-index |
| `source_concentration` | `warning` | Single source accounts for >50% of items |
| `empty_digest` | `warning` | Items fetched but no digest generated |

---

## AlertState

Daily alert tracking state, stored at `data/alerts/alert-state-YYYY-MM-DD.json`. Separate from DailyMetrics -- this is the authoritative source for alert tracking across multiple quick-check runs per day.

```json
{
  "_schema_v": 1,
  "date": "YYYY-MM-DD",
  "alerts_sent": 0,
  "max_alerts": 3,
  "alerted_urls": [],
  "alert_log": [
    {
      "news_id": "string",
      "event_id": "string or null",
      "url": "string",
      "title": "string",
      "importance_score": 0.0,
      "alert_type": "standard|delta",
      "sent_at": "ISO8601"
    }
  ]
}
```

**Field notes:**
- `max_alerts`: Fixed at 3 (daily cap)
- `alerted_urls`: Array of URLs already alerted today for same-URL dedup
- `alert_log`: Audit trail of all alerts sent today
- If file not found for today, initialize with `alerts_sent: 0, max_alerts: 3, alerted_urls: [], alert_log: []`

---

## Preferences Auto-Update Fields (ANTI-05)

The following fields in `config/preferences.json` are auto-managed by the quota algorithm (see `references/processing-instructions.md` Section 4, Step 7):

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `style.exploration_appetite` | float | 0.3 | Controls exploration slot sizing. Auto-incremented by +0.05 every 7 days (cap 0.4) by ANTI-05 preference correction. |
| `style.last_exploration_increase` | string (ISO8601) or null | null | Tracks when the last auto-increase of `exploration_appetite` happened. Set to today's date after each auto-increment. If null, treated as "never increased" (triggers increase on next run). |

**Write convention:** Always use backup-before-write pattern (write backup, then write new file atomically) when updating preferences.json. See existing pipeline convention for atomic writes.

---

## Bootstrap & Migration

### New Fields Registry

All fields added across phases, with version, default, and migration behavior.

| Field | Model | Added In | Schema Version | Default for Old Records | Notes |
|-------|-------|----------|----------------|------------------------|-------|
| `content_hash` | NewsItem | Phase 0 | v2 | `null` | SHA256 of normalized content |
| `processing_status` | NewsItem | Phase 0 | v2 | `"raw"` | Pipeline progress tracking |
| `duplicate_of` | NewsItem | Phase 0 | v2 | `null` | Points to primary item ID |
| `dedup_status` | NewsItem | Phase 2 | v3 | `"unique"` | Title dedup result |
| `language` | NewsItem | Phase 2 | v3 | `"zh"` | Detected content language |
| `keywords` | Event | Phase 2 | v2 | `[]` | Event matching keywords |
| `timeline` | Event | Phase 2 | v2 | `[]` | Chronological event entries |
| `depth_preference` | Preferences | Phase 3 | v2 | `"moderate"` | Summary depth control |
| `judgment_angles` | Preferences | Phase 3 | v2 | `[]` | User perspective preferences |
| `degraded_since` | Source.stats | Phase 3 | - | `null` | Demotion countdown start |
| `recovery_streak_start` | Source.stats | Phase 3 | - | `null` | Recovery countdown start |
| `per_source` | DailyMetrics | Phase 6 | - | `{}` | Per-source pipeline counters |
| `prompt_version` | CacheEntry | Phase 8 | v2 | `"legacy"` | Prompt version for cache invalidation |
| `digest_eligible` | NewsItem | Phase 9 | v4 | `true` | Noise filter eligibility flag |
| `noise_filter_suppressed` | DailyMetrics.items | Phase 9 | - | `0` | Count of items filtered by noise/importance |
| `noise_patterns` | Source.fetch_config | Phase 9 | - | `[]` | Per-source noise regex patterns |
| `title_discard_patterns` | Source.fetch_config | Phase 9 | - | `[]` | Per-source title discard patterns |
| `alert_log` | AlertState | Phase 10 | v1 | `[]` | Audit trail of alerts sent today |
| `last_alerted_at` | Event | Phase 10 | v3 | `null` | Timestamp of last alert for this event |
| `last_alert_news_id` | Event | Phase 10 | v3 | `null` | News ID that triggered last alert |
| `last_alert_brief` | Event | Phase 10 | v3 | `null` | Summary of last alert content |

### Schema Change Procedure

When adding a new field to any data model:
1. Add the field to the schema in this document with current `_schema_v` + 1
2. Define a default value for records lacking the field (backward compatibility)
3. Add an entry to the New Fields Registry table above
4. Update fixture files in `data/fixtures/` to include the new field
5. Increment `_schema_v` in the model schema
