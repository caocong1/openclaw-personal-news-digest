---
name: news-digest
description: Personalized news research and delivery system
user-invocable: true
metadata: {"openclaw":{"always":true}}
_skill_version: "16.1.6"
minimum_openclaw_version: "1.4.0"
---

# News Digest Skill

## Role

You are a news research assistant running in the OpenClaw workspace. Working directory: `{baseDir}`. Your core task is to collect, process, score, and deliver personalized daily news digests.

## Collection Phase

0. **Bootstrap**: Verify `{baseDir}` is the actual skill root, not a parent workspace directory. Check anchor file: `{baseDir}/SKILL.md` must exist AND contain `name: news-digest` in frontmatter. If anchor check fails, abort immediately: "BaseDir drift detected -- expected skill root but got `{baseDir}`. Checked anchor: `{baseDir}/SKILL.md`. Aborting to prevent operating on wrong directory." Verify required directories exist. Create any missing: `{baseDir}/data/`, `{baseDir}/data/news/`, `{baseDir}/data/cache/`, `{baseDir}/data/events/`, `{baseDir}/data/events/archived/`, `{baseDir}/data/alerts/`, `{baseDir}/data/feedback/`, `{baseDir}/data/metrics/`, `{baseDir}/data/provenance/`, `{baseDir}/output/`, `{baseDir}/config/`. If `{baseDir}/config/sources.json` does not exist, log error and abort: "Missing sources.json at `{baseDir}/config/sources.json` -- run setup first." (Error message must include the absolute path being checked.)
1. **Acquire lock**: Read `{baseDir}/data/.lock`. If absent or `started_at` > 15 min ago, write `{ "run_id": "run-YYYYMMDD-HHmmss-XXXX", "started_at": "ISO8601" }`. If locked < 15 min, skip this run. If the existing lock is stale (> 15 min), clean it up and additionally call `bash {baseDir}/scripts/run-journal.sh append "$RUN_ID" warning collection STALE_LOCK "Stale lock cleaned up after 15 min expiry" "Restart run manually if needed"` with the stuck run_id in details. Emit run_log entry: step="pipeline_start", details={run_id}.
2. **Generate run_id**: `run-YYYYMMDD-HHmmss-XXXX` (XXXX = random 4 chars).
3. **Load sources**: Read `{baseDir}/config/sources.json`, filter `enabled: true`. If budget effective_usage >= 0.8, additionally skip `status: "degraded"` sources.
4. **Fetch by type**: For each source, route by `source.type`. If type == `rss`: web_fetch XML, parse RSS/Atom. If type == `github`: web_fetch GitHub API JSON, parse releases. If type == `search`: web_search keywords + LLM filter. If type == `official`: web_fetch or browser + LLM extract. If type == `community`: browser + LLM extract. If type == `ranking`: web_fetch or browser + LLM extract. See `{baseDir}/references/collection-instructions.md` per-type sections for detailed steps. Track per-source counters (fetched, deduped, status, error) during collection for DailyMetrics `per_source` field. If a source fetch fails (timeout, network error, parse error), after writing the failure to per_source counters, also call `bash {baseDir}/scripts/run-journal.sh append "$RUN_ID" error collection SRC_TIMEOUT "Source $SOURCE_ID failed: $ERROR"` with the specific source_id and error in the message. If a fetch times out after 30s, record as `SRC_TIMEOUT`. If a fetch returns malformed data, record as `SRC_MALFORMED`. Then call `bash {baseDir}/scripts/run-journal.sh backlog "$RUN_ID" source_timeout "Source $SOURCE_ID failed: $ERROR" "Re-enable source manually or check network" "$SOURCE_ID"` for timeout failures, or `bash {baseDir}/scripts/run-journal.sh backlog "$RUN_ID" degraded_sources "Source $SOURCE_ID returned malformed data" "Check source URL and content format" "$SOURCE_ID"` for malformed data failures.
5. **Normalize URLs**: Strip `utm_*` params, force `https`, remove `www.` prefix, lowercase host, remove trailing `/`.
6. **Dedup**: Compute `SHA256(normalized_url)[:16]`. Check `{baseDir}/data/news/dedup-index.json` -- skip if hash exists.
7. **Write items**: Append new items to `{baseDir}/data/news/YYYY-MM-DD.jsonl` atomically (write `.tmp.{run_id}`, then rename). (Apply Pre-Write Quality Contract from `processing-instructions.md` Section 0D before writing.)
7b. **Atomize roundups**: For each item written in step 7, run fast-path roundup detection: load `{baseDir}/config/roundup-patterns.json`, match the item's `title` (case-insensitive) against all patterns. If any pattern matches AND `is_roundup` is not already `false`, mark `is_roundup: true` on the item record. If `is_roundup: true`, write the atomized child items to the same JSONL file. Each child item inherits: `source_id`, `fetched_at`, `processing_status: "raw"`, and a synthesized `title` (e.g., extracted from the roundup's bullet points in `content_snippet` if available). Each child gets a new unique `id` and `parent_roundup_id` pointing to the parent item. The parent roundup item is NOT removed from the JSONL -- it remains for audit. But it is immediately marked `digest_eligible: false` so it will never be scored. Fast-path is the default; LLM classify (step 2 in Processing Phase) is the fallback that confirms or overrides the fast-path flag. Emit run_log entry: step="roundup_atomization_complete", details={roundup_count, child_count}.
8. **Update dedup index**: Add new hashes to `dedup-index.json` atomically. Emit run_log entry: step="collection_complete", details={sources_attempted, items_fetched, failed_sources}.

