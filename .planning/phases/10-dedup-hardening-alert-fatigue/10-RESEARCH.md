# Phase 10: Dedup Hardening & Alert Fatigue - Research

**Researched:** 2026-04-02
**Domain:** Alert state management, cross-digest dedup, delta alert generation
**Confidence:** HIGH

## Summary

Phase 10 addresses two related problems: alert fatigue (too many breaking news alerts) and cross-digest repetition (same events appearing in consecutive digests without new information). The current system has basic alert infrastructure (alerts_sent_today, alerted_urls in DailyMetrics) but lacks persistent alert state across runs, per-event alert memory, delta detection, and cross-digest repetition penalties.

The work falls into three domains: (1) a persistent alert-state file that enforces a daily cap of 3 alerts with URL dedup, replacing the current in-metrics tracking; (2) per-event alert memory on Event objects enabling delta alerts that show what changed since the last alert; (3) a DigestHistory model that tracks recent digests and enables a 0.7x repetition penalty for events with no new timeline progress.

**Primary recommendation:** Implement as three sequential plans -- alert state + unified decision tree first, then delta alerts with event memory, then cross-digest dedup with repetition penalty and suppression footer.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ALERT-01 | Daily alert state file (alert-state-YYYY-MM-DD.json) with 3-alert daily cap and URL dedup | New AlertState data model, replaces DailyMetrics alert tracking |
| ALERT-02 | Event objects store per-event alert memory (last_alerted_at, last_alert_news_id, last_alert_brief) | New fields on Event schema v3 |
| ALERT-03 | Quick-Check uses unified decision tree for alert eligibility | Consolidate scattered alert checks into single decision tree in Quick-Check flow |
| ALERT-04 | Delta alerts fire for event updates (update/correction/reversal/escalation relations) | Event timeline relation matching + previous alert comparison |
| ALERT-05 | Delta alert prompt and template show what changed vs previous alert | New prompt file + output template section |
| ALERT-06 | Fallback to standard alert when event context unavailable | Decision tree branch for items without event_id |
| DEDUP-01 | DigestHistory tracks last 5 runs with event_timeline_snapshot | New DigestHistory data model at data/digest-history.json |
| DEDUP-02 | Cross-digest repetition penalty (0.7x) for events with no new timeline progress | Scoring modifier in Output Phase, comparing current timeline to snapshot |
| DEDUP-03 | Output footer shows count of suppressed repeat items | Extend transparency footer template |
</phase_requirements>

## Architecture Patterns

### New Data Models

#### AlertState (ALERT-01)

New file: `data/alerts/alert-state-YYYY-MM-DD.json`

```json
{
  "_schema_v": 1,
  "date": "YYYY-MM-DD",
  "alerts_sent": 3,
  "max_alerts": 3,
  "alerted_urls": ["https://example.com/story1", "https://example.com/story2"],
  "alert_log": [
    {
      "news_id": "abc123",
      "event_id": "evt-12345678",
      "url": "https://example.com/story1",
      "title": "Breaking story",
      "importance_score": 0.9,
      "alert_type": "standard|delta",
      "sent_at": "ISO8601"
    }
  ]
}
```

**Key design decisions:**
- Separate file from DailyMetrics -- alert state must persist across multiple quick-check runs per day, independently of digest pipeline runs
- The existing `alerts_sent_today` and `alerted_urls` in DailyMetrics should remain for backward compatibility but the authoritative source becomes alert-state file
- `data/alerts/` directory needs bootstrap verification in SKILL.md step 0

#### Event Schema v3 (ALERT-02)

New fields added to Event model:

```json
{
  "last_alerted_at": "ISO8601 or null",
  "last_alert_news_id": "string or null",
  "last_alert_brief": "string or null",
  "_schema_v": 3
}
```

**Defaults for v2 records:** `last_alerted_at`: null, `last_alert_news_id`: null, `last_alert_brief`: null.

These fields enable delta comparison: when a new alert fires for an event, the system can compare the current timeline entry against `last_alert_brief` to generate a "what changed" description.

#### DigestHistory (DEDUP-01)

New file: `data/digest-history.json`

```json
{
  "_schema_v": 1,
  "runs": [
    {
      "run_id": "run-20260402-080000-abcd",
      "date": "2026-04-02",
      "event_timeline_snapshot": {
        "evt-12345678": {
          "timeline_count": 5,
          "last_news_id": "abc123",
          "last_timestamp": "ISO8601"
        }
      },
      "selected_event_ids": ["evt-12345678", "evt-87654321"]
    }
  ]
}
```

