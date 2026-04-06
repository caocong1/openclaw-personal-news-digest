---
phase: 20-p0-infrastructure-fixes
plan: 01
subsystem: infra
tags: [fcntl, flock, atomic-write, crash-safety, concurrency]

# Dependency graph
requires: []
provides:
  - "fcntl.flock concurrency guard preventing concurrent cron runs"
  - "atomic_write_text helper using tmp+fsync+os.replace pattern"
affects: [20-02-PLAN]

# Tech tracking
tech-stack:
  added: [fcntl, tempfile.mkstemp, os.fsync, os.replace]
  patterns: [atomic-file-write, process-level-flock]

key-files:
  created: []
  modified:
    - scripts/debug_quick_check.py

key-decisions:
  - "Used .pipeline.lock (not .lock) to avoid collision with JSON-based lock from SKILL.md"
  - "Exit code 0 for second instance (graceful yield, not error)"
  - "LOCK_FD kept module-level to prevent GC from closing file descriptor"

patterns-established:
  - "atomic_write_text: all state/metrics JSON writes use tmp+fsync+os.replace"
  - "fcntl.flock LOCK_EX|LOCK_NB at script entry for single-instance guard"

requirements-completed: [INFRA-01, INFRA-02]

# Metrics
duration: 2min
completed: 2026-04-06
---

# Phase 20 Plan 01: Concurrency Guard and Atomic Writes Summary

**fcntl.flock concurrency guard and atomic_write_text helper for crash-safe JSON state writes in debug_quick_check.py**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-06T03:15:26Z
- **Completed:** 2026-04-06T03:17:30Z
- **Tasks:** 2
- **Files modified:** 1 (+ SKILL.md, CHANGELOG.md per project commit rules)

## Accomplishments
- Process-level flock prevents concurrent cron invocations from corrupting state
- atomic_write_text helper ensures crash mid-write leaves previous valid file intact
- All three JSON state files (STATE_FILE, METRICS_FILE, NEWS_FILE) now use atomic writes

## Task Commits

Each task was committed atomically:

1. **Task 1: Add fcntl concurrency guard at script entry** - `62bc698` (fix)
2. **Task 2: Add atomic_write_text helper and replace all JSON state writes** - `f195447` (fix)

## Files Created/Modified
- `scripts/debug_quick_check.py` - Added fcntl import, concurrency guard, atomic_write_text helper, replaced 3 write call sites

## Decisions Made
- Used dedicated `.pipeline.lock` file to avoid collision with the JSON-based `.lock` used by SKILL.md's run locking
- Second concurrent instance exits with code 0 (graceful yield) rather than non-zero (not an error condition)
- LOCK_FD assigned at module level to prevent garbage collection from closing the file descriptor prematurely

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- atomic_write_text helper is available for Plan 02 (write-ordering fix) which depends on it
- Concurrency guard active immediately on next cron invocation

---
*Phase: 20-p0-infrastructure-fixes*
*Completed: 2026-04-06*

## Self-Check: PASSED

- [x] scripts/debug_quick_check.py exists
- [x] Commit 62bc698 (Task 1) exists
- [x] Commit f195447 (Task 2) exists
