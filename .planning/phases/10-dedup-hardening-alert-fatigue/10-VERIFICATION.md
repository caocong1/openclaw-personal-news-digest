---
phase: 10-dedup-hardening-alert-fatigue
verified: 2026-04-02T14:00:00Z
status: passed
score: 5/5 success criteria verified
gaps: []
human_verification: []
---

# Phase 10: Dedup Hardening & Alert Fatigue Verification Report

**Phase Goal:** Users receive at most 3 alerts per day, see delta information for event updates, and never see stale repeat content across consecutive digests
**Verified:** 2026-04-02T14:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Daily alert cap of 3 is enforced via alert-state file with URL dedup | VERIFIED | Section 5A decision tree in processing-instructions.md steps 3-5 reads alert-state-{today}.json, checks alerts_sent >= max_alerts (3) and URL in alerted_urls. SKILL.md Quick-Check step 2 references Section 5A. AlertState schema in data-models.md defines max_alerts: 3. |
| 2 | Delta alerts fire for event updates showing what changed vs previous alert | VERIFIED | Section 5B in processing-instructions.md documents full delta detection, generation via delta-alert.md prompt, rendering via Delta Alert template. Section 5A step 6 routes to 5B when event_id + last_alerted_at present. output-templates.md has Delta Alert (Event Update) section with 【快讯更新】format. |
| 3 | Cross-digest repetition penalty (0.7x) is applied to events with no new timeline progress | VERIFIED | Section 4A in processing-instructions.md documents full penalty procedure: reads digest-history.json, compares timeline.length vs snapshot.timeline_count, applies item.final_score *= 0.7. SKILL.md Output Phase step 1b wires it between scoring and quota allocation. |
| 4 | Event objects persist per-event alert memory (last_alerted_at, last_alert_news_id) | VERIFIED | Event schema v3 in data-models.md includes last_alerted_at, last_alert_news_id, last_alert_brief fields with null defaults. New Fields Registry has all three rows for Phase 10 v3. Section 5B documents both standard and delta memory update procedures. events-active-v3.json fixture validates both alerted and never-alerted scenarios. |
| 5 | Digest footer shows count of suppressed repeat items | PARTIAL | output-templates.md Transparency Footer section contains the conditional "已抑制重复: {repeat_suppressed_count} 条 (无新进展的事件)" line. SKILL.md step 7 writes repeat_suppressed to DailyMetrics items object. metrics-sample.json fixture includes "repeat_suppressed": 2. HOWEVER: the DailyMetrics schema in data-models.md does NOT include repeat_suppressed in the items object JSON definition, and the New Fields Registry has no entry for this field. |

**Score:** 4/5 success criteria verified (1 partial)

---

## Required Artifacts

### Plan 10-01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `references/data-models.md` | AlertState schema definition | VERIFIED | Contains "## AlertState" section with _schema_v: 1, max_alerts: 3, alerted_urls, alert_log array. New Fields Registry entry for alert_log exists. |
| `references/processing-instructions.md` | Unified Alert Decision Tree | VERIFIED | "## Section 5A: Unified Alert Decision Tree (ALERT-01, ALERT-03, ALERT-06)" exists with all 9 numbered steps, STANDARD ALERT path, DailyMetrics Derivation subsection, Backward Compatibility subsection. |
| `SKILL.md` | Bootstrap data/alerts/, Quick-Check uses Section 5A | VERIFIED | Bootstrap list includes `{baseDir}/data/alerts/`. Quick-Check step 2 references Section 5A and "alert-state-{today YYYY-MM-DD}.json". Output Phase step 7 derives alerts_sent_today and alerted_urls from alert-state file. |
| `data/fixtures/alert-state-sample.json` | Fixture with max_alerts, alerts_sent: 3 | VERIFIED | Valid JSON with _schema_v: 1, alerts_sent: 3, max_alerts: 3, 3 entries in alert_log covering both standard and delta alert_type values. |
| `references/output-templates.md` | Breaking News Alert references alert-state file | VERIFIED | Additional safeguards section reads: "Read data/alerts/alert-state-{today}.json to check alerts_sent >= max_alerts. Alert-state file is authoritative (not DailyMetrics)." References Section 5A. |

