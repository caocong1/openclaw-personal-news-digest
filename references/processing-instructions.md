# Processing Instructions

Detailed reference for the Processing Phase and Output Phase of the news digest pipeline. SKILL.md's Processing Phase and Output Phase steps expand on this document.

---

## Section 0: Preference Decay (PREF-04)

Regress preference weights toward neutral values when not reinforced by user feedback, preventing interest fixation over time.

### When to Run

At the START of each daily pipeline run, before feedback processing (Section 11 of SKILL.md) and before any LLM calls.

### Decay Check Procedure

1. Read `config/preferences.json`
2. Check `last_decay_at` field:
   - If `last_decay_at` is null OR `(now - last_decay_at) >= 30 days`: proceed with decay
   - Otherwise: skip decay, continue to next pipeline step
3. **No catch-up rule**: If 60+ days have passed, still apply only ONE decay round. Do NOT accumulate missed periods.

### Decay Formula

For each field that decays:

**topic_weights (decay toward 0.5 -- cold-start neutral):**
```
For each key in topic_weights:
  topic_weights[key] = topic_weights[key] + (0.5 - topic_weights[key]) * 0.05
```

**source_trust (decay toward 0 -- neutral/absent):**
```
For each key in source_trust:
  source_trust[key] = source_trust[key] + (0.0 - source_trust[key]) * 0.05
  If abs(source_trust[key]) < 0.01: DELETE key (clean up near-zero entries)
```

**form_preference (decay toward 0 -- neutral):**
```
For each key in form_preference:
  form_preference[key] = form_preference[key] + (0.0 - form_preference[key]) * 0.05
```

**Fields that do NOT decay:** style.*, feedback_samples, depth_preference, judgment_angles

### Write-Back

1. Set `last_decay_at` to current ISO8601 timestamp
2. Backup-before-write (existing pattern from feedback-rules.md)
3. Atomic write `config/preferences.json`
4. Log to daily metrics: `"preference_decay_applied": true`

### Interaction with Feedback

Decay runs BEFORE feedback processing. This means user feedback in the same run adjusts from the post-decay baseline, which is correct -- recent feedback should override decay drift.

---

## Section 0A: Circuit-Breaker Enforcement (COST-02)

Before each LLM batch, check budget utilization and enforce hard limits.

### Check Procedure

1. Read `config/budget.json`
2. Compute `usage_ratio = calls_today / daily_llm_call_limit`
3. Compute `token_ratio = tokens_today / daily_token_limit`
4. Use the **higher** of the two ratios as `effective_usage`

### Circuit-Breaker States

**If `effective_usage >= 1.0` (100%) -- CIRCUIT BREAK:**
- Stop ALL LLM processing (classify, summarize, filter, extract)
- **EXCEPTION:** Daily digest output generation is exempt (1 final LLM call allowed for digest assembly)
- Leave remaining items as `processing_status: "raw"` (breakpoint resume will pick them up next run)
- Log to metrics: `"circuit_breaker_activated": true`
- Add to digest footer: `"Warning: LLM budget exhausted. Some items unprocessed."`

**If `effective_usage >= alert_threshold` (default 0.8) -- WARNING:**
- Log warning: `"LLM budget at {percentage}%"`
- **CONTINUE processing normally** (warning only, do not stop)
- Add to digest footer: `"Note: LLM budget at {percentage}%"`
- This triggers SKILL.md Standing Orders escalation: notify user about approaching limit

**If `effective_usage < alert_threshold` -- PROCEED normally:**
- No action needed, continue to cache lookup and batch processing

---

## Section 0B: LLM Result Cache (COST-03)

Cache files eliminate redundant LLM calls for previously-seen URLs. Check cache before every LLM call; write results after.

### Cache Files

- `data/cache/classify-cache.json` -- keyed by URL SHA, stores classification results
- `data/cache/summary-cache.json` -- keyed by URL SHA, stores summary results

### Cache Cleanup (at start of each pipeline run)

1. Read `data/cache/classify-cache.json` and `data/cache/summary-cache.json`
2. Delete all entries where `(now - cached_at) > 7 days`
3. Atomic write cleaned cache files (write to tmp, then rename)
4. Log: `"Cache cleanup: removed {N} stale entries from classify-cache, {M} from summary-cache"`

### Cache Lookup (before each LLM batch)

For each item in the batch:

1. Compute `url_sha = SHA256(normalized_url)[:16]` (same hash as dedup-index)
2. Look up `url_sha` in `data/cache/classify-cache.json` (or `data/cache/summary-cache.json` for the summarize step)
3. **If found AND `(now - cached_at) < 7 days`:**
   - Apply cached result to item (set `categories`, `importance_score`, `form_type`, `tags` for classify; set `content_summary` for summarize)
   - Remove item from the LLM batch (skip the call)
   - Increment run metrics: `cache_hits += 1`
