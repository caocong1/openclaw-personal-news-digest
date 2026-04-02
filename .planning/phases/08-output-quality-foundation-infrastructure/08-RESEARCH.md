# Phase 8: Output Quality Foundation & Infrastructure - Research

**Researched:** 2026-04-02
**Domain:** Output localization (Chinese), data quality validation, cache versioning, test fixtures, bootstrap verification
**Confidence:** HIGH

## Summary

Phase 8 addresses four distinct but complementary concerns: (1) full Chinese localization of all user-facing output labels/headers, (2) pre-write data quality contracts for UTF-8 and title correctness, (3) cache versioning infrastructure to prevent stale LLM results when prompts change, and (4) deterministic test fixtures plus SKILL.md bootstrap verification.

This is a prompt/config/reference-doc project -- there is no runtime code, only Markdown instruction files, JSON schemas, and shell scripts. All changes are edits to existing reference documents (`output-templates.md`, `data-models.md`, `processing-instructions.md`, `SKILL.md`) or creation of new fixture/test files. The project uses JSONL + JSON flat-file storage with atomic writes via tmp+rename.

**Primary recommendation:** Organize work into two plans: (1) L10N + output quality (templates, prompts, rendering contracts), and (2) infrastructure foundations (cache versioning, bootstrap, fixtures, data model updates).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| L10N-01 | Daily digest output uses Chinese labels for all section headers and metadata | Audit of output-templates.md identifies 20+ English labels requiring translation in daily digest template |
| L10N-02 | Breaking alert output uses Chinese labels (kuaixun format) | Alert template uses `[Breaking]` prefix and English field labels; needs full Chinese conversion |
| L10N-03 | Weekly report output uses Chinese labels for all sections | Weekly template has 6 English section headers plus English metadata labels |
| L10N-04 | Summarize and weekly-report prompts enforce Chinese-output rule | summarize.md already instructs Chinese output; weekly-report.md needs explicit Chinese-output mandate |
| QUAL-01 | Pre-write quality contract validates UTF-8 sanitization and title validation for all source types | New section needed in processing-instructions.md defining validation rules before any JSONL write |
| QUAL-02 | Quick-Check output strips JSON field names from alert rendering | Alert template currently shows raw field names; needs rendering contract separating internal vs display |
| QUAL-03 | Output templates define rendering contract separating user-facing vs internal fields | New rendering contract section needed in output-templates.md |
| INFRA-01 | Cache entries include prompt_version field; version mismatch triggers cache miss | CacheEntry schema needs prompt_version field; cache lookup logic needs version check |
| INFRA-02 | Data models include bootstrap & migration section with new fields registry | New section in data-models.md documenting all schema versions, new fields, and migration defaults |
| INFRA-03 | SKILL.md verifies required directories on first run | SKILL.md needs bootstrap step at pipeline start checking/creating required directory structure |
| INFRA-04 | Test fixture directory with deterministic fixture files for all verification scenarios | New `data/fixtures/` directory with sample JSONL, cache, events, and metrics files |
</phase_requirements>

## Architecture Patterns

### Current Project Structure (Relevant Subset)
```
references/
  output-templates.md      # L10N-01, L10N-02, L10N-03, QUAL-02, QUAL-03
  data-models.md           # INFRA-01, INFRA-02
  processing-instructions.md  # QUAL-01, INFRA-01 (cache logic in Section 0B)
  prompts/
    summarize.md           # L10N-04
    weekly-report.md       # L10N-04
    classify.md            # (prompt_version source for cache)
SKILL.md                   # INFRA-03
data/
  cache/                   # INFRA-01 (classify-cache.json, summary-cache.json)
  news/                    # QUAL-01 target
  fixtures/                # INFRA-04 (to be created)
```

### Pattern 1: Localization via Template Labels
**What:** Replace all English labels in output templates with Chinese equivalents while keeping internal field names (JSON keys) in English.
**When to use:** Every user-facing output section header, metadata label, and footer text.

**Label mapping (daily digest):**

