# Processing Instructions

Detailed reference for the Processing Phase and Output Phase of the news digest pipeline. SKILL.md's Processing Phase and Output Phase steps expand on this document.

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
2. **Fill categories**: Read `config/categories.json`, format the 12 categories into `{categories_list}` placeholder
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
| **15+ items** | Generate full digest per `references/output-templates.md`. Approximate section distribution: Core Focus ~50%, Adjacent Dynamics ~20%, Today's Hotspot ~15%, Exploration ~15%. |

### Section Assignment

For items going into the full digest (15+ items):

1. **Core Focus** (~50% of items): Highest-scored items where `categories.primary` matches user's top topic_weights
2. **Adjacent Dynamics** (~20%): Items whose `categories.primary` is in the `adjacent` list of user's top categories (from `config/categories.json`)
3. **Today's Hotspot** (~15%): High `importance_score` items regardless of user preference match
4. **Exploration** (~15%): Items with `categories.primary = null` (partial processing), or items from categories with low user weight (`topic_weight < 0.3`), or items randomly selected for exploration based on `exploration_appetite`

These percentages are approximate targets for MVP, not strict requirements.

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
