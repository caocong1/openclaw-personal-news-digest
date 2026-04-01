# Phase 00: MVP Pipeline - Research

**Researched:** 2026-03-31
**Domain:** OpenClaw Skill development -- RSS collection, LLM processing pipeline, cron automation, file-based data management
**Confidence:** HIGH

## Summary

Phase 0 delivers an end-to-end news digest pipeline as an OpenClaw Skill: one RSS source is fetched, items are deduplicated by URL, classified and summarized by LLM in batches, scored, and assembled into a daily Markdown digest. The Skill runs inside an OpenClaw Agent using platform-native tools (`web_fetch`, `read`/`write`, `cron`, `exec`, `message`/`delivery`).

The core technical challenge is that this is NOT a traditional application -- it is a set of Markdown instructions (SKILL.md < 3000 tokens) plus reference documents that instruct an AI agent how to orchestrate a data pipeline using platform tools. There is no application code to write in the traditional sense. Instead, the deliverables are: (1) directory structure with config/data/reference files, (2) SKILL.md orchestration instructions, (3) reference documents (prompts, data models, output templates, scoring formula), (4) shell scripts for deterministic operations, and (5) cron job configurations.

**Primary recommendation:** Structure the phase into three waves: (1) scaffold directory + config files + data models, (2) write SKILL.md + reference documents + shell scripts covering the full collect-dedup-classify-score-output pipeline, (3) set up cron jobs + platform capability verification + integration testing.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FRMW-01 | Skill directory structure (SKILL.md + references/ + scripts/ + config/ + data/ + output/) | Architecture Patterns section defines exact structure from design doc |
| FRMW-02 | SKILL.md modular orchestration (< 3000 tokens), detailed specs in references/ | SKILL.md pattern section with `{baseDir}` referencing |
| FRMW-03 | Standing Orders (authorization scope, escalation conditions, prohibitions) | Standing Orders template from design doc Section 3.4 |
| FRMW-04 | File lock mutual exclusion (acquire-or-skip, 15 min expiry) | Lock mechanism pattern in Architecture Patterns |
| FRMW-05 | Atomic writes (tmp + rename, crash recovery for > 15min temp files) | Atomic write pattern documented |
| FRMW-06 | Schema versioning with compatible reads (_schema_v field, missing field defaults) | Schema compatibility pattern documented |
| SRC-01 | RSS/Atom feed collection (web_fetch parse XML, extract title/link/description/pubDate) | RSS Collection section -- critical finding about web_fetch vs exec approach |
| PROC-01 | URL normalization + link-level dedup (strip tracking params, SHA256[:16], dedup-index query) | URL normalization rules and dedup-index pattern |
| PROC-02 | LLM multi-label classification (12 top categories + tags + importance + form_type) | Classification prompt template from design doc Section 8.3 |
| PROC-03 | LLM summary generation (2-3 sentence Chinese summary, non-Chinese titles preserved) | Summary prompt template from design doc Section 8.4 |
| PROC-05 | Batch LLM processing (5-10 items/call to reduce per-call overhead) | Batch processing pattern documented |
| PROC-07 | Error handling (classify fails but summary succeeds -> exploration slot; format error -> retry 1x) | Error handling matrix from design doc Section 4.2 |
| PROC-08 | Checkpoint resume (processing_status: "raw" records get classification/summary next run) | Idempotency pattern documented |
| PREF-02 | Cold-start strategy (all topic_weights = 0.5, exploration_appetite = 0.3, no questionnaire) | Cold-start preferences.json template |
| OUT-01 | Daily digest generation (core + adjacent + hotspot + exploration + event tracking, 15-25 items) | Output template from design doc Section 13.3 (simplified for MVP) |
| OUT-05 | Quality-aware output (insufficient content -> shorten rather than pad; empty input -> no empty digest) | Quality control rules documented |
| COST-01 | Daily budget cap (daily_llm_call_limit default 500, daily_token_limit default 1M) | budget.json schema and tracking pattern |
| MON-01 | Daily health metrics file (sources/items/llm/output/feedback dimensions) | Metrics file schema from design doc Section 4.6 |
| PLAT-01 | Cron job configuration (daily digest 0 8, etc.) | Cron configuration format fully documented |
| PLAT-02 | Delivery configuration (announce mode push to chat channel) | Delivery modes documented (announce/webhook/none) |
| PLAT-03 | Isolated session execution (cron triggers independent session) | Isolated session behavior documented; skill loading bug fixed |
| PLAT-04 | Platform capability verification (isolated session / exec / browser / delivery / timeout) | Verification checklist from design doc Section 3.2 |
</phase_requirements>