4. **If found but `cached_at > 7 days`:**
   - Delete stale entry
   - Keep item in batch (needs fresh LLM call)
5. **If not found:**
   - Keep item in batch

### Cache Write (after each LLM batch)

1. For each item that received a fresh LLM result:
   - Write to cache: `url_sha -> { result fields, cached_at: now ISO8601 }`
2. Atomic write the cache file (write to tmp, then rename)

---

## Section 0C: Tiered Model Strategy (COST-04)

Model tier guidance for routing LLM calls to appropriate cost/capability levels.

### Fast Model (lower cost, sufficient for structured tasks)

- **Classification** (`references/prompts/classify.md`) -- structured JSON output, well-defined categories
- **Summarization** (`references/prompts/summarize.md`) -- short factual summaries
- **Search result filtering** (`references/prompts/filter-search.md`) -- binary keep/discard decisions
- **Content extraction** (`references/prompts/extract-content.md`) -- structured data extraction

### Strong Model (higher cost, needed for nuanced reasoning)

- Event merging and timeline analysis (Phase 2)
- Weekly report generation with cross-domain synthesis (Phase 3)
- Ambiguous feedback interpretation when disambiguation cascade fails
- Complex query answering from history

### Implementation Note

If the OpenClaw platform supports model selection via prompt parameters or system settings, specify the tier. If not, use the default model for all tasks and log this as a future optimization opportunity. The tiered guidance is documented here so it can be activated when platform support is confirmed.

---

## Section 1: Batch LLM Processing

### Collecting Unprocessed Items

1. Read today's data file: `data/news/YYYY-MM-DD.jsonl`
2. Filter items where `processing_status` is `"raw"` or `"partial"`
3. Group into batches of 5-10 items

### Classification Batch

For each batch:

1. **Load prompt**: Read `references/prompts/classify.md`
2. **Fill categories**: Read `config/categories.json`, format the 12 categories into `{categories_list}` placeholder. For each category, include `id`, `name_zh`, `name_en`, `description`, and `negative_examples` (the list of items that should NOT be classified under that category). The formatted output for each category should look like:
   ```
   - {id} ({name_zh} / {name_en}): {description}
     NOT this category: {negative_examples[0]}; {negative_examples[1]}; {negative_examples[2]}
   ```
   This ensures the LLM sees both what belongs in a category and what does not.
3. **Fill batch data**: For each item in the batch, format into `{news_batch}`:
   ```
   ID: {item.id}
   Title: {item.title}
   Source: {item.source_id}
   Content: {item.content_snippet (from description, stripped of HTML)}
   ---
   ```
4. **Process**: Use the filled prompt template to classify the batch (the agent performs classification using the template as instructions)
5. **Parse response**: Expect a JSON array. Match each result to its item by `id`
6. **Update items**: Set `categories.primary`, `categories.tags`, `importance_score`, `form_type` from the classification result

### Summarization Batch

For the same batch:

1. **Load prompt**: Read `references/prompts/summarize.md`
2. **Fill batch data**: For each item, format into the input template:
   ```
   ID: {item.id}
   Title: {item.title}
   Source: {item.source_id}
   Content: {item.content_snippet}
   ---
   ```
3. **Process**: Use the filled prompt template to generate summaries
4. **Parse response**: Expect a JSON array. Match each result to its item by `id`
5. **Update items**: Set `content_summary` from the summarization result

### Finalizing Batch

After both classification and summarization succeed for an item:

1. Set `processing_status: "complete"`
2. Write updated items back to JSONL atomically (see `references/collection-instructions.md` Section 4)
3. Update budget counters (see Section 2 below)

### Budget Tracking

After each batch completes:

1. Read `config/budget.json`
2. **Date rollover check**: If `current_date` != today's date (YYYY-MM-DD):
   - Reset `calls_today` to 0
   - Reset `tokens_today` to 0
   - Set `current_date` to today's date
3. Increment `calls_today` by the number of actual LLM calls made (exclude cache hits)
4. Estimate and increment `tokens_today` (approximate: count input characters + output characters, multiply by token estimation factor)
5. Write updated `budget.json` atomically
6. Update daily metrics (`data/metrics/daily-YYYY-MM-DD.json`):
   - Increment `llm.calls` by actual LLM calls made
   - Increment `llm.cache_hits` by the number of items served from cache this batch
   - Increment `llm.tokens_input` and `llm.tokens_output` accordingly

---

## Section 1A: Title Near-Duplicate Detection (PROC-04)

After URL dedup and batch LLM processing (classification + summarization), run title-level near-duplicate detection to merge items reporting the same story from different sources. This is a 3-stage funnel that progressively narrows candidates to minimize LLM calls.

