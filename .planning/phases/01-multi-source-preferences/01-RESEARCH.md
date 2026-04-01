# Phase 1: Multi-Source + Preferences - Research

**Researched:** 2026-04-01
**Domain:** Multi-source news collection, user preference system, feedback learning, LLM caching, breaking news alerts, cost control
**Confidence:** HIGH

## Summary

Phase 1 expands the Phase 0 single-RSS pipeline into a multi-source system with 5 new source types (GitHub, search, official announcements, community pages, hot rankings), adds the full 5-layer preference model with feedback learning, implements breaking news alerts, and introduces LLM result caching with cost circuit-breakers. The project runs as an OpenClaw Skill (not standalone code), meaning all "implementation" is authoring instruction documents (references/*.md), prompt templates (references/prompts/*.md), config schemas (config/*.json), and orchestration logic (SKILL.md). There is no application code -- the OpenClaw agent interprets SKILL.md instructions at runtime and uses platform tools (web_fetch, browser, web_search, read, write, cron, message).

Phase 0 delivered a structurally complete Skill with RSS collection, LLM classification/summarization, scoring, and daily digest output. Phase 1 must extend existing files (SKILL.md collection/processing/output phases, data-models.md source schema, scoring-formula.md feedback_boost dimension, output-templates.md footer stats) and create new reference documents (collection instructions for each new source type, feedback-rules.md, cache instructions). The source.json schema already supports `type`, `stats`, `status`, and `fetch_config` fields designed for multi-source expansion. The preferences.json already has the 5-layer structure with cold-start defaults. The budget.json already tracks calls/tokens but lacks the circuit-breaker enforcement logic.

**Primary recommendation:** Organize Phase 1 into 4 plans: (1) multi-source collection infrastructure + new source type instructions, (2) feedback system + preference update rules, (3) LLM cache + cost circuit-breaker + tiered model strategy, (4) breaking news alerts + output transparency stats. This decomposition isolates source expansion, preference learning, cost control, and output features into independently completable units.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SRC-02 | GitHub Release/Repo collection (GitHub API JSON) | New collection instruction section; web_fetch GitHub API; source schema type="github" with fetch_config for owner/repo/token |
| SRC-03 | Search-based collection (web_search + LLM filtering) | New collection instruction section; web_search tool; LLM filter prompt to discard irrelevant results |
| SRC-04 | Official announcement collection (web_fetch or browser + LLM extraction) | New collection instruction section; web_fetch preferred, browser fallback; LLM extraction prompt |
| SRC-05 | Community page collection (browser rendering + LLM extraction) | New collection instruction section; browser tool required; LLM extraction prompt |
| SRC-06 | Hot ranking collection (web_fetch or browser + LLM extraction) | New collection instruction section; dual-mode fetch; LLM ranking extraction prompt |
| SRC-07 | Natural language source management (add/delete/enable/disable/adjust weight) | New reference doc for source management commands; SKILL.md feedback instructions section; disambiguation rules |
| SRC-08 | Source health metrics (quality_score, dedup_rate, selection_rate auto-calculation) | Extend processing-instructions.md with post-run stats computation; formula from design doc section 7.5 |
| SRC-10 | Input disambiguation (ambiguous operations prompt for confirmation, similar sources list candidates) | Part of SRC-07 source management reference; disambiguation rules from design doc section 7.2 |
| PREF-01 | 5-layer preference model (topic weights + source trust + form preference + style tolerance + sample feedback) | preferences.json already has structure; new reference doc feedback-rules.md documents layer interactions |
| PREF-03 | 7-dimension personalization scoring formula (activate feedback_boost dimension) | Extend scoring-formula.md to document feedback_boost computation from liked/disliked samples |
| PREF-05 | Preference auto-backup (backup before update, retain last 10) | Document backup procedure in feedback-rules.md; backup path data/feedback/backup/ |
| OUT-02 | Breaking news output (importance >= 0.85 trigger, no output when nothing qualifies) | New breaking news instruction in SKILL.md; extend output-templates.md with kuaixun template activation; cron quick-check job already configured |
| OUT-06 | Runtime transparency (footer shows source count, items processed, LLM calls, cache hits) | Extend output-templates.md footer; wire metrics counters to digest generation |
| FB-01 | 8 feedback types (more/less/trust_source/distrust_source/like/dislike/block_pattern/adjust_style) | New reference doc feedback-rules.md with type-to-preference mapping table |
| FB-02 | Incremental preference update (read unprocessed feedback -> apply in time order -> atomic write) | Document update procedure in feedback-rules.md; timestamp comparison against preferences.last_updated |
| FB-03 | Feedback reference disambiguation (message reply -> sequence number -> keyword search -> event reference -> list candidates) | Document disambiguation cascade in feedback-rules.md |
| FB-04 | Kill Switch (feedback_processing_enabled: false freezes preference updates) | preferences.json already has the field; document check in feedback-rules.md processing flow |
| FB-05 | Large adjustment escalation (single change > 0.3 requires human confirmation) | Document threshold check in feedback-rules.md; aligns with Standing Orders escalation conditions |
| COST-02 | Circuit-breaker (80% alert, 100% stop non-essential LLM calls, preserve daily digest generation) | Extend processing-instructions.md budget section with circuit-breaker logic; extend SKILL.md processing phase |
| COST-03 | LLM result cache (classify-cache + summary-cache, URL SHA key, 7-day TTL) | New cache reference doc or extend processing-instructions.md; cache file schema; lookup-before-call pattern |
| COST-04 | Tiered model strategy (simple tasks use fast model, complex tasks use strong model) | Document model selection guidance in processing-instructions.md or a new reference |
</phase_requirements>

## Standard Stack

This is an OpenClaw Skill project -- there are no npm packages, no application code, and no build system. The "stack" consists of platform tools, file formats, and authoring conventions.

### Core Platform Tools

| Tool | Purpose | Phase 1 Usage |
|------|---------|---------------|
| `web_fetch` | HTTP GET with text/JSON extraction | RSS (existing), GitHub API JSON, official announcement pages |
| `browser` | Headless browser page rendering | Community pages, ranking pages, official announcements (fallback) |
| `web_search` | Keyword search returning results | Search-type sources with LLM filtering |
| `read` / `write` | Workspace file I/O | All config, data, reference document access |
| `cron` | Scheduled job execution | Daily digest (existing), quick-check for breaking news (activate) |
| `message` + `delivery` | Chat channel push | Digest delivery (existing), breaking news alerts |
| `exec` | Shell script execution | Health check, data archive (existing) |

### File Formats

| Format | Files | Convention |
|--------|-------|------------|
| JSON | config/*.json, data/cache/*.json, data/events/*.json | Pretty-printed, atomic write (tmp + rename) |
| JSONL | data/news/YYYY-MM-DD.jsonl, data/feedback/log.jsonl | One record per line, append-only for logs |
| Markdown | references/*.md, output/*.md, SKILL.md | Instruction documents for agent consumption |

### Authoring Conventions (from Phase 0)

| Convention | Rule |
|------------|------|
| SKILL.md size | < 3000 tokens; flow skeleton only; details in references/ |
| Schema versioning | `_schema_v` field on all JSON records; bump version when adding fields; readers apply defaults for missing fields |
| Atomic writes | Always write to `.tmp.{run_id}` then rename to target |
| File lock | Acquire-or-skip at pipeline start; 15 min expiry |
| Crash recovery | On startup, delete `data/**/*.tmp.*` older than 15 min |
| LLM prompts | Return ONLY valid JSON arrays; no markdown fencing |
| Reference loading | Agent reads reference docs on demand per phase; never load all at once |

## Architecture Patterns

### Phase 1 File Changes Map

```
SKILL.md                              # EXTEND: add source-type routing, feedback section, cache check, breaking news check
references/
  collection-instructions.md          # EXTEND: add sections for GitHub, search, official, community, ranking
  processing-instructions.md          # EXTEND: add cache lookup/write, circuit-breaker enforcement, source stats computation
  scoring-formula.md                  # EXTEND: activate feedback_boost computation
  output-templates.md                 # EXTEND: activate breaking news template, add transparency footer wiring
  feedback-rules.md                   # NEW: feedback type mapping, preference update procedure, disambiguation, backup, kill switch
  data-models.md                      # EXTEND: update Source schema for new types, add FeedbackEntry, add CacheEntry
  prompts/
    filter-search.md                  # NEW: LLM prompt for filtering web_search results
    extract-content.md                # NEW: LLM prompt for extracting structured data from web pages (official/community/ranking)
config/
  sources.json                        # EXTEND: add example sources for each new type
data/
  cache/
    classify-cache.json               # NEW: URL SHA -> classification result cache
    summary-cache.json                # NEW: URL SHA -> summary result cache
  feedback/
    backup/                           # NEW: preference backup directory (retain last 10)
```

### Pattern 1: Source-Type Routing in SKILL.md

**What:** SKILL.md collection phase routes to different fetch strategies based on `source.type`.
**When to use:** Every collection run must handle multiple source types.

The routing pattern extends SKILL.md step 4 from "Fetch RSS" to a type-based dispatch:

```
For each enabled source:
  If type == "rss":     -> web_fetch XML, parse RSS/Atom (existing logic)
  If type == "github":  -> web_fetch GitHub API JSON, parse releases
  If type == "search":  -> web_search keywords, LLM filter results
  If type == "official": -> web_fetch (or browser if dynamic), LLM extract
  If type == "community": -> browser render, LLM extract
  If type == "ranking":  -> web_fetch (or browser), LLM extract rankings
```

Each branch references its collection instruction section for detailed steps. The post-fetch pipeline (normalize URL, dedup, write JSONL) is shared across all types.

### Pattern 2: Cache-Before-Call for LLM Operations

**What:** Before making any LLM classify or summarize call, check the cache file for a hit by URL SHA.
**When to use:** Every processing phase batch.

```
For each item in batch:
  url_sha = SHA256(normalized_url)[:16]
  cached = lookup classify-cache.json[url_sha]
  If cached AND cached.cached_at < 7 days ago:
    Apply cached result, skip LLM call
    Increment metrics.llm.cache_hits
  Else:
    Include in LLM batch
After LLM call:
  Write results to cache with current timestamp
```

### Pattern 3: Incremental Feedback Application

**What:** On each pipeline run, read unprocessed feedback entries and apply them to preferences incrementally.
**When to use:** At the start of the processing phase, before scoring.

```
1. Read preferences.json
2. If feedback_processing_enabled == false: skip
3. Read data/feedback/log.jsonl
4. Filter entries where timestamp > preferences.last_updated
5. Sort by timestamp ascending
6. For each entry:
   - Check if single adjustment > 0.3 threshold -> escalate to user
   - Apply adjustment per feedback-rules.md mapping table
   - Clamp values to valid ranges
7. Backup current preferences to data/feedback/backup/
8. Atomic write updated preferences.json
```

### Pattern 4: GitHub API Collection

**What:** Fetch GitHub releases or repository activity via the public API.
**When to use:** Sources with `type: "github"`.

The source `fetch_config` carries repository-specific parameters:

```json
{
  "id": "src-github-langchain",
  "type": "github",
  "url": "https://api.github.com/repos/langchain-ai/langchain/releases",
  "fetch_config": {
    "owner": "langchain-ai",
    "repo": "langchain",
    "endpoint": "releases",
    "per_page": 10
  }
}
```

Collection steps:
1. `web_fetch` the API URL with `extractMode: "text"`
2. Parse JSON array of release objects
3. Map: `name` -> title, `html_url` -> url, `body` (truncated) -> content_snippet, `published_at` -> published_at
4. Follow shared normalize-dedup-write pipeline

**Rate limit consideration:** GitHub public API allows 60 requests/hour unauthenticated. With 5-10 GitHub sources fetched every 2 hours (quick-check) or once daily, this is well within limits. If authenticated token available, store in `fetch_config.token` for 5000 req/hour.

### Pattern 5: Search Source with LLM Filtering

**What:** Use web_search to find news, then LLM-filter for relevance.
**When to use:** Sources with `type: "search"`.

```json
{
  "id": "src-search-ai-safety",
  "type": "search",
  "url": "",
  "fetch_config": {
    "keywords": ["AI safety regulation 2026", "AI alignment research"],
    "max_results": 10,
    "filter_prompt": "Keep only results that are genuine news or analysis about AI safety. Discard product ads, forum posts, and irrelevant results."
  }
}
```

Collection steps:
1. For each keyword in `fetch_config.keywords`: call `web_search(keyword)`
2. Collect all result URLs and titles
3. Pass to LLM with filter prompt from `references/prompts/filter-search.md`
4. LLM returns a JSON array of kept results with title/url/snippet
5. Follow shared normalize-dedup-write pipeline

### Pattern 6: Browser-Based Extraction (Community/Ranking)

**What:** Use browser tool to render JavaScript-heavy pages, then LLM-extract structured items.
**When to use:** Sources with `type: "community"` or `type: "ranking"`.

```
1. browser(url=source.url) -> rendered page content
2. Pass rendered text to LLM with extract-content.md prompt
3. LLM returns JSON array of extracted items (title, url, snippet)
4. Follow shared normalize-dedup-write pipeline
```

The `extract-content.md` prompt must be parameterized for the expected page structure (ranking list, forum thread list, announcement list).

### Anti-Patterns to Avoid

- **Separate SKILL.md per source type:** All source types live in the SAME SKILL.md with type-based routing. The design doc explicitly warns: "Do not break source expansion into infinitely fragmented Skill list."
- **Full-text storage:** Never store the full web page content. Extract title, URL, and a content_snippet (max ~500 chars) for LLM processing.
- **Eager context loading:** Do not load all reference documents at pipeline start. Load collection instructions during collection, processing instructions during processing, output templates during output.
- **Synchronous feedback processing in output phase:** Process feedback at the START of the processing phase (before scoring), not during output generation.
- **Cache without TTL:** Always check `cached_at` age against the 7-day TTL. Never serve stale cache entries.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| RSS/Atom parsing | Custom XML parser | `web_fetch` text mode + known field extraction, or `exec` feedparser fallback | RSS has many quirks (CDATA, Atom vs RSS 2.0, missing fields); Phase 0 already documents handling |
| GitHub API pagination | Manual next-page logic | Single `per_page=10` request for releases endpoint | Most repos have < 10 releases in any period; pagination adds complexity for minimal gain in Phase 1 |
| URL normalization | Per-source-type normalizer | Shared 6-rule normalizer from Phase 0 collection-instructions.md | All source types produce URLs that need the same normalization |
| Preference backup rotation | Custom rotation logic | Simple "list backups sorted by name, delete oldest if count > 10" | File system operations are straightforward; no need for complex rotation |
| Feedback type parsing | Regex-based NL parser | Let the OpenClaw agent's built-in NL understanding interpret user intent, map to 8 types | The agent is an LLM -- it can understand "this source is great" as `trust_source` without custom parsing |

**Key insight:** This is a Skill authoring project, not a software engineering project. The "implementation" is writing clear instructions that the agent follows. Complexity comes from unclear instructions, not from code bugs.

## Common Pitfalls

### Pitfall 1: SKILL.md Token Budget Explosion
**What goes wrong:** Adding instructions for 5 new source types, feedback processing, cache checks, and breaking news directly into SKILL.md pushes it far beyond the 3000-token target.
**Why it happens:** Natural tendency to put all logic in the main instruction file.
**How to avoid:** SKILL.md contains ONLY the routing skeleton ("If type == github: read references/collection-instructions.md Section N"). All detailed steps live in reference documents loaded on demand.
**Warning signs:** SKILL.md exceeds ~600 words (current is 499 words). Count words after each edit.

### Pitfall 2: Breaking News False Positives
**What goes wrong:** Quick-check cron job fires alerts for items that are not truly breaking, annoying the user.
**Why it happens:** importance_score is LLM-assigned and can be inconsistent across runs. A threshold of 0.85 might be hit by routine news if the classification prompt is not calibrated.
**How to avoid:** The design doc explicitly states "no alert fires when nothing qualifies" and "kuaixun threshold is conservative, preferring to miss rather than false-alarm." Add explicit guidance in the classification prompt about what constitutes 0.85+ importance. Consider requiring BOTH importance >= 0.85 AND primary category == "breaking" for alerts.
**Warning signs:** Alerts firing more than once per day on average.

### Pitfall 3: Feedback Loop Runaway
**What goes wrong:** User gives several "more AI" feedback signals in quick succession, topic_weight shoots to 1.0, and the digest becomes a mono-topic feed.
**Why it happens:** Each feedback applies +0.1 independently; 5 rapid feedbacks = +0.5 in one session.
**How to avoid:** FB-05 requires escalation when single change > 0.3. But multiple small changes can sum past this. Document a per-session cumulative cap (e.g., max +0.3 net change to any single weight per pipeline run) in feedback-rules.md.
**Warning signs:** Any topic_weight reaching 0.9+ or 0.1- within the first 2 weeks.

### Pitfall 4: Cache Key Collision Across Source Types
**What goes wrong:** Different source types produce different content_snippets for the same URL, but cache returns the first one seen.
**Why it happens:** Cache key is URL SHA only. A GitHub release page URL fetched via API gives structured JSON, while the same URL fetched as a web page gives HTML.
**How to avoid:** This is actually fine for the current design -- cache stores classification and summary results based on the news item, not the raw fetch. The item is deduplicated by URL before processing, so only one version enters the pipeline. Document this explicitly in the cache reference.
**Warning signs:** None expected if dedup runs before cache lookup.

### Pitfall 5: Browser Tool Instability
**What goes wrong:** Community and ranking sources that depend on `browser` tool fail intermittently, producing empty results or timeouts.
**Why it happens:** The design doc lists browser stability as an unverified platform capability (to be tested in Phase 1).
**How to avoid:** Always provide a web_fetch fallback for ranking/official sources. For community sources that truly require rendering, document graceful degradation: if browser fails, skip the source for this run and increment `consecutive_failures`.
**Warning signs:** Source `consecutive_failures` > 3 for browser-dependent sources.

### Pitfall 6: LLM Cache Grows Unbounded
**What goes wrong:** classify-cache.json and summary-cache.json grow indefinitely as new URLs are processed daily.
**Why it happens:** Only a 7-day TTL is defined but no cleanup mechanism is specified.
**How to avoid:** Add cache cleanup to the pipeline: at the start of each run (or weekly via health-check), scan cache entries and delete those where `cached_at` is > 7 days old. This mirrors the dedup-index 7-day window.
**Warning signs:** Cache files exceeding 1MB (roughly 3000+ entries).

### Pitfall 7: Source Stats Division by Zero
**What goes wrong:** quality_score formula divides by total_fetched or uses rates that are undefined when a source is newly added.
**Why it happens:** New sources have `total_fetched: 0`, making rate calculations impossible.
**How to avoid:** Initialize quality_score at 0.5 (already done in Phase 0 source schema). Only recompute stats after the source has at least 7 days of data. Document the minimum data requirement in the stats computation section.
**Warning signs:** quality_score of 0 or NaN on newly added sources.

## Code Examples

Since this is a Skill project, "code examples" are instruction document patterns and JSON schemas.

### Source Schema Extension for New Types

Source: gpt-plan-v3.md section 7.1 + existing config/sources.json

```json
{
  "id": "src-github-langchain",
  "name": "LangChain Releases",
  "type": "github",
  "url": "https://api.github.com/repos/langchain-ai/langchain/releases",
  "weight": 1.0,
  "credibility": 0.9,
  "topics": ["ai-models", "dev-tools"],
  "enabled": true,
  "fetch_config": {
    "owner": "langchain-ai",
    "repo": "langchain",
    "endpoint": "releases",
    "per_page": 10
  },
  "stats": {
    "total_fetched": 0,
    "last_fetch": null,
    "last_hit_count": 0,
    "avg_daily_items": 0,
    "consecutive_failures": 0,
    "last_error": null,
    "quality_score": 0.5,
    "dedup_rate": 0.0,
    "selection_rate": 0.0
  },
  "status": "active"
}
```

### Search Source Schema

```json
{
  "id": "src-search-ai-regulation",
  "name": "AI Regulation News",
  "type": "search",
  "url": "",
  "weight": 0.8,
  "credibility": 0.6,
  "topics": ["macro-policy", "ai-models"],
  "enabled": true,
  "fetch_config": {
    "keywords": ["AI regulation news 2026", "artificial intelligence policy"],
    "max_results": 10
  },
  "stats": { "total_fetched": 0, "last_fetch": null, "last_hit_count": 0, "avg_daily_items": 0, "consecutive_failures": 0, "last_error": null, "quality_score": 0.5, "dedup_rate": 0.0, "selection_rate": 0.0 },
  "status": "active"
}
```

### Cache Entry Schema

Source: gpt-plan-v3.md section 4.5

```json
// classify-cache.json
{
  "a1b2c3d4e5f6a7b8": {
    "primary": "ai-models",
    "tags": ["llm", "benchmark"],
    "importance_score": 0.7,
    "form_type": "news",
    "cached_at": "2026-04-01T08:00:00Z"
  }
}

// summary-cache.json
{
  "a1b2c3d4e5f6a7b8": {
    "summary": "OpenAI released GPT-5...",
    "cached_at": "2026-04-01T08:00:00Z"
  }
}
```

### Feedback Type Mapping Table

Source: gpt-plan-v3.md section 14.1

```
| Type             | Example           | Target Field                | Adjustment |
|------------------|-------------------|-----------------------------|------------|
| more             | "more AI news"    | topic_weights[topic]        | +0.1       |
| less             | "less gaming"     | topic_weights[topic]        | -0.1       |
| trust_source     | "this source good" | source_trust[source_id]    | +0.15      |
| distrust_source  | "downgrade this"  | source_trust[source_id]    | -0.2       |
| like             | "this one is good" | feedback_samples.liked_items | append + micro-adjust related topic +0.05 |
| dislike          | "don't want this" | feedback_samples.disliked_items | append + micro-adjust related topic -0.05 |
| block_pattern    | "no clickbait"   | form_preference + blocked_patterns | form -0.2, record pattern |
| adjust_style     | "more exploration" | style.*                    | direct set |
```

### Feedback Boost Scoring Computation

Source: gpt-plan-v3.md section 9.3

```
feedback_boost calculation:
1. Check if item's primary category matches any liked_item's category -> +0.3
2. Check if item's source_id is in trusted_sources -> +0.2
3. Check if item's primary category matches any disliked_item's category -> -0.3
4. Check if item's source_id is in distrusted_sources -> -0.2
5. Clamp result to [0, 1]
6. If no feedback data exists (cold start): feedback_boost = 0

Note: This is a simplified heuristic. The design doc says "based on liked/disliked sample category similarity."
The exact formula should be documented in scoring-formula.md with this level of specificity.
```

### Quality Score Computation for Source Health

Source: gpt-plan-v3.md section 7.5

```
quality_score = selection_rate * 0.4 + (1 - dedup_rate) * 0.3 + fetch_success_rate * 0.3

Where:
- selection_rate = items_selected_for_output / total_fetched (last 7 days)
- dedup_rate = items_deduped / total_fetched (last 7 days)
- fetch_success_rate = successful_fetches / total_fetch_attempts (last 7 days)

All rates default to 0.5 if total_fetched < 7 (insufficient data).
```

### Circuit-Breaker Logic

Source: gpt-plan-v3.md section 4.3

```
Before each LLM batch:
  Read budget.json
  usage_ratio = calls_today / daily_llm_call_limit

  If usage_ratio >= 1.0:
    CIRCUIT BREAK: Stop all LLM processing
    EXCEPTION: Daily digest output generation is exempt (1 call)
    Leave remaining items as processing_status: "raw"
    Log "circuit breaker activated" to metrics

  If usage_ratio >= alert_threshold (0.8):
    Log warning: "LLM budget at {percentage}%"
    CONTINUE processing (warning only)
    Include warning in next digest footer
```

## State of the Art

| Phase 0 Approach | Phase 1 Approach | What Changes |
|------------------|------------------|--------------|
| Single RSS source type | 6 source types (rss, github, search, official, community, ranking) | SKILL.md needs type-routing; collection-instructions.md needs 5 new sections |
| feedback_boost = 0 (hardcoded) | feedback_boost computed from liked/disliked samples | scoring-formula.md needs activation; preferences.json feedback_samples populated by feedback loop |
| event_boost = 0 (hardcoded) | event_boost still 0 (Phase 2) | No change for Phase 1 |
| No cache | classify-cache.json + summary-cache.json with 7-day TTL | New cache files; processing-instructions.md cache-check-before-call pattern |
| Budget tracking only (log calls/tokens) | Budget enforcement (80% warning, 100% circuit-breaker) | processing-instructions.md gains enforcement logic |
| No feedback processing | 8 feedback types -> incremental preference update | New feedback-rules.md reference; SKILL.md gains feedback instructions section |
| No breaking news | Quick-check cron fires alerts for importance >= 0.85 | Activate existing cron config from cron-configs.md; SKILL.md gains breaking news check flow |
| No output stats footer | Footer shows source count, items processed, LLM calls, cache hits | output-templates.md footer already has the template but wiring needs activation |
| Source stats exist but never updated | quality_score, dedup_rate, selection_rate auto-computed after each run | processing-instructions.md gains post-run stats computation step |

## Open Questions

1. **Browser tool stability for community/ranking sources**
   - What we know: Platform verification checklist (Phase 0) lists browser as "to be tested in Phase 1." The design doc provides fallback to web_fetch.
   - What's unclear: Whether browser tool works reliably on JavaScript-heavy pages in the OpenClaw environment.
   - Recommendation: Implement community and ranking sources with explicit browser-failure fallback. If browser is unreliable, these two source types degrade to web_fetch static parsing or are skipped. Do not block Phase 1 completion on browser reliability.

2. **Tiered model strategy specifics (COST-04)**
   - What we know: The design doc says "simple tasks use fast model, complex tasks use strong model." The OpenClaw platform presumably supports model selection in LLM calls.
   - What's unclear: How the agent specifies which model to use for a given task within SKILL.md instructions. Is it via a parameter in the prompt, a system setting, or something else?
   - Recommendation: Document the model tier mapping (classify/summarize = fast model; event merge/weekly report = strong model) in the reference doc. If the platform does not support explicit model selection, note this as a future optimization and use the default model for all tasks.

3. **Feedback entry point mechanics**
   - What we know: Users interact via chat. The agent receives natural language messages. Feedback-rules.md will document type mapping.
   - What's unclear: How does the agent distinguish between a feedback message ("I like this article") and a query ("what happened with AI today")? Is this handled by the OpenClaw platform's intent routing, or must SKILL.md instructions include disambiguation logic?
   - Recommendation: Document in SKILL.md that when the agent detects user feedback intent (keywords like "more/less/like/dislike/trust/block"), it should log to feedback/log.jsonl and confirm the action. For ambiguous inputs, ask the user to clarify. The platform's NL understanding handles intent classification naturally.

4. **Search source freshness**
   - What we know: web_search returns results but may include old content.
   - What's unclear: Whether web_search supports date-range filtering or if freshness filtering must be done post-search via LLM.
   - Recommendation: Include date-range keywords in search queries (e.g., "AI safety news 2026") and have the LLM filter prompt discard results older than 48 hours based on visible dates.

## Sources

### Primary (HIGH confidence)
- gpt-plan-v3.md -- Full design specification, reviewed by 6 AI models. Sections 4.3 (cost), 4.5 (cache), 5.4-5.5 (preference/feedback models), 7.1-7.5 (source types/management/health), 9 (preference system), 13 (output), 14 (feedback learning)
- Existing codebase -- SKILL.md, config/*.json, references/*.md, data-models.md all read directly from workspace

### Secondary (MEDIUM confidence)
- GitHub API documentation (general knowledge) -- public releases endpoint format, rate limits (60/hr unauthenticated, 5000/hr authenticated)

### Tertiary (LOW confidence)
- OpenClaw platform browser tool reliability -- listed as unverified in platform-verification.md; must be tested during Phase 1 execution
- OpenClaw model selection mechanics -- unclear how to specify model tier in agent instructions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - This is a well-documented Skill project; all tools and formats are specified in the design doc and Phase 0 implementation
- Architecture: HIGH - Phase 0 established clear patterns (reference docs, SKILL.md routing, atomic writes, schema versioning); Phase 1 extends these patterns
- Source collection: HIGH for RSS/GitHub (well-understood APIs), MEDIUM for search/official/community/ranking (depends on platform tool behavior)
- Feedback system: HIGH - Design doc section 14 provides complete specification
- Cost control: HIGH - Design doc section 4.3/4.5 provides complete specification
- Pitfalls: HIGH - Derived from design doc review, Phase 0 verification findings, and analysis of interaction patterns

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable project; design spec is finalized)