**Design notes:**
- Keep only last 5 runs (rolling window) -- sufficient for repetition detection
- `event_timeline_snapshot` captures the timeline length and last entry per event at digest time
- Comparison: if an event appears in the current digest AND its `timeline_count` equals the snapshot from the previous digest, it has no new progress and receives 0.7x penalty

### Unified Alert Decision Tree (ALERT-03)

The current Quick-Check flow has alert logic scattered across SKILL.md and output-templates.md. Consolidate into a single decision tree:

```
1. Item has importance_score >= 0.85?
   NO  -> skip
   YES -> continue

2. Item form_type is "news" or "announcement"?
   NO  -> skip
   YES -> continue

3. Read alert-state file. alerts_sent >= max_alerts (3)?
   YES -> skip (cap reached)
   NO  -> continue

4. Item URL already in alerted_urls?
   YES -> skip (URL dedup)
   NO  -> continue

5. Item has event_id AND event has last_alerted_at?
   YES -> DELTA ALERT path (ALERT-04/05)
   NO  -> STANDARD ALERT path (ALERT-06)

DELTA ALERT:
  5a. Event has timeline entries after last_alerted_at with
      relation in [update, correction, reversal, escalation]?
      YES -> Generate delta alert showing changes
      NO  -> Skip (no new developments worth alerting)

STANDARD ALERT:
  6. Generate standard alert per existing template
```

### Delta Alert Flow (ALERT-04, ALERT-05)

When an item triggers a delta alert:

1. Look up the event via `item.event_id`
2. Find timeline entries added since `event.last_alerted_at`
3. Compare current event summary with `event.last_alert_brief`
4. Generate delta alert using a new prompt that emphasizes what changed

**New prompt needed:** `references/prompts/delta-alert.md` -- takes the previous alert brief and new timeline entries, produces a "what changed" summary.

**New output template section:** Delta alert format in `references/output-templates.md`:

```
【快讯更新】{event_title}

变化: {delta_summary - what changed since last alert}
当前状态: {current_event_summary}

新进展:
- [{timestamp}] {brief} ({relation})

上次快讯: {last_alert_brief} ({last_alerted_at})
来源: {source_name} | 重要性: {importance_score}
```

### Cross-Digest Repetition Penalty (DEDUP-02)

Applied during Output Phase scoring (after computing `final_score`, before quota allocation):

```
For each scored item with event_id:
  1. Look up event_id in last digest's event_timeline_snapshot
  2. If found AND current event timeline_count == snapshot timeline_count:
     -> No new progress. Apply 0.7x multiplier to final_score.
  3. If found AND current timeline_count > snapshot timeline_count:
     -> New progress exists. No penalty.
  4. If not found in previous digest:
     -> First appearance. No penalty.
```

**Integration point:** This runs AFTER the 7-dimension scoring formula but BEFORE quota allocation (between Output Phase steps 1 and 3 in SKILL.md).

### Suppression Footer (DEDUP-03)

Extend the transparency footer in `references/output-templates.md`:

```
已抑制重复: {N} 条 (无新进展的事件)
```

This count tracks items that received the 0.7x penalty AND were subsequently pushed below the selection threshold by the penalty.

### Recommended Project Structure Changes

