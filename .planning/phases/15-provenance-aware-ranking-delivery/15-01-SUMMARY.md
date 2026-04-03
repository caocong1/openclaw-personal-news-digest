---
phase: 15-provenance-aware-ranking-delivery
plan: 01
subsystem: ranking
tags: [provenance, scoring, adjusted-score, representative-selection, schema]

# Dependency graph
requires:
  - phase: 13-provenance-core
    provides: provenance tiers, provenance-db join contract, and citation-backed source lineage
  - phase: 14-source-discovery-automation
    provides: current v3 pipeline context for provenance-driven downstream ranking and delivery work
provides:
  - post-formula provenance modifier contract for ranking
  - event representative selection contract with runtime-only non-representative exclusion
  - Event schema v4 field for representative_item_id
  - provenance scoring fixture proving boost, decay, and selection behavior
affects: [phase-15-plan-02, phase-15-plan-03, alerts, digest-rendering]

# Tech tracking
tech-stack:
  added: []
  patterns: [post-formula-provenance-modifier, event-representative-selection, runtime-only-digest-pool-exclusion]

key-files:
  created:
    - data/fixtures/provenance-scoring-sample.json
  modified:
    - references/scoring-formula.md
    - references/processing-instructions.md
    - references/data-models.md
    - SKILL.md

key-decisions:
  - "Provenance ranking stays a post-formula multiplier on final_score rather than becoming an eighth weighted dimension"
  - "Event representatives are selected by tier rank first, then source credibility, then adjusted_score"
  - "Non-representative exclusion is runtime-only while representative_item_id persists on the Event record"

patterns-established:
  - "Adjusted-score contract: compute final_score first, then apply provenance_modifier before any downstream ranking decisions"
  - "Representative-selection contract: persist Event.representative_item_id while keeping digest-pool exclusions out of persistent NewsItem storage"

requirements-completed: [PIPE-01, PIPE-03]

# Metrics
duration: 8min
completed: 2026-04-03
---

# Phase 15 Plan 01: Provenance Ranking and Representative Selection Summary

**Post-formula provenance scoring modifiers with event-level representative selection contracts, Event schema v4 support, and a proving fixture for boost/decay outcomes**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-03T06:46:42Z
- **Completed:** 2026-04-03T06:54:53Z
- **Tasks:** 2
- **Files modified:** 5 (including 1 created)

## Accomplishments
- Added a provenance modifier table, `adjusted_score` formula, and lookup pseudocode to keep T1/T2 items ahead of redundant T4 aggregation without changing the base 7-dimension weights
- Inserted provenance-aware scoring flow into the processing contract, including repetition-penalty ordering, Section 4R representative selection, and runtime-only exclusion rules for non-representative siblings
- Added `representative_item_id` to the Event model at schema v4 and created a fixture proving T1 boost, conditional T4 decay, solo-T4 neutrality, and representative selection outcomes

## Task Commits

Each task was committed atomically:

1. **Task 1: Add provenance score modifier to scoring formula and representative selection to processing instructions** - `5d93990` (feat)
2. **Task 2: Add representative_item_id to Event model and create provenance scoring fixture** - `1199c05` (feat)

## Files Created/Modified
- `references/scoring-formula.md` - Added the provenance modifier table, `adjusted_score` formula, and modifier lookup pseudocode tied to provenance and event joins
- `references/processing-instructions.md` - Added the provenance-adjusted scoring step, Section 4R representative selection, and downstream `adjusted_score` usage through repetition penalty and quota ranking
- `SKILL.md` - Updated Output Phase scoring guidance to mention provenance modifiers, representative selection, and `adjusted_score` repetition penalty behavior
- `references/data-models.md` - Added `representative_item_id`, bumped Event schema to v4, and updated schema/new-field registries
- `data/fixtures/provenance-scoring-sample.json` - Added a four-item, two-event fixture proving the boost/decay/selection behavior expected by PIPE-01 and PIPE-03

## Decisions Made
- Provenance modifies ranking after the weighted sum, preserving the existing 7-dimension score contract and weight totals
- Representative choice is deterministic: tier outranks credibility, and credibility outranks score when multiple event siblings compete
- The pipeline may persist the winning representative on the Event record, but exclusion of losing siblings remains runtime-only to avoid mutating persistent digest eligibility state

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized downstream ranking references to `adjusted_score`**
- **Found during:** Task 1 (Add provenance score modifier to scoring formula and representative selection to processing instructions)
- **Issue:** The plan introduced `adjusted_score` for downstream ranking but left existing repetition-penalty and quota-ordering references on `final_score`, which would leave contradictory instructions in the same ranking path
- **Fix:** Updated Section 4 quota ordering, Section 4A repetition-penalty language, and the SKILL Output Phase repetition-penalty step to use `adjusted_score`; also removed the stale MVP simplification note from scoring
- **Files modified:** `references/processing-instructions.md`, `SKILL.md`
- **Verification:** `rg -n "final_score|adjusted_score" references/processing-instructions.md` and task verification greps confirmed the adjusted-score contract is present in the downstream daily ranking path
- **Committed in:** `5d93990` (part of Task 1 commit)

**2. [Rule 1 - Bug] Resolved single-item representative ambiguity in the Event model note**
- **Found during:** Task 2 (Add representative_item_id to Event model and create provenance scoring fixture)
- **Issue:** The plan text for the Event field note said single-item events could leave `representative_item_id` null, but the fixture and Section 4R semantics treat the sole item as the representative
- **Fix:** Documented `representative_item_id` as null only when an event has no items in the current scoring pool, aligning the data model with the fixture and representative-selection contract
- **Files modified:** `references/data-models.md`
- **Verification:** Fixture validation passed and the field note now matches the representative-selection outcome documented elsewhere in this plan
- **Committed in:** `1199c05` (part of Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 bug/consistency fixes)
**Impact on plan:** Both fixes were required to keep the new provenance-ranking contract internally consistent. No scope creep beyond the ranking and representative-selection documentation introduced by this plan.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PIPE-01 and PIPE-03 are now documented and fixture-backed for downstream implementation and verification
- Phase 15 Plan 02 can build alert gating and rendering rules on top of the new `adjusted_score` and `representative_item_id` contracts
- Phase 15 Plan 03 can reuse the fixture and ranking contract when documenting weekly provenance-aware reporting

## Self-Check: PASSED

- Summary and all 5 implementation files verified present on disk
- Both task commits (`5d93990`, `1199c05`) verified in git log

---
*Phase: 15-provenance-aware-ranking-delivery*
*Completed: 2026-04-03*
