---
phase: 11-observability-data-integrity
plan: 03
subsystem: observability
tags: [bash, python3, diagnostics, schema-registry]

# Dependency graph
requires:
  - phase: 11-observability-data-integrity
    provides: run_log schema (11-02), source accuracy (11-01)
provides:
  - Schema Version Registry documenting all 11 data models with current versions and phase-labeled change history
  - Diagnostics command (scripts/diagnostics.sh) producing 6-section consolidated operator report
  - SKILL.md User Commands routing for diagnostics intent
affects: [future phases adding new data models]

# Tech tracking
tech-stack:
  added: [bash, python3 (inline)]
  patterns: [on-demand operator inspection tool, consolidated multi-source report]

key-files:
  created: [scripts/diagnostics.sh]
  modified: [references/data-models.md, SKILL.md]

key-decisions:
  - "Diagnostics is on-demand inspection (operator triggered), health-check.sh is automated alerting (cron triggered)"

patterns-established:
  - "Schema Version Registry maintained alongside New Fields Registry, both updated on schema changes"
  - "Consolidated diagnostics report reads existing JSON data files, produces structured text output"

requirements-completed: [OBS-03, OBS-04]

# Metrics
duration: 3min
completed: 2026-04-03
---

# Phase 11 Plan 03: Schema Version Registry and Diagnostics Command Summary

**Schema Version Registry documents all 11 data models with current _schema_v and phase-labeled change history; diagnostics.sh produces 6-section consolidated operator report from metrics, alerts, history, budget, and data files.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-02T16:28:47Z
- **Completed:** 2026-04-02T16:31:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Schema Version Registry added to data-models.md documenting all 11 data models (NewsItem v4, Event v3, CacheEntry v2, Preferences v2, AlertState v1, DigestHistory v1, DailyMetrics n/a, Source n/a, AlertCondition v1, FeedbackEntry v1, DedupIndex n/a) with current versions and per-phase change history
- diagnostics.sh created as on-demand operator inspection tool with 6 sections: Pipeline Status, Source Health, Alert Activity, Digest History, Budget Status, Data Integrity
- SKILL.md User Commands updated with Diagnostics routing (item 5), General moved to item 6

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Schema Version Registry to data-models.md** - `758ef57` (feat)
2. **Task 2: Create diagnostics.sh script and add SKILL.md command routing** - `a8310a5` (feat)

**Plan metadata:** `2a93f8d` (docs: complete plan)

## Files Created/Modified
- `references/data-models.md` - Schema Version Registry section added before Bootstrap & Migration
- `scripts/diagnostics.sh` - New consolidated diagnostics report script (239 lines, bash + inline python3)
- `SKILL.md` - User Commands section updated with Diagnostics entry (item 5), General renumbered to 6

## Decisions Made
- Diagnostics is on-demand inspection tool (operator triggered via User Commands), health-check.sh is automated alerting (cron triggered). Different purposes, separate tools.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

Phase 12 (Interaction Surface & Deployment UX) can proceed. All Phase 11 observability requirements (OBS-01 through OBS-04) are now complete. Schema Version Registry provides authoritative reference for all future schema changes.

---
*Phase: 11-observability-data-integrity*
*Completed: 2026-04-03*
