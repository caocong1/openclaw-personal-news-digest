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
| `<description>` | `content_snippet` | Strip HTML tags, preserve upstream link targets as plain text `Original link: <url>` lines when present, truncate to ~500 chars |
| `<pubDate>` | `published_at` | Parse to ISO8601; if missing, use `fetched_at` |
| `<dc:creator>` or `<author>` | _(not stored in MVP)_ | Optional, for future use |

### Handling RSS Quirks

- **CDATA wrapping**: `<![CDATA[content]]>` -- strip the CDATA markers, keep inner content
- **Missing pubDate**: Use `fetched_at` (current ISO8601 timestamp) as fallback
- **HTML in description**: Strip all HTML tags to produce plain text `content_snippet`, but preserve anchor destinations as `Original link: <url>` lines when a link target exists
- **Encoded entities**: Decode `&amp;`, `&lt;`, `&gt;`, `&quot;` to their character equivalents
- **Atom feeds**: Map `<entry>` to item, `<link href="...">` to url, `<summary>` or `<content>` to description

### Provenance Preservation Guarantee

When stripping HTML from RSS descriptions or extracted content:

- Preserve anchor destinations as plain text `Original link: <url>` lines when a link target exists.
- Do not discard upstream URLs from `content_snippet` during cleanup.
- Keep this as a collection guarantee so downstream provenance and citation extraction can rely on stable `content_snippet` input.

### Fallback Method: Agent-Native LLM Extraction

If `web_fetch` text mode returns mangled content (XML tags stripped, items merged into a single block), keep the pipeline agent-native instead of calling an external runtime:

1. Retry `web_fetch(url=source.url, extractMode="text")` once and preserve the raw fetched text exactly as returned.
2. Ask the LLM to extract a JSON array of feed items from the raw text, with fields: `title`, `url`, `description`, and `published`.
3. Instruct the LLM to use only evidence visible in the fetched feed text, preserve upstream link targets as `Original link: <url>` lines inside `description` when present, and leave missing fields as empty strings.
4. Parse the LLM JSON response into structured items and continue with the same field mapping table above.
5. If the LLM response is invalid JSON, retry once. If it still fails, skip the source for this run and set `stats.last_error` to `"parse_error"`.

### Language Detection

- If the feed's `<language>` tag is present, use it (map `zh-cn`, `zh-tw` to `zh`; `en-us`, `en-gb` to `en`)
- If absent, infer from content: if majority of title characters are CJK (Unicode range 4E00-9FFF), set `language: "zh"`; otherwise `"en"`

---

## Section 2B: Freshness Gate

### Purpose

Hard time-based filter that discards stale items before they enter the pipeline. This is the primary defense against old articles appearing in digests and alerts.

### When to Run

After URL dedup (Collection Phase step 6), before writing items to JSONL (step 7). Referenced from SKILL.md Collection Phase step 6b.

### Filter Rule

For each item surviving dedup:

1. Determine item age: `age_hours = (current_time - reference_time) / 3600`
   - `reference_time` = `published_at` if present and valid ISO8601
   - `reference_time` = `fetched_at` if `published_at` is null or unparseable
2. If `age_hours > 24`: **discard** — do NOT write to JSONL
3. If `age_hours <= 24`: **keep** — proceed to write

### Edge Cases

- **`published_at` is null**: Use `fetched_at` as fallback. Since `fetched_at` is always set to current time during collection, these items always pass the gate. This is acceptable — items without publication dates are assumed fresh.
- **`published_at` is in the future**: Keep the item (clock skew or timezone issue, not a staleness problem).
- **`published_at` format varies**: Parse ISO8601 with timezone. If timezone is missing, assume UTC.

### Counters

- Increment `freshness_filtered` in per-source metrics for each discarded item
- Emit run_log entry: `step="freshness_gate"`, `details={filtered_count, oldest_discarded_age_hours}`

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

---

## GitHub Release/Repo Collection

### When to Use

Sources with `type: "github"`. Fetches structured release or commit data from the GitHub public API.

### Source Config Example

