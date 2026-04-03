---
phase: 14-source-discovery-automation
plan: 02
subsystem: source-discovery
tags: [auto-enable, auto-disable, source-config, discovery-metadata, provenance]

# Dependency graph
requires:
  - phase: 14-source-discovery-automation/01
    provides: discovery-state schema, accumulation fixture, rolling-window contract
provides:
  - exact auto-enable gate definitions with five deterministic checks
  - exact auto-disable trigger definitions with three rolling-window thresholds
  - event-based uniqueness join path for enable evaluation
  - generated source-config contract reusing existing Source schema
  - six additive discovery metadata fields on Source model
  - type inference rules for auto-discovered sources
  - rejected/disabled discovery outcome fixture
  - auto-discovered source fixture
affects: [14-source-discovery-automation/03, 15-provenance-ranking-output]

# Tech tracking
tech-stack:
  added: []
  patterns: [five-gate-enable-evaluation, three-trigger-disable-evaluation, additive-discovery-metadata, deterministic-source-id-generation]

key-files:
  created:
    - data/fixtures/source-config-auto-discovered-sample.json
    - data/fixtures/discovered-sources-rejected-sample.json
  modified:
    - references/processing-instructions.md
    - references/data-models.md

key-decisions:
  - "Discovery metadata fields are additive to Source model -- they do not replace enabled or status"
  - "Auto-disable sets enabled:false without changing status, preserving operational health semantics"
  - "Uniqueness gate uses event_id coverage join, not title or URL novelty"
  - "Generated source IDs use deterministic src-auto-{hash(domain)} pattern"
  - "Default type fallback is official with prefer_browser:true for unknown domains"

patterns-established:
  - "Five-gate enable evaluation: all gates must pass (frequency, quality, uniqueness, not-already-enabled, age)"
  - "Three-trigger disable evaluation: any trigger fires disablement (tier ratio, sustained inactivity, low activity)"
  - "Discovery metadata as additive Source fields rather than parallel model"

requirements-completed: [DISC-02, DISC-03, DISC-04]

# Metrics
duration: 3min
completed: 2026-04-03
---

# Phase 14 Plan 02: Auto-Enable/Disable Rules and Generated Source-Config Contract Summary

**Deterministic five-gate auto-enable evaluator, three-trigger auto-disable contract, and generated source-config schema with additive discovery metadata on the existing Source model**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-03T04:26:01Z
- **Completed:** 2026-04-03T04:29:27Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Defined exact auto-enable evaluation with five mandatory gates (frequency >= 5, quality >= 0.3, event-based uniqueness, not-already-enabled, age >= 3 days) and documented the provenance-to-event uniqueness join path
- Defined exact auto-disable triggers (t1_ratio < 0.1, 14 consecutive days without T1/T2, hit_count_7d < 2 for 7 days) with a disable contract that preserves operational status semantics
- Extended the Source model with six additive discovery metadata fields and documented backward-compatible defaults for older records
- Created Source Config Generation rules with type inference, deterministic ID generation, and write-back contract
- Created two fixture files proving enabled, deferred, and disabled discovery outcomes with concrete threshold details

## Task Commits

Each task was committed atomically:

1. **Task 1: Add exact auto-enable and auto-disable evaluator rules** - `681bc27` (feat)
2. **Task 2: Define the generated source-config contract and discovery metadata** - `b4c135c` (feat)

## Files Created/Modified
- `references/processing-instructions.md` - Added Auto-Enable Evaluation, Auto-Disable Evaluation, and Source Config Generation subsections
- `references/data-models.md` - Extended Source section with discovery metadata fields, generated-source defaults, and backward-compatible defaults
- `data/fixtures/source-config-auto-discovered-sample.json` - Generated source entry example with full Source schema and discovery metadata
- `data/fixtures/discovered-sources-rejected-sample.json` - Deferred and disabled discovery outcome examples with decision history

## Decisions Made
- Discovery metadata fields are additive to the Source model -- they do not replace `enabled` or `status`, keeping operator tools and source-health semantics intact
- Auto-disable sets `enabled: false` without changing `status`, so operational health demotion and discovery disable remain independent mechanisms
- Uniqueness gate uses event_id coverage join (provenance -> event_id -> enabled source coverage set) rather than title or URL novelty, matching the design spec faithfully
- Generated source IDs use deterministic `src-auto-{hash(domain)}` pattern ensuring idempotent re-evaluation
- Default type fallback is `official` with `prefer_browser: true` for unknown domains since they likely need JavaScript rendering

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Auto-enable and auto-disable evaluation rules are fully documented with exact thresholds
- Generated source-config contract is complete with type inference, defaults, and write-back rules
- Discovery metadata fields are defined and backward-compatible
- Ready for 14-03: discovery audit artifacts, pattern-library expansion rules, and verification coverage

## Self-Check: PASSED

All files verified present. All commits verified in git history.

---
*Phase: 14-source-discovery-automation*
*Completed: 2026-04-03*