### Stage A: Rule Normalization

For each item in today's batch:

1. **Detect language**: Check if majority of characters are CJK (U+4E00-U+9FFF). If >50% CJK characters -> set `language: "zh"`, otherwise set `language: "en"`.
2. **Strip common prefixes/suffixes** (comparison only, preserve original title for display):
   - Chinese: "快讯:", "独家:", "【视频】", "【独家】", "突发:", "重磅:"
   - English: "Breaking:", "Update:", "Exclusive:", "[Video]", "[Exclusive]", "BREAKING:"
3. **Normalize**: Remove all punctuation, collapse whitespace, lowercase (for English) or keep as-is (for Chinese characters).
4. Store normalized title separately -- original title is always preserved for display.

### Stage B: Jaccard Bigram Similarity

For each pair of items in the same day's batch with the **SAME** `language` value:

1. Generate character bigrams from normalized title: `bigrams(text) = {text[i:i+2] for i in range(len(text)-1)}`
2. Compute Jaccard similarity: `J = |intersection(bigrams_a, bigrams_b)| / |union(bigrams_a, bigrams_b)|`
3. If `J >= 0.6`: add pair to candidate group for LLM judgment

**Efficiency constraint**: Only compare items sharing the same `categories.primary` OR same `source_id`. This limits comparisons from O(n^2) to manageable clusters.

**Cross-language prohibition (PROC-06)**: Stage B MUST skip pairs where `item_a.language != item_b.language`. Chinese and English titles are NEVER compared for title dedup. Cross-language merging happens only at event level in Plan 02.

Expected volume: ~500 items/day -> 20-50 candidate pairs.

### Stage C: LLM Precise Judgment

Only for candidate groups identified in Stage B (not all items):

1. Batch up to 10 candidate titles per LLM call using `references/prompts/dedup.md`
2. Fill `{title_list_with_ids}` with candidate title IDs and original titles (not normalized)
3. Parse LLM response: JSON array of duplicate group ID lists
4. For each duplicate group:
   - Keep the item with the highest `source.credibility` (from `config/sources.json`) as the primary item
   - For each secondary item: set `dedup_status: "title_dup"` and `duplicate_of: <primary_item_id>`
5. Items not in any duplicate group remain `dedup_status: "unique"`

Expected volume: 5-15 LLM calls/day for this step.

---

## Section 1B: Multi-Language Processing (PROC-06)

Rules for handling Chinese and English content across the pipeline.

### Language Detection

Set the `language` field on each NewsItem during Stage A of title dedup:
- Compute CJK character ratio: count characters in U+4E00-U+9FFF range / total non-whitespace characters
- If ratio > 0.5 -> `language: "zh"`
- Otherwise -> `language: "en"`

### Title Dedup: Per-Language Independent Pipelines

- Chinese items are deduped only against other Chinese items
- English items are deduped only against other English items
- Cross-language title comparison NEVER happens (Jaccard bigram across scripts produces garbage results)

### Summarization

- All items receive Chinese-language summaries regardless of source language (existing behavior in `references/prompts/summarize.md`)
- For English source items, the LLM reads the English content and produces a Chinese summary

### Output Display Format for English Items

English-language items appear in the digest with the original English title plus a Chinese translation:

```
### Original English Title (Chinese Translation of Title)
{Chinese summary, 2-3 sentences}
Source: {source_name} | {form_type} | Importance: {score}
```

Example:
```
### OpenAI Announces GPT-6 (OpenAI 发布 GPT-6)
OpenAI 正式发布 GPT-6 模型，在多项基准测试中大幅超越前代。该模型引入了新的推理架构，定价降低 40%。
Source: TechCrunch | news | Importance: 0.9
```

### Event Merging

Cross-language event merging is allowed -- the same event reported in both Chinese and English sources can be merged at event level. This is handled in Plan 02 (not in title dedup).

---

## Section 1C: Event Merging (EVT-01)

After title dedup, run event merging for all items with `dedup_status: "unique"`. This is a 3-step funnel that progressively narrows candidate events to minimize LLM calls while maintaining merge accuracy.

### Step 1 -- Topic Pre-filter

1. Load `data/events/active.json`
2. Filter events where `event.topic == item.categories.primary`
3. Include events with status `"stable"` (they may reactivate if new related news appears)
4. Exclude events with status `"archived"` (already moved to archive files)
5. Expected: 50-200 total events -> 5-20 same-topic candidates

### Step 2 -- Keyword Quick Match

1. Tokenize the item title into words (split on whitespace and punctuation)
2. For each candidate event from Step 1, count overlapping tokens with `event.keywords[]`
3. Keep candidates with overlap >= 2 tokens
4. If no candidates remain after this step, proceed directly to "new event" creation (skip Step 3)
5. Expected: 5-20 candidates -> 1-5 candidates