## Standard Stack

### Core Platform Tools
| Tool | Purpose | Confidence |
|------|---------|------------|
| `web_fetch` | HTTP GET for RSS XML feeds (extractMode: "text" for raw XML) | HIGH |
| `read` / `write` | Workspace file I/O for JSON, JSONL, Markdown files | HIGH |
| `exec` | Run shell scripts (dedup-index-rebuild, data-archive, health-check) | HIGH |
| `cron` | Schedule daily digest, manage job lifecycle | HIGH |
| `message` + `delivery` | Push digest output to chat channels via announce mode | HIGH |

### Supporting Libraries (via exec)
| Library | Purpose | When to Use |
|---------|---------|-------------|
| Python `feedparser` | Parse RSS/Atom XML into structured data | If web_fetch + LLM XML parsing proves unreliable |
| Node.js `rss-parser` | Alternative RSS parsing | If Python not available |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| web_fetch for RSS | exec + feedparser | feedparser is more robust for malformed XML, but adds Python dependency; web_fetch + text extraction + LLM parsing is simpler and dependency-free |
| JSONL files | SQLite | JSONL is simpler, sufficient for Phase 0 scale (~50 items/day), no extra dependencies |
| Shell scripts via exec | Inline SKILL.md instructions | Scripts are deterministic and testable; inline instructions would bloat SKILL.md |

## Architecture Patterns

### Recommended Project Structure
```
<skill-workspace>/
  SKILL.md                          # < 3000 tokens, orchestration only
  references/
    data-models.md                # NewsItem, Source, Event JSON schemas
    prompts/
      classify.md               # Classification prompt template
      summarize.md              # Summary prompt template
    output-templates.md           # Daily digest Markdown template
    scoring-formula.md            # 7-dimension scoring formula
  scripts/
    dedup-index-rebuild.sh        # Rebuild dedup-index from JSONL files
    data-archive.sh               # Archive old data files
    health-check.sh               # Data consistency check
  config/
    sources.json                  # RSS source definitions (1 source for MVP)
    preferences.json              # Cold-start preferences (all 0.5)
    categories.json               # 12 top-level category definitions
    budget.json                   # LLM call/token budget tracking
  data/
    news/
      YYYY-MM-DD.jsonl           # Daily news items
      dedup-index.json           # URL hash -> news_id mapping
    events/
      active.json                # Active events (empty for MVP)
    feedback/
      log.jsonl                  # Feedback entries (empty for MVP)
    cache/                        # LLM cache (empty for MVP)
    metrics/
      daily-YYYY-MM-DD.json     # Daily health metrics
    .lock                         # File lock (transient)
  output/
    latest-digest.md              # Most recent daily digest
```

### Pattern 1: SKILL.md Modular Referencing
**What:** SKILL.md contains ONLY high-level orchestration (~6 sections, < 3000 tokens). Detailed specs are loaded on-demand via `read("{baseDir}/references/...")`.
**When to use:** Always -- this is a core design principle.
**Example:**
```markdown
---
name: news-digest
description: Personalized news research and delivery system
user-invocable: true
metadata: {"openclaw":{"always":true}}
---

# News Digest Skill

## Role
You are a news research assistant running in the OpenClaw workspace.
Working directory: {baseDir}

## Collection Phase
1. Read `{baseDir}/config/sources.json` for active sources
2. For each RSS source: fetch with `web_fetch`, extract items
3. For each item: normalize URL, check `{baseDir}/data/news/dedup-index.json`
4. Write new items to `{baseDir}/data/news/YYYY-MM-DD.jsonl`

## Processing Phase
1. Read `{baseDir}/references/prompts/classify.md` for prompt template
2. Batch unprocessed items (5-10 per call), classify + summarize
3. Write results back to JSONL, update processing_status

## Output Phase
1. Read `{baseDir}/references/scoring-formula.md` for scoring rules
2. Score all items, sort by final_score descending
3. Read `{baseDir}/references/output-templates.md` for format
4. Generate daily digest, write to `{baseDir}/output/latest-digest.md`

## Standing Orders
[authorization, escalation, prohibitions]

## Constraints
[budget limits, error handling, lock acquisition]
```

