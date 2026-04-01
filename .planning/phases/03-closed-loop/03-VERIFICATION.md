---
phase: 03-closed-loop
verified: 2026-04-01T08:15:00Z
status: passed
score: 20/20 must-haves verified
re_verification: false
---

# Phase 3: Closed-Loop Verification Report

**Phase Goal:** Closed-loop feedback system with preference decay, source auto-demotion/recovery, weekly trend reports, and natural language history queries.
**Verified:** 2026-04-01T08:15:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | After 30 days without reinforcement, preference weights decay toward neutral via 5% regression formula | VERIFIED | `processing-instructions.md` Section 0 documents exact formula: `w + (0.5 - w) * 0.05` for topic_weights |
| 2 | Decay applies at most once per 30-day period with no catch-up for missed periods | VERIFIED | Section 0 explicitly states "No catch-up rule: If 60+ days have passed, still apply only ONE decay round" |
| 3 | topic_weights decay toward 0.5, source_trust toward 0, form_preference toward 0 | VERIFIED | Three separate decay formulas documented in Section 0 with correct neutral targets |
| 4 | Decay runs BEFORE feedback processing in the pipeline | VERIFIED | SKILL.md Processing Phase step 0 is "Preference decay"; feedback is step 11 |
| 5 | preferences.json has depth_preference and judgment_angles as new 7-layer fields | VERIFIED | `config/preferences.json` has `"depth_preference": "moderate"` and `"judgment_angles": []`; version bumped to 3, `_schema_v` to 2 |
| 6 | depth_preference controls summary depth, NOT the scoring formula; judgment_angles influences emphasis, NOT scoring | VERIFIED | data-models.md field notes explicitly state "Wired into summarize prompt, NOT the scoring formula" for both fields |
| 7 | User can query preference state and receive human-readable text description | VERIFIED | `feedback-rules.md` "Preference Visualization (PREF-06/HIST-06)" section documents complete procedure with 7-layer template; SKILL.md User Commands step 3 routes to it |
| 8 | Source with quality_score < 0.2 for 14 consecutive days is auto-demoted to degraded | VERIFIED | `processing-instructions.md` Section 6 documents demotion check with exact thresholds; SKILL.md step 13 wires it |
| 9 | Degraded source with quality_score > 0.3 for 7 consecutive days auto-recovers to active | VERIFIED | Section 6 recovery check documents `>= 7 days` with `quality_score > 0.3` threshold |
| 10 | degraded_since resets when quality recovers before 14-day trigger; recovery_streak_start resets when quality dips | VERIFIED | Section 6 documents both hysteresis reset conditions explicitly |
| 11 | Degraded sources still collected but deprioritized (0.5x source_trust); skipped when budget >= 80% | VERIFIED | Section 6 scoring penalty and collection-instructions.md "Degraded Source Handling" document both behaviors |
| 12 | Source tracking fields degraded_since and recovery_streak_start in schema | VERIFIED | data-models.md Source stats schema includes both fields with field notes and migration defaults |
| 13 | Weekly report covers 5+ topic categories with trend analysis | VERIFIED | output-templates.md "Weekly Report Template" has Category Trends section; processing-instructions.md Section 7 enforces >= 5 category minimum |
| 14 | Weekly report includes event timelines for top events | VERIFIED | Template has "Key Events & Timelines" section with full timeline format |
| 15 | Weekly report has cross-domain synthesis written by strong model | VERIFIED | processing-instructions.md Section 7 specifies strong model tier for synthesis; weekly-report.md prompt generates "Cross-Domain Connections" |
| 16 | Weekly quota 40/20/20/20 (core/adjacent/hotspot/explore), different from daily 50/20/15/15 | VERIFIED | processing-instructions.md Section 7 explicitly states "core 40% / adjacent 20% / hotspot 20% / explore 20%" |
| 17 | Weekly cron job fires Sunday 20:00 CST | VERIFIED | cron-configs.md "Weekly Report Job" has `"expr": "0 20 * * 0", "tz": "Asia/Shanghai"` |
| 18 | Natural language queries classified into 5 types (RECENT_ACTIVITY, TOPIC_REVIEW, EVENT_TRACKING, HOTSPOT_SCAN, SOURCE_ANALYSIS) | VERIFIED | `references/prompts/history-query.md` documents all 5 types with Chinese and English examples |
| 19 | All 5 history query types have execution procedures with data lookups and capped at 20 items | VERIFIED | processing-instructions.md Section 8 documents HIST-01 through HIST-05 with response formats; "Cap at 20 items" stated for each |
| 20 | SKILL.md routes history queries through classification prompt then Section 8 execution; word count within 950-word budget | VERIFIED | SKILL.md User Commands step 4 references both `history-query.md` and "Section 8"; word count is 945 |

