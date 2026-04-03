---
phase: 15-provenance-aware-ranking-delivery
plan: 03
subsystem: reporting
tags: [weekly-report, source-discovery, e2e-fixture, provenance, verification]

# Dependency graph
requires:
  - phase: 14-source-discovery-automation
    provides: discovered-source decision history, rolling metrics, and source enable/disable semantics
  - phase: 15-provenance-aware-ranking-delivery
    provides: provenance-aware scoring, representative-selection, alert-threshold, and rendering contracts from Plans 01-02
provides:
  - weekly source-discovery reporting contract for weekly report assembly
  - Chinese-language weekly discovery template with enabled, disabled, tier-mix, and watchlist sections
  - end-to-end Phase 15 fixture covering PIPE-01 through PIPE-05 in one scenario
affects: [phase-verification, weekly-reporting, provenance-audits]

# Tech tracking
tech-stack:
  added: []
  patterns: [weekly-source-discovery-report, provenance-pipeline-e2e-fixture]

key-files:
  created:
    - data/fixtures/provenance-ranking-e2e-sample.json
  modified:
    - references/processing-instructions.md
    - references/output-templates.md

key-decisions:
  - "Weekly discovery reporting reads discovered-source decision_history plus the current tier-stats days map rather than assuming a legacy daily shape"
  - "Weekly discovery output renders explicit placeholder text when enabled, disabled, or watchlist sections would otherwise be empty"
  - "The end-to-end verification fixture is organized by PIPE requirement ID so each requirement can be checked independently"

patterns-established:
  - "Weekly reporting contract: append a dedicated discovery section after the main weekly report body, but skip subsections entirely when discovery has not started"
  - "Verification-fixture contract: keep one coherent scenario while breaking proofs into PIPE-specific sections with explicit _proof and _note fields"

requirements-completed: [PIPE-05]

# Metrics
duration: 4min
completed: 2026-04-03
---

# Phase 15 Plan 03: Weekly Discovery Reporting and E2E Fixture Summary

**Weekly source-discovery reporting contract plus a single-scenario fixture that proves all five provenance-aware PIPE requirements together**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-03T07:20:00Z
- **Completed:** 2026-04-03T07:24:22Z
- **Tasks:** 2
- **Files modified:** 3 (including 1 created)

## Accomplishments

- Added `Section 7A` to the weekly-report contract so weekly assembly can report newly enabled sources, newly disabled sources, weekly tier mix changes, and discovery watchlist candidates
- Added a Chinese-language weekly discovery template to `references/output-templates.md`, including explicit zero-result placeholders instead of empty report sections
- Created `data/fixtures/provenance-ranking-e2e-sample.json`, a single coherent scenario that demonstrates provenance scoring, representative selection, alert gating, provenance rendering, and weekly discovery reporting together

## Task Commits

Each task was committed atomically:

1. **Task 1: Add weekly source-discovery report section to processing instructions and output templates** - `7bafc58` (docs)
2. **Task 2: Create end-to-end provenance-aware pipeline verification fixture** - `2759e74` (test)

## Files Created/Modified

- `references/processing-instructions.md` - Added Section 7A, empty-state handling, week-over-week tier comparison rules, and assembly guidance for appending the discovery section
- `references/output-templates.md` - Added the weekly discovery report template with enabled, disabled, tier distribution, and watchlist subsections
- `data/fixtures/provenance-ranking-e2e-sample.json` - Added a requirement-structured Phase 15 fixture covering PIPE-01 through PIPE-05

## Decisions Made

- Weekly discovery reporting should describe the repo's real discovery artifacts, so the contract now references the current `tier-stats.json` `days` store and current discovery decision reasons instead of an older generalized shape
- Empty discovery actions are user-visible states, not absences of data, so the weekly report explicitly renders placeholder lines for zero enabled, zero disabled, and zero watchlist cases
- Phase verification should be able to test requirements independently, so the E2E fixture is divided by PIPE requirement while still describing one pipeline run

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Normalized Section 7A to the repo's current discovery data shapes**
- **Found during:** Task 1 (Add weekly source-discovery report section to processing instructions and output templates)
- **Issue:** The plan assumed a generic `tier-stats.json` `daily` map and simplified disable-reason labels, but the repo's actual fixtures and current schema use a `days` map plus more specific discovery reason codes. Following the plan literally would have documented joins that do not match the checked-in artifacts.
- **Fix:** Updated Section 7A to aggregate from the `days[date].tiers` structure, documented normalization from any legacy `daily` reader, mapped actual disable reasons to Chinese labels, and added a fallback when enable decisions do not snapshot `hit_count_7d`
- **Files modified:** `references/processing-instructions.md`
- **Verification:** Compared the new contract against `data/fixtures/discovered-sources-sample.json` and `data/fixtures/tier-stats-sample.json`, then verified `Section 7A`, empty-state handling, and watchlist guidance via grep
- **Committed in:** `7bafc58` (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking schema-alignment fix)
**Impact on plan:** The deviation keeps the weekly reporting contract aligned with the repo's actual discovery fixtures and prevents verification drift. No scope beyond the weekly-report and fixture objectives was added.

## Issues Encountered

None

## User Setup Required

None - this plan only updates documentation contracts and fixture coverage.

## Next Phase Readiness

- All five Phase 15 PIPE requirements now have concrete documentation or fixture coverage in the repo
- Phase-level verification can now check ranking, representative selection, alert gating, rendering, and weekly discovery reporting against a shared provenance-aware contract

## Self-Check: PASSED

- `grep "Section 7A" references/processing-instructions.md` returns the discovery report section
- `grep "来源发现动态" references/output-templates.md` returns the weekly discovery template
- `python3` assertions pass for `data/fixtures/provenance-ranking-e2e-sample.json`, including all five PIPE sections and key value relationships

---
*Phase: 15-provenance-aware-ranking-delivery*
*Completed: 2026-04-03*
