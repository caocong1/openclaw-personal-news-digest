---
phase: 09-noise-floor-classification-quality
plan: 01
subsystem: processing
tags: [noise-filter, pre-classify, regex-patterns, data-models, pipeline]

# Dependency graph
requires:
  - phase: 08-output-quality-foundation-infrastructure
    provides: "Pre-write quality contract, schema versioning infrastructure"
provides:
  - "NewsItem v4 schema with digest_eligible field"
  - "DailyMetrics noise_filter_suppressed counter"
  - "Source noise_patterns and title_discard_patterns in fetch_config"
  - "Section 0E pre-classify noise filter procedure"
  - "SKILL.md step 2.5 noise filter pipeline integration"
affects: [09-noise-floor-classification-quality, processing-phase, output-phase]

# Tech tracking
tech-stack:
  added: []
  patterns: ["regex-based pre-classify noise filtering", "digest_eligible gating for scoring pool"]

key-files:
  created: []
  modified:
    - references/data-models.md
    - config/sources.json
    - references/processing-instructions.md
    - SKILL.md

key-decisions:
  - "Empty noise_patterns arrays for all sources (conservative default per research)"
  - "noise_filtered items stay in JSONL for history queryability, not deleted"
  - "digest_eligible defaults to true for backward compatibility with v3 items"

patterns-established:
  - "Pre-classify filter pattern: regex matching before LLM calls to save budget"
  - "digest_eligible gating: items with false excluded from scoring pool"

requirements-completed: [NOISE-01, NOISE-03, NOISE-04, NOISE-05]

# Metrics
duration: 3min
completed: 2026-04-02
---

# Phase 09 Plan 01: Noise Filter Infrastructure Summary

**Pre-classify noise filter pipeline with NewsItem v4 schema, per-source regex patterns, Section 0E filter procedure, and SKILL.md step 2.5 integration**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-02T08:21:09Z
- **Completed:** 2026-04-02T08:24:24Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Extended NewsItem schema to v4 with digest_eligible field and noise_filtered processing status
- Added noise_patterns and title_discard_patterns to all 6 source fetch_config entries
- Created Section 0E pre-classify noise filter procedure with complete filter logic and pipeline interactions
- Wired noise filter step 2.5 into SKILL.md Processing Phase and digest_eligible exclusion into Output Phase scoring

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend data models and source config for noise filtering** - `06aaec6` (feat)
2. **Task 2: Create Section 0E pre-classify noise filter and wire into SKILL.md** - `e0fa96c` (feat)

## Files Created/Modified
- `references/data-models.md` - NewsItem v4 with digest_eligible, noise_filtered status, DailyMetrics noise_filter_suppressed, Source noise_patterns/title_discard_patterns docs, New Fields Registry entries
- `config/sources.json` - All 6 sources now have noise_patterns and title_discard_patterns arrays in fetch_config
- `references/processing-instructions.md` - New Section 0E pre-classify noise filter procedure between 0D and 1
- `SKILL.md` - Step 2.5 noise filter in Processing Phase, digest_eligible exclusion in Output Phase step 1

## Decisions Made
- Empty noise_patterns arrays for all sources as conservative default -- patterns will be populated based on observed noise in production
- Noise-filtered items remain in JSONL with processing_status "noise_filtered" for history queryability rather than being deleted
- digest_eligible defaults to true for backward compatibility so v3 items are not incorrectly excluded

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all noise_patterns arrays are intentionally empty as conservative defaults; patterns will be populated based on observed noise data.

## Next Phase Readiness
- Noise filter infrastructure complete, ready for pattern population in future plans
- Section 0E procedure fully specified for agent execution
- SKILL.md pipeline wired end-to-end with noise filtering

---
*Phase: 09-noise-floor-classification-quality*
*Completed: 2026-04-02*
