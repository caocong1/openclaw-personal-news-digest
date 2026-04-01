---
phase: 03-closed-loop
plan: 01
subsystem: preferences
tags: [decay, preference-model, visualization, 7-layer]

requires:
  - phase: 02-smart-processing
    provides: "5-layer preference model, feedback processing pipeline, quota algorithm"
provides:
  - "Preference decay mechanism (30-day, 5% regression toward neutral)"
  - "7-layer preference model (depth_preference + judgment_angles)"
  - "Preference visualization procedure for user queries"
  - "SKILL.md wiring for decay step 0 and preference query routing"
affects: [03-02, 03-03, 03-04, summarize-prompt, weekly-report]

tech-stack:
  added: []
  patterns: [preference-decay-before-feedback, schema-migration-with-defaults]

key-files:
  created: []
  modified:
    - references/processing-instructions.md
    - references/data-models.md
    - references/feedback-rules.md
    - config/preferences.json
    - SKILL.md

key-decisions:
  - "Decay runs as step 0 in Processing Phase, before all LLM calls and feedback processing"
  - "depth_preference and judgment_angles wired into summarize prompt, NOT scoring formula"
  - "Schema v2 with backward-compatible defaults for v1 readers"

patterns-established:
  - "Preference decay as pipeline pre-step: always decay before feedback to ensure recent feedback overrides drift"
  - "User Commands split routing: preference queries vs history queries vs general"

requirements-completed: [PREF-04, PREF-06, PREF-07, HIST-06]

duration: 3min
completed: 2026-04-01
---

# Phase 3 Plan 01: Preference Decay, 7-Layer Model, and Visualization Summary

**30-day preference decay with 5% neutral regression, 7-layer model adding depth_preference and judgment_angles, and human-readable preference profile visualization**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-01T07:34:43Z
- **Completed:** 2026-04-01T07:37:59Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Preference decay procedure documented in processing-instructions.md Section 0 with 5% regression per 30-day period, no catch-up rule, and decay-before-feedback ordering
- 7-layer preference model schema in data-models.md with depth_preference (summary depth control) and judgment_angles (perspective emphasis) -- neither affects scoring formula
- Preference visualization procedure in feedback-rules.md generates human-readable profile text covering all 7 preference layers
- SKILL.md wired: Processing Phase step 0 runs decay check; User Commands routes preference queries separately from history queries

## Task Commits

Each task was committed atomically:

1. **Task 1: Add preference decay procedure and 7-layer model schema** - `6c71c7f` (feat)
2. **Task 2: Add preference visualization and wire decay + queries into SKILL.md** - `3fe12a4` (feat)

## Files Created/Modified
- `references/processing-instructions.md` - Added Section 0: Preference Decay (PREF-04) with decay formula, timing, and no-catch-up constraint
- `references/data-models.md` - Added Preferences schema section with full field documentation including depth_preference and judgment_angles
- `references/feedback-rules.md` - Added Preference Visualization (PREF-06/HIST-06) section with structured profile template and LLM polish step
- `config/preferences.json` - Added depth_preference, judgment_angles fields; bumped to version 3 and schema v2
- `SKILL.md` - Added decay step 0 to Processing Phase; split User Commands into preference query, history query, and general routing

## Decisions Made
- Decay runs as step 0 in Processing Phase, before all LLM calls and feedback processing -- recent feedback overrides decay drift
- depth_preference and judgment_angles are wired into summarize prompt and weekly report, NOT the scoring formula
- Schema bumped to v2 with backward-compatible defaults (depth_preference="moderate", judgment_angles=[]) for v1 readers

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Decay mechanism ready for pipeline integration
- 7-layer model schema ready for summarize prompt and weekly report consumption (plans 03-02 through 03-04)
- Preference visualization ready for user queries via SKILL.md routing

## Self-Check: PASSED

All files exist, all commits found, all content patterns verified.

---
*Phase: 03-closed-loop*
*Completed: 2026-04-01*