```json
{
  "id": "src-github-langchain",
  "type": "github",
  "url": "https://api.github.com/repos/langchain-ai/langchain/releases",
  "fetch_config": {
    "owner": "langchain-ai",
    "repo": "langchain",
    "endpoint": "releases",
    "per_page": 10,
    "token": null
  }
}
```

### Fetch Steps

1. Construct API URL: `https://api.github.com/repos/{fetch_config.owner}/{fetch_config.repo}/{fetch_config.endpoint}?per_page={fetch_config.per_page}`
2. `web_fetch(url, extractMode="text")` to get JSON text
3. Parse JSON array of release/commit objects
4. Map fields per endpoint:
   - **releases**: `name` -> title, `html_url` -> url, `body` (truncated to 500 chars) -> content_snippet, `published_at` -> published_at
   - **commits**: `commit.message` (first line) -> title, `html_url` -> url, `commit.message` (truncated to 500 chars) -> content_snippet, `commit.author.date` -> published_at
5. If `fetch_config.token` is set, include header `Authorization: token {token}` for authenticated requests (5000 req/hr vs 60 req/hr unauthenticated)
6. Follow shared normalize-dedup-write pipeline (Section 2, 3, 4)

### Error Handling

- **HTTP 403 / rate limit**: Increment `stats.consecutive_failures`, set `stats.last_error` to "rate_limited", skip source for this run
- **HTTP 404**: Source misconfigured. Set `stats.last_error` to "repo_not_found", skip source
- **Empty array**: Valid response (no new releases). Set `stats.last_hit_count` to 0, continue
- **Malformed JSON**: Increment `stats.consecutive_failures`, set `stats.last_error` to "parse_error", skip source

---

## Search-Based Collection

### When to Use

Sources with `type: "search"`. Uses `web_search` with keywords to find recent news, then LLM-filters results for relevance.

### Source Config Example

```json
{
  "id": "src-search-ai-regulation",
  "type": "search",
  "url": "",
  "fetch_config": {
    "keywords": ["AI regulation news 2026", "artificial intelligence policy"],
    "max_results": 10
  }
}
```

### Fetch Steps

1. For each keyword in `fetch_config.keywords`:
   - Append current year to keyword if not already present (for freshness)
   - Call `web_search(keyword)` to get search results
   - Collect results (title, url, snippet) up to `fetch_config.max_results` per keyword
