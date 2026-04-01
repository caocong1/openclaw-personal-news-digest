---
phase: 03-closed-loop
plan: 02
subsystem: pipeline
tags: [quality-score, auto-demotion, source-management, state-machine]

# Dependency graph
requires:
  - phase: 02-smart-processing
    provides: "Source health metrics computation (quality_score, dedup_rate, selection_rate)"
provides:
  - "Source auto-demotion procedure (14-day threshold, quality_score < 0.2)"
  - "Source auto-recovery procedure (7-day threshold, quality_score > 0.3)"
  - "Degraded source handling in collection and scoring"
  - "Source schema with degraded_since and recovery_streak_start tracking fields"
affects: [scoring, collection, source-management]

# Tech tracking
tech-stack:
  added: []
  patterns: [state-machine-with-hysteresis, backup-before-write]

key-files:
  created: []
  modified:
    - references/processing-instructions.md
    - references/collection-instructions.md
    - references/data-models.md
    - SKILL.md

key-decisions:
  - "Asymmetric thresholds: demotion at 0.2 (14 days) vs recovery at 0.3 (7 days) prevents oscillation"
  - "Degraded sources still collected but deprioritized (0.5x source_trust penalty) rather than excluded"
  - "Budget-tight skip: degraded sources skipped only when effective_usage >= 0.8"

patterns-established:
  - "Hysteresis counters: degraded_since and recovery_streak_start reset on quality recovery/dip to prevent rapid state cycling"

requirements-completed: [SRC-09]

# Metrics
duration: 3min
completed: 2026-04-01
---

# Phase 3 Plan 02: Source Auto-Demotion Summary

**Source quality state machine with 14-day demotion, 7-day recovery, hysteresis counters, and 0.5x scoring penalty for degraded sources**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-01T07:34:44Z
- **Completed:** 2026-04-01T07:37:33Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Source auto-demotion procedure with 14-day threshold (quality_score < 0.2) and hysteresis reset
- Source auto-recovery procedure with 7-day threshold (quality_score > 0.3) and streak tracking
- Degraded source handling in collection (budget-tight skip) and scoring (0.5x source_trust multiplier)
- Source schema extended with degraded_since and recovery_streak_start tracking fields
- SKILL.md wired for both processing (step 13) and collection (step 3 degraded skip)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add source auto-demotion/recovery procedure and update Source schema** - `a20c270` (feat)
2. **Task 2: Add degraded source collection rules and wire into SKILL.md** - `31a1153` (feat)

## Files Created/Modified
- `references/processing-instructions.md` - Added Section 6: Source Auto-Demotion and Recovery with demotion check, recovery check, scoring penalty, and write-back procedure
- `references/collection-instructions.md` - Added Degraded Source Handling section with budget-tight skip, display rules, and manual override
- `references/data-models.md` - Extended Source stats schema with degraded_since and recovery_streak_start fields plus field notes and defaults
- `SKILL.md` - Added Processing Phase step 13 (source status check) and updated Collection Phase step 3 (skip degraded when budget tight)

## Decisions Made
- Asymmetric thresholds (0.2 demotion vs 0.3 recovery) create a hysteresis band that prevents rapid oscillation between active and degraded states
- Degraded sources are deprioritized (0.5x source_trust) rather than excluded, giving them a path back to active status
- Budget-tight skip only activates at effective_usage >= 0.8, matching the existing circuit-breaker warning threshold

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Source auto-demotion/recovery is fully specified and wired into the pipeline
- Ready for remaining Phase 3 plans (health dashboard, weekly report, etc.)

## Self-Check: PASSED

All files exist. All commit hashes verified.

---
*Phase: 03-closed-loop*
*Completed: 2026-04-01*
