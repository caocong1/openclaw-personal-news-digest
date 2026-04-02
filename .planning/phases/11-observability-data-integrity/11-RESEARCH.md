# Phase 11: Observability & Data Integrity - Research

**Researched:** 2026-04-02
**Domain:** Metrics accuracy, structured logging, schema governance, diagnostics tooling
**Confidence:** HIGH

## Summary

Phase 11 addresses four observability gaps in the news-digest pipeline: (1) the transparency footer's `source_count` should reflect only enabled sources and name any failed sources, (2) DailyMetrics needs a `run_log` array capturing timestamped pipeline milestones, (3) a schema version registry should document current versions and change history for all data models, and (4) a diagnostics command should consolidate metrics, alert-state, and digest-history into a single operator-readable report.

All four requirements are documentation/config/prompt-only changes -- no runtime code (consistent with project constraint that this is a prompt/config/reference-doc project). The changes touch `references/output-templates.md`, `references/data-models.md`, `references/processing-instructions.md`, `SKILL.md`, and potentially a new `scripts/diagnostics.sh`. The existing `scripts/health-check.sh` provides a strong foundation for OBS-04 but does not read digest-history or alert-state in a consolidated way.

**Primary recommendation:** Implement as 3 plans -- (1) source_count accuracy + failed source footer, (2) run_log schema + population instructions, (3) schema version registry + diagnostics command.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OBS-01 | source_count reflects enabled sources; footer shows failed source names | Transparency footer in output-templates.md currently defines source_count as "Number of enabled sources in sources.json at time of run" but does NOT name failed sources. The footer template and SKILL.md Output Phase step 8 need updates to append failed source names. The per_source field in DailyMetrics already tracks which sources failed (status: "failed" with error message). |
| OBS-02 | DailyMetrics includes run_log array populated during pipeline execution | DailyMetrics schema in data-models.md has no run_log field. Need to add a new `run_log` array field with timestamped entries at key pipeline milestones. SKILL.md pipeline steps need log-emit instructions at each phase boundary. |
| OBS-03 | Schema version registry with current versions and change history | data-models.md already has a "New Fields Registry" table and "Schema Change Procedure". Need to formalize a "Schema Version Registry" section that lists each model's current _schema_v, what changed at each version, and date of change. This is largely a documentation consolidation task. |
| OBS-04 | Diagnostics command reads metrics + alert-state + digest-history | health-check.sh reads metrics and does consistency checks but does NOT read alert-state or digest-history. A new diagnostics command (or extension of health-check.sh) needs to consolidate all three data sources into a single report. |
</phase_requirements>

## Architecture Patterns

### Current State Analysis

**Transparency Footer (OBS-01):**
The footer template in `references/output-templates.md` lines 148-165 currently shows:
```
统计: {source_count} 个来源已检查 | {items_processed} 条已处理 | {llm_calls} 次 LLM 调用 | {cache_hits} 次缓存命中
```
- `source_count` is defined as "Number of enabled sources in sources.json at time of run" (correct)
- However, there is no mention of listing failed source names
- The `per_source` field in DailyMetrics already tracks `status: "failed"` per source
- SKILL.md Output Phase step 7 writes metrics including per_source
- SKILL.md Output Phase step 8 reads metrics and appends footer

The gap: footer does not include a "failed sources" line. Need to add conditional footer line like:
```
采集失败: {failed_source_names} (共 {failed_count} 个)
```

**DailyMetrics run_log (OBS-02):**
The DailyMetrics schema in `references/data-models.md` has no `run_log` field. The pipeline has clear phase boundaries that should be logged:
1. Lock acquired
2. Collection started / completed
3. Processing started / completed (with sub-milestones: noise filter, classify, summarize, title dedup, event merge)
4. Output generation started / completed
5. Metrics written
6. Lock released

Each entry should have: `{ "step": "string", "timestamp": "ISO8601", "details": {} }`.