### Step 3 -- LLM Precise Merge

1. Use `references/prompts/merge-event.md` with the 1-5 candidate events
2. Use **strong model tier** per COST-04 (event merging requires nuanced reasoning about whether news reports the same core event)
3. Fill prompt placeholders: `{news_title}`, `{news_summary}`, `{news_primary_category}`, `{event_list}` (candidate event id, title, summary, status)
4. Parse LLM response JSON: `{ action, event_id, relation, brief, new_event_title, new_event_keywords }`

**On "merge" action:**
- Add `item.id` to `event.item_ids`
- Add timeline entry: `{ news_id: item.id, relation, timestamp: now, brief }`
- Update `event.last_updated` to now
- If event status was `"stable"`, transition back to `"active"` (reactivation)
- Update `event.importance` to `max(event.importance, item.importance_score)`
- Set `item.event_id` to the merged event's id
- If relation is not `"initial"`: set `item.dedup_status` to `"event_merged"`
- If relation is `"update"`, `"correction"`, or `"reversal"`: re-summarize the event with 1 additional LLM call (strong model) incorporating the new information -- EVT-04. Skip re-summarization for `"analysis"` relation (opinion/interpretation, not new facts).

**On "new" action:**
- Create new Event object per the Event schema in `references/data-models.md`:
  - `id`: `"evt-"` + random 8-char alphanumeric
  - `title`: from LLM `new_event_title`
  - `summary`: `item.content_summary`
  - `first_seen`: now (ISO8601)
  - `last_updated`: now (ISO8601)
  - `status`: `"active"`
  - `topic`: `item.categories.primary`
  - `importance`: `item.importance_score`
  - `keywords`: from LLM `new_event_keywords` (3-5 keywords)
  - `item_ids`: `[item.id]`
  - `timeline`: `[{ news_id: item.id, relation: "initial", timestamp: now, brief }]`
  - `_schema_v`: 2
- Append new event to `data/events/active.json`
- Set `item.event_id` to the new event's id

**Write:** Updated `data/events/active.json` atomically (write to tmp, then rename).

### Cross-language Event Merging (PROC-06)

Unlike title dedup, event merging DOES work cross-language. The LLM prompt handles Chinese and English titles together for merge decisions. A Chinese news report and an English news report about the same event can be merged into a single event entry.

---

## Section 1D: Event Lifecycle Management (EVT-02)

Run at the **START** of each pipeline run, **before** event merging (Section 1C). This ensures the candidate event pool is current and manageable.

### Lifecycle Transition Procedure

1. Read `data/events/active.json`
2. For each event in the array:
   - **Active -> Stable:** If `status == "active"` and `(now - last_updated) > 3 days`, set `status = "stable"`
   - **Stable -> Archived:** If `status == "stable"` and `(now - last_updated) > 7 days`, set `status = "archived"`, move event to archive file
3. Write updated `data/events/active.json` atomically (excluding archived events)

### Archive File Management

- Archived events are stored in `data/events/archived/YYYY-MM.json` (grouped by month of archival)
- Create the `data/events/archived/` directory if it does not exist
- Each archive file is a JSON array of Event objects
- If the archive file already exists, read it, append newly archived events, write atomically
- Archived events are permanent records and are not deleted

### State Transition Summary

```
active  ---(3 days no update)---> stable
stable  ---(7 days no update)---> archived (moved to data/events/archived/YYYY-MM.json)
stable  ---(new item merged)----> active   (reactivation, handled in Section 1C)
```

---

## Section 2: Error Handling

Error handling matrix derived from the design document. Apply these rules during batch processing.

### Error Type 1: LLM Call Failure

**Trigger**: LLM call returns an error, times out, or produces no response.

**Action**:
1. Skip classification/summarization for the affected batch
2. Mark all items in the batch as `processing_status: "partial"`
3. Items with `"partial"` status appear in the digest with title + source only (no summary, no classification)
4. Log the failure for metrics

### Error Type 2: LLM Format Error (Invalid JSON)

**Trigger**: LLM returns a response that is not valid JSON, or JSON structure does not match expected schema.

**Action**:
1. **Retry once** with the same prompt
2. If retry succeeds: proceed normally
3. If retry still fails: mark all items in the batch as `processing_status: "partial"`
4. Increment `llm.failures` in daily metrics

### Error Type 3: Partial Processing (Classify Fails, Summarize Succeeds)

**Trigger**: Classification fails (or produces invalid results for specific items) but summarization succeeds.

**Action**:
1. Set `categories.primary` to `null` for the affected items
2. Set `importance_score` to default `0.3`
3. Keep the successful summary in `content_summary`
4. Mark `processing_status: "partial"`
5. During output generation, items with `null` primary category enter the digest in the **Exploration** section

