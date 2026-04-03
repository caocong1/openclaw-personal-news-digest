---
phase: 13-provenance-core
plan: 01
subsystem: data
tags: [provenance, schema, config, pipeline]
requires:
  - phase: 12-interaction-surface-deployment-ux
    provides: collection-processing pipeline conventions and schema-doc patterns reused by Phase 13
provides:
  - dedicated T1 and T2 provenance rule libraries under config/
  - a first-class provenance stage between collection and processing
  - authoritative provenance persistence contracts under data/provenance/
affects: [13-02-provenance-inference, 13-03-cross-validation, source-discovery]
tech-stack:
  added: []
  patterns: [dedicated provenance rule libraries, file-backed provenance joins by NewsItem.id]
key-files:
  created: [config/t1-sources.json, config/t2-sources.json]
  modified: [SKILL.md, references/data-models.md]
key-decisions:
  - "T1 and T2 provenance matching rules live in dedicated config files instead of config/sources.json."
  - "Authoritative provenance remains outside NewsItem and joins back through NewsItem.id."
patterns-established:
  - "Provenance-stage configuration is additive and separate from collection-source fetch settings."
  - "Phase 13 stores provenance in dedicated data/provenance contracts before downstream ranking or discovery logic."
requirements-completed: [PROV-01, PROV-02, DISC-05, PROV-06]
duration: 11 min
completed: 2026-04-03
---

# Phase 13 Plan 01: Provenance Foundation Summary

**Dedicated T1/T2 provenance rule libraries with a documented provenance stage and file-backed provenance schemas keyed by NewsItem.id**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-03T03:13:00Z
- **Completed:** 2026-04-03T03:24:10Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added dedicated `config/t1-sources.json` and `config/t2-sources.json` libraries so provenance URL matching no longer depends on `config/sources.json`.
- Inserted a first-class `## Provenance Phase` in `SKILL.md` and bootstrapped `data/provenance/` as a required runtime directory.
- Defined authoritative `ProvenanceRecord`, `CitationGraph`, and `TierStats` contracts in `references/data-models.md`, explicitly joined by `NewsItem.id`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add dedicated T1/T2 provenance rule libraries with concrete starter patterns** - `f1ee074` (feat)
2. **Task 2: Add provenance pipeline bootstrap and schema contracts for authoritative persistence** - `b6e437b` (docs)

## Files Created/Modified

- `config/t1-sources.json` - T1 direct-source rule library covering official AI announcements, GitHub releases, arXiv, policy, PR wires, scientific journals, and filings.
- `config/t2-sources.json` - T2 original-report rule library covering AI-focused and general tech media domains.
- `SKILL.md` - Provenance pipeline stage inserted between collection and processing, plus bootstrap support for `data/provenance/`.
- `references/data-models.md` - Authoritative provenance schemas and schema-version registry entries for the new stores.

## Decisions Made

- Keep provenance rule libraries additive and provenance-specific so Phase 14 can expand them without inheriting fetch-management fields.
- Store authoritative provenance outside `NewsItem` and join via `NewsItem.id` to avoid schema churn in the collection/output path.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase `13-02` can now rely on dedicated T1/T2 rule libraries and documented provenance store contracts.
- Citation extraction and provenance prompt work can build on a stable stage boundary between collection and processing.

## Self-Check: PASSED

- Verified `config/t1-sources.json` and `config/t2-sources.json` parse as valid JSON.
- Verified `SKILL.md` contains `## Provenance Phase` and `data/provenance/` bootstrap coverage.
- Verified `references/data-models.md` contains `## ProvenanceRecord`, `## CitationGraph`, and `## TierStats`.
- Verified task commits `f1ee074` and `b6e437b` are present in git history.

---
*Phase: 13-provenance-core*
*Completed: 2026-04-03*