The `run_log` needs to be accumulated in-memory during the pipeline run and written as part of the DailyMetrics JSON at Output Phase step 7.

**Schema Version Registry (OBS-03):**
The "New Fields Registry" table in data-models.md is field-oriented, not version-oriented. Need a version-oriented registry that shows:
- Each model name
- Current _schema_v
- Version history: what changed at each increment
- Date of change (phase reference)

This is a documentation restructuring task within data-models.md.

**Diagnostics Command (OBS-04):**
`scripts/health-check.sh` already reads daily metrics and checks various health conditions. The diagnostics command needs to additionally read:
- `data/alerts/alert-state-{today}.json` -- show today's alert activity
- `data/digest-history.json` -- show recent digest runs, repeat suppression stats
- Consolidate with existing metrics into a single "system status report"

### Recommended Approach

**OBS-01 changes:**
1. `references/output-templates.md` -- Add failed source line to Transparency Footer section
2. `references/processing-instructions.md` Section 5 -- Add instruction to track failed source names during collection
3. `SKILL.md` Output Phase step 8 -- Reference failed source footer rendering

**OBS-02 changes:**
1. `references/data-models.md` -- Add `run_log` field to DailyMetrics schema
2. `references/processing-instructions.md` -- Add run_log accumulation instructions at each pipeline phase
3. `SKILL.md` -- Add log-emit instructions at Collection/Processing/Output phase boundaries
4. `data/fixtures/metrics-sample.json` -- Add sample run_log array

**OBS-03 changes:**
1. `references/data-models.md` -- Add "Schema Version Registry" section with per-model version history table

**OBS-04 changes:**
1. New `scripts/diagnostics.sh` -- Reads metrics + alert-state + digest-history, produces consolidated report
2. `SKILL.md` User Commands -- Add diagnostics command routing
3. `references/cron-configs.md` -- No cron needed (on-demand only)

### Anti-Patterns to Avoid

- **Overloading health-check.sh**: The diagnostics command should be separate from health-check.sh. Health-check is for automated alerts (cron-triggered, action-oriented). Diagnostics is for operator inspection (on-demand, informational). Mixing them creates confusion about when to use which.
- **run_log as separate file**: Do NOT store run_log in a separate file. It belongs inside DailyMetrics because it describes a single run. This keeps the metrics file self-contained.
- **Verbose run_log**: Keep entries concise. Log phase transitions and counts, not individual item processing. Target 8-15 entries per run.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Failed source detection | Custom tracking logic | Read `per_source[*].status` from existing DailyMetrics | Already tracked -- just need to surface in footer |
| Schema history | Separate changelog file | Consolidate into data-models.md registry section | Single source of truth, already partially exists |
| System diagnostics | Complex monitoring dashboard | Simple bash script reading existing JSON files | Consistent with existing health-check.sh pattern |

## Common Pitfalls

### Pitfall 1: source_count vs sources.total confusion
**What goes wrong:** `sources.total` in DailyMetrics includes all sources attempted (including disabled ones that were skipped). `source_count` in the footer should be enabled-only.
**Why it happens:** The DailyMetrics `sources.total` field counts sources that were attempted, which may differ from enabled count if degraded sources were skipped due to budget.
**How to avoid:** Define `source_count` explicitly as "count of `enabled: true` in sources.json" (already defined this way in processing-instructions.md Section 5). The footer reads this directly from sources.json, NOT from DailyMetrics `sources.total`.
**Warning signs:** Footer shows different number than `sources.total` in metrics -- this is EXPECTED and correct.

### Pitfall 2: run_log timestamps across time zones
**What goes wrong:** Timestamps in run_log may be in local time vs UTC, creating confusion.
**Why it happens:** The project uses ISO8601 everywhere but some bash scripts use local time.
**How to avoid:** Mandate ISO8601 UTC for all run_log timestamps. Add explicit note in data-models.md.