### Error Type 4: Partial Processing (Classify Succeeds, Summarize Fails)

**Trigger**: Classification succeeds but summarization fails.

**Action**:
1. Keep classification results (`categories`, `importance_score`, `form_type`)
2. Set `content_summary` to `null`
3. Mark `processing_status: "partial"`
4. During output generation, use title as a stand-in for the summary

### Budget Limit Reached

**Trigger**: Before processing a batch, `calls_today >= daily_llm_call_limit` in `config/budget.json`.

**Action**:
1. **Stop processing immediately**. Do not process this batch or any further batches.
2. Leave remaining items as `processing_status: "raw"` -- they will be picked up on the next run (breakpoint resume)
3. Log "budget limit reached" in daily metrics

### Budget Warning

**Trigger**: Before processing a batch, `calls_today >= alert_threshold * daily_llm_call_limit` (default: 80% of limit).

**Action**:
1. Log a warning: "LLM budget at {percentage}% ({calls_today}/{daily_llm_call_limit} calls)"
2. **Continue processing** -- the warning is informational only
3. The hard stop occurs only when the actual limit is reached

---

## Section 3: Breakpoint Resume (PROC-08)

The pipeline supports resuming interrupted runs without reprocessing completed items.

### Resume Logic

At the start of the Processing Phase:

1. Read today's `data/news/YYYY-MM-DD.jsonl`
2. Scan all items for their `processing_status`:
   - `"raw"` items: Need full processing (classify + summarize)
   - `"partial"` items: Need only the missing step
   - `"complete"` items: Skip entirely

### Partial Item Recovery

For items with `processing_status: "partial"`:

| Has categories? | Has summary? | Action |
|-----------------|-------------|--------|
| No | No | Full process (classify + summarize) |
| Yes | No | Summarize only |
| No | Yes | Classify only |
| Yes | Yes | Unexpected -- mark as "complete" |

**Detection logic**:
- "Has categories" = `categories.primary` is not `null`
- "Has summary" = `content_summary` is not `null`

### Idempotency Guarantees

- Processing the same item twice produces the same result (LLM may vary slightly, but status transitions are safe)
- Items already marked `"complete"` are never re-processed
- Budget counters are only incremented for new LLM calls, not for skipped items

---

## Section 4: Output Generation (OUT-01, OUT-05)

### Scoring

1. Read `references/scoring-formula.md`
2. For each item with `processing_status: "complete"` or `"partial"`:
   - Compute `final_score` using the 7-dimension formula (MVP simplification: `feedback_boost = 0`, `event_boost = 0`)
   - For `"partial"` items with missing data, use defaults:
     - `importance_score` default: `0.3`
     - `categories.primary` default: `null` (routes to Exploration section)
     - `form_type` default: `"other"`
3. Sort all scored items by `final_score` descending

### Quality Gate

Apply quality gate based on the number of scored items:

| Scored Items | Action |
|-------------|--------|
| **0 items** | Do NOT generate output. Log "no content for digest" in metrics. Set `output.generated: false`. Release lock and exit. |
| **1-2 items** | Generate a shortened digest with only the **Core Focus** section. Omit all other sections. |
| **3-14 items** | Generate digest with available sections. Omit any section that would be empty. |
| **15+ items** | Generate full digest per `references/output-templates.md`. Section distribution enforced by quota algorithm below. |

### Quota-Based Section Assignment (ANTI-01, ANTI-02)

For items going into the full digest (15+ items), apply the following deterministic quota algorithm. This replaces the previous approximate percentage targets.

#### Step 1 -- Classify Items into Quota Groups

Read `config/preferences.json` topic_weights and `config/categories.json` adjacent mappings. For each scored item, assign a quota group:

- **"core"**: `item.categories.primary` has `topic_weight >= 0.7` in preferences.json
- **"adjacent"**: `item.categories.primary` is in the `adjacent` list of any core category (from categories.json) AND is not itself core
- **"hotspot"**: `item.importance_score >= 0.8` AND not core AND not adjacent
- **"explore"**: everything else

**Cold-start handling:** When NO topic reaches `topic_weight >= 0.7` (e.g., all weights are 0.5 at initial setup), use the **top-3 topics by weight** as pseudo-core. If multiple topics tie, break ties alphabetically by category ID. This preserves quota structure during cold start.

#### Step 2 -- Compute Target Counts

Given N = target item count (15-25 for daily digest):

- `core_target = round(N * 0.50)`
- `adjacent_target = round(N * 0.20)`
- `hotspot_target = round(N * 0.15)`
- `explore_target = round(N * 0.15)`

#### Step 3 -- Fill from Each Group