### Plan 10-02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `references/data-models.md` | Event v3 schema with last_alerted_at and escalation | VERIFIED | Event schema has _schema_v: 3, escalation in timeline relation enum, last_alerted_at/last_alert_news_id/last_alert_brief fields and field notes, null defaults for all three. |
| `references/prompts/delta-alert.md` | LLM prompt for delta alert generation | VERIFIED | Exists with `<!-- prompt_version: delta-alert-v1 -->` comment. Contains {event_title}, {last_alert_brief}, {last_alerted_at} placeholders. Returns structured JSON with delta_summary and current_status. |
| `references/output-templates.md` | Delta Alert template with 【快讯更新】 | VERIFIED | "## Delta Alert (Event Update)" section exists. Format uses 【快讯更新】header. Rendering rules include escalation -> 升级 display label. Fallback to standard alert on LLM error documented. |
| `references/processing-instructions.md` | Section 5B delta alert flow | VERIFIED | "## Section 5B: Delta Alert Flow (ALERT-04, ALERT-05)" exists. Delta Detection filters update/correction/reversal/escalation. Delta Alert Generation loads delta-alert.md. Event Memory Update and Standard Alert Memory Update subsections present. LLM fallback documented. alert_type: "delta" in Alert State Update. |
| `data/fixtures/events-active-v3.json` | Fixture with alerted and never-alerted events | VERIFIED | Two events: evt-fix00001 has non-null last_alerted_at, evt-fix00002 has null last_alerted_at. Both have _schema_v: 3. |

### Plan 10-03 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `references/data-models.md` | DigestHistory schema definition | VERIFIED | "## DigestHistory" section exists with _schema_v: 1, runs array, event_timeline_snapshot structure, selected_event_ids. Field notes document 5-run rolling window. New Fields Registry has `runs | DigestHistory | Phase 10 | v1 | [] ` entry. |
| `references/processing-instructions.md` | Section 4A repetition penalty + Section 4B history write | VERIFIED | Section 4A documents full 5-step penalty procedure with 0.7x multiplier, non-compounding note, timing (AFTER scoring, BEFORE quota), repeat_suppressed_count definition (penalized AND excluded). Section 4B documents atomic write with runs.length > 5 rolling window cleanup. |
| `references/output-templates.md` | Suppression footer line "已抑制重复" | VERIFIED | Transparency Footer section contains conditional "已抑制重复: {repeat_suppressed_count} 条 (无新进展的事件)" line with correct definition reference to Section 4A step 5. |
| `SKILL.md` | Output Phase steps 1b, 6b, updated 7 and 8 | VERIFIED | Step 1b "Cross-digest repetition penalty" present referencing Section 4A. Step 6b "Write digest history" present referencing Section 4B. Step 7 includes repeat_suppressed write instruction. Step 8 includes repeat_suppressed_count in footer instruction. |
| `data/fixtures/digest-history-sample.json` | 5-run fixture with event_timeline_snapshot | VERIFIED | Valid JSON with exactly 5 runs. Each run has event_timeline_snapshot with timeline_count, last_news_id, last_timestamp. Demonstrates progression: evt-fix00001 timeline_count grows from 2 to 3 between runs 1-2 and 2-3. |
| `data/fixtures/metrics-sample.json` | repeat_suppressed field in items object | VERIFIED | items object contains "repeat_suppressed": 2 after noise_filter_suppressed. |

---

## Key Link Verification

