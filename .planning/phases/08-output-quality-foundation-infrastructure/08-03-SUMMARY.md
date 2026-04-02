---
phase: 08-output-quality-foundation-infrastructure
plan: 03
subsystem: data-quality
tags: [utf-8, validation, jsonl, quality-contract, pre-write]

# Dependency graph
requires:
  - phase: 08-02
    provides: "SKILL.md cross-references to Section 0D, edge-case fixture file"
provides:
  - "Pre-write quality contract (Section 0D) in processing-instructions.md with 4 validation rules"
affects: [collection-phase, processing-phase, data-integrity]

# Tech tracking
tech-stack:
  added: []
  patterns: [pre-write-validation-contract, skip-and-log-on-failure]

key-files:
  created: []
  modified:
    - references/processing-instructions.md

key-decisions:
  - "Section 0D placed between 0C (Tiered Model) and 1 (Batch LLM) following existing numbering convention"
  - "Cross-reference kept in processing-instructions.md rather than modifying SKILL.md (already done by Plan 02)"

patterns-established:
  - "Pre-write quality contract: validate all items before JSONL write, skip invalid with logged warning"
  - "UTF-8 sanitization strips null bytes, control chars (except newline/tab), lone surrogates"

requirements-completed: [QUAL-01]

# Metrics
duration: 1min
completed: 2026-04-02
---

# Phase 08 Plan 03: Pre-Write Quality Contract Summary

**Pre-write validation contract with 4 rules (UTF-8, title, URL, ID consistency) applied at both JSONL write points in the pipeline**

## Performance

- **Duration:** 1 min
- **Started:** 2026-04-02T05:21:37Z
- **Completed:** 2026-04-02T05:22:35Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added Section 0D: Pre-Write Quality Contract (QUAL-01) to processing-instructions.md
- Defined 4 validation rules with specific thresholds: UTF-8 character ranges, 500-char title max, https:// URL requirement, SHA256[:16] ID verification
- Specified failure behavior: invalid items skipped entirely, warnings logged, pipeline continues for valid items
- Documented interaction with existing Collection and Processing phase steps

## Task Commits

Each task was committed atomically:

1. **Task 1: Add pre-write quality contract to processing-instructions.md** - `a61f172` (feat)

**Plan metadata:** (pending)

## Files Created/Modified
- `references/processing-instructions.md` - Added Section 0D: Pre-Write Quality Contract between Section 0C and Section 1

## Decisions Made
- Section 0D positioned between 0C (Tiered Model Strategy) and 1 (Batch LLM Processing) following the existing 0/0A/0B/0C numbering pattern
- Cross-reference to SKILL.md write points documented within Section 0D header rather than modifying SKILL.md (Plan 02 already added the SKILL.md cross-references)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Quality contract is defined and cross-referenced from both SKILL.md write points
- Edge-case fixture file (data/fixtures/news-items-edge-cases.jsonl from Plan 02) exercises all 4 rules
- Phase 08 plans complete; ready for phase transition

## Self-Check: PASSED

- references/processing-instructions.md: FOUND
- 08-03-SUMMARY.md: FOUND
- Commit a61f172: FOUND

---
*Phase: 08-output-quality-foundation-infrastructure*
*Completed: 2026-04-02*