| English Label | Chinese Label |
|---------------|---------------|
| `## Core Focus` | `## 核心关注` |
| `## Adjacent Dynamics` | `## 邻近动态` |
| `## Today's Hotspot` | `## 今日热点` |
| `## Exploration` | `## 探索发现` |
| `## Event Tracking` | `## 事件追踪` |
| `Source:` | `来源:` |
| `Importance:` | `重要性:` |
| `Recommendation reason:` | `推荐理由:` |
| `Status:` | `状态:` |
| `Items:` | `条目:` |
| `First seen:` | `首次出现:` |
| `Sources:` (footer) | `来源数:` |
| `Processed:` | `处理:` |
| `Selected:` | `入选:` |
| `Stats:` | `统计:` |
| `sources checked` | `个来源已检查` |
| `items processed` | `条已处理` |
| `LLM calls` | `次 LLM 调用` |
| `cache hits` | `次缓存命中` |
| `Budget: EXHAUSTED` | `预算: 已耗尽` |
| `Budget: X% used` | `预算: 已使用 X%` |

**Label mapping (breaking alert):**

| English Label | Chinese Label |
|---------------|---------------|
| `[Breaking]` | `【快讯】` |
| `Source:` | `来源:` |
| `Importance:` | `重要性:` |
| `Time:` | `时间:` |

**Label mapping (weekly report):**

| English Label | Chinese Label |
|---------------|---------------|
| `# Weekly News Digest:` | `# 每周新闻摘要:` |
| `## One Week Overview` | `## 本周概览` |
| `## Key Events & Timelines` | `## 重要事件与时间线` |
| `## Category Trends` | `## 分类趋势` |
| `## Source Health Summary` | `## 来源健康概况` |
| `## Cross-Domain Connections` | `## 跨领域关联` |
| `This week:` | `本周:` |
| `Trend:` | `趋势:` |
| `Key stories:` | `重要报道:` |
| `Active sources:` | `活跃来源:` |
| `Degraded sources:` | `降级来源:` |
| `Quality changes:` | `质量变化:` |
| `New sources added this week:` | `本周新增来源:` |
| `Week stats:` | `周统计:` |
| `items from` | `条来自` |
| `sources` | `个来源` |
| `events tracked` | `个事件追踪中` |
| `LLM calls total` | `次 LLM 调用` |

### Pattern 2: Rendering Contract (Internal vs User-Facing Fields)
**What:** Define which NewsItem/Event fields are internal-only (never shown to user) vs user-facing (rendered in output).
**When to use:** Output generation and alert rendering to prevent JSON field name leakage.

**User-facing fields** (rendered with Chinese labels):
- `title`, `content_summary`, `source_name`, `importance_score`, `form_type`, `categories.primary` (as display name)
- Event: `title`, `summary`, `timeline[].brief`, `timeline[].relation`, `status`, `importance`

**Internal-only fields** (never rendered):
- `id`, `url`, `normalized_url`, `content_hash`, `processing_status`, `dedup_status`, `duplicate_of`, `_schema_v`, `event_id`, `language`
- `categories.secondary`, `categories.tags` (used for processing, not display)
- Cache fields: `cached_at`, `prompt_version`

### Pattern 3: Cache Version Gating
**What:** Add `prompt_version` to each cache entry. On lookup, compare stored version against current prompt version. Mismatch = cache miss (forces re-computation).
**When to use:** Every cache lookup in Section 0B of processing-instructions.md.

**Implementation:**
- Add `prompt_version` field to CacheEntry schemas (both classify and summary)
- Define current prompt versions: `classify-v1` for classify.md, `summarize-v1` for summarize.md
- Each prompt file gets a version comment at the top: `<!-- prompt_version: classify-v1 -->`
- Cache lookup adds step: if `entry.prompt_version != current_prompt_version`, treat as cache miss
- Cache write includes `prompt_version` in the entry

### Pattern 4: Pre-Write Quality Contract
**What:** Validation rules applied before any JSONL write to ensure data integrity.
**When to use:** Collection Phase step 7 (write items) and Processing Phase step 7 (write results).