### Pitfall 3: Diagnostics command reading stale files
**What goes wrong:** Diagnostics reads today's metrics file but pipeline hasn't run yet today.
**Why it happens:** First run of the day hasn't completed yet when operator checks diagnostics.
**How to avoid:** Diagnostics should read the MOST RECENT metrics file (not just today's), and display the file date prominently. If no file exists for today, fall back to yesterday's.

### Pitfall 4: Schema registry completeness
**What goes wrong:** Registry omits a model or version increment.
**Why it happens:** Manual documentation that falls out of sync with actual changes.
**How to avoid:** Cross-reference the New Fields Registry table (which tracks per-field additions) with the _schema_v values in each model definition. Both must be consistent.

## Code Examples

### OBS-01: Enhanced Transparency Footer

Addition to `references/output-templates.md` Transparency Footer section:

```markdown
If any sources had `status: "failed"` in today's per_source metrics, append on a new line:
采集失败: {failed_source_name_1}, {failed_source_name_2} (共 {failed_count} 个)

Where:
- Failed source names are read from per_source entries where `status == "failed"`
- Source display names are looked up from sources.json `name` field (not source_id)
- If no sources failed, omit this line entirely
```

### OBS-02: run_log Schema Addition

Addition to DailyMetrics in `references/data-models.md`:

```json
{
  "run_log": [
    {
      "step": "pipeline_start",
      "timestamp": "ISO8601 (UTC)",
      "details": { "run_id": "run-..." }
    },
    {
      "step": "collection_complete",
      "timestamp": "ISO8601 (UTC)",
      "details": { "sources_attempted": 5, "items_fetched": 30, "failed_sources": ["src-example"] }
    },
    {
      "step": "noise_filter_complete",
      "timestamp": "ISO8601 (UTC)",
      "details": { "pre_classify_filtered": 3, "batch_remaining": 27 }
    },
    {
      "step": "classification_complete",
      "timestamp": "ISO8601 (UTC)",
      "details": { "classified": 25, "partial": 2, "post_classify_filtered": 4 }
    },
    {
      "step": "summarization_complete",
      "timestamp": "ISO8601 (UTC)",
      "details": { "summarized": 21 }
    },
    {
      "step": "dedup_complete",
      "timestamp": "ISO8601 (UTC)",
      "details": { "title_deduped": 2, "events_merged": 5, "events_created": 3 }
    },
    {
      "step": "output_complete",
      "timestamp": "ISO8601 (UTC)",
      "details": { "selected": 15, "repeat_suppressed": 2 }
    },
    {
      "step": "pipeline_end",
      "timestamp": "ISO8601 (UTC)",
      "details": { "duration_seconds": 180 }
    }
  ]
}
```

### OBS-03: Schema Version Registry Format

Addition to `references/data-models.md`:

```markdown
## Schema Version Registry

| Model | Current Version | History |
|-------|----------------|---------|
| NewsItem | v4 | v1: initial (Phase 0), v2: +content_hash/processing_status/duplicate_of (Phase 0), v3: +dedup_status/language (Phase 2), v4: +digest_eligible (Phase 9) |
| Event | v3 | v1: initial (Phase 0), v2: +keywords/timeline (Phase 2), v3: +last_alerted_at/last_alert_news_id/last_alert_brief (Phase 10) |
| CacheEntry | v2 | v1: initial (Phase 0), v2: +prompt_version (Phase 8) |
| Preferences | v2 | v1: initial (Phase 0), v2: +depth_preference/judgment_angles (Phase 3) |
| AlertState | v1 | v1: initial (Phase 10) |
| DigestHistory | v1 | v1: initial (Phase 10) |
| DailyMetrics | - | No _schema_v field (flat evolving schema). See New Fields Registry for field additions. |
| Source | - | No _schema_v field (config model). See New Fields Registry for field additions. |
| AlertCondition | v1 | v1: initial (Phase 2) |
| FeedbackEntry | v1 | v1: initial (Phase 0) |
| DedupIndex | - | No _schema_v field (index structure). |
```

### OBS-04: Diagnostics Script Structure

```bash
#!/bin/bash
# Diagnostics: consolidated system health report
# Usage: bash scripts/diagnostics.sh [base_dir]
#
# Reads: daily metrics, alert-state, digest-history, sources, budget
# Output: Structured text report for operator inspection

# Sections:
# 1. Pipeline Status (last run_id, duration, item counts from most recent metrics)
# 2. Source Health (per-source status, failed sources, degraded sources)
# 3. Alert Activity (today's alert-state: alerts_sent, cap remaining, last alert)
# 4. Digest History (last 5 runs from digest-history.json: dates, event counts, repeat suppression)
# 5. Budget Status (calls_today/limit, tokens_today/limit, effective_usage)
# 6. Data Integrity (dedup-index size, event counts, lock status)
```

## Interaction with Existing Files

### Files to Modify

| File | Change | Requirement |
|------|--------|-------------|
| `references/output-templates.md` | Add failed source line to Transparency Footer | OBS-01 |
| `references/processing-instructions.md` Section 5 | Add failed source name tracking instruction | OBS-01 |
| `references/data-models.md` | Add run_log to DailyMetrics, add Schema Version Registry section | OBS-02, OBS-03 |
| `references/processing-instructions.md` | Add run_log accumulation instructions at pipeline phases | OBS-02 |
| `SKILL.md` | Add run_log emit instructions at phase boundaries, add diagnostics command routing | OBS-02, OBS-04 |
| `data/fixtures/metrics-sample.json` | Add sample run_log array | OBS-02 |

### New Files

| File | Purpose | Requirement |
|------|---------|-------------|
| `scripts/diagnostics.sh` | Consolidated diagnostics report | OBS-04 |

### Files NOT Modified

- `scripts/health-check.sh` -- Keep as-is (automated health alerting, separate concern from diagnostics)
- `config/sources.json` -- No schema changes needed
- `references/prompts/*` -- No prompt changes needed
- `references/feedback-rules.md` -- No changes needed
- `references/scoring-formula.md` -- No changes needed

## Plan Decomposition Recommendation

### Plan 11-01: Source Count Accuracy & Failed Source Footer (OBS-01)
- Update output-templates.md Transparency Footer with conditional failed source line
- Update processing-instructions.md Section 5 to document failed source name tracking
- Update SKILL.md Output Phase step 8 to reference failed source footer

### Plan 11-02: Run Log Schema & Pipeline Instrumentation (OBS-02)
- Add run_log field to DailyMetrics schema in data-models.md
- Define run_log entry schema (step, timestamp, details)
- Add run_log accumulation instructions to processing-instructions.md
- Update SKILL.md Collection/Processing/Output phases with log-emit points
- Update metrics-sample.json fixture
- Add run_log to New Fields Registry

### Plan 11-03: Schema Version Registry & Diagnostics Command (OBS-03, OBS-04)
- Add Schema Version Registry section to data-models.md
- Create scripts/diagnostics.sh reading metrics + alert-state + digest-history
- Add diagnostics command routing to SKILL.md User Commands section

## Open Questions

None. All four requirements have clear implementation paths based on existing infrastructure.

## Sources

### Primary (HIGH confidence)
- `references/data-models.md` -- Current DailyMetrics schema, all model definitions, New Fields Registry
- `references/output-templates.md` -- Current Transparency Footer template and rendering rules
- `references/processing-instructions.md` -- Pipeline flow, metrics collection (Section 5), alert flow (Section 5A)
- `SKILL.md` -- Pipeline phase structure, Output Phase step 7-8 for metrics/footer writing
- `scripts/health-check.sh` -- Existing diagnostics pattern (bash + python3 inline)
- `data/fixtures/metrics-sample.json` -- Current metrics fixture structure

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new libraries, all changes are within existing file patterns
- Architecture: HIGH - Well-understood pipeline with clear extension points
- Pitfalls: HIGH - Based on direct analysis of existing code and data model inconsistencies

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable -- documentation/config changes only)
