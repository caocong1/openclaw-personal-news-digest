---
phase: 02-smart-processing
plan: 04
subsystem: monitoring
tags: [health-check, alerting, data-lifecycle, TTL, cron, bash]

# Dependency graph
requires:
  - phase: 00-mvp-pipeline
    provides: "Base health-check.sh and data-archive.sh scripts, daily metrics schema"
provides:
  - "MON-02 alert conditions in health-check.sh daily mode (5 alerts)"
  - "MON-03 weekly inspection checklist in health-check.sh weekly mode (6 checks)"
  - "Per-type TTL data lifecycle management in data-archive.sh"
  - "AlertCondition schema in data-models.md"
  - "Weekly health inspection cron job in cron-configs.md"
affects: [monitoring, operations, cron-configs]

# Tech tracking
tech-stack:
  added: []
  patterns: ["--mode flag for multi-mode bash scripts", "atomic JSON writes via tmp+mv", "ALERT/WARN/INFO/OK prefix convention for grep-filterable output"]

key-files:
  created: []
  modified:
    - scripts/health-check.sh
    - scripts/data-archive.sh
    - references/data-models.md
    - references/cron-configs.md

key-decisions:
  - "Health-check.sh uses --mode daily|weekly flag rather than separate scripts to keep alert logic co-located"
  - "All JSON modifications in data-archive.sh use atomic writes (write to .tmp, then os.rename) to prevent corruption"
  - "Weekly health inspection cron job delivers only when alerts or warnings are found to avoid noise"

patterns-established:
  - "Multi-mode bash scripts with --mode flag for different execution depths"
  - "Structured output prefixes (ALERT/WARN/INFO/OK) for grep-based filtering"
  - "Per-entry TTL cleanup with atomic JSON file rewrites"

requirements-completed: [MON-02, MON-03, MON-04]

# Metrics
duration: 3min
completed: 2026-04-01
---

# Phase 2 Plan 4: Monitoring, Alerting, and Data Lifecycle Summary

**Proactive alerting with 5 daily alert conditions, 6 weekly inspection checks, and per-type TTL data lifecycle management across all data stores**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-01T06:51:15Z
- **Completed:** 2026-04-01T06:54:30Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Expanded health-check.sh with --mode flag supporting daily quick checks (MON-02: 5 alert conditions) and weekly full inspection (MON-03: 6 additional checks)
- Expanded data-archive.sh with per-type TTL rules: 30d news, 7d dedup-index entries, 90d feedback, 7d cache, 30d metrics, permanent archived events
- Added AlertCondition schema to data-models.md with severity mapping table and alerts array on DailyMetrics
- Added weekly-health-inspection cron job to cron-configs.md (Monday 03:00 CST, isolated session, conditional delivery)

## Task Commits

Each task was committed atomically:

1. **Task 1: Expand health-check.sh with alert conditions and weekly inspection, add AlertCondition schema** - `41b8e7a` (feat)
2. **Task 2: Expand data-archive.sh with per-type TTL rules and add weekly cron job config** - `966a5d9` (feat)

## Files Created/Modified
- `scripts/health-check.sh` - Expanded with --mode daily|weekly, 5 MON-02 alerts, 6 MON-03 weekly checks
- `scripts/data-archive.sh` - Per-type TTL lifecycle management with atomic JSON writes
- `references/data-models.md` - AlertCondition schema, alerts array on DailyMetrics
- `references/cron-configs.md` - Weekly health inspection cron job definition

## Decisions Made
- Health-check.sh uses --mode flag (daily|weekly) rather than separate scripts, keeping all alert and inspection logic in one file for easier maintenance
- All JSON modifications use atomic writes (write to .tmp then os.rename) to prevent data corruption during cleanup
- Weekly health inspection cron job uses conditional delivery (onlyIf: alerts or warnings found) to reduce noise
- Entries without valid timestamps are preserved (not deleted) during TTL cleanup to avoid accidental data loss

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The weekly health inspection cron job uses the same placeholder `{target_chat_id}` as existing cron jobs.

## Next Phase Readiness
- All MON-02, MON-03, MON-04 requirements complete
- Health-check.sh and data-archive.sh ready for weekly cron job registration
- AlertCondition schema available for future structured alert collection into DailyMetrics

## Self-Check: PASSED

All files exist, all commits verified.

---
*Phase: 02-smart-processing*
*Completed: 2026-04-01*
