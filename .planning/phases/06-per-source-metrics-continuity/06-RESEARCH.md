# Phase 6: Per-Source Metrics Continuity - Research

**Researched:** 2026-04-02
**Domain:** Per-source metrics schema, producer wiring, monitoring, and source degrade/recover continuity
**Confidence:** HIGH

## Summary

Phase 6 closes the last remaining integration gap in the v1.0 milestone: the `per_source` DailyMetrics contract that source health computation, monitoring alerts, and the degrade/recover state machine all depend on. The audit identified this as MISSING-06 (no documented schema or producer) and BROKEN-03 (degrade/recover continuity cannot work end-to-end without per-source history in daily metrics).

The existing codebase already has all the **consumer** logic in place -- `scripts/health-check.sh` reads `per_source` from daily metrics, `references/collection-instructions.md` defines formulas that require per-source history, and `references/processing-instructions.md` Section 6 defines the degrade/recover state machine. What is missing is: (1) a documented `per_source` schema in `references/data-models.md`, (2) producer instructions in `references/processing-instructions.md` that tell the pipeline to collect and persist per-source counters during each run, and (3) alignment of all consumers to use the documented contract consistently.

**Primary recommendation:** Define the `per_source` schema as a new field in DailyMetrics, add producer steps to the metrics write-up in processing-instructions.md, and verify that health-check.sh and collection-instructions.md formulas consume the same field names.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SRC-08 | Source health metrics (quality_score / dedup_rate / selection_rate auto-computation) | Per-source counters in DailyMetrics enable the 7-day rolling computation defined in collection-instructions.md |
| SRC-09 | Source auto-demotion/recovery (quality_score < 0.2 for 14d demote, > 0.3 for 7d recover) | Requires per-source quality history across daily metrics files for the hysteresis counters to function |
| MON-02 | Alert conditions (source failure, budget, dedup inconsistency, concentration, empty digest) | health-check.sh source concentration alert (check #10) reads `per_source.fetched`; all-source failure check could also benefit from per-source breakdown |
| MON-03 | Weekly health inspection (dedup consistency, empty events, long-stable, success rates, preferences, cache) | health-check.sh weekly source-success inspection (check #15) reads `per_source.status` across 7 days of metrics |
</phase_requirements>

## Architecture Patterns

### Current State: What Exists vs What Is Missing

**EXISTS (consumers -- already coded/documented):**

1. `scripts/health-check.sh` check #10 (source concentration): reads `m.get('per_source', {})` and checks `stats.get('fetched', 0)` per source
2. `scripts/health-check.sh` check #15 (weekly source success): reads `per_source.status` across 7 days of metrics
3. `references/collection-instructions.md` "Source Health Metrics Computation": defines `selection_rate`, `dedup_rate`, `fetch_success_rate`, `quality_score` formulas from 7-day per-source history
4. `references/processing-instructions.md` Section 6: degrade/recover state machine consuming `stats.quality_score` on sources.json
5. `references/data-models.md` Source schema: `stats` object with `quality_score`, `dedup_rate`, `selection_rate`, `degraded_since`, `recovery_streak_start`

**MISSING (producer + contract):**

1. `references/data-models.md`: No `per_source` field documented in DailyMetrics schema
2. `references/processing-instructions.md` Section 5 (metrics write): Only documents aggregate counters, never mentions per-source breakdown
3. SKILL.md Output Phase step 7: "Write metrics" has no mention of per-source data

### Required per_source Schema

Based on consumer analysis, the `per_source` field must provide these per-source-id fields:

| Field | Type | Consumer | Purpose |
|-------|------|----------|---------|
| `fetched` | integer | health-check.sh #10 (concentration), collection-instructions.md (dedup_rate, selection_rate denominators) | Items fetched from this source in this run |
| `deduped` | integer | collection-instructions.md (dedup_rate numerator) | Items from this source that were URL-deduped |
| `title_deduped` | integer | collection-instructions.md (quality signal) | Items from this source marked as title duplicates |
| `selected` | integer | collection-instructions.md (selection_rate numerator) | Items from this source that made it into the digest output |
| `status` | string | health-check.sh #15 (weekly success rate) | "success" if source fetched >= 1 item, "failed" if 0 items or error |
| `error` | string or null | health-check.sh (diagnostics) | Error message if fetch failed, null otherwise |

### Producer Wiring Points

The per-source counters must be accumulated during the pipeline and written as part of the existing metrics write step:

1. **Collection Phase** (SKILL.md step 4): For each source attempted, record `fetched` count and `status` (success/failed)
2. **Dedup step** (SKILL.md step 6): For each source, count items that were URL-deduped
3. **Title dedup** (Processing Phase step 8): For each source, count items marked as title duplicates
4. **Output generation** (Output Phase step 3): For each source, count items that received a `quota_group` tag (i.e., selected for output)
5. **Metrics write** (Output Phase step 7): Persist the accumulated per-source map into `data/metrics/daily-YYYY-MM-DD.json` as the `per_source` field

### Source Health Recomputation Flow (End-to-End)

The complete flow that must work after this phase:

```
Daily run writes per_source to metrics
    |
    v
Processing Phase step 12 reads last 7 days of metrics per_source data
    |
    v
Computes selection_rate, dedup_rate, fetch_success_rate per source
    |
    v
quality_score = selection_rate * 0.4 + (1 - dedup_rate) * 0.3 + fetch_success_rate * 0.3
    |
    v
Writes updated stats to config/sources.json
    |
    v
Processing Phase step 13 checks quality_score thresholds
    |
    v
Demotion: quality_score < 0.2 for 14 consecutive days -> status = "degraded"
Recovery: quality_score > 0.3 for 7 consecutive days -> status = "active"
    |
    v
health-check.sh daily reads per_source for concentration alerts
health-check.sh weekly reads per_source for success rate inspection
```

### Anti-Patterns to Avoid

- **Redefining formulas:** The quality_score, dedup_rate, selection_rate, and fetch_success_rate formulas already exist in collection-instructions.md. Do NOT create alternative formulas. The task is to wire the data, not redesign the computation.
- **Breaking existing aggregate counters:** The `sources.total/success/failed/degraded`, `items.fetched/url_deduped/...`, and `source_proportions` fields in DailyMetrics must remain unchanged. `per_source` is an additive new field.
- **Changing health-check.sh consumer code unnecessarily:** The existing Python snippets in health-check.sh already read `per_source` with correct field names. If the schema matches what they expect, no changes needed to checks #10 and #15. Only fix them if field names diverge.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-source counters | Custom tracking outside the pipeline | Accumulate during existing pipeline steps and persist in DailyMetrics | The pipeline already touches all the data points; just collect them |
| Quality score formula | New computation | Existing formula in collection-instructions.md Section "Source Health Metrics Computation" | Already defined, tested conceptually, and referenced by consumers |
| Degrade/recover logic | New state machine | Existing logic in processing-instructions.md Section 6 | Already fully specified with thresholds and hysteresis |

## Common Pitfalls

### Pitfall 1: Field Name Mismatch Between Producer and Consumer
**What goes wrong:** Schema defines `items_fetched` but health-check.sh reads `fetched`. Consumer silently gets 0.
**Why it happens:** Schema designed without checking existing consumer code.
**How to avoid:** Derive field names FROM the consumer code (health-check.sh), not the other way around.
**Warning signs:** health-check.sh always reports "INFO: No per-source breakdown available" even after metrics are written.

### Pitfall 2: Forgetting to Count Deduped Items Per Source
**What goes wrong:** `dedup_rate` computation has no per-source numerator, so all sources get dedup_rate = 0.
**Why it happens:** URL dedup happens at the item level (by hash), and the source_id is not tracked through the dedup check.
**How to avoid:** During dedup (Collection Phase step 6), when an item is skipped as a URL duplicate, still record that the source contributed a deduped item.

### Pitfall 3: Source Health Computed Before Output Selection
**What goes wrong:** `selection_rate` is always 0 because source stats are computed before items are selected for output.
**Why it happens:** SKILL.md step 12 "Compute source stats" is in the Processing Phase, but `selected` count depends on Output Phase step 3 (quota allocation).
**How to avoid:** The `selected` count for today's run should be written to per_source metrics during the Output Phase metrics write (step 7). The source health recomputation in step 12 reads historical data (last 7 days) and can use yesterday's `selected` counts. Today's selection feeds into tomorrow's computation. This is consistent with the existing rolling-window design.

### Pitfall 4: Empty per_source on First Run
**What goes wrong:** Quality score recomputation fails or produces NaN because per_source data does not exist in historical metrics.
**Why it happens:** Metrics files from before Phase 6 have no `per_source` field.
**How to avoid:** The existing minimum data requirement (total_fetched < 7 -> keep defaults at 0.5) already handles this. The health computation code must gracefully handle `per_source` being absent from older metrics files (use `.get('per_source', {})`).

## Code Examples

### per_source Schema (to add to DailyMetrics in data-models.md)

```json
{
  "per_source": {
    "src-36kr": {
      "fetched": 12,
      "deduped": 3,
      "title_deduped": 1,
      "selected": 4,
      "status": "success",
      "error": null
    },
    "src-github-langchain": {
      "fetched": 5,
      "deduped": 0,
      "title_deduped": 0,
      "selected": 2,
      "status": "success",
      "error": null
    },
    "src-search-ai-regulation": {
      "fetched": 0,
      "deduped": 0,
      "title_deduped": 0,
      "selected": 0,
      "status": "failed",
      "error": "web_search returned empty"
    }
  }
}
```

### Source Health Recomputation (using per_source from 7-day metrics)

Pseudo-code matching collection-instructions.md formulas:

```python
# Read last 7 days of daily-YYYY-MM-DD.json
for source_id in all_enabled_source_ids:
    total_fetched = sum(m['per_source'].get(source_id, {}).get('fetched', 0)
                        for m in last_7_days_metrics)
    items_deduped = sum(m['per_source'].get(source_id, {}).get('deduped', 0)
                        for m in last_7_days_metrics)
    items_selected = sum(m['per_source'].get(source_id, {}).get('selected', 0)
                         for m in last_7_days_metrics)
    days_success = sum(1 for m in last_7_days_metrics
                       if m['per_source'].get(source_id, {}).get('status') == 'success')
    days_attempted = sum(1 for m in last_7_days_metrics
                         if source_id in m.get('per_source', {}))

    if total_fetched < 7:
        # Minimum data requirement -- keep defaults
        continue

    selection_rate = items_selected / total_fetched
    dedup_rate = items_deduped / total_fetched
    fetch_success_rate = days_success / max(days_attempted, 1)

    quality_score = selection_rate * 0.4 + (1 - dedup_rate) * 0.3 + fetch_success_rate * 0.3
```

## Files Requiring Changes

| File | Change Type | Description |
|------|-------------|-------------|
| `references/data-models.md` | ADD | Document `per_source` schema as a new field in DailyMetrics |
| `references/processing-instructions.md` | ADD | Add per-source metrics producer steps to Section 5 (metrics write) |
| `references/collection-instructions.md` | ALIGN | Verify source health formulas reference `per_source` from DailyMetrics consistently; clarify data source for each formula variable |
| `scripts/health-check.sh` | VERIFY/ALIGN | Verify field names in checks #10 and #15 match the documented per_source schema; fix if they diverge |
| `SKILL.md` | ADD | Mention per-source counter accumulation in Collection Phase and metrics write in Output Phase |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bash + manual inspection (no automated test framework in project) |
| Config file | none |
| Quick run command | `bash scripts/health-check.sh . --mode daily` |
| Full suite command | `bash scripts/health-check.sh . --mode weekly` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SRC-08 | per_source counters enable quality_score recomputation | manual | Inspect `data/metrics/daily-*.json` for `per_source` field after a pipeline run | N/A |
| SRC-09 | degrade/recover uses quality_score history from per_source metrics | manual | Run pipeline for multiple days, check `config/sources.json` status transitions | N/A |
| MON-02 | health-check.sh source concentration reads per_source.fetched | smoke | `bash scripts/health-check.sh . --mode daily` (check #10 should not say "No per-source breakdown") | existing |
| MON-03 | weekly inspection reads per_source.status across 7 days | smoke | `bash scripts/health-check.sh . --mode weekly` (check #15 should show source success rates) | existing |

### Sampling Rate
- **Per task commit:** `bash scripts/health-check.sh . --mode daily`
- **Per wave merge:** `bash scripts/health-check.sh . --mode weekly`
- **Phase gate:** Both daily and weekly health checks pass without "INFO: No per-source breakdown/metrics" messages

### Wave 0 Gaps
None -- existing health-check.sh serves as smoke test. The schema/wiring changes are documentation-level (reference files), so automated unit tests are not applicable. Verification is via health-check.sh integration checks after a live pipeline run.

## Open Questions

1. **Historical metrics backfill**
   - What we know: Metrics files from before Phase 6 lack `per_source`. All consumer code already uses `.get('per_source', {})` which returns empty dict gracefully.
   - What's unclear: Whether source health computation should attempt backfilling per_source into old metrics files or just accept degraded accuracy for the first 7 days.
   - Recommendation: Do NOT backfill. The minimum data requirement (total_fetched < 7 -> keep defaults at 0.5) already handles the cold-start window. After 7 days of runs with the new producer, the rolling window will be fully populated.

2. **health-check.sh ALERTS counter bug**
   - What we know: The audit notes that health-check.sh "prints ALERT lines but never increments the shell ALERTS counter." This is tech debt from Phase 2.
   - What's unclear: Whether fixing this counter is in scope for Phase 6.
   - Recommendation: Fix it opportunistically if health-check.sh is being edited anyway, but do not make it a blocker. It is cosmetic (affects only the summary line, not alert detection).

## Sources

### Primary (HIGH confidence)
- `references/data-models.md` -- existing DailyMetrics schema (no per_source field)
- `references/collection-instructions.md` -- source health formulas (consumer of per-source history)
- `references/processing-instructions.md` Section 5 and Section 6 -- metrics write and degrade/recover logic
- `scripts/health-check.sh` -- monitoring consumer code reading `per_source`
- `.planning/v1.0-MILESTONE-AUDIT.md` -- MISSING-06 and BROKEN-03 gap definitions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - this is a documentation/wiring phase with no new libraries
- Architecture: HIGH - all consumers already exist, schema can be derived from their expectations
- Pitfalls: HIGH - clear from code analysis of producer/consumer mismatch points

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable -- no external dependencies to go stale)
