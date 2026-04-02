---
phase: 11-observability-data-integrity
plan: 01
subsystem: observability
tags: [transparency-footer, failed-sources, per-source-metrics, chinese-output]

# Dependency graph
requires:
  - phase: 04-integration-wiring
    provides: per_source metrics in DailyMetrics
provides:
  - Conditional failed source footer line in transparency footer
  - Failed source name tracking derivation procedure
  - SKILL.md Output Phase step 8 failed source rendering instruction
affects: [output-templates, processing-instructions, SKILL.md]

# Tech tracking
tech-stack:
  added: []
  patterns: [conditional-footer-line, per-source-status-derived-display]

key-files:
  created: []
  modified:
    - references/output-templates.md
    - references/processing-instructions.md
    - SKILL.md

key-decisions:
  - "Failed source names derived from existing per_source data -- no new collection logic"
  - "Display names looked up from config/sources.json name field, not source_id"

patterns-established:
  - "Conditional footer line: omit entirely when condition not met (no empty state)"

requirements-completed: [OBS-01]

# Metrics
duration: 2min
completed: 2026-04-02
---

# Phase 11 Plan 01: Transparency Footer Failed Source Visibility Summary

**Conditional footer line showing failed source display names derived from per_source metrics, with Chinese label**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-02T15:24:56Z
- **Completed:** 2026-04-02T15:26:12Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added conditional failed source line to Transparency Footer template with Chinese label (采集失败)
- Documented failed source name derivation procedure in processing-instructions.md Section 5
- Updated SKILL.md Output Phase step 8 to instruct pipeline to check per_source for failures and render names

## Task Commits

Each task was committed atomically:

1. **Task 1: Add failed source footer template and tracking instruction** - `432362d` (feat)
2. **Task 2: Update SKILL.md Output Phase step 8 to reference failed source footer** - `6ca139c` (feat)

## Files Created/Modified
- `references/output-templates.md` - Added conditional failed source footer line and field definitions
- `references/processing-instructions.md` - Added Failed Source Name Tracking subsection in Section 5
- `SKILL.md` - Updated Output Phase step 8 with per_source failed status check

## Decisions Made
- Failed source display names derived from existing per_source data (no new collection logic needed)
- Display names looked up from config/sources.json name field, not raw source_id

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Footer template ready for pipeline to render failed source names
- All three files (output-templates.md, processing-instructions.md, SKILL.md) consistently reference the failed source flow
- Phase 11 Plan 02 (run log) and Plan 03 can proceed independently

---
*Phase: 11-observability-data-integrity*
*Completed: 2026-04-02*