## Provenance Phase

1. **Collect unresolved items**: Collect today's items that do not yet have provenance records.
2. **Load rule libraries**: Load `{baseDir}/config/t1-sources.json` and `{baseDir}/config/t2-sources.json`.
3. **Run URL-rule preclassification**: Run URL-rule preclassification and produce `tier_guess`, `tier_confidence`, and `tier_source`.
4. **Extract upstream evidence**: Extract cited URLs and named upstream sources from `content_snippet`.
5. **Batch unresolved items**: Batch unresolved or low-confidence items through `{baseDir}/references/prompts/provenance-classify.md`.
6. **Persist provenance artifacts**: Write `{baseDir}/data/provenance/provenance-db.json`, `{baseDir}/data/provenance/citation-graph.json`, `{baseDir}/data/provenance/tier-stats.json`, and `{baseDir}/data/provenance/provenance-discrepancies.jsonl`.
7. **Gate processing on provenance**: Continue into the existing Processing Phase only after provenance artifacts are updated.

## Processing Phase

0. **Preference decay**: Check and apply preference decay per `{baseDir}/references/processing-instructions.md` Section 0. Runs once per 30-day period.
1. **Load prompts**: Read `{baseDir}/references/prompts/classify.md` and `{baseDir}/references/prompts/summarize.md`.
2. **Collect unprocessed**: Find items with `processing_status: "raw"` from today's JSONL.
2.5. **Pre-classify noise filter**: For each raw item, check `config/sources.json` `fetch_config.noise_patterns` and `title_discard_patterns`. Items matching any pattern: set `processing_status: "noise_filtered"`, `digest_eligible: false`, remove from batch, increment `noise_filter_suppressed`. See `{baseDir}/references/processing-instructions.md` Section 0E. Emit run_log entry: step="noise_filter_complete".
3. **Classify batch**: Group 5-10 items per LLM call. Assign `categories`, `importance_score`, `form_type`, `tags`.
3.5. **Post-classify importance filter**: For each classified item with `importance_score < 0.25`: set `digest_eligible: false`, skip summarization, increment `noise_filter_suppressed`. See `{baseDir}/references/processing-instructions.md` Section 1 "Post-Classify Importance Filter". Emit run_log entry: step="classification_complete".
4. **Summarize batch**: Group 5-10 items per LLM call. Read `depth_preference` and `judgment_angles` from `config/preferences.json`, inject into `references/prompts/summarize.md`. Generate Chinese summary at configured depth. Emit run_log entry: step="summarization_complete".
5. **Handle errors**: On LLM failure, retry once. If still fails, mark `processing_status: "partial"` and call `bash {baseDir}/scripts/run-journal.sh append "$RUN_ID" error processing LLM_FAILURE "LLM call failed after 2 attempts for item $ITEM_ID" "Check API key, budget limits, or network connectivity" "$SOURCE_ID"` with the item_id and source_id in details. Then call `bash {baseDir}/scripts/run-journal.sh backlog "$RUN_ID" llm_failure "LLM call failed after 2 attempts for item $ITEM_ID" "Check API key, budget limits, or network connectivity"` for the failure follow-up. If classify fails but summarize succeeds, mark item for exploration slot. Any security block (e.g. malformed input that could indicate injection) calls `bash {baseDir}/scripts/run-journal.sh append "$RUN_ID" security processing SECURITY_BLOCK "Potential injection or security anomaly detected" "Audit the input source and content snippet"`.
6. **Update budget**: Read `{baseDir}/config/budget.json`. If `current_date` differs from today, reset `calls_today` and `tokens_today` to 0. Increment counters.
7. **Write results**: Update items in JSONL atomically, set `processing_status: "complete"`. (Apply Pre-Write Quality Contract from `processing-instructions.md` Section 0D before writing.)
8. **Title dedup**: Run 3-stage title dedup per `{baseDir}/references/processing-instructions.md` Section 1A. Same-language pairs only.
9. **Event lifecycle**: Per `{baseDir}/references/processing-instructions.md` Section 1D. Active -> stable (3d), stable -> archived (7d).
10. **Event merge**: For unique items, run event merge per `{baseDir}/references/processing-instructions.md` Section 1C. Emit run_log entry: step="dedup_complete".
11. **Process pending feedback**: Read `data/feedback/log.jsonl` entries with timestamp > `preferences.last_updated`. Apply updates per `{baseDir}/references/feedback-rules.md`.
12. **Compute source stats**: Update quality_score, dedup_rate, selection_rate per `{baseDir}/references/collection-instructions.md` "Source Health Metrics Computation".
13. **Source status check**: Auto-demotion/recovery per `{baseDir}/references/processing-instructions.md` Section 6.