### Pattern 2: File Lock Mutual Exclusion
**What:** Acquire-or-skip lock to prevent concurrent pipeline runs.
**When to use:** At the start of every cron-triggered pipeline execution.
**Example:**
```
Lock file: data/.lock
Content: { "run_id": "run-YYYYMMDD-HHmmss-XXXX", "started_at": "ISO8601" }
Acquire: write lock file -> success means lock acquired
Conflict: read existing lock -> if started_at < 15min ago, skip this run; else delete stale lock and retry
Release: delete lock file after pipeline completes
Crash recovery: on startup, scan data/**/*.tmp.*, delete files > 15 min old
```

### Pattern 3: Atomic Write
**What:** Write to temporary file first, then rename to target path.
**When to use:** Every data file write (JSONL, JSON, Markdown output).
**Example:**
```
1. Write content to "{target_path}.tmp.{run_id}"
2. Rename/move to "{target_path}"
3. On crash: temp files with age > 15 min are cleaned up next run
```

### Pattern 4: RSS Collection via web_fetch
**What:** Fetch RSS XML using web_fetch with extractMode "text", then parse with LLM or string extraction.
**When to use:** For RSS/Atom feed collection.
**Important consideration:** web_fetch runs Readability extraction by default which mangles XML. Two viable approaches:

**Approach A (Recommended for MVP):** Use `web_fetch` with `extractMode: "text"` to get raw text content of the RSS feed. The XML structure should be preserved in text mode. The agent (LLM) can then parse the XML directly to extract title, link, description, pubDate fields.

**Approach B (Fallback):** Use `exec` to run a Python script with `feedparser` or a Node.js script with `rss-parser`. This is more robust for malformed feeds but adds a dependency. The design doc lists `web_fetch` as the primary tool for RSS, so try Approach A first.

### Pattern 5: Batch LLM Processing
**What:** Send 5-10 news items per LLM call for classification and summarization.
**When to use:** During the processing phase to reduce per-call overhead.
**Example flow:**
```
1. Collect items with processing_status: "raw" from today's JSONL
2. Group into batches of 5-10
3. For each batch: read classify.md prompt template, fill with batch items, call LLM
4. Parse structured JSON response, update each item's categories/importance/form_type
5. Similarly batch summarization (can combine with classification in single call)
6. Update processing_status to "complete" (or "partial" on failure)
7. Track LLM calls in budget.json
```

### Pattern 6: Cron Job Configuration
**What:** Set up daily digest cron job with isolated session and announce delivery.
**When to use:** After the pipeline is validated to work end-to-end.
**Example:**
```json
{
  "name": "daily-digest",
  "schedule": { "kind": "cron", "expr": "0 8 * * *", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Execute the daily news digest pipeline: collect from RSS sources, deduplicate, classify and summarize new items, score and rank, generate daily digest, track metrics.",
    "lightContext": false
  },
  "delivery": {
    "mode": "announce",
    "channel": "{user_channel}",
    "to": "{user_target}"
  }
}
```

### Anti-Patterns to Avoid
- **Monolithic SKILL.md:** Do NOT put all prompts, data models, and output templates into SKILL.md. Keep it < 3000 tokens. Use `read()` to load references on demand.
- **Custom application code:** This is NOT a backend service. Do NOT write Python/Node.js applications. The "application" IS the SKILL.md instructions + reference documents that guide the AI agent.
- **Direct LLM API calls:** Do NOT call LLM APIs directly. The agent IS the LLM. Classification and summarization happen by providing the prompt template and data, and the agent processes them.
- **Complex state machines in SKILL.md:** Keep orchestration simple. The agent follows step-by-step instructions. Complex conditional logic should be expressed as clear if/then rules, not as code.
- **Ignoring budget tracking:** Every LLM processing step must increment counters in budget.json. Forgetting this means uncontrolled costs.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| RSS XML parsing | Custom XML parser in shell | web_fetch (text mode) + LLM extraction, or exec + feedparser | RSS/Atom feeds have many edge cases (CDATA, namespaces, encoding) |
| URL normalization | Simple string replace | Documented normalization rules (strip utm_*, https, www, trailing slash, lowercase host) + SHA256 | Tracking parameter removal has many edge cases |
| Cron scheduling | Custom timer scripts | OpenClaw native `cron` tool | Platform handles persistence, session management, delivery |
| Content delivery | Custom message sending | OpenClaw `delivery` config on cron jobs | Platform handles channel routing, formatting |
| File locking | Complex distributed lock | Simple file-based lock (acquire-or-skip, 15 min expiry) | Single-user, low-concurrency -- simple is correct |