Select items from each group, ordered by `final_score` descending, up to the group's target count.

#### Step 4 -- One-Way Chain Yielding (ANTI-02)

If any group is underfilled (fewer available items than target), yield remaining slots in one direction only:

1. If **explore** underfilled: yield remaining slots to **adjacent**
2. If **adjacent** underfilled: yield remaining slots to **hotspot**
3. If **hotspot** underfilled: yield remaining slots to **core**

Direction is strictly one-way: explore -> adjacent -> hotspot -> core (one-way chain yielding). Slots never yield in the reverse direction (core never yields to explore). Each yield step selects the next-best items by `final_score` from the receiving group.

#### Step 5 -- Reverse Diversity Constraints (ANTI-03)

Read last 3 days of `data/metrics/daily-*.json` to get `category_proportions` and `source_proportions` history.

- **Topic concentration cap:** If the same `categories.primary` topic exceeds 60% of the digest for 3 consecutive days, cap that topic at 50% today. Replace excess items with next-best items from other categories (by `final_score`).
- **Source concentration cap:** If the same `source_id` exceeds 30% of the digest for 3 consecutive days, cap that source at 20% today. Replace excess items with next-best items from other sources.
- **Stale event filter:** If the same event (`event_id`) has been pushed for > 3 consecutive days, include only if the item has `relation != "initial"` (i.e., new developments only).

**Grace period:** If fewer than 3 days of metrics with `category_proportions` data exist, skip ANTI-03 constraints entirely. Log: `"ANTI-03 grace period: insufficient history."`

#### Step 6 -- Hotspot Injection (ANTI-04)

After quota fill, check for items with `importance_score >= 0.8` that were excluded from the selected list:

1. Force-inject these items into the candidate pool (add to the selected list)
2. Injected items are still subject to title dedup (no duplicates) and quality checks
3. Tag injected items with `quota_group: "hotspot"`

#### Step 7 -- Preference Correction (ANTI-05)

After final selection:

1. **Minimum category exposure:** Check if each of the 12 categories has >= 2% representation in the final list. If any category has 0% and items exist for it in the scored pool, swap the lowest-scored item in the largest quota group with the highest-scored item from the missing category.

2. **Exploration appetite auto-increase:** Read `config/preferences.json` fields `style.exploration_appetite` and `style.last_exploration_increase`:
   - If `last_exploration_increase` is null or >= 7 days ago: set `exploration_appetite += 0.05` (cap at 0.4), update `last_exploration_increase` to today's date (ISO8601)
   - Write preferences.json atomically (backup-before-write pattern per existing convention)

#### Step 8 -- Tag Items with Quota Group

Each selected item gets a `quota_group` tag: `"core"` / `"adjacent"` / `"hotspot"` / `"explore"`. This tag is used by the output template to assign items to the correct digest section.

### Digest Assembly

1. Read `references/output-templates.md` for the Markdown format
2. Fill sections with assigned items using the template structure
3. For each item:
   - **Core Focus**: Full format (title, 2-3 sentence summary, source, form_type, importance)
   - **Adjacent Dynamics**: Compact format (title, 1-sentence summary, source)
   - **Today's Hotspot**: Compact format (title, 1-sentence summary, source)
   - **Exploration**: Compact format with recommendation reason
4. Omit sections with 0 items (do not render empty section headers)
5. Omit **Event Tracking** section in MVP (no active events)
6. Append footer with run statistics

### Writing Output

1. Generate digest Markdown content
2. Write to `output/latest-digest.md` atomically (write to `.tmp.{run_id}`, then rename)

### Writing Metrics

1. Compile daily metrics following the DailyMetrics schema in `references/data-models.md`
2. Fill all counters: sources (total, success, failed), items (fetched, deduped, classified, partial, selected), llm (calls, tokens, failures), output (type, item_count, generated)
3. Write to `data/metrics/daily-YYYY-MM-DD.json` atomically

### Releasing Lock

After output and metrics are written:

1. Delete `data/.lock`
2. Pipeline run is complete

---

## Section 5: Metrics Collection for Transparency

During each pipeline run, track these counters for the transparency footer and breaking news alerting:

| Metric | Source | When Updated |
|--------|--------|--------------|
| source_count | Count of `enabled: true` in sources.json | At run start |
| items_fetched | Items returned by collection phase | After collection |
| items_new | Items that passed dedup | After dedup |
| items_processed | Items reaching `processing_status: "complete"` | After processing |
| llm_calls | `calls_today` from budget.json | After each LLM batch |
| cache_hits | Classify + summarize cache hits | After each cache lookup |
| alerts_sent_today | Breaking news alerts sent (integer, default 0) | After alert delivery |
| alerted_urls | URLs already alerted today (array, default []) | After alert delivery |