**Score: 20/20 truths verified**

---

### Required Artifacts

| Artifact | Provides | Status | Details |
|----------|----------|--------|---------|
| `references/processing-instructions.md` | Decay (S0), auto-demotion (S6), weekly report (S7), history queries (S8) | VERIFIED | All 4 sections present and substantive |
| `references/feedback-rules.md` | Preference Visualization for PREF-06/HIST-06 | VERIFIED | Full 7-layer visualization template with LLM polish step |
| `references/data-models.md` | Preferences schema (depth_preference, judgment_angles); Source schema (degraded_since, recovery_streak_start) | VERIFIED | Both schema sections present with field notes and migration defaults |
| `config/preferences.json` | Updated preferences with 7-layer fields, version 3, schema v2 | VERIFIED | depth_preference="moderate", judgment_angles=[], version=3, _schema_v=2, last_decay_at=null |
| `SKILL.md` | Decay step 0; source status step 13; weekly step 4b; user command routing steps 3-4 | VERIFIED | All wiring present; 945 words (within 950-word budget) |
| `references/collection-instructions.md` | Degraded source handling: budget-tight skip, display, manual override | VERIFIED | "Degraded Source Handling" section present with all three behaviors |
| `references/output-templates.md` | Weekly report template with 6 sections | VERIFIED | Template present with Overview, Events, Category Trends, Source Health, Cross-Domain, Stats footer |
| `references/prompts/weekly-report.md` | LLM prompt for cross-domain synthesis | VERIFIED | New file created; contains cross-domain synthesis requirements with strong model context |
| `references/cron-configs.md` | Weekly report cron job (Sunday 20:00 CST) | VERIFIED | "Weekly Report Job (Phase 3+)" section present with correct cron expression |
| `references/prompts/history-query.md` | LLM prompt classifying user messages into 5 query types | VERIFIED | New file created; RECENT_ACTIVITY, TOPIC_REVIEW, EVENT_TRACKING, HOTSPOT_SCAN, SOURCE_ANALYSIS with parameter extraction |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `SKILL.md` | `processing-instructions.md` Section 0 | Processing Phase step 0 triggers decay | WIRED | Step 0: "Preference decay: Check and apply preference decay per ... Section 0" |
| `SKILL.md` | `feedback-rules.md` "Preference Visualization" | User Commands step 3 routes preference query | WIRED | Step 3: "follow ... feedback-rules.md Preference Visualization section" |
| `processing-instructions.md` | `config/preferences.json` | Decay reads and writes preferences atomically | WIRED | Section 0 references `config/preferences.json` for read and write-back |
| `SKILL.md` | `processing-instructions.md` Section 6 | Processing Phase step 13 triggers source status check | WIRED | Step 13: "Auto-demotion/recovery per ... Section 6" |
| `processing-instructions.md` | `config/sources.json` | Section 6 reads quality_score and writes status | WIRED | Section 6 references sources.json for demotion/recovery write-back |
| `collection-instructions.md` | `config/sources.json` | Degraded source skip when budget tight | WIRED | "Degraded Source Handling" references status: "degraded" and budget check |
| `SKILL.md` | `processing-instructions.md` Section 7 | Output Phase step 4b triggers weekly report | WIRED | Step 4b: "Read ... Section 7. Aggregate 7 days of data..." |
| `processing-instructions.md` | `data/news/*.jsonl` | Weekly report reads 7-day JSONL files | WIRED | Section 7: "Read last 7 days of data/news/YYYY-MM-DD.jsonl files" |
| `processing-instructions.md` | `data/metrics/daily-*.json` | Weekly report aggregates 7-day metrics | WIRED | Section 7: "Read last 7 days of data/metrics/daily-*.json files" |
| `processing-instructions.md` | `data/events/active.json` | Weekly report includes event timelines | WIRED | Section 7: "Read data/events/active.json for event timelines" |
| `SKILL.md` | `history-query.md` + Section 8 | User Commands step 4 routes history queries | WIRED | Step 4: "classify query type per ... history-query.md, then execute per ... Section 8" |
| `processing-instructions.md` | `data/news/*.jsonl` | History queries read JSONL by date range | WIRED | Section 8 references JSONL files for HIST-01, HIST-02, HIST-04 |
| `processing-instructions.md` | `data/events/active.json` | Event tracking queries read active events | WIRED | Section 8 HIST-03: "Read data/events/active.json" |
| `processing-instructions.md` | `config/sources.json` | Source analysis queries read source stats | WIRED | Section 8 HIST-05: "Read config/sources.json" |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| PREF-04 | 03-01 | Preference decay (30-day, 5% regression toward neutral) | SATISFIED | processing-instructions.md Section 0 with exact formula; wired into SKILL.md step 0 |
| PREF-06 | 03-01 | Preference visualization (human-readable text description) | SATISFIED | feedback-rules.md "Preference Visualization" section; SKILL.md routes step 3 |
| PREF-07 | 03-01 | 7-layer preference model (depth_preference + judgment_angles) | SATISFIED | data-models.md Preferences schema; config/preferences.json updated |
| HIST-06 | 03-01 | Preference state query (same as PREF-06) | SATISFIED | feedback-rules.md "Preference Visualization (PREF-06 / HIST-06)" |
| SRC-09 | 03-02 | Source auto-demotion (quality < 0.2 for 14d) and recovery (quality > 0.3 for 7d) | SATISFIED | processing-instructions.md Section 6 with exact thresholds and hysteresis |
| OUT-03 | 03-03 | Weekly report generation (trend review, event timelines, cross-domain summary, 30-50 items) | SATISFIED | output-templates.md template; processing-instructions.md Section 7; cron-configs.md job |
| HIST-01 | 03-04 | Recent activity query (last 24 hours) | SATISFIED | processing-instructions.md Section 8 HIST-01 with 24h lookback |
| HIST-02 | 03-04 | Topic review (filter by category, last N days) | SATISFIED | Section 8 HIST-02 with category matching and 7-day default |
| HIST-03 | 03-04 | Event tracking query (active event timelines) | SATISFIED | Section 8 HIST-03 reading data/events/active.json |
| HIST-04 | 03-04 | Hotspot scan (high importance outside user interests) | SATISFIED | Section 8 HIST-04 with importance_score >= 0.7 and topic_weight < 0.5 filters |
| HIST-05 | 03-04 | Source analysis and health query | SATISFIED | Section 8 HIST-05 with full source health dashboard format |