**Key insight:** The entire system is an AI agent following instructions. The "code" is the instructions and data schemas. There is no runtime to build -- OpenClaw IS the runtime.

## Common Pitfalls

### Pitfall 1: web_fetch Readability Mangling XML
**What goes wrong:** web_fetch defaults to Readability extraction which converts HTML to markdown. When fetching RSS XML feeds, this can strip or restructure the XML data, losing structured fields.
**Why it happens:** web_fetch is designed for readable web content, not structured data formats.
**How to avoid:** Use `extractMode: "text"` to get raw content. If XML is still mangled, fall back to `exec` with a proper RSS parser library.
**Warning signs:** Missing pubDate, garbled description fields, items appearing as a single block of text.

### Pitfall 2: SKILL.md Context Overflow
**What goes wrong:** SKILL.md grows beyond 3000 tokens as developers add detailed prompts, data schemas, and edge case handling inline.
**Why it happens:** Natural tendency to put everything in one place for completeness.
**How to avoid:** Strict discipline: SKILL.md has ONLY orchestration steps. Every detailed spec goes in `references/`. Count tokens after each edit.
**Warning signs:** SKILL.md exceeding ~2000 Chinese characters or ~4000 English words.

### Pitfall 3: Isolated Session Not Finding Skill Files
**What goes wrong:** Cron job triggers isolated session but agent cannot find SKILL.md or workspace files.
**Why it happens:** Historical bug (issue #10804) where isolated sessions did not load workspace skills. Fixed in PR #13457 (merged ~Feb 2026). Also, `lightContext: true` omits workspace bootstrap.
**How to avoid:** Use `lightContext: false` for the daily digest job (it needs full workspace access). Ensure OpenClaw is updated past version 2026.2.2-3. Verify workspace file access as part of PLAT-04.
**Warning signs:** "skill not found" errors in cron run logs.

### Pitfall 4: LLM Response Format Inconsistency
**What goes wrong:** LLM returns malformed JSON when processing batches, causing the entire batch to fail.
**Why it happens:** Batch processing with 5-10 items increases prompt complexity; LLM may drop items or produce invalid JSON.
**How to avoid:** (1) Prompt explicitly requests JSON array output with exact field names. (2) On parse failure, retry once (PROC-07). (3) If retry fails, mark items as `processing_status: "partial"` and continue. (4) Include example output in prompt template.
**Warning signs:** Increasing "partial" status items, missing classifications.

### Pitfall 5: Dedup Index Growing Unbounded
**What goes wrong:** dedup-index.json grows indefinitely as URL hashes accumulate.
**Why it happens:** No eviction policy applied to the index.
**How to avoid:** dedup-index should cover only the last 7 days (matching data lifecycle). The `dedup-index-rebuild.sh` script rebuilds from recent JSONL files. For MVP, manual rebuild is acceptable; automated weekly rebuild comes in Phase 2.
**Warning signs:** dedup-index.json exceeding 500KB, slow dedup lookups.

### Pitfall 6: Budget Tracking Race Condition
**What goes wrong:** budget.json `calls_today` and `tokens_today` counters are not atomically updated, leading to inaccurate counts.
**Why it happens:** Read-modify-write cycle on budget.json without proper synchronization.
**How to avoid:** The file lock (FRMW-04) ensures single pipeline execution, so only one process writes budget.json at a time. Also check `current_date` -- if date has changed, reset counters before incrementing.
**Warning signs:** Counters not matching actual LLM calls, counters not resetting at day boundary.

### Pitfall 7: Empty RSS Feed Producing Empty Digest
**What goes wrong:** RSS source returns no new items (or all items are duplicates), and the system generates an empty digest.
**Why it happens:** No quality gate between scoring and output generation.
**How to avoid:** OUT-05 requires: if no items pass scoring threshold, output nothing (stay silent) or output a shortened "no significant news today" message. Never output an empty digest with section headers but no content.
**Warning signs:** Digest files with only headers and no news items.

## Code Examples

### NewsItem Schema (for references/data-models.md)
```json
{
  "id": "string (SHA256(normalized_url)[:16])",
  "title": "string",
  "url": "string (original URL)",
  "normalized_url": "string (tracking params stripped)",
  "source_id": "string (e.g., src-36kr)",
  "content_summary": "string (LLM-generated 2-3 sentence summary)",
  "categories": {
    "primary": "string (one of 12 category IDs)",
    "secondary": ["string"],
    "tags": ["string (kebab-case, 2-5 tags)"]
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

### Cold-Start preferences.json
```json
{
  "topic_weights": {
    "ai-models": 0.5,
    "dev-tools": 0.5,
    "tech-products": 0.5,
    "business": 0.5,
    "finance": 0.5,
    "macro-policy": 0.5,
    "international": 0.5,
    "security": 0.5,
    "open-source": 0.5,
    "gaming": 0.5,
    "science": 0.5,
    "breaking": 0.5
  },
  "source_trust": {},
  "form_preference": {
    "news": 0.0,
    "analysis": 0.0,
    "opinion": 0.0,
    "announcement": 0.0,
    "other": 0.0
  },
  "style": {
    "density": "medium",
    "repetition_tolerance": "low",
    "exploration_appetite": 0.3,
    "rumor_tolerance": "low"
  },
  "feedback_samples": {
    "liked_items": [],
    "disliked_items": [],
    "trusted_sources": [],
    "distrusted_sources": [],
    "blocked_patterns": []
  },
  "version": 2,
  "last_updated": null,
  "last_decay_at": null,
  "total_feedback_count": 0,
  "feedback_processing_enabled": true
}
```

### budget.json Initial Config
```json
{
  "daily_llm_call_limit": 500,
  "daily_token_limit": 1000000,
  "alert_threshold": 0.8,
  "current_date": "YYYY-MM-DD",
  "calls_today": 0,
  "tokens_today": 0
}
```

### MVP Source Config (sources.json)
```json
[
  {
    "id": "src-36kr",
    "name": "36Kr",
    "type": "rss",
    "url": "https://36kr.com/feed",
    "weight": 1.0,
    "credibility": 0.8,
    "topics": ["tech-products", "business"],
    "enabled": true,
    "fetch_config": {},
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
]
```

### Scoring Formula (MVP simplified)
```
final_score =
  importance_score * 0.25
  + topic_weight(primary) * 0.20
  + source_trust(source_id) * 0.10    // defaults to source.credibility
  + form_preference_norm * 0.10        // (form_preference + 1) / 2
  + feedback_boost * 0.10              // 0 in MVP (no feedback yet)
  + recency_score * 0.15              // max(0, 1 - hours_since_published / 48)
  + event_boost * 0.10                // 0 in MVP (no events yet)

MVP simplification: feedback_boost = 0, event_boost = 0
So effective MVP formula:
  importance * 0.25 + topic * 0.20 + source * 0.10 + form * 0.10 + recency * 0.15
  (normalizes to 0.80 max, but relative ordering is what matters)
```

### Daily Metrics Schema (for data/metrics/)
```json
{
  "date": "YYYY-MM-DD",
  "run_id": "run-YYYYMMDD-HHmmss-XXXX",
  "sources": {
    "total": 1,
    "success": 1,
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

### Cron Job Config for Daily Digest
```json
{
  "name": "news-daily-digest",
  "schedule": {
    "kind": "cron",
    "expr": "0 8 * * *",
    "tz": "Asia/Shanghai"
  },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Execute the daily news digest pipeline: collect RSS sources, deduplicate, classify/summarize new items, score and rank, generate daily digest, update metrics.",
    "lightContext": false,
    "timeoutSeconds": 600
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "{target_chat_id}"
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Monolithic SKILL.md | Modular SKILL.md + references/ | v3 design (2026-03) | Agent consistency improves with smaller context |
| 3 sub-phases (0A/0B/0C) | Single Phase 0 | v3 design (2026-03) | Faster delivery, less overhead |
| 7-layer preferences | 5-layer preferences for Phase 0-2 | v3 design (2026-03) | Reduced complexity; expand to 7 in Phase 3 |
| Complex lock with heartbeat | Simple acquire-or-skip lock | v3 design (2026-03) | Sufficient for single-user scenario |
| Full feedback rebuild | Incremental-only feedback | v3 design (2026-03) | Simpler, manual override available |
| Isolated sessions missing skills | Fixed in PR #13457 | 2026-02 | Cron jobs now correctly load workspace skills |

**Deprecated/outdated:**
- `clawdbot` / `moltbot` naming: Now `openclaw`. Metadata aliases `metadata.clawdbot` still work but use `metadata.openclaw`.
- `full_content` field in NewsItem: Removed in v3 -- processing chain never consumes it.
- `media_urls` / `word_count` fields: Removed in v3 -- no consumer in the pipeline.

## Open Questions

1. **web_fetch behavior with RSS XML content**
   - What we know: web_fetch supports `extractMode: "text"` which should return raw content. Readability (default markdown mode) would mangle XML.
   - What's unclear: Whether text mode truly preserves XML structure for RSS feeds, or if some post-processing strips tags.
   - Recommendation: Test during PLAT-04 verification. Use approach A (web_fetch text mode + LLM parsing) first. If XML is mangled, fall back to approach B (exec + feedparser/rss-parser).

2. **exec tool availability in skill workspace**
   - What we know: exec tool is documented and supports shell command execution with configurable security levels.
   - What's unclear: Whether the default security policy allows exec in cron-triggered isolated sessions without manual approval.
   - Recommendation: Verify during PLAT-04. Check if `exec.ask` needs to be set to `"off"` for cron jobs, or if the cron session auto-approves.

3. **Agent turn timeout for full pipeline**
   - What we know: Default timeout is not explicitly documented for cron agentTurn. The `timeoutSeconds` parameter exists in payload config.
   - What's unclear: What the practical upper limit is. Design doc assumes >= 10 minutes needed.
   - Recommendation: Set `timeoutSeconds: 600` in cron config. If pipeline exceeds this, consider splitting into separate collect and generate cron jobs.

4. **Specific RSS source for MVP**
   - What we know: Design doc does not specify which RSS source to use for the single MVP source.
   - What's unclear: User preference for initial source. 36Kr (Chinese tech news) is a reasonable default.
   - Recommendation: Use a well-known, reliably structured RSS feed. The planner should make the source configurable and include one default.

## Sources

### Primary (HIGH confidence)
- [OpenClaw Cron Jobs Documentation](https://docs.openclaw.ai/automation/cron-jobs) -- cron configuration, delivery modes, session types
- [OpenClaw Web Fetch Documentation](https://docs.openclaw.ai/tools/web-fetch) -- web_fetch parameters, extractMode, size limits
- [OpenClaw Exec Tool Documentation](https://docs.openclaw.ai/tools/exec) -- exec parameters, security modes, timeout settings
- [OpenClaw Skills Documentation](https://docs.openclaw.ai/tools/skills) -- SKILL.md format, frontmatter, workspace structure
- [ClawHub Skill Format Specification](https://github.com/openclaw/clawhub/blob/main/docs/skill-format.md) -- YAML frontmatter fields, file restrictions
- Design document `gpt-plan-v3.md` -- data models, prompts, scoring formula, output templates, Phase 0 definition

### Secondary (MEDIUM confidence)
- [OpenClaw Wikipedia](https://en.wikipedia.org/wiki/OpenClaw) -- platform history, naming changes
- [DeepWiki: Web Search & Fetch](https://deepwiki.com/openclaw/openclaw/3.4.5-web-search-and-fetch) -- web_fetch internals
- [DeepWiki: Automation & Cron](https://deepwiki.com/openclaw/openclaw/3.7-automation-and-cron) -- cron system architecture
- [GitHub Issue #10804](https://github.com/openclaw/openclaw/issues/10804) -- isolated session skill loading bug (FIXED)
- [openclaw-feeds SKILL.md](https://github.com/openclaw/skills/blob/main/skills/nesdeq/openclaw-feeds/SKILL.md) -- existing RSS skill pattern using exec + feedparser
- [rss-skill repository](https://github.com/sincere-arjun/rss-skill) -- alternative RSS skill using Node.js rss-parser

### Tertiary (LOW confidence)
- web_fetch XML handling specifics -- no official documentation found on how text mode handles XML content types; needs runtime verification

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- OpenClaw tool documentation is official and verified
- Architecture: HIGH -- directory structure and patterns are prescribed by the design document (gpt-plan-v3.md)
- Data models: HIGH -- JSON schemas are fully specified in the design document
- SKILL.md format: HIGH -- verified against official OpenClaw skill format documentation
- Cron/delivery: HIGH -- official documentation confirms all required features
- RSS parsing: MEDIUM -- web_fetch text mode behavior with XML is undocumented; existing skills use exec + parser libraries as alternative
- Pitfalls: HIGH -- derived from official documentation, known bugs, and design document error handling specs

**Research date:** 2026-03-31
**Valid until:** 2026-04-30 (stable platform, design doc is locked)