**Validation rules:**
1. **UTF-8 sanitization:** Reject or clean characters outside valid UTF-8 range. Strip null bytes, control characters (except newline/tab), and lone surrogates.
2. **Title validation:** Title must be non-empty, non-whitespace-only, max 500 characters. If title is empty after trimming, skip the item (do not write).
3. **URL validation:** `normalized_url` must be non-empty and start with `https://`.
4. **ID consistency:** `id` must equal `SHA256(normalized_url)[:16]`.

### Pattern 5: Directory Bootstrap
**What:** SKILL.md verifies required directory structure exists at pipeline start.
**When to use:** Before Collection Phase step 1 (acquire lock).

**Required directories:**
```
data/
data/news/
data/cache/
data/events/
data/events/archived/
data/feedback/
data/metrics/
output/
config/
```

### Anti-Patterns to Avoid
- **Partial localization:** Do not translate only section headers while leaving metadata labels in English. Users see the full output -- all visible text must be Chinese.
- **Translating JSON keys:** Internal field names (`importance_score`, `form_type`, etc.) stay in English. Only the rendered labels change.
- **Cache invalidation by time only:** Adding prompt_version prevents the subtle bug where a prompt change produces stale cached results that look correct but use outdated classification/summarization logic.
- **Test fixtures with real data:** Fixtures must be deterministic and synthetic, not copied from production runs (which may contain PII or change over time).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| UTF-8 validation | Custom character-by-character scanner | Standard UTF-8 validation rules documented in quality contract | Edge cases with CJK, emoji, combining characters |
| Cache versioning | Ad-hoc version checks scattered across code | Centralized prompt_version field in cache schema + single validation point in Section 0B | Prevents version check drift |
| Directory creation | Per-phase mkdir commands | Single bootstrap checklist in SKILL.md | One source of truth for required structure |

## Common Pitfalls

### Pitfall 1: Inconsistent Label Translation
**What goes wrong:** Some outputs show Chinese headers but English metadata (e.g., `## 核心关注` but `Source: xxx`), creating a jarring mixed-language experience.
**Why it happens:** Templates have labels scattered across multiple sections and it is easy to miss some.
**How to avoid:** Systematic audit using the label mapping tables above. Check every line in output-templates.md that contains a colon followed by a placeholder.
**Warning signs:** Any English word followed by `:` or `|` in the output template within user-facing sections.

### Pitfall 2: Breaking Existing Cache on Version Field Addition
**What goes wrong:** Adding `prompt_version` to cache schema causes all existing cache entries to be treated as invalid (mass cache miss), triggering a spike in LLM calls.
**Why it happens:** Existing entries lack the `prompt_version` field, and a naive check treats missing field as mismatch.
**How to avoid:** Define fallback: if `prompt_version` is missing from a cache entry, treat it as version "v0" (legacy). On first run after update, legacy entries will miss only if the current version differs from "v0". Alternatively, accept the one-time cache flush as acceptable (cache is only 7-day TTL anyway).
**Warning signs:** Budget spike after deploying cache version changes.

### Pitfall 3: Fixture Files Becoming Stale
**What goes wrong:** Test fixtures reference schema versions or field names that no longer match current data models.
**Why it happens:** Fixtures created once and never updated when schemas evolve.
**How to avoid:** Include `_schema_v` in all fixture files matching current versions. Add a note in data-models.md that fixture updates are part of schema change procedure.
**Warning signs:** Fixture files with `_schema_v` lower than current schema version.

### Pitfall 4: Weekly Report Prompt Language Gap
**What goes wrong:** weekly-report.md prompt is entirely in English, and the LLM may generate English output despite the summarize prompt enforcing Chinese.
**Why it happens:** The weekly-report.md prompt was written in English and lacks an explicit Chinese-output instruction.
**How to avoid:** Add explicit instruction: "Generate all output text in Chinese (中文)" to weekly-report.md, matching summarize.md's existing Chinese-output rule.
**Warning signs:** Weekly report sections appearing in English.

## Code Examples