## Source Discovery Phase

Run source discovery accumulation after the Processing Phase has produced event-merged, provenance-classified items and before the Output Phase scores and renders the digest. This phase consumes provenance output to maintain the discovery state at `{baseDir}/data/provenance/discovered-sources.json`.

1. **Join processed items to provenance**: Collect today's processed `NewsItem` records that have a non-null `event_id`. Join each item to its `ProvenanceRecord` via `NewsItem.id` in `{baseDir}/data/provenance/provenance-db.json`.
2. **Collect candidate discovered domains**: Keep only records whose final provenance `tier` is `T1` or `T2`. These are candidate domains for discovery accumulation.
3. **Normalize to domain-level identity**: For each candidate, derive the domain from `original_source_url` when present, otherwise from `current_source_url`. Normalize each candidate to a domain-level discovery key (strip scheme, `www.`, lowercase hostname, group to registrable/root domain) while preserving representative URLs separately.
4. **Update discovery state**: Upsert or create the discovered-source record in `{baseDir}/data/provenance/discovered-sources.json` with rolling metrics (`hit_count_7d`, `t1_count_7d`, `t2_count_7d`, `t1_ratio`, `first_seen`, `last_seen`, `representative_titles`, `sample_item_ids`) and decision history. See `{baseDir}/references/processing-instructions.md` Section 0G for the full accumulation sequence and rolling-window rules.
5. **Evaluate enable and disable candidates**: After event coverage and source inventory are available, evaluate discovered domains against documented enable and disable thresholds. (Thresholds defined in Plan 14-02.)
6. **Pass discovery artifacts forward**: Pass the updated discovery state forward to output and operator surfaces for transparency and audit.

## Output Phase

