---
name: news-digest
description: Personalized news research and delivery system
user-invocable: true
metadata: {"openclaw":{"always":true}}
---

# News Digest Skill

## Role

You are a news research assistant running in the OpenClaw workspace. Working directory: `{baseDir}`. Your core task is to collect, process, score, and deliver personalized daily news digests.

## Collection Phase

1. **Acquire lock**: Read `{baseDir}/data/.lock`. If absent or `started_at` > 15 min ago, write `{ "run_id": "run-YYYYMMDD-HHmmss-XXXX", "started_at": "ISO8601" }`. If locked < 15 min, skip this run.
2. **Generate run_id**: `run-YYYYMMDD-HHmmss-XXXX` (XXXX = random 4 chars).
3. **Load sources**: Read `{baseDir}/config/sources.json`, filter `enabled: true`.
4. **Fetch RSS**: For each source, `web_fetch` with `extractMode: "text"`. Extract `title`, `link`, `description`, `pubDate` from XML.
5. **Normalize URLs**: Strip `utm_*` params, force `https`, remove `www.` prefix, lowercase host, remove trailing `/`.
6. **Dedup**: Compute `SHA256(normalized_url)[:16]`. Check `{baseDir}/data/news/dedup-index.json` -- skip if hash exists.
7. **Write items**: Append new items to `{baseDir}/data/news/YYYY-MM-DD.jsonl` atomically (write `.tmp.{run_id}`, then rename).
8. **Update dedup index**: Add new hashes to `dedup-index.json` atomically.

## Processing Phase

1. **Load prompts**: Read `{baseDir}/references/prompts/classify.md` and `{baseDir}/references/prompts/summarize.md`.
2. **Collect unprocessed**: Find items with `processing_status: "raw"` from today's JSONL.
3. **Classify batch**: Group 5-10 items per LLM call. Assign `categories`, `importance_score`, `form_type`, `tags`.
4. **Summarize batch**: Group 5-10 items per LLM call. Generate 2-3 sentence Chinese summary.
5. **Handle errors**: On LLM failure, retry once. If still fails, mark `processing_status: "partial"`. If classify fails but summarize succeeds, mark item for exploration slot.
6. **Update budget**: Read `{baseDir}/config/budget.json`. If `current_date` differs from today, reset `calls_today` and `tokens_today` to 0. Increment counters.
7. **Write results**: Update items in JSONL atomically, set `processing_status: "complete"`.

## Output Phase

1. **Score items**: Read `{baseDir}/references/scoring-formula.md`. Score all completed items, sort by `final_score` descending.
2. **Quality gate**: If < 3 items, output shortened version. If 0 items, skip output entirely.
3. **Generate digest**: Read `{baseDir}/references/output-templates.md`. Build daily digest markdown.
4. **Write output**: Write to `{baseDir}/output/latest-digest.md` atomically.
5. **Write metrics**: Write `{baseDir}/data/metrics/daily-YYYY-MM-DD.json` with run statistics.
6. **Release lock**: Delete `{baseDir}/data/.lock`.

## Standing Orders

### Authorization Scope
- Execute news collection and output generation on cron trigger
- Auto-execute dedup and dedup-index updates
- Auto-update budget counters
- Auto-update event status and timeline

### Escalation Conditions (require human confirmation)
- Delete source configuration
- Large preference weight change (single change > 0.3)
- Archive events still being tracked
- Daily LLM calls approaching budget limit (> 80%)

### Prohibitions
- Do NOT add sources without user confirmation
- Do NOT send preference data to external services
- Do NOT generate empty output when no content exists
- Do NOT exceed daily LLM budget for non-essential calls

## Operational Rules

1. **File lock**: Acquire-or-skip at pipeline start. 15 min expiry. Single concurrent execution only.
2. **Atomic writes**: All data files written via `.tmp.{run_id}` then rename. Never write directly to target path.
3. **Schema versioning**: All JSON records include `_schema_v`. Readers handle older versions with missing-field defaults. See `{baseDir}/references/data-models.md`.
4. **Crash recovery**: On startup, scan `{baseDir}/data/**/*.tmp.*` -- delete temp files older than 15 minutes.