2. Deduplicate collected results by URL (within this source's batch)
3. Prepare LLM filter input: format all results as title/url/snippet blocks separated by `---`
4. Load `references/prompts/filter-search.md` prompt template
5. Fill template placeholders: `{source_topics}` from `source.topics`, `{filter_context}` from source description, `{search_results}` with formatted results
6. Call LLM with the filled prompt
7. Parse LLM response as JSON array of kept items (title, url, snippet)
8. Map fields: `title` -> title, `url` -> url, `snippet` -> content_snippet, current timestamp -> fetched_at
9. Follow shared normalize-dedup-write pipeline (Section 2, 3, 4)

### Error Handling

- **web_search returns empty**: Log warning, set `stats.last_hit_count` to 0, continue to next keyword
- **LLM filter returns invalid JSON**: Retry once. If still invalid, skip this source for this run, increment `stats.consecutive_failures`
- **LLM filter returns empty array**: Valid response (all results filtered out). Set `stats.last_hit_count` to 0

---

## Official Announcement Collection

### When to Use

Sources with `type: "official"`. Fetches official blog posts, press releases, and announcements from organization websites.

### Source Config Example

```json
{
  "id": "src-official-openai-blog",
  "type": "official",
  "url": "https://openai.com/blog",
  "fetch_config": {
    "prefer_browser": false
  }
}
```

### Fetch Steps

1. Try `web_fetch(source.url, extractMode="text")` first
2. Check result quality:
   - If result text is too short (< 200 chars) or appears to be only navigation/boilerplate, the page likely requires JavaScript rendering
   - If `fetch_config.prefer_browser` is `true`, skip directly to browser
3. If web_fetch result is insufficient, fall back to `browser(source.url)` to render the page
4. Load `references/prompts/extract-content.md` prompt template
5. Fill template: `{extraction_type}` = "official_announcement", `{page_text}` = rendered text, `{base_url}` = source URL base
6. Call LLM with the filled prompt
7. Parse LLM response as JSON array of extracted items (title, url, snippet)
8. Map fields: `title` -> title, `url` -> url, `snippet` -> content_snippet, current timestamp -> fetched_at
9. Follow shared normalize-dedup-write pipeline (Section 2, 3, 4)

### Error Handling

- **web_fetch returns empty/short content**: Fall back to browser (not an error)
- **browser fails**: Increment `stats.consecutive_failures`, set `stats.last_error` to "browser_failed", skip source
- **LLM extraction returns invalid JSON**: Retry once. If still invalid, skip source, increment `stats.consecutive_failures`
- **LLM extraction returns empty array**: Valid response (no new announcements). Set `stats.last_hit_count` to 0

---

## Community Page Collection

### When to Use

Sources with `type: "community"`. Renders JavaScript-heavy community pages (forums, aggregators) and extracts post listings via LLM.

### Source Config Example

```json
{
  "id": "src-community-hackernews",
  "type": "community",
  "url": "https://news.ycombinator.com",
  "fetch_config": {
    "max_items": 15
  }
}
```

### Fetch Steps

1. Use `browser(source.url)` to render the page (community pages typically require JavaScript)
2. Load `references/prompts/extract-content.md` prompt template
3. Fill template: `{extraction_type}` = "community_posts", `{page_text}` = rendered text, `{base_url}` = source URL base
4. Call LLM with the filled prompt
5. Parse LLM response as JSON array of extracted items (title, url, snippet)
6. Trim results to `fetch_config.max_items` (default 15) if LLM returns more
7. Map fields: `title` -> title, `url` -> url, `snippet` -> content_snippet, current timestamp -> fetched_at
8. Follow shared normalize-dedup-write pipeline (Section 2, 3, 4)

### Error Handling

- **browser fails**: This is the primary fetch method with no fallback. Increment `stats.consecutive_failures`, set `stats.last_error` to "browser_failed", skip source for this run
- **LLM extraction returns invalid JSON**: Retry once. If still invalid, skip source, increment `stats.consecutive_failures`
- **LLM extraction returns empty array**: Valid response (page may have changed structure). Log warning, set `stats.last_hit_count` to 0
- **consecutive_failures > 3**: Source may need URL update or browser may be unreliable. Status remains `active` but source is effectively degraded

---

## Hot Ranking Collection

### When to Use

Sources with `type: "ranking"`. Fetches trending/hot lists from ranking pages (e.g., GitHub Trending, Hacker News front page rankings).

### Source Config Example

```json
{
  "id": "src-ranking-github-trending",
  "type": "ranking",
  "url": "https://github.com/trending",
  "fetch_config": {
    "prefer_browser": false,
    "max_items": 20
  }
}
```

### Fetch Steps

1. Try `web_fetch(source.url, extractMode="text")` first
2. Check result quality:
   - If result appears incomplete (< 200 chars, or missing expected ranking structure), fall back to browser
   - If `fetch_config.prefer_browser` is `true`, skip directly to browser
3. If web_fetch is insufficient, use `browser(source.url)` to render the page
4. Load `references/prompts/extract-content.md` prompt template
5. Fill template: `{extraction_type}` = "ranking_list", `{page_text}` = rendered/fetched text, `{base_url}` = source URL base
6. Call LLM with the filled prompt
7. Parse LLM response as JSON array of extracted items (title, url, snippet)
8. Trim results to `fetch_config.max_items` (default 20) if LLM returns more
9. Map fields: `title` -> title, `url` -> url, `snippet` -> content_snippet, current timestamp -> fetched_at
10. Follow shared normalize-dedup-write pipeline (Section 2, 3, 4)

### Error Handling

- **web_fetch returns incomplete content**: Fall back to browser (not an error)
- **browser fails after web_fetch fallback**: Increment `stats.consecutive_failures`, set `stats.last_error` to "browser_failed", skip source
- **LLM extraction returns invalid JSON**: Retry once. If still invalid, skip source, increment `stats.consecutive_failures`
- **LLM extraction returns empty array**: Valid response. Set `stats.last_hit_count` to 0

---

## Source Management Commands

### When to Use

When user intent is detected as source management (add, delete, enable, disable, adjust weight). Referenced from SKILL.md "User Commands" section.

### Add Source

1. Parse user description (e.g., "add LangChain GitHub releases", "monitor AI safety news")
2. Infer source type from keywords:
   - GitHub / release / repo / repository -> `github`
   - search / find / monitor / track keywords -> `search`
   - official / blog / announcement / press -> `official`
   - community / forum / reddit / discussion -> `community`
   - ranking / trending / hot / top -> `ranking`
   - RSS / feed / atom / XML -> `rss`
3. Construct source config with sensible defaults:
   - `id`: `src-{type}-{slugified-name}`
   - `weight`: 1.0
   - `credibility`: 0.5 (new sources start at neutral credibility)
   - `enabled`: false (user must explicitly enable after confirming)
   - `stats`: all zeros with `quality_score: 0.5`
   - `status`: "active"
4. For `github` type: extract owner/repo from URL or description, set `fetch_config.endpoint` to "releases" by default
5. For `search` type: extract keywords from user description, set `fetch_config.max_results` to 10
6. Present constructed source config to user for confirmation before writing to `config/sources.json`

### Delete Source

1. Match source by name (case-insensitive substring) or by ID (exact match)
2. If multiple matches, list candidates and ask user to pick
3. **ALWAYS require second confirmation** per Standing Orders: "Delete source '{name}'? This cannot be undone. Confirm yes/no."
4. On confirmation: remove source from `config/sources.json`, write atomically

### Enable / Disable Source

1. Match source by name or ID (same matching as delete)
2. Toggle the `enabled` field
3. Confirm action to user: "Source '{name}' is now {enabled/disabled}."

### Adjust Weight

1. Match source by name or ID
2. Accept relative adjustments: "increase weight of X" -> +0.2, "decrease weight" -> -0.2
3. Accept absolute adjustments: "set X weight to 0.5" -> direct set
4. Clamp result to [0.1, 2.0]
5. If single change > 0.3, escalate per Standing Orders (require human confirmation)
6. Confirm new weight to user: "Source '{name}' weight updated: {old} -> {new}."

### Input Disambiguation (SRC-10)

When user input is ambiguous, do NOT guess. Instead:

1. **Multi-meaning operations**: If "add Apple" could mean Apple Inc news (official) or Apple developer blog (official) or Apple stock (search), list 2-3 candidate interpretations:
   ```
   "add Apple" could mean:
   1. Apple Newsroom (official announcements) - https://www.apple.com/newsroom/
   2. Apple Developer Blog (official dev updates) - https://developer.apple.com/news/
   3. "Apple news" keyword search (search type)
   Please pick a number or clarify.
   ```

2. **Similar existing sources**: Before adding, check existing sources. If a source name has edit distance <= 2 or is a substring match with an existing source:
   ```
   Warning: Source "36Kr Tech" is similar to existing source "36Kr" (src-36kr).
   Did you mean to modify the existing source, or add a new one?
   ```

3. **Ambiguous type**: If type cannot be inferred from keywords, ask:
   ```
   What type of source is "TechCrunch"?
   1. RSS feed (if you have the feed URL)
   2. Official blog (web page scraping)
   3. Keyword search (search for TechCrunch articles)
   ```

---

## Section 7B: Seed Discovery Command

### Purpose

Discover new text-based news sources from a seed URL (B站 video, blog post, news article, etc.).

### Trigger

User provides a URL with intent to discover news sources. Examples:
- "从这个B站视频发现新闻源: https://b23.tv/PHDMt7f"
- "分析这个链接找新闻来源: https://example.com/news-roundup"
- "discover sources from https://..."
- "加载预取的种子发现结果" / "load pending seeds"

### Two-Phase Mode (Pre-fetched Seeds)

When the agent's network environment cannot reach certain platforms (e.g., B站 blocked by proxy/firewall), the seed discovery flow supports a **two-phase split**:

- **Phase 1 (external)**: Run locally via Claude Code or other tools with full network access. Fetch video/page metadata, extract topics, discover candidate sources via web search. Write results to `data/source-discovery/pending-seeds.json`.
- **Phase 2 (this agent)**: Read `pending-seeds.json`, skip Steps 1-4, proceed directly to Step 5 (Source Profiling) using the pre-discovered `candidate_sources` array.

**Trigger**: If `data/source-discovery/pending-seeds.json` exists and is non-empty, inform the user: "发现预取的种子发现结果（{N} 个候选源），是否直接进入源画像和确认流程？"

**Pre-fetched file format** (`data/source-discovery/pending-seeds.json`):
```json
{
  "_generated_at": "ISO timestamp",
  "_generated_by": "claude-code|manual",
  "seeds": [
    {
      "seed_url": "https://...",
      "seed_platform": "bilibili|generic",
      "up_name": "UP主 or author name",
      "topics_extracted": ["topic1", "topic2"]
    }
  ],
  "candidate_sources": [
    {
      "url": "https://example.com",
      "rss_url": "https://example.com/feed/ (or null)",
      "name": "Source Name",
      "name_zh": "中文名",
      "recommended_type": "rss|official|community|ranking|search|github",
      "topics": ["ai-models", "security"],
      "credibility_estimate": 0.85,
      "language": "en|zh|mixed",
      "update_frequency": "hourly|daily|weekly|irregular",
      "discovery_reason": "Why this source was found",
      "matched_topics": ["topic that led to discovery"]
    }
  ]
}
```

**When reading pre-fetched data**:
1. Load `pending-seeds.json`, validate structure
2. For each `candidate_sources` entry, run Step 5 (Source Profiling) if `credibility_estimate` is missing or if the agent wants to verify. Otherwise, trust the pre-fetched profiling and skip directly to Step 6 (User Confirmation)
3. After successful onboarding, rename the file to `pending-seeds.{timestamp}.done.json` to prevent re-processing
4. Record in `data/provenance/seed-analyses.jsonl` with `"generated_by"` field from the file

### Input Handling (Direct Mode)

**Step 1: URL Classification & Resolution**
1. Detect platform: bilibili (b23.tv, bilibili.com, space.bilibili.com), youtube, twitter, weibo, generic
2. For short URLs (b23.tv, t.co): resolve via HTTP redirect to full URL
3. Determine bilibili URL type:
   - **Video URL** (`bilibili.com/video/BVxxx`): extract BV number -> call bilibili video API (`api.bilibili.com/x/web-interface/view?bvid={bvid}`) via `web_fetch`
   - **Space/User URL** (`space.bilibili.com/{mid}` or `bilibili.com/space/{mid}`): extract member ID (mid) -> call user card API (`api.bilibili.com/x/web-interface/card?mid={mid}`) to get UP主 name -> use `web_search("{UP主name} bilibili 最新", allowed_domains=["bilibili.com"])` to find recent videos -> pick top 3 video URLs -> for each, extract BV number and call video API
4. For generic URLs: `web_fetch(url)` to get page content
5. **Fallback**: If bilibili API fails (403/timeout), fallback to `web_fetch` of the video page HTML and extract title/description from meta tags. If space API rate-limited, fallback to `web_search` with UP主 name from URL.

**Step 2: Content Extraction**
1. For bilibili video: use API response fields (title, desc, tag list, tname)
2. For bilibili space: aggregate fields from top 3 recent videos (merge titles, descriptions, tags)
3. For generic URL: extract title (og:title or `<title>`), description (og:description or meta description), main content (first ~2000 chars)
4. **Sanitize**: Truncate description/content to 2000 characters max
5. Extract all URLs found in the content
6. **Title-only fallback**: If description is empty or very short (< 30 chars), set `title_only_mode: true`. In this mode, Step 3 relies solely on the title for topic extraction. Titles like "阿里千问正式发布Qwen3.6-Plus；Gemma 4 即将发布 | AI日报0402" contain enough signal for topic extraction. When multiple videos are aggregated (space URL), combine all titles into a single text block for richer extraction.

**Step 3: Topic Extraction (LLM)**
1. Read `references/prompts/seed-extract.md`
2. Wrap content in `<seed_content>` tags to isolate from prompt instructions
3. Call LLM with title + description + tags
4. Output: 3-8 news topics with search queries, extracted URLs with classification
5. Budget: 1 LLM call

**Step 4: Source Discovery**
1. For each topic (max 5 topics to search):
   - `web_search(topic.search_query, max_results=5)`
   - Collect unique domains from results
2. For extracted URLs classified as "news_source":
   - `web_fetch` each URL to verify accessibility
3. Merge all candidate URLs, deduplicate by domain
4. Exclude URLs whose domain matches any existing enabled source in `config/sources.json`
5. Cap at 15 candidate sources maximum

**Step 5: Source Profiling (LLM)**
1. For each candidate (batch up to 5 per LLM call):
   - `web_fetch(candidate_url)` to get sample content (~1000 chars)
   - Read `references/prompts/source-profile.md`
   - Wrap content in `<candidate_content>` tags
   - LLM evaluates: type, credibility, topics, overlap, recommendation
2. Filter: keep only candidates with `recommendation: "add"` or `"review"`
3. Budget: 1 LLM call per 5 candidates (max 3 calls = 15 candidates)

**Step 6: User Confirmation**
1. Present candidate list to user in readable format:
   ```
   发现 N 个候选新闻源:

   1. [推荐添加] SourceName (rss) — https://example.com/feed.xml
      话题: ai-models, dev-tools | 可信度: 0.8 | 更新频率: daily
      推荐理由: ...

   2. [建议审查] AnotherSource (official) — https://another.com/blog
      话题: tech-products | 可信度: 0.6 | 与现有源重叠: src-36kr
      审查理由: ...
   ```
2. Wait for user to confirm which sources to add
3. User can say "全部添加", "添加 1,3", "跳过", etc.

**Step 7: Source Onboarding**
1. **Check pipeline lock**: If `.lock` file exists and is fresh (< 15 min), inform user that pipeline is running and suggest waiting
2. For each confirmed source, generate source config entry following existing Source schema:
   - `id`: auto-generate (e.g., `src-{domain-slug}`)
   - `name`: from profiling result
   - `type`: from profiling result (rss/official/community/ranking/search/github)
   - `url`: from profiling result (recommended_url or rss_url if available)
   - `weight`: from profiling result (suggested_weight)
   - `credibility`: from profiling result (credibility_estimate)
   - `topics`: from profiling result
   - `enabled`: false (user must explicitly enable -- respect Standing Orders)
   - `auto_discovered`: true
   - `auto_discovered_at`: current ISO timestamp
   - `discovery_domain`: extracted domain
   - `discovery_decision`: "seed_confirmed"
   - `discovery_decided_at`: current ISO timestamp
   - `fetch_config`: from profiling hints
   - `stats`: initialize empty (total_fetched: 0, etc.)
3. Present constructed source config to user for final confirmation
4. Atomic write to `config/sources.json` (load -> append -> write via tmp + rename)
5. Also register in `data/provenance/discovered-sources.json`:
   - Add entry with `discovery_origin: "seed"`, `seed_url: "{original_input_url}"`
   - `seed_platform`: platform string ("bilibili", "youtube", or "generic")
   - `decision_history`: append `{"ts": "ISO timestamp", "decision": "seed_confirmed", "reason": "user confirmed from seed analysis", "details": null}`

**Step 8: Record & Report**
1. Append analysis record to `data/provenance/seed-analyses.jsonl`:
   ```json
   {
     "run_id": "seed-YYYYMMDD-HHmmss",
     "seed_url": "...",
     "seed_platform": "bilibili|generic",
     "seed_title": "视频/页面标题",
     "analyzed_at": "ISO timestamp",
     "topics_found": 5,
     "topics": ["AI模型", "开源项目", "..."],
     "candidates_found": 12,
     "candidates_confirmed": 3,
     "sources_added": ["src-xxx", "src-yyy"],
     "llm_calls_used": 5,
     "status": "completed",
     "error": null
   }
   ```
2. Update `config/budget.json`: increment `seed_calls_today` counter
3. Report to user: "已添加 N 个新闻源（默认未启用）。使用 'enable src-xxx' 来启用。"

### Budget Controls

- Check `config/budget.json` field `seed_calls_today` before starting
- Max 2 seed analyses per day (`seed_daily_limit: 2` in budget.json)
- Max 30 LLM calls per analysis
- If daily pipeline budget usage > 80%, warn user but allow proceeding
- Seed discovery LLM calls count toward `calls_today` in budget.json

### Error Handling

- URL resolution failure -> inform user, suggest checking URL
- Bilibili API failure -> fallback to page HTML meta extraction
- web_search returns no results for a topic -> skip that topic, continue
- All candidates already exist -> inform user "所有发现的源已在配置中"
- Pipeline lock active -> inform user, suggest waiting

### Repeat Analysis Detection

Before Step 1, check `data/provenance/seed-analyses.jsonl` for same `seed_url` within 7 days.
If found: "此URL已于 {date} 分析过，发现了 N 个源。是否重新分析？"

---

## Source Health Metrics Computation

### When to Compute

After each pipeline run, during the Processing Phase (after item processing, before output generation). Referenced from SKILL.md Processing Phase step "Compute source stats".

### Metrics Formula

For each source that contributed items in the current run, compute updated stats using the last 7 days of data:

**Data source:** Read `per_source` from `data/metrics/daily-YYYY-MM-DD.json` for each of the last 7 days. For each source_id, the `per_source[source_id]` object provides `fetched`, `deduped`, `title_deduped`, `selected`, `status`, and `error` fields. See `references/data-models.md` DailyMetrics schema for field definitions. If a metrics file lacks `per_source` (pre-Phase-6 files), treat as empty dict -- that source has no data for that day.

**selection_rate** = items_selected_for_output / total_fetched
- `items_selected_for_output`: sum of `per_source[source_id].selected` across last 7 days of daily metrics
- `total_fetched`: sum of `per_source[source_id].fetched` across last 7 days of daily metrics

**dedup_rate** = items_deduped / total_fetched
- `items_deduped`: sum of `per_source[source_id].deduped` across last 7 days of daily metrics
- `total_fetched`: same as above

**fetch_success_rate** = successful_fetches / total_fetch_attempts
- `successful_fetches`: count of days where `per_source[source_id].status == 'success'` across last 7 days of daily metrics
- `total_fetch_attempts`: count of days where `source_id` appears in `per_source` across last 7 days of daily metrics

**quality_score** = selection_rate * 0.4 + (1 - dedup_rate) * 0.3 + fetch_success_rate * 0.3

### Minimum Data Requirement

If `total_fetched < 7` for a source (insufficient data for meaningful rates):
- Keep all rates at 0.5 (neutral default)
- `quality_score` remains at 0.5
- Do NOT recompute until the source accumulates at least 7 fetched items

### Write-Back Procedure

1. Read current `config/sources.json`
2. For each source with updated stats:
   - Update `stats.quality_score`, `stats.dedup_rate`, `stats.selection_rate`
   - Update `stats.total_fetched`, `stats.last_fetch`, `stats.last_hit_count`
   - Reset `stats.consecutive_failures` to 0 on successful fetch
3. Write updated `config/sources.json` atomically (write `.tmp.{run_id}`, then rename)

---

## Degraded Source Handling

### Collection Behavior for Degraded Sources

Sources with `status: "degraded"` are still fetched during collection, with two exceptions:

1. **Budget-tight skip**: If budget effective_usage >= 0.8 (circuit-breaker warning threshold), skip degraded sources entirely during collection. Prioritize healthy sources for remaining budget. Log: "Budget tight ({pct}%): skipping degraded source {name}".
2. **All other runs**: Collect degraded sources normally. Their items receive a scoring penalty (0.5x source_trust dimension) but are otherwise processed through the full pipeline.

### Source Management Display

When displaying source lists to the user (source management commands), include degraded status:
- Active sources: normal display
- Degraded sources: append " (degraded since {date})" to display
- Paused sources: append " (paused)" to display

### Manual Override

User can manually re-activate a degraded source via "activate {source_name}" or "restore {source_name}" command. This sets `status: "active"`, resets `degraded_since` and `recovery_streak_start` to null. Log: "Source {name} manually reactivated by user."