```
data/
  alerts/                    # NEW directory
    alert-state-YYYY-MM-DD.json  # NEW: daily alert state
  digest-history.json        # NEW: rolling 5-run digest history
references/
  prompts/
    delta-alert.md           # NEW: delta alert prompt
  data-models.md             # MODIFY: add AlertState, DigestHistory, Event v3
  output-templates.md        # MODIFY: add delta alert template, suppression footer
  processing-instructions.md # MODIFY: add alert decision tree, repetition penalty
SKILL.md                     # MODIFY: update Quick-Check flow, bootstrap, Output Phase
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timeline diff detection | Custom diff algorithm | Simple count comparison (timeline_count) | The timeline is append-only; comparing counts is sufficient and avoids complexity |
| Alert state persistence | In-memory tracking | File-based alert-state-YYYY-MM-DD.json | Multiple quick-check runs per day need shared state; files are the project's persistence pattern |
| Delta summary generation | Template string formatting | LLM prompt (delta-alert.md) | Describing "what changed" in natural language requires LLM reasoning, not mechanical diffing |

**Key insight:** The project is entirely prompt/config/reference-doc based (no runtime code). All logic is expressed as instructions to the OpenClaw agent. "Implementation" means writing precise instructions and data schemas, not code.

## Common Pitfalls

### Pitfall 1: Alert State vs DailyMetrics Race Condition
**What goes wrong:** Quick-check runs update alert-state but daily digest run overwrites DailyMetrics, losing alert tracking.
**Why it happens:** DailyMetrics is written at end of daily pipeline run, potentially resetting alert counts.
**How to avoid:** Make alert-state-YYYY-MM-DD.json the authoritative source. DailyMetrics `alerts_sent_today` and `alerted_urls` become read-from-alert-state (derived, not primary). Quick-Check reads/writes alert-state directly.
**Warning signs:** Alerts exceeding daily cap of 3.

### Pitfall 2: Missing Bootstrap for New Directories
**What goes wrong:** First run after deployment fails because `data/alerts/` directory doesn't exist.
**Why it happens:** New directory not added to SKILL.md bootstrap step.
**How to avoid:** Add `data/alerts/` to SKILL.md Collection Phase step 0 bootstrap list.
**Warning signs:** File write errors on first quick-check run.

### Pitfall 3: Event Schema Migration Breaks Existing Data
**What goes wrong:** Existing events in active.json lack the new v3 fields, causing null reference errors.
**Why it happens:** Reader code doesn't apply defaults for missing fields.
**How to avoid:** Follow established schema versioning pattern: define defaults (`null` for all three new fields), document in New Fields Registry, bump `_schema_v` to 3.
**Warning signs:** Errors when processing events created before Phase 10.

### Pitfall 4: Repetition Penalty Creates Dead Events
**What goes wrong:** Important ongoing events never appear in digests because they keep getting the 0.7x penalty.
**Why it happens:** The penalty accumulates over multiple days without new timeline entries.
**How to avoid:** The 0.7x penalty is a single multiplier (not compounding). It only compares against the LAST digest, not all previous digests. Events with genuinely high importance (0.85+) still score above threshold even with the penalty (0.85 * 0.7 = 0.595, still competitive).
**Warning signs:** High-importance events disappearing from digests for multiple days.

### Pitfall 5: Escalation Relation Type Not in Current Schema
**What goes wrong:** ALERT-04 mentions "escalation" as a relation type for delta alerts, but the Event timeline relation enum only has: initial, update, correction, analysis, reversal.
**Why it happens:** Requirements reference a relation type not yet in the data model.
**How to avoid:** Either (a) add "escalation" to the timeline relation enum in Event schema, or (b) treat "escalation" as a subset of "update" and use the existing relations. Recommendation: use existing relations -- "update" covers escalation scenarios. The delta alert logic should trigger on relation in [update, correction, reversal] (excluding analysis, same as event re-summarization logic).
**Warning signs:** Delta alerts never firing because they check for a non-existent relation type.

## Code Examples

### Alert State File Read/Write Pattern

```
// Reading alert state (in Quick-Check flow)
Read data/alerts/alert-state-{today}.json
If file not found:
  Initialize: { _schema_v: 1, date: today, alerts_sent: 0, max_alerts: 3, alerted_urls: [], alert_log: [] }
```

### Repetition Penalty Application

```
// In Output Phase, after scoring, before quota allocation
Read data/digest-history.json
Get last_run = runs[runs.length - 1]  // most recent

For each scored item where item.event_id is not null:
  snapshot = last_run.event_timeline_snapshot[item.event_id]
  If snapshot exists:
    current_event = lookup event in active.json
    If current_event.timeline.length == snapshot.timeline_count:
      item.final_score *= 0.7  // no new progress penalty
      increment repeat_suppressed_count
