---
phase: 12-interaction-surface-deployment-ux
plan: 01
subsystem: infra
tags: [cron, scheduling, routing, docs]
requires:
  - phase: 11-observability-data-integrity
    provides: schema registry and operator-doc conventions reused by Phase 12 docs
provides:
  - repo-backed schedule profile config with active profile selection
  - canonical intent recognition table for user command routing
  - thin SKILL dispatch rules for scheduling and source workflows
affects: [12-02-source-status, deployment-operations, skill-routing]
tech-stack:
  added: []
  patterns: [repo-backed schedule profiles, canonical intent routing table]
key-files:
  created: [config/schedule-profiles.json]
  modified: [references/data-models.md, references/cron-configs.md, references/feedback-rules.md, SKILL.md]
key-decisions:
  - "Scheduling presets live in config/schedule-profiles.json with stable profile IDs and active_profile selection."
  - "Intent recognition examples are centralized in references/feedback-rules.md; SKILL.md only dispatches."
patterns-established:
  - "Schedule changes begin from repo state, then map to platform cron job_name values during apply."
  - "New interaction intents add rows to the Intent Recognition Table instead of duplicating phrases in SKILL.md."
requirements-completed: [INTERACT-01, INTERACT-04]
duration: 5 min
completed: 2026-04-03
---

# Phase 12 Plan 01: Scheduling Profiles and Canonical Intent Routing Summary

**Repo-backed cron schedule profiles with stable IDs and a canonical intent recognition table for SKILL routing**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-02T17:07:50Z
- **Completed:** 2026-04-02T17:12:35Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added `config/schedule-profiles.json` with `daily-default`, `weekday-only`, and `custom-hours` as the concrete schedule source of truth.
- Documented the schedule profile schema and profile-application flow in the data model and cron references.
- Centralized natural-language intent recognition in `references/feedback-rules.md` and reduced `SKILL.md` to a thin routing layer.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create schedule profile source of truth and document its schema** - `e952d37` (feat)
2. **Task 2: Centralize intent recognition and slim SKILL routing** - `5964bae` (feat)

## Files Created/Modified

- `config/schedule-profiles.json` - Named schedule profiles with the active profile and concrete cron expressions.
- `references/data-models.md` - `ScheduleProfileConfig` contract plus registry entry for the new schema.
- `references/cron-configs.md` - Profile-aware schedule management flow and command table.
- `references/feedback-rules.md` - Canonical `Intent Recognition Table` covering schedule, source, feedback, history, and diagnostics routes.
- `SKILL.md` - Thin dispatcher that points user messages to the canonical routing table and destination docs.

## Decisions Made

- Scheduling profile IDs are stable operator-facing command targets, so the repo stores them in config instead of repeating cron examples in prose only.
- Trigger examples now live in one canonical table in `references/feedback-rules.md`; `SKILL.md` keeps routes visible without becoming a second source of truth.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added `ScheduleProfileConfig` to the schema version registry**
- **Found during:** Task 1 (Create schedule profile source of truth and document its schema)
- **Issue:** `references/data-models.md` declares the schema registry authoritative; adding a new `_schema_v` model without a registry row would leave the documentation internally inconsistent.
- **Fix:** Added a `ScheduleProfileConfig | v1` entry to the Schema Version Registry alongside the new schema section.
- **Files modified:** `references/data-models.md`
- **Verification:** `rg -n "ScheduleProfileConfig" references/data-models.md`
- **Committed in:** `e952d37` (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** The extra change kept the schema documentation internally consistent without expanding scope beyond the planned schedule-profile contract.

## Issues Encountered

- A transient `.git/index.lock` blocked the first staging attempt for Task 1. No active git process was present, and a retry succeeded without deleting unrelated files or changing the worktree.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 12 now has concrete schedule profile state and a single routing table to build on for source-status behavior in `12-02`.
- Future interaction routes can extend `references/feedback-rules.md` without reintroducing duplicated trigger phrases in `SKILL.md`.

## Self-Check: PASSED

- Verified summary file exists at `.planning/phases/12-interaction-surface-deployment-ux/12-01-SUMMARY.md`.
- Verified task commits `e952d37` and `5964bae` are present in git history.

---
*Phase: 12-interaction-surface-deployment-ux*
*Completed: 2026-04-03*
