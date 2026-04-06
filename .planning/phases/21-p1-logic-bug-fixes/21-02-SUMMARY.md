---
phase: 21-p1-logic-bug-fixes
plan: 02
subsystem: dedup
tags: [union-find, dedup, anchors, bug-fix]

# Dependency graph
requires:
  - phase: 20-p0-infrastructure-fixes
    provides: "atomic_write_text and write ordering foundation"
provides:
  - "Correct enumerate-based union-find cluster lookup"
  - "Dollar-anchor guard requiring second non-dollar anchor for merge"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: ["enumerate-based index for identity-sensitive loops"]

key-files:
  created: []
  modified:
    - scripts/debug_quick_check.py
    - SKILL.md
    - CHANGELOG.md

key-decisions:
  - "Dollar-only shared anchors require a second non-dollar anchor to merge -- prevents spurious merges on common amounts like $1B"

patterns-established:
  - "Use enumerate(collection) instead of collection.index(item) when identity matters over equality"

requirements-completed: [LOGIC-03, LOGIC-04]

# Metrics
duration: 2min
completed: 2026-04-06
---

# Phase 21 Plan 02: Union-Find Lookup Fix and Dollar-Anchor Guard Summary

**Enumerate-based union-find cluster lookup eliminating wrong-cluster bug, plus dollar-anchor guard requiring second non-dollar anchor for event merge**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-06T11:15:03Z
- **Completed:** 2026-04-06T11:17:30Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Fixed union-find dedup loop: replaced `alerts.index(a)` with `enumerate(alerts)` index, eliminating O(n^2) linear search and wrong-cluster assignment when two alert dicts are value-equal (LOGIC-03 / B11)
- Added dollar-anchor guard in `_same_event()`: dollar-amount-only shared anchors (e.g. "$1B") no longer trigger event merge unless a second non-dollar anchor is also shared (LOGIC-04 / B9)
- Bumped SKILL.md to 16.1.5 and documented both fixes in CHANGELOG.md

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix union-find lookup and dollar-anchor guard** - `5859a48` (fix)
2. **Task 2: Update SKILL.md version and CHANGELOG.md** - `fffbb74` (chore)

## Files Created/Modified
- `scripts/debug_quick_check.py` - Fixed enumerate-based cluster lookup and dollar-anchor guard in _same_event()
- `SKILL.md` - Version bumped to 16.1.5
- `CHANGELOG.md` - Added 16.1.5 entry documenting both fixes

## Decisions Made
- Dollar-only shared anchors require a second non-dollar anchor to confirm event relatedness -- a shared "$1B" alone is too generic to merge events

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 21 logic bug fixes complete (both plans 01 and 02 done)
- Phase 22 (dead code cleanup) can proceed independently

---
*Phase: 21-p1-logic-bug-fixes*
*Completed: 2026-04-06*

## Self-Check: PASSED