All 11 requirement IDs declared across Phase 3 plans are satisfied. No orphaned requirements found.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `references/processing-instructions.md` | 169 | `{categories_list}` placeholder | Info | Template variable in prompt fill procedure — intentional, not a stub |
| `references/processing-instructions.md` | 340 | `{news_title}`, `{event_list}` placeholders | Info | Template variables in prompt fill procedure — intentional |
| `references/processing-instructions.md` | 734 | `{days_count}` placeholder | Info | Template variable in weekly report LLM prompt fill — intentional |
| `SKILL.md` | 16-17 | `{baseDir}`, `run-YYYYMMDD-HHmmss-XXXX` patterns | Info | Runtime path and ID templates — intentional design patterns |

No blockers or warnings found. All flagged patterns are intentional template variables, not incomplete implementations.

---

### Human Verification Required

None. This is a documentation-only codebase (LLM skill instructions). All verifiable behaviors are encoded as procedure text which can be fully checked programmatically against the must-have patterns.

The following behaviors are verifiable only at runtime (informational, not blocking):

#### 1. Preference Decay Timing

**Test:** Trigger pipeline run when `last_decay_at` is null. Verify it is set to current timestamp afterward.
**Expected:** `config/preferences.json` `last_decay_at` updated; daily metrics log `"preference_decay_applied": true`.
**Why human:** Requires live pipeline execution.

#### 2. Source Demotion State Transition

**Test:** Manipulate a source's `quality_score` below 0.2 and set `degraded_since` to 14 days ago. Trigger pipeline run.
**Expected:** Source `status` changes to `"degraded"` in sources.json.
**Why human:** Requires live pipeline execution with controlled source data.

#### 3. Weekly Report End-to-End

**Test:** Trigger weekly cron manually with 7 days of JSONL data present.
**Expected:** `output/latest-weekly.md` generated with all 6 sections; strong model called for synthesis sections.
**Why human:** Requires live pipeline with actual news data and LLM calls.

#### 4. History Query Classification Accuracy

**Test:** Send Chinese and English queries of each type (e.g., "最近有什么AI新闻", "what did I miss this week").
**Expected:** LLM classifies each to the correct query type and returns relevant data from JSONL files.
**Why human:** Requires live LLM classification and data lookup.

---

## Notes

**Pre-existing omission (not Phase 3 scope):** `config/preferences.json` is missing `style.last_exploration_increase` field documented in data-models.md. This field is managed by the ANTI-05 quota algorithm (Phase 2 scope). The data-models.md documents it with a null default, so readers handle missing field correctly. Not a Phase 3 gap.

**SKILL.md word budget:** Final count is 945 words, within the 950-word constraint. Plan 03-04 required compacting Processing Phase steps 8-13 to stay within budget after adding history query routing; this was handled during execution (deviation noted in 03-04-SUMMARY.md).

---

_Verified: 2026-04-01T08:15:00Z_
_Verifier: Claude (gsd-verifier)_