All metrics are written to `data/metrics/daily-YYYY-MM-DD.json` at the end of each run.

The daily digest output phase reads these metrics to populate the Transparency Footer (see `references/output-templates.md` "Transparency Footer" section).

The quick-check flow reads `alerts_sent_today` and `alerted_urls` to enforce the daily alert cap and URL dedup for breaking news.

---

## Section 6: Source Auto-Demotion and Recovery (SRC-09)

Implements source auto-demotion and auto-recovery based on rolling quality_score thresholds.

### When to Run

After source health stats computation (SKILL.md Processing Phase step 12 "Compute source stats"), check all sources for status transitions.

### Demotion Check (active -> degraded)

For each source in sources.json where `status == "active"`:

1. If `stats.quality_score < 0.2`:
   a. If `stats.degraded_since` is null: set `stats.degraded_since = today` (ISO8601 date). This starts the countdown.
   b. If `stats.degraded_since` is NOT null AND `(today - stats.degraded_since) >= 14 days`: set `status = "degraded"`. Log alert: `"Source {name} auto-demoted: quality_score < 0.2 for 14 consecutive days"`.
2. If `stats.quality_score >= 0.2`: reset `stats.degraded_since = null`. Quality recovered before the 14-day trigger -- reset counter. This provides hysteresis against brief dips.

### Recovery Check (degraded -> active)

For each source in sources.json where `status == "degraded"`:

1. If `stats.quality_score > 0.3`:
   a. If `stats.recovery_streak_start` is null: set `stats.recovery_streak_start = today` (ISO8601 date). This starts the recovery countdown.
   b. If `stats.recovery_streak_start` is NOT null AND `(today - stats.recovery_streak_start) >= 7 days`: set `status = "active"`, reset `stats.degraded_since = null`, reset `stats.recovery_streak_start = null`. Log: `"Source {name} auto-recovered: quality_score > 0.3 for 7 consecutive days"`.
2. If `stats.quality_score <= 0.3`: reset `stats.recovery_streak_start = null`. Quality dipped again -- reset recovery counter.

### Effect on Scoring

Degraded sources are NOT removed from collection. They are still fetched each run. However, items from degraded sources receive a scoring penalty:
- During scoring (Section 4), if `item.source.status == "degraded"`: apply a 0.5x multiplier to the `source_trust` dimension value before the weighted sum. This deprioritizes degraded source items without completely excluding them.
- If budget is tight (effective_usage >= 0.8 per Section 0A circuit-breaker), skip degraded sources in collection to save budget for healthy sources.

### Write-Back

Atomic write `config/sources.json` after all status checks. Use backup-before-write pattern.

---

## Section 7: Weekly Report Generation (OUT-03)

Generates a weekly trend report aggregating 7 days of data with cross-domain synthesis using the strong model tier.

### Trigger

Weekly cron job (Sunday 20:00 CST) or manual user request.

### Data Collection (pre-LLM)

1. Read last 7 days of `data/news/YYYY-MM-DD.jsonl` files. Collect all items with `processing_status: "complete"`.
2. Read last 7 days of `data/metrics/daily-*.json` files. Aggregate totals.
3. Read `data/events/active.json` for event timelines. Include events with status "active" or "stable" that have timeline entries in the last 7 days.
4. Read `config/sources.json` for source health data.
5. Read `config/preferences.json` for `depth_preference` and `judgment_angles`.

### Pre-filtering (to avoid LLM context overflow)

- From the 7-day item pool, use only items that were selected for daily digests (items with `quota_group` set). Expected: 15-25/day * 7 = ~105-175 items.
- If still > 200 items: further filter to top 150 by `final_score`.
- Group items by `categories.primary` for per-category summaries.
- Pass event summaries rather than full item lists to the LLM.

### Weekly Quota (different from daily)

Apply weekly quota ratios: core 40% / adjacent 20% / hotspot 20% / explore 20%.
The weekly report shows more exploration and hotspot content than daily (daily: 50/20/15/15).
Target 30-50 items for weekly report. Apply the same quota algorithm from Section 4 but with weekly ratios.

### Category Minimum

Ensure >= 5 different categories are represented. If fewer than 5 categories have items, include the best item from each missing category that has ANY items in the 7-day pool (even if not selected for daily digests).

### LLM Synthesis

1. Use `references/prompts/weekly-report.md` template
2. Fill placeholders with aggregated data
3. Use **strong model tier** (COST-04) for this call -- cross-domain synthesis requires nuanced reasoning
4. Parse LLM output: extract "One Week Overview" and "Cross-Domain Connections" sections

### Assembly

1. Fill weekly report template from `references/output-templates.md`
2. Write to `output/latest-weekly.md` atomically
3. Write weekly metrics to `data/metrics/weekly-{start_date}.json` (separate from daily metrics)