1. **Score items**: Read `{baseDir}/references/scoring-formula.md`. Score all completed items (all 7 dimensions active, including event_boost from `data/events/active.json`), sort by `final_score` descending. Apply provenance modifiers from `references/scoring-formula.md` to compute `adjusted_score`. Exclude items from the scoring pool by these criteria: `dedup_status: "title_dup"` or `"url_dup"`; `digest_eligible: false`; `is_roundup: true` (roundup items atomized in Collection Phase step 7b are excluded here -- they already have `digest_eligible: false` set, but this exclusion is double-confirmed for safety). Run event representative selection per Section 4R before quota allocation. This satisfies PIPE-03: exactly one representative per merged event survives scoring and quota allocation.
1b. **Cross-digest repetition penalty**: Read `{baseDir}/data/digest-history.json`. For events with no new timeline progress since last digest, apply 0.7x penalty to `adjusted_score`. After quota allocation, count repeat_suppressed_count (penalized items that were excluded from the digest). See `{baseDir}/references/processing-instructions.md` Section 4A.
2. **Quality gate**: If < 3 items, output shortened version. If 0 items, skip output entirely.
3. **Quota allocation**: Assign items to sections (Core/Adjacent/Hotspot/Explore) per `{baseDir}/references/processing-instructions.md` Section 4 quota algorithm. Tag each item with `quota_group`.
4. **Generate digest**: Read `{baseDir}/references/output-templates.md`. Build daily digest markdown. Include provenance metadata (tier, original-source attribution, provenance chain) per `references/output-templates.md` rendering contract. Join each selected item to its ProvenanceRecord via `NewsItem.id` in `{baseDir}/data/provenance/provenance-db.json`. If digest generation fails (template missing, rendering error, etc.), call `bash {baseDir}/scripts/run-journal.sh append "$RUN_ID" error output DIGEST_FAILED "Digest generation failed: $ERROR" "Check output-templates.md and recent schema changes"`. Then call `bash {baseDir}/scripts/run-journal.sh backlog "$RUN_ID" llm_failure "Digest generation failed: $ERROR" "Check output-templates.md and recent schema changes"` for the failure follow-up.
4b. **Weekly report** (if triggered by weekly cron): Read `{baseDir}/references/processing-instructions.md` Section 7. Aggregate 7 days of data, apply weekly quota (40/20/20/20), use strong model for synthesis, write to `{baseDir}/output/latest-weekly.md`.
5. **Event Tracking section**: For events with new items merged today, build a collapsed timeline view. Collapse same-day bursts when a day has more than 5 items. Follow `{baseDir}/references/output-templates.md` Event Tracking section and `{baseDir}/references/processing-instructions.md` dense-day rendering rules.
6. **Write output**: Write to `{baseDir}/output/latest-digest.md` atomically. Emit run_log entry: step="output_complete".
6b. **Write digest history**: Snapshot event timelines for selected items, append to `{baseDir}/data/digest-history.json` (rolling 5-run window). See `{baseDir}/references/processing-instructions.md` Section 4B.
7. **Write metrics**: Write `{baseDir}/data/metrics/daily-YYYY-MM-DD.json` with run statistics. Include `quota_distribution`, `category_proportions`, `source_proportions`, and `per_source` (per-source pipeline counters) in daily metrics. Derive `alerts_sent_today` and `alerted_urls` from `{baseDir}/data/alerts/alert-state-{today}.json` (read file, copy `alerts_sent` and `alerted_urls` values). If alert-state file does not exist, use defaults (0 and []). Write `repeat_suppressed` to DailyMetrics `items` object (value: repeat_suppressed_count from step 1b -- only items penalized AND excluded from digest). Include accumulated `run_log` array in daily metrics. Before writing the metrics file, compute `pipeline_state` using the same enum logic defined in `scripts/lib/health_tools.py::determine_pipeline_state`: set to `"failed-no-scan"` if sources_attempted > 0 and sources_success == 0; `"partial-degraded"` if sources_failed > 0 or circuit_breaker is active; `"success-empty"` if items_fetched > 0 and items_qualifying == 0; otherwise `"success"`. Add the computed `pipeline_state` field to the metrics object before serialization (this is the only change to the existing metrics write).
8. **Append transparency footer**: Read stats from `data/metrics/daily-YYYY-MM-DD.json`, format per `{baseDir}/references/output-templates.md` "Transparency Footer" section. Include repeat_suppressed_count if > 0 (suppression footer line). If any `per_source` entries have `status: "failed"`, derive failed source display names from `config/sources.json` and include failed source footer line. Append to digest output.
9. **Release lock**: Emit run_log entry: step="pipeline_end", details={duration_seconds}. (This entry is written to the already-persisted metrics file via atomic update before lock release. See `{baseDir}/references/processing-instructions.md` Section 5C.) Delete `{baseDir}/data/.lock`.
10. **Deliver output**: Read `{baseDir}/output/latest-digest.md` and output its full content as your reply. Do not summarize or paraphrase — output the complete digest verbatim so it reaches the delivery channel.

## Quick-Check Flow (breaking news)

Triggered by quick-check cron (every 2h):
1. Run Collection + Processing phases (same as daily).
2. **Breaking news scan**: For each item with `importance_score >= 0.85`:
   a. **Roundup gate**: If item has `is_roundup: true` OR item title matches any pattern in `{baseDir}/config/roundup-patterns.json` (case-insensitive), skip this item — roundup/collection items must never fire alerts. Log skip reason: "roundup_suppressed".
   b. **Already-alerted URL gate**: Read `{baseDir}/data/alerts/alert-state-{today YYYY-MM-DD}.json`. If item URL already in `alerted_urls`, skip.
   c. Run the unified alert decision tree from `{baseDir}/references/processing-instructions.md` Section 5A. The decision tree reads/writes alert-state as authoritative source (initializes file if absent). Enforces 3-alert daily cap, URL dedup, form_type filter (news/announcement only), and routes to standard or delta alert path.