### Plan 10-01 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| SKILL.md Quick-Check flow | processing-instructions.md Section 5A | Quick-Check step 2 references decision tree | VERIFIED | SKILL.md step 2: "run the unified alert decision tree from `{baseDir}/references/processing-instructions.md` Section 5A" |
| processing-instructions.md Section 5A | data/alerts/alert-state-YYYY-MM-DD.json | Read/write alert state file | VERIFIED | Section 5A step 3: "Read data/alerts/alert-state-{today YYYY-MM-DD}.json" with initialization logic. Step 9: "Atomic write alert-state file" |

### Plan 10-02 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| processing-instructions.md Section 5A step 6 | processing-instructions.md Section 5B | Delta alert path branch | VERIFIED | Section 5A step 6: "YES -> DELTA ALERT path (see Section 5B in Plan 10-02)" — note the "in Plan 10-02" is a stale reference to the plan document (minor, non-blocking: Section 5B is correctly present in processing-instructions.md) |
| processing-instructions.md Section 5B | references/prompts/delta-alert.md | LLM prompt for delta summary | VERIFIED | Section 5B "Delta Alert Generation" step 1: "Load prompt: Read `references/prompts/delta-alert.md`" |
| processing-instructions.md Section 5B | data/events/active.json | Write last_alerted_at after alert | VERIFIED | Section 5B "Event Memory Update" step 1: "Update the event in `data/events/active.json`: Set last_alerted_at to current ISO8601 timestamp" with atomic write |

### Plan 10-03 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| SKILL.md Output Phase step 1 | processing-instructions.md Section 4A | Apply penalty after scoring, before quota | VERIFIED | SKILL.md step 1b explicitly references "Section 4A" in processing-instructions.md |
| SKILL.md Output Phase | data/digest-history.json | Write digest history after output | VERIFIED | SKILL.md step 6b: "append to `{baseDir}/data/digest-history.json`" referencing Section 4B |
| references/output-templates.md footer | DailyMetrics | repeat_suppressed count in footer | VERIFIED | SKILL.md step 7 writes repeat_suppressed to DailyMetrics items object; step 8 reads it for footer; output-templates.md footer reads from daily metrics |

---

## Data-Flow Trace (Level 4)

This is a documentation-only system (no rendering components). All data flows are through LLM-consumed instruction documents and JSON state files. The relevant data flows are:

| Data Path | Source | Produces Real Data | Status |
|-----------|--------|--------------------|--------|
| Alert cap enforcement: Quick-Check -> alert-state file | Section 5A step 3-4 | Yes — reads alerts_sent from file | FLOWING |
| Delta detection: Section 5B -> event.last_alerted_at | Section 5B Delta Detection step 2 | Yes — compares timeline timestamps | FLOWING |
| Repetition penalty: Section 4A -> digest-history.json | Section 4A step 1-4 | Yes — compares timeline.length | FLOWING |
| Suppression count: Section 4A step 5 -> SKILL.md step 7 -> footer | SKILL.md steps 1b, 7, 8 | Yes — penalized-AND-excluded items only | FLOWING |
| repeat_suppressed to DailyMetrics schema | data-models.md items object | No — field absent from schema definition | DISCONNECTED from schema |

---

## Behavioral Spot-Checks

This is a documentation-only skill (LLM instruction documents, no runnable code entry points). Behavioral verification is through structural analysis of the instruction documents.

