---
phase: 06-per-source-metrics-continuity
plan: 01
subsystem: monitoring
tags: [per-source-metrics, daily-metrics, source-health, pipeline-counters]

# Dependency graph
requires:
  - phase: 04-integration-wiring-fixes
    provides: source health stats fields and degraded penalty in scoring formula
provides:
  - per_source field in DailyMetrics schema with 6 sub-fields
  - Per-source metrics accumulation steps documented in processing-instructions.md
  - Source health formulas explicitly referencing per_source as data source
  - SKILL.md pipeline steps mentioning per-source counter tracking
affects: [source-health, monitoring, health-check, auto-demotion-recovery]

# Tech tracking
tech-stack:
  added: []
  patterns: [per-source pipeline counter accumulation, backward-compatible schema extension]

key-files:
  created: []
  modified:
    - references/data-models.md
    - references/processing-instructions.md
    - references/collection-instructions.md
    - SKILL.md

key-decisions:
  - "per_source schema uses 6 sub-fields (fetched, deduped, title_deduped, selected, status, error) matching existing health-check.sh consumer expectations"
  - "Backward compatibility via .get('per_source', {}) -- no backfill of historical metrics needed"

patterns-established:
  - "Per-source counter accumulation: track counters at each pipeline step, persist in daily metrics"

requirements-completed: [SRC-08, SRC-09, MON-02, MON-03]

# Metrics
duration: 2min
completed: 2026-04-01
---

# Phase 06 Plan 01: Per-Source Metrics Continuity Summary

**per_source DailyMetrics contract with 6 sub-fields wiring source health computation, monitoring alerts, and auto-demotion/recovery end-to-end**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-01T16:23:53Z
- **Completed:** 2026-04-01T16:26:02Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Documented per_source field in DailyMetrics schema with all 6 sub-fields matching health-check.sh consumer expectations (fetched, deduped, title_deduped, selected, status, error)
- Added Per-Source Metrics Accumulation subsection in processing-instructions.md with accumulation points mapped to specific pipeline steps
- Updated source health formulas in collection-instructions.md to explicitly reference per_source fields as data source
- Added per-source counter tracking references to SKILL.md Collection Phase step 4 and Output Phase step 7

## Task Commits

Each task was committed atomically:

1. **Task 1: Document per_source schema in DailyMetrics and add producer steps** - `1c39868` (feat)
2. **Task 2: Wire per_source references into collection-instructions.md and SKILL.md** - `21872e5` (feat)

## Files Created/Modified
- `references/data-models.md` - Added per_source field to DailyMetrics JSON schema and Field notes (per_source) section
- `references/processing-instructions.md` - Added Per-Source Metrics Accumulation subsection in Section 5
- `references/collection-instructions.md` - Added Data source paragraph and updated formula definitions to reference per_source fields
- `SKILL.md` - Added per-source counter tracking note in Collection Phase step 4 and per_source in Output Phase step 7

## Decisions Made
- per_source schema uses 6 sub-fields (fetched, deduped, title_deduped, selected, status, error) matching existing health-check.sh consumer field names without modification
- Backward compatibility ensured via .get('per_source', {}) pattern -- no backfill of historical metrics needed, pre-Phase-6 files gracefully handled

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- per_source contract fully documented and wired across all 4 reference files
- health-check.sh consumers already use correct field names -- no script changes needed
- MISSING-06 and BROKEN-03 from v1.0 milestone audit should now be resolved

## Self-Check: PASSED

All 4 modified files verified present. Both task commits (1c39868, 21872e5) verified in git log.

---
*Phase: 06-per-source-metrics-continuity*
*Completed: 2026-04-01*