### Example 1: Updated Daily Digest Template (L10N-01)
```markdown
# {date}

## 核心关注

{For each item:}
### {title}
{2-3 sentence Chinese summary}
来源: {source_name} | {form_type} | 重要性: {importance_score}
{If exploration/hotspot slot: "推荐理由: {reason}"}

## 邻近动态

- **{title}** -- {1 sentence summary} ({source_name})

## 今日热点

- **{title}** -- {1 sentence summary} ({source_name})
  推荐理由: {reason}

## 探索发现

- **{title}** -- {1 sentence summary}
  推荐理由: {reason}

## 事件追踪

### {event_title}
{event_summary}
时间线:
- [{date}] {brief} ({relation}) -- 来源: {source_name}
状态: {status} | 条目: {item_count} | 首次出现: {first_seen_date}

---
来源数: {source_count} | 处理: {total_items} 条 | 入选: {selected_items} 条
```

### Example 2: Updated Breaking Alert Template (L10N-02)
```markdown
【快讯】{title}

{1-sentence summary}

来源: {source_name} | 重要性: {importance_score}
时间: {published_at or fetch time}
```

### Example 3: CacheEntry with prompt_version (INFRA-01)
```json
{
  "_schema_v": 2,
  "primary": "ai-models",
  "tags": ["llm", "benchmark"],
  "importance_score": 0.8,
  "form_type": "news",
  "cached_at": "2026-04-02T10:00:00Z",
  "prompt_version": "classify-v1"
}
```

### Example 4: Pre-Write Quality Contract (QUAL-01)
```markdown
## Pre-Write Quality Contract

Before writing any item to JSONL (Collection Phase step 7, Processing Phase step 7):

1. **UTF-8 sanitization**: Strip null bytes (U+0000), control characters (U+0001-U+001F except U+000A newline and U+0009 tab), and lone surrogates (U+D800-U+DFFF). Replace with empty string.
2. **Title validation**: `title` must be non-empty after trimming whitespace and must not exceed 500 characters. If invalid, skip item entirely (do not write).
3. **URL validation**: `normalized_url` must be non-empty and begin with `https://`.
4. **ID consistency**: Verify `id == SHA256(normalized_url)[:16]`.

If any validation fails: log a warning with the item URL and skip writing. Do NOT write partial/invalid items.
```

### Example 5: Bootstrap Directory Check (INFRA-03)
```markdown
## Bootstrap (before Collection Phase step 1)

Verify these directories exist. Create any missing directories silently:

- `{baseDir}/data/`
- `{baseDir}/data/news/`
- `{baseDir}/data/cache/`
- `{baseDir}/data/events/`
- `{baseDir}/data/events/archived/`
- `{baseDir}/data/feedback/`
- `{baseDir}/data/metrics/`
- `{baseDir}/output/`
- `{baseDir}/config/`

