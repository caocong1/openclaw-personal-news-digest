---
phase: 10-dedup-hardening-alert-fatigue
plan: 03
subsystem: dedup
tags: [digest-history, repetition-penalty, suppression-footer, cross-digest]

requires:
  - phase: 10-dedup-hardening-alert-fatigue
    plan: 02
    provides: Event v3 schema with alert memory and delta alert flow
provides:
  - DigestHistory data model with rolling 5-run window and event_timeline_snapshot
  - Cross-digest repetition penalty (Section 4A) applying 0.7x to stale events
  - DigestHistory write step (Section 4B) with atomic write at end of Output Phase
  - Suppression footer line showing repeat_suppressed_count in digest output
  - repeat_suppressed field in DailyMetrics items object
affects: [11-observability]

tech-stack:
  added: []
  patterns: [rolling-window-history, non-compounding-penalty]

key-files:
  created:
    - data/fixtures/digest-history-sample.json
  modified:
    - references/data-models.md
    - references/processing-instructions.md
    - references/output-templates.md
    - SKILL.md
    - data/fixtures/metrics-sample.json

key-decisions:
  - "[Phase 10]: DigestHistory uses rolling 5-run window comparing only against last digest (non-compounding 0.7x penalty)"
  - "[Phase 10]: repeat_suppressed_count tracks only items penalized AND excluded from digest (not all penalized items)"
  - "[Phase 10]: DigestHistory written after output, before lock release, using atomic write"

patterns-established:
  - "Rolling window history: DigestHistory keeps last 5 runs, oldest evicted on write"
  - "Non-compounding penalty: 0.7x multiplier compares only against last run, preventing exponential decay"

requirements-completed: [DEDUP-01, DEDUP-02, DEDUP-03]

duration: 2min
completed: 2026-04-02
---

# Phase 10 Plan 03: DigestHistory Model, Cross-Digest Repetition Penalty, and Suppression Footer Summary

**DigestHistory with rolling 5-run window, 0.7x non-compounding repetition penalty for stale events, suppression footer showing excluded repeat items, and full SKILL.md Output Phase wiring**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-02T13:36:40Z
- **Completed:** 2026-04-02T13:39:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- DigestHistory data model defined with _schema_v: 1, rolling 5-run window, event_timeline_snapshot per event
- Section 4A documents cross-digest repetition penalty: 0.7x applied ONCE to final_score for events with no new timeline progress since last digest
- Section 4B documents DigestHistory write procedure with atomic write and rolling window cleanup
- Suppression footer line conditionally appended when repeat_suppressed_count > 0
- SKILL.md Output Phase wires penalty (step 1b), history write (step 6b), metrics write (step 7), and footer (step 8)
- DailyMetrics items object now includes repeat_suppressed field; metrics fixture updated

## Task Commits

Each task was committed atomically:

1. **Task 1: DigestHistory data model + repetition penalty logic + suppression footer** - `7b764f0` (feat)
2. **Task 2: Wire SKILL.md Output Phase and update metrics fixture** - `384e32b` (feat)

## Files Created/Modified
- `references/data-models.md` - DigestHistory schema definition, runs field in New Fields Registry
- `references/processing-instructions.md` - Section 4A (repetition penalty) and Section 4B (digest history write)
- `references/output-templates.md` - Suppression footer line in Transparency Footer section
- `SKILL.md` - Output Phase steps 1b, 6b, updated steps 7 and 8 for repeat_suppressed
- `data/fixtures/digest-history-sample.json` - 5-run fixture with progress and no-progress scenarios
- `data/fixtures/metrics-sample.json` - Added repeat_suppressed: 2 to items object

## Decisions Made
- DigestHistory uses rolling 5-run window comparing only against last digest (non-compounding 0.7x penalty)
- repeat_suppressed_count tracks only items penalized AND excluded from digest (not all penalized items)
- DigestHistory written after output, before lock release, using atomic write

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all data flows are fully wired.

## Next Phase Readiness
- Phase 10 complete: AlertState (plan 01), delta alerts (plan 02), and cross-digest repetition (plan 03) all implemented
- DigestHistory and repeat_suppressed ready for Phase 11 observability and diagnostics

---
*Phase: 10-dedup-hardening-alert-fatigue*
*Completed: 2026-04-02*