---

## Section 8: History Query Execution (HIST-01 through HIST-05)

### Overview

When the user sends a natural language query (not source management, not feedback, not preference query), classify query type using `references/prompts/history-query.md`, then execute the matching procedure below. Cap all results at 20 items.

### HIST-01: Recent Activity Query

**Trigger:** User asks about recent/latest/today's news (e.g., "最新消息", "what's new", "今天有什么", "latest news").

**Procedure:**
1. Read today's `data/news/YYYY-MM-DD.jsonl`
2. Filter items with `processing_status: "complete"`
3. Sort by `final_score` descending (if available) or `importance_score` descending
4. Cap at 20 items
5. Format response: compact list with title, 1-sentence summary, source, importance

**Response format:**
```
## Recent News (last 24 hours)
Found {N} items.

1. **{title}** -- {1-sentence summary}
   Source: {source_name} | Importance: {score} | {time_ago}
2. ...
```

### HIST-02: Topic Review Query

**Trigger:** User asks about a specific topic over a time period (e.g., "这周的 AI 新闻", "AI news this week", "show me dev-tools from last 3 days").

**Procedure:**
1. Classify the topic using `config/categories.json` category IDs
2. Read N days of `data/news/YYYY-MM-DD.jsonl` files (default 7, max 30)
3. Filter items where `categories.primary == matched_topic` AND `processing_status: "complete"`
4. Sort by `published_at` descending
5. Cap at 20 items
6. Use LLM to generate a brief trend summary of the filtered items (2-3 sentences)

**Response format:**
```
## {Topic Name} News (last {N} days)
{LLM trend summary: 2-3 sentences}

Found {total} items, showing top {shown}:
1. **{title}** -- {1-sentence summary}
   Source: {source_name} | {date} | Importance: {score}
2. ...
```

### HIST-03: Event Tracking Query

**Trigger:** User asks about a specific event's developments (e.g., "某某事件后续", "what happened with X", "follow-up on the merger").

**Procedure:**
1. Read `data/events/active.json`
2. Match event by keyword overlap: tokenize user query keywords, compare against `event.keywords` and `event.title`
3. If multiple matches: present top 3 candidates and ask user to clarify
4. If single match: present full event timeline

**Response format:**
```
## Event: {event_title}
Status: {status} | Importance: {importance} | First seen: {date}

{event_summary}

### Timeline
- [{date}] {brief} ({relation}) -- Source: {source_name}
- [{date}] {brief} ({relation}) -- Source: {source_name}
...

Related items: {item_count} total
```

If no event match found, also scan last 7 days of JSONL for items matching the query keywords and present those instead.

### HIST-04: Hotspot Scan Query

**Trigger:** User asks about missed or high-importance news outside their interests (e.g., "我错过了什么", "what did I miss", "有什么重要的我没关注的").

**Procedure:**
1. Read `config/preferences.json` to get `topic_weights`
2. Read last 7 days of JSONL files
3. Filter items where: `importance_score >= 0.7` AND `topic_weights[categories.primary] < 0.5`
4. Sort by `importance_score` descending
5. Cap at 20 items

**Response format:**
```
## Things You Might Have Missed
High-importance news outside your usual interests:

1. **{title}** -- {1-sentence summary}
   Category: {category} (your weight: {weight}) | Importance: {score}
   Why shown: Important event in a category you don't usually follow
2. ...
```

### HIST-05: Source Analysis Query

**Trigger:** User asks about a specific source's performance (e.g., "36Kr 怎么样", "how is TechCrunch doing", "source health").

**Procedure:**
1. Read `config/sources.json`
2. Match source by name (case-insensitive substring match)
3. If multiple matches: list candidates and ask user to clarify
4. If single match: format source health dashboard

**Response format:**
```
## Source: {source_name}
Type: {type} | Status: {status} | Enabled: {enabled}

### Performance (7-day rolling)
- Quality score: {quality_score}
- Dedup rate: {dedup_rate} ({interpretation})
- Selection rate: {selection_rate} ({interpretation})
- Total fetched: {total_fetched}
- Last fetch: {last_fetch}
- Consecutive failures: {consecutive_failures}

{If degraded: "Degraded since: {degraded_since}. Source will auto-recover when quality_score > 0.3 for 7 consecutive days."}
```

### Query Performance Guidelines

- Default lookback: 1 day (HIST-01), 7 days (HIST-02, HIST-04), event lifetime (HIST-03)
- Max lookback: 30 days. If user requests longer range, cap at 30 and inform: "Showing last 30 days (maximum range)."
- JSONL files are date-partitioned so lookback maps directly to file count
- If no results found for a query, inform the user and suggest broadening the search (longer time range or different topic)