```

### DigestHistory Write Pattern

```
// At end of Output Phase, after writing digest
Read data/digest-history.json (or initialize empty {runs: []})
Build event_timeline_snapshot from selected items' events
Append new run entry
If runs.length > 5: remove oldest entry
Atomic write data/digest-history.json
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Alert counts in DailyMetrics only | Dedicated alert-state file per day | Phase 10 | Reliable cross-run alert tracking |
| No event memory for alerts | Per-event last_alerted_at/brief | Phase 10 | Enables delta alerts |
| No cross-digest dedup | Timeline snapshot comparison + 0.7x penalty | Phase 10 | Reduces stale repetition |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual verification via fixture files |
| Config file | N/A (prompt/config project, no test runner) |
| Quick run command | Manual: compare fixture data against expected behavior |
| Full suite command | Manual: run pipeline with fixture data, verify outputs |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ALERT-01 | Alert state file created, cap enforced | fixture | Verify alert-state fixture with 3 alerts blocks 4th | Wave 0 |
| ALERT-02 | Event objects have alert memory fields | fixture | Verify events-active fixture has v3 fields | Wave 0 |
| ALERT-03 | Unified decision tree documented | manual-only | Read Quick-Check flow, trace decision path | N/A |
| ALERT-04 | Delta alerts fire on event updates | fixture | Verify delta alert fixture output | Wave 0 |
| ALERT-05 | Delta template shows changes | manual-only | Inspect delta-alert prompt and template | N/A |
| ALERT-06 | Standard fallback when no event context | manual-only | Trace decision tree for item without event_id | N/A |
| DEDUP-01 | DigestHistory tracks 5 runs | fixture | Verify digest-history fixture has snapshot data | Wave 0 |
| DEDUP-02 | 0.7x penalty for no-progress events | fixture | Score item with/without penalty, compare | Wave 0 |
| DEDUP-03 | Footer shows suppressed count | manual-only | Inspect output template for suppression line | N/A |

### Wave 0 Gaps
- [ ] `data/fixtures/alert-state-sample.json` -- covers ALERT-01 (alert state with cap reached)
- [ ] `data/fixtures/events-active-v3.json` -- covers ALERT-02 (events with alert memory fields)
- [ ] `data/fixtures/digest-history-sample.json` -- covers DEDUP-01, DEDUP-02 (5-run history with snapshots)

### Sampling Rate
- **Per task commit:** Verify fixture files match schema, trace decision tree manually
- **Per wave merge:** Full manual walkthrough of Quick-Check and Output Phase flows
- **Phase gate:** All fixtures valid, all templates updated, all data models documented

## Plan Decomposition Recommendation

### Plan 10-01: Alert State & Unified Decision Tree
**Scope:** ALERT-01, ALERT-03, ALERT-06
- Define AlertState data model in data-models.md
- Add `data/alerts/` to SKILL.md bootstrap
- Write unified alert decision tree in processing-instructions.md (new section)
- Update Quick-Check flow in SKILL.md to read/write alert-state file
- Add standard alert fallback path (ALERT-06)
- Create alert-state fixture file
- Update DailyMetrics to read from alert-state (derived)

### Plan 10-02: Delta Alerts & Event Memory
**Scope:** ALERT-02, ALERT-04, ALERT-05
- Add alert memory fields to Event schema v3 in data-models.md
- Create delta-alert.md prompt
- Add delta alert template to output-templates.md
- Wire delta alert path into the decision tree (from 10-01)
- Update event merge flow to write alert memory after alert sent
- Create events-active-v3 fixture
- Add Event relation display mapping for delta alert context

### Plan 10-03: Cross-Digest Repetition & Suppression
**Scope:** DEDUP-01, DEDUP-02, DEDUP-03
- Define DigestHistory data model in data-models.md
- Add digest-history write step to Output Phase in processing-instructions.md
- Add repetition penalty logic to scoring section in processing-instructions.md
- Update SKILL.md Output Phase to apply penalty between scoring and quota allocation
- Add suppression footer line to output-templates.md
- Create digest-history fixture file
- Update metrics fixture to include repeat_suppressed count

## Sources

### Primary (HIGH confidence)
- `references/data-models.md` -- current Event v2, DailyMetrics, NewsItem v4 schemas
- `references/output-templates.md` -- current alert format, transparency footer
- `references/processing-instructions.md` -- current pipeline flow, alert tracking in Section 5
- `SKILL.md` -- current Quick-Check flow, Output Phase steps, bootstrap
- `references/scoring-formula.md` -- 7-dimension formula, event_boost mechanics
- `data/fixtures/` -- existing fixture patterns for schema validation

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` -- ALERT-01 through ALERT-06, DEDUP-01 through DEDUP-03 definitions
- `.planning/ROADMAP.md` -- Phase 10 success criteria

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- this is a prompt/config/reference-doc project with well-established patterns across 9 prior phases
- Architecture: HIGH -- all new data models follow existing schema versioning, atomic write, and fixture patterns
- Pitfalls: HIGH -- identified from careful analysis of existing data flows and the interaction between quick-check and daily pipeline runs

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (30 days -- stable project patterns)
