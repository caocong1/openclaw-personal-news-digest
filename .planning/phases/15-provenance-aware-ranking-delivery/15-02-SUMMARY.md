---
phase: 15-provenance-aware-ranking-delivery
plan: 02
subsystem: delivery
tags: [provenance, alerts, digest-rendering, templates, output-contract]

# Dependency graph
requires:
  - phase: 13-provenance-core
    provides: provenance tiers, original-source attribution fields, and provenance-chain records keyed by NewsItem.id
  - phase: 15-provenance-aware-ranking-delivery
    provides: adjusted-score and event-representative selection contracts from Plan 01
provides:
  - event-level alert suppression and tier-aware T4 alert threshold contract
  - provenance-aware digest and alert rendering rules with tier display mapping
  - explicit user-facing vs internal-only provenance field split for output rendering
  - SKILL output-phase guidance for joining selected items to ProvenanceRecord
affects: [phase-15-plan-03, alerts, digest-rendering, quick-check]

# Tech tracking
tech-stack:
  added: []
  patterns: [event-level-alert-suppression, tier-aware-alert-threshold, provenance-rendering-contract]

key-files:
  created: []
  modified:
    - references/processing-instructions.md
    - references/output-templates.md
    - references/data-models.md
    - SKILL.md

key-decisions:
  - "T4 alert eligibility stays on a stricter 0.92 threshold while T0-T3 items retain the 0.85 breaking-news bar"
  - "Source tier is always user-facing, while original-source attribution and provenance-chain rendering remain conditional"
  - "Provenance diagnostics such as tier_source and llm_result stay internal-only even when provenance metadata is shown to users"

patterns-established:
  - "Alert-entry contract: suppress already-alerted event_ids before threshold evaluation, then derive the effective threshold from ProvenanceRecord.tier"
  - "Rendering contract: join every selected item or alert candidate to ProvenanceRecord, render tier labels through Chinese display mapping, and never expose provenance diagnostics"

requirements-completed: [PIPE-02, PIPE-04]

# Metrics
duration: 7min
completed: 2026-04-03
---

# Phase 15 Plan 02: Alert Gating and Provenance Rendering Summary

**Event-level alert suppression with T4-specific alert thresholds and provenance-aware digest and alert rendering contracts**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-03T06:55:30Z
- **Completed:** 2026-04-03T07:02:40Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added Section 5A entry steps for event-level alert suppression and a tier-aware `effective_threshold`, keeping T0-T3 at `0.85` while raising T4 to `0.92`
- Updated daily digest, breaking-news alert, and delta-alert templates to show tier labels, conditional original-source attribution, provenance-chain rendering, and the English-title guidance note
- Formalized which provenance fields are user-facing versus internal-only, and updated `SKILL.md` so output generation joins selected items to `data/provenance/provenance-db.json`

## Task Commits

Each task was committed atomically:

1. **Task 1: Add event-level alert suppression and tier-aware threshold to the alert decision tree** - `97915ef` (feat)
2. **Task 2: Add provenance rendering rules to output templates, tier display mapping, and updated rendering contract** - `630a187` (feat)

## Files Created/Modified
- `references/processing-instructions.md` - Added Step 0 event suppression, Step 0A tier-aware thresholding, and renumbered downstream alert references
- `references/output-templates.md` - Added provenance-aware digest and alert formats, tier display mapping, provenance-chain rendering rules, and updated rendering contract tables
- `references/data-models.md` - Clarified which ProvenanceRecord fields are user-facing versus internal-only
- `SKILL.md` - Documented the Output Phase provenance join and rendering requirements for selected items

## Decisions Made
- Kept the conservative breaking-news policy anchored at `0.85` for direct and neutral tiers, while treating T4 aggregation as a stricter `0.92` exception instead of changing the global policy
- Rendered provenance metadata through the output contract rather than adding inline provenance fields to `NewsItem`, preserving the existing `NewsItem.id -> ProvenanceRecord` join path
- Made provenance-chain and original-source attribution conditional so user-visible output gains trust context without cluttering every item

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Extended provenance display to alert templates**
- **Found during:** Task 2 (Add provenance rendering rules to output templates, tier display mapping, and updated rendering contract)
- **Issue:** The plan objective and success criteria required provenance display in alerts and digests, but the task body only specified digest-format edits. Leaving alert templates unchanged would have produced an incomplete user-facing contract.
- **Fix:** Updated the Breaking News Alert and Delta Alert templates to render `信源层级`, conditional `原始来源`, and conditional `溯源链`; also added the English-title guidance note to the standard alert format where applicable.
- **Files modified:** `references/output-templates.md`
- **Verification:** `sed -n '94,180p' references/output-templates.md` and task verification greps confirm the alert templates now include provenance rendering lines while diagnostic fields remain internal-only
- **Committed in:** `630a187` (part of Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical functionality fix)
**Impact on plan:** The deviation closed a gap between the task instructions and the plan objective. No scope expansion beyond the stated alert-rendering contract.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan `15-03` can build weekly provenance-aware reporting on top of the alert and rendering contract defined here
- Quick-check and digest output guidance now share the same provenance vocabulary (`信源层级`, `原始来源`, `溯源链`) and the same internal-only guardrails

## Self-Check: PASSED

- Summary file exists at `.planning/phases/15-provenance-aware-ranking-delivery/15-02-SUMMARY.md`
- Task commits `97915ef` and `630a187` are present in git history

---
*Phase: 15-provenance-aware-ranking-delivery*
*Completed: 2026-04-03*