If `config/sources.json` does not exist, log error and abort: "Missing sources.json -- run setup first."
```

### Example 6: Test Fixture NewsItem (INFRA-04)
```json
{
  "id": "a1b2c3d4e5f6g7h8",
  "title": "测试新闻标题 - AI 模型发布",
  "url": "https://example.com/test-article",
  "normalized_url": "https://example.com/test-article",
  "source_id": "src-test",
  "content_summary": "这是一条用于测试的新闻摘要，包含中文内容和 UTF-8 字符验证。",
  "categories": {
    "primary": "ai-models",
    "secondary": [],
    "tags": ["test-fixture", "llm"]
  },
  "importance_score": 0.7,
  "event_id": null,
  "fetched_at": "2026-01-01T00:00:00Z",
  "published_at": "2026-01-01T00:00:00Z",
  "form_type": "news",
  "language": "zh",
  "dedup_status": "unique",
  "content_hash": "x1y2z3w4a5b6c7d8",
  "processing_status": "complete",
  "duplicate_of": null,
  "_schema_v": 3
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| English output labels | Chinese localized labels | Phase 8 | All user-facing text in Chinese |
| No cache versioning | prompt_version in cache entries | Phase 8 | Prevents stale cached results after prompt changes |
| No pre-write validation | Quality contract before JSONL writes | Phase 8 | Catches corrupt/invalid data before it enters the pipeline |
| No bootstrap check | Directory verification on startup | Phase 8 | First-run reliability |
| No test fixtures | Deterministic fixture directory | Phase 8 | Enables verification of all pipeline scenarios |

## Fixture File Plan (INFRA-04)

The `data/fixtures/` directory should contain deterministic files covering these scenarios:

| Fixture File | Purpose | Scenarios Covered |
|--------------|---------|-------------------|
| `news-items-complete.jsonl` | Complete processed items | Normal output generation, quota allocation |
| `news-items-partial.jsonl` | Mix of raw/partial/complete items | Breakpoint resume, error recovery |
| `news-items-multilingual.jsonl` | Chinese + English items | Language detection, cross-language display |
| `news-items-edge-cases.jsonl` | UTF-8 edge cases, empty titles, long titles | Quality contract validation |
| `cache-with-versions.json` | Cache entries with various prompt_versions | Cache version mismatch testing |
| `events-active.json` | Active events with timelines | Event tracking section rendering |
| `metrics-sample.json` | Sample daily metrics | Transparency footer, quota distribution |
| `preferences-default.json` | Default preferences (cold start) | Cold-start quota behavior |

Each fixture file includes `_schema_v` matching current schema versions and uses fixed timestamps (2026-01-01T00:00:00Z base) for determinism.

## Schema Changes Summary (INFRA-02)

### CacheEntry Schema v1 -> v2
- **New field:** `prompt_version` (string, e.g., "classify-v1" or "summarize-v1")
- **Default for v1 entries:** treat missing `prompt_version` as `"legacy"` (forces cache miss on first run with new prompts)
- **Applies to:** Both `classify-cache.json` and `summary-cache.json`

### New Fields Registry (for data-models.md)
Document all fields added across all phases with version, default, and migration behavior. This is a documentation section, not a code migration -- the project already uses `_schema_v` with missing-field defaults.

## Open Questions

1. **form_type display in Chinese?**
   - What we know: `form_type` values are English enum strings (`news`, `analysis`, `opinion`, `announcement`, `other`)
   - What's unclear: Should these be displayed as Chinese labels in output? (e.g., `新闻`, `分析`, `观点`, `公告`, `其他`)
   - Recommendation: YES -- translate for display only, keep English internally. Add a display mapping table.

2. **Event status display in Chinese?**
   - What we know: `status` values are `active`, `stable`, `archived`
   - What's unclear: Should these show as Chinese in event tracking section?
   - Recommendation: YES -- `活跃`, `稳定`, `已归档`. Add display mapping.

3. **Relation type display in Chinese?**
   - What we know: Timeline relation types are `initial`, `update`, `correction`, `analysis`, `reversal`
   - What's unclear: These appear in parentheses in event timelines.
   - Recommendation: YES -- `首报`, `更新`, `更正`, `分析`, `反转`. Add display mapping.

## Sources

### Primary (HIGH confidence)
- Direct file reads of all project reference documents (output-templates.md, data-models.md, processing-instructions.md, SKILL.md, prompts/summarize.md, prompts/weekly-report.md, prompts/classify.md)
- Direct inspection of existing cache files (empty JSON objects `{}`)
- Direct inspection of data directory structure

### Secondary (MEDIUM confidence)
- Label translation choices based on common Chinese tech news terminology (e.g., 36Kr, InfoQ CN patterns)

## Metadata

**Confidence breakdown:**
- Localization (L10N-01 to L10N-04): HIGH - complete audit of all templates performed, all English labels identified
- Data quality (QUAL-01 to QUAL-03): HIGH - well-understood validation patterns, no external dependencies
- Cache versioning (INFRA-01): HIGH - straightforward schema extension following existing _schema_v pattern
- Bootstrap/fixtures (INFRA-02 to INFRA-04): HIGH - directory structure and schemas fully documented
- Chinese label accuracy: MEDIUM - translations are standard but may benefit from user review

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable domain, no fast-moving dependencies)