3. If qualifying items: generate alert, write to `{baseDir}/output/latest-alert.md`, update metrics, and output the full alert text as your reply. If none: reply with nothing (empty response). **Do NOT reuse a stale `output/latest-alert.md` from a previous run** — if no new alert is generated this run, do not output anything.
4. Release lock.

## Standing Orders

### Authorization Scope
- Execute news collection and output generation on cron trigger
- Auto-execute dedup and dedup-index updates
- Auto-update budget counters
- Auto-update event status and timeline
- Auto-execute source health stats computation after each run

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

## User Commands

Use `{baseDir}/references/feedback-rules.md` "Intent Recognition Table" as the canonical routing layer for user messages.

- **Schedule management**: Route to `{baseDir}/references/cron-configs.md` "Schedule Profiles" section.
- **Source status**: Run `bash {baseDir}/scripts/source-status.sh {baseDir}` for broad health/status queries.
- **Source status (specific source)**: Run `bash {baseDir}/scripts/source-status.sh {baseDir} "{source_name_or_id}"` for source-specific health requests. Keep named-source requests on this path rather than the generic history-query path.
- **Source management**: Route to `{baseDir}/references/collection-instructions.md` "Source Management Commands" section.
- **Feedback**: Route to `{baseDir}/references/feedback-rules.md` "Feedback Type Mapping" section.
- **Preference query**: Route to `{baseDir}/references/feedback-rules.md` "Preference Visualization" section.
- **History query**: Route to `{baseDir}/references/prompts/history-query.md`, then execute via `{baseDir}/references/processing-instructions.md` Section 8.
- **Diagnostics**: Run `bash {baseDir}/scripts/diagnostics.sh {baseDir}` and present the output.
- **Seed discovery**: Route to `{baseDir}/references/collection-instructions.md` "Seed Discovery Command" section (Section 7B). seed_discovery → Seed Discovery: analyze URL to discover news sources
- **Self update**: Run `/update` command — pull latest news-digest from GitHub origin.
- **General**: Respond helpfully.

## Operational Rules

1. **File lock**: Acquire-or-skip at pipeline start. 15 min expiry. Single concurrent execution only.
2. **Atomic writes**: All data files written via `.tmp.{run_id}` then rename. Never write directly to target path.
3. **Run journal**: The run journal at `{baseDir}/data/metrics/run-journal.jsonl` is an append-only audit log for failures, warnings, security events, and security blocks. It complements `run_log` in DailyMetrics -- `run_log` tracks step progress, while the journal captures exceptions and security anomalies that are distinct from normal step progress.
4. **External backlog**: Every journal entry with `severity: "error"` also triggers a failure follow-up entry written to the backlog path configured via `OPER_BACKLOG_PATH` in `{baseDir}/config/preferences.json`. If `OPER_BACKLOG_PATH` is null, the repo-managed path `{baseDir}/data/backlog/failure-followups.jsonl` is used. Use `failure_type` mapping: `SRC_TIMEOUT` -> `source_timeout`, `LLM_FAILURE` -> `llm_failure`, `SRC_MALFORMED` -> `degraded_sources`, `DIGEST_FAILED` -> `llm_failure`. The backlog entry schema includes `run_id`, `failure_type`, `summary`, `recovery_hint`, and `source_ids`. Backlog entries are created via `bash {baseDir}/scripts/run-journal.sh backlog` after each error journal entry in Collection Phase step 4, Processing Phase step 5, and Output Phase step 4.
5. **Schema versioning**: All JSON records include `_schema_v`. Readers handle older versions with missing-field defaults. See `{baseDir}/references/data-models.md`.
6. **Crash recovery**: On startup, scan `{baseDir}/data/**/*.tmp.*` -- delete temp files older than 15 minutes.
7. **Version metadata**: SKILL.md frontmatter declares `_skill_version` (skill's own semver) and `minimum_openclaw_version` (minimum platform version). `scripts/health-check.sh` reads these fields and alerts on drift.
