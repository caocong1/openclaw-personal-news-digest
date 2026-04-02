---
phase: 09-noise-floor-classification-quality
plan: 03
subsystem: processing
tags: [noise-filter, post-classify, importance-threshold, fixtures, pipeline]

# Dependency graph
requires:
  - phase: 09-noise-floor-classification-quality
    plan: 01
    provides: "NewsItem v4 with digest_eligible, Section 0E pre-classify filter, SKILL.md step 2.5"
provides:
  - "Post-classify importance filter procedure (importance < 0.25 threshold)"
  - "SKILL.md step 3.5 post-classify filter integration"
  - "Noise-filtered test fixture with 4 scenarios"
  - "Updated metrics fixture with noise_filter_suppressed field"
affects: [09-noise-floor-classification-quality, processing-phase, output-phase]

# Tech tracking
tech-stack:
  added: []
  patterns: ["post-classify importance threshold filtering", "dual-stage noise filter counter aggregation"]

key-files:
  created:
    - data/fixtures/news-items-noise-filtered.jsonl
  modified:
    - references/processing-instructions.md
    - SKILL.md
    - data/fixtures/metrics-sample.json

key-decisions:
  - "Post-classify filter keeps processing_status as-is (not noise_filtered) since classification DID succeed"
  - "noise_filter_suppressed is single counter summing pre-classify and post-classify filtered items"
  - "Importance threshold 0.25 defined as single-point constant for easy tuning"

patterns-established:
  - "Post-classify threshold filter: importance < 0.25 items skip summarization but keep complete status"
  - "Fixture coverage pattern: one file per filter stage with all scenarios represented"

requirements-completed: [NOISE-02, NOISE-05]

# Metrics
duration: 2min
completed: 2026-04-02
---

# Phase 09 Plan 03: Post-Classify Importance Filter Summary

**Post-classify importance filter with 0.25 threshold skipping summarization for low-value items, plus 4-scenario noise fixture and updated metrics fixture**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-02T08:26:41Z
- **Completed:** 2026-04-02T08:28:38Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added post-classify importance filter procedure in processing-instructions.md Section 1 between Classification and Summarization batches
- Wired step 3.5 into SKILL.md Processing Phase for post-classify filtering
- Created noise-filtered fixture with 4 items covering pre-classify noise pattern, title discard, post-classify low importance, and normal pass-through
- Updated metrics fixture with noise_filter_suppressed counter

## Task Commits

Each task was committed atomically:

1. **Task 1: Add post-classify importance filter to processing-instructions.md and SKILL.md** - `dc5ba06` (feat)
2. **Task 2: Create noise-filtered fixture and update metrics fixture** - `f90c36e` (feat)

## Files Created/Modified
- `references/processing-instructions.md` - New Post-Classify Importance Filter (NOISE-02) subsection in Section 1 with threshold 0.25, digest_eligible marking, summarization skip, and counter documentation
- `SKILL.md` - Step 3.5 post-classify importance filter in Processing Phase
- `data/fixtures/news-items-noise-filtered.jsonl` - 4 JSONL items: pre-classify noise pattern match, title discard match, post-classify low importance (score 0.15), normal pass-through (score 0.85)
- `data/fixtures/metrics-sample.json` - Added noise_filter_suppressed: 3 to items object

## Decisions Made
- Post-classify filtered items keep processing_status as-is (not "noise_filtered") because classification DID succeed -- this is a threshold filter not a pattern filter
- noise_filter_suppressed is a single counter aggregating both pre-classify and post-classify filtered items for simplicity
- Importance threshold 0.25 defined as a single constant in processing-instructions.md for easy future tuning

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all content is fully specified with no placeholder values.

## Next Phase Readiness
- Complete noise filtering pipeline now specified: pre-classify (Section 0E) + post-classify (Section 1)
- SKILL.md pipeline fully wired with steps 2.5 and 3.5
- Fixture files cover all 4 noise filtering scenarios for validation
- Metrics fixture updated for integration testing

---
*Phase: 09-noise-floor-classification-quality*
*Completed: 2026-04-02*