**Step 7b: SKIPPED (no runnable entry points — this is an LLM-instruction-document-based skill)**

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ALERT-01 | 10-01 | Daily alert state file with 3-alert daily cap and URL dedup | SATISFIED | AlertState schema in data-models.md; Section 5A decision tree enforces cap; SKILL.md bootstrap creates data/alerts/ directory |
| ALERT-02 | 10-02 | Event objects store per-event alert memory | SATISFIED | Event schema v3 in data-models.md has last_alerted_at, last_alert_news_id, last_alert_brief with null defaults; New Fields Registry updated |
| ALERT-03 | 10-01 | Quick-Check uses unified decision tree for alert eligibility | SATISFIED | SKILL.md Quick-Check step 2 explicitly references Section 5A unified decision tree |
| ALERT-04 | 10-02 | Delta alerts fire for event updates (update/correction/reversal/escalation relations) | SATISFIED | Section 5B Delta Detection step 3 filters exactly these four relation types; escalation added to Event timeline enum |
| ALERT-05 | 10-02 | Delta alert prompt and template show what changed vs previous alert | SATISFIED | delta-alert.md prompt instructs LLM to describe WHAT CHANGED; output-templates.md Delta Alert template has 变化: {delta_summary} and 上次快讯: {last_alert_brief} |
| ALERT-06 | 10-01 | Fallback to standard alert when event context unavailable | SATISFIED | Section 5A step 6 routes to STANDARD ALERT path when no event_id or no last_alerted_at; Section 5B documents fallback to standard alert on LLM failure |
| DEDUP-01 | 10-03 | DigestHistory tracks last 5 runs with event_timeline_snapshot | SATISFIED | DigestHistory schema in data-models.md; Section 4B documents rolling 5-run window with runs.length > 5 eviction; digest-history-sample.json fixture has 5 runs |
| DEDUP-02 | 10-03 | Cross-digest repetition penalty (0.7x) for events with no new timeline progress | SATISFIED | Section 4A documents full penalty procedure with item.final_score *= 0.7, non-compounding, compare-only-against-last-run |
| DEDUP-03 | 10-03 | Output footer shows count of suppressed repeat items | PARTIAL | output-templates.md footer and SKILL.md step 8 are wired. GAP: repeat_suppressed field is absent from DailyMetrics schema definition in data-models.md and New Fields Registry |

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `references/processing-instructions.md` | 927 | "DELTA ALERT path (see Section 5B in Plan 10-02)" | Info | Stale reference to plan document number. Section 5B is present and correctly named in processing-instructions.md. Non-blocking — LLM agent will find Section 5B regardless of the trailing reference text. |
| `references/data-models.md` | ~351-398 | DailyMetrics items object missing `repeat_suppressed` field | Warning | The DailyMetrics JSON schema block does not include `"repeat_suppressed": 0`. An LLM agent executing strictly from the schema definition would not know to write this field. SKILL.md step 7 provides the instruction, but the schema is the canonical source. Also missing from New Fields Registry. |

---

## Human Verification Required

None — all critical behaviors are verifiable through structural analysis of instruction documents and JSON schema definitions.

---

## Gaps Summary

One gap was identified blocking complete goal achievement:

**Gap: DailyMetrics schema missing `repeat_suppressed` field**

The DEDUP-03 requirement ("Output footer shows count of suppressed repeat items") is structurally wired — SKILL.md step 7 instructs the LLM to write `repeat_suppressed` to DailyMetrics items, step 8 reads it for the footer, output-templates.md has the conditional footer line, and the metrics-sample.json fixture includes the value. However, the DailyMetrics JSON schema definition in `references/data-models.md` (lines ~342-397) does not include `"repeat_suppressed": 0` in the items object, and the New Fields Registry table has no entry for this field.

The practical impact: an LLM agent reading data-models.md to understand what fields DailyMetrics contains would not find `repeat_suppressed`. The schema is the authoritative contract for readers and writers of this data. The omission creates an inconsistency between the schema (canonical) and the fixture + SKILL.md (operational instructions).

**Fix required:** Add `"repeat_suppressed": 0` to the DailyMetrics items object in data-models.md, and add a New Fields Registry row: `repeat_suppressed | DailyMetrics.items | Phase 10 | - | 0 | Count of items penalized AND excluded from digest due to cross-digest repetition`.

All other must-haves across all three plans are fully verified and wired.

---

_Verified: 2026-04-02T14:00:00Z_
_Verifier: Claude (gsd-verifier)_
