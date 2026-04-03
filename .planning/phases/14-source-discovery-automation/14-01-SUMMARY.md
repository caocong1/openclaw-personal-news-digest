---
phase: 14-source-discovery-automation
plan: 01
subsystem: provenance
tags: [discovery, domain-normalization, rolling-metrics, t1-ratio, decision-history, fixtures]

# Dependency graph
requires:
  - phase: 13-provenance-core
    provides: ProvenanceRecord schema, provenance-db.json, t1/t2 rule libraries, tier-stats
provides:
  - DiscoveredSourcesState schema in data-models.md
  - Source Discovery Phase in SKILL.md pipeline ordering
  - Section 0G Source Discovery Accumulation in processing-instructions.md
  - discovered-sources-sample.json fixture with 3 domain records
affects: [14-02-PLAN, 14-03-PLAN, source-discovery-automation]

# Tech tracking
tech-stack:
  added: []
  patterns: [domain-level-identity-with-path-evidence, rolling-window-metrics, append-only-decision-history]

key-files:
  created:
    - data/fixtures/discovered-sources-sample.json
  modified:
    - references/data-models.md
    - references/processing-instructions.md
    - SKILL.md

key-decisions:
  - "Discovery state stored at data/provenance/discovered-sources.json, kept separate from config/sources.json"
  - "Domain-level identity for counting with representative URLs preserved for path-sensitive rule-library expansion"
  - "Source Discovery Phase positioned between Processing Phase and Output Phase in pipeline ordering"
  - "Section 0G placed after provenance persistence (0F) and before batch LLM processing (Section 1)"

patterns-established:
  - "Domain normalization: strip scheme, www., lowercase, group to registrable root domain"
  - "Rolling-window metrics: hit_count_7d, t1_count_7d, t2_count_7d with t1_ratio = t1_count_7d / max(hit_count_7d, 1)"
  - "Decision history: append-only array with ts, decision, reason, details"

requirements-completed: [DISC-01]

# Metrics
duration: 3min
completed: 2026-04-03
---

# Phase 14 Plan 01: Discovery Foundation Summary

**Domain-normalized discovery-state schema with rolling T1/T2 metrics, representative path evidence, and fixture-backed accumulation contract**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-03T04:19:48Z
- **Completed:** 2026-04-03T04:22:49Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Defined the authoritative DiscoveredSourcesState schema in data-models.md with full field documentation, normalization rules, and defaults
- Created discovered-sources-sample.json fixture with 3 records (openai.com T1, techcrunch.com T2, github.com T1) proving domain identity plus path evidence coexistence
- Added Source Discovery Phase to SKILL.md pipeline ordering between Processing and Output phases
- Added Section 0G Source Discovery Accumulation to processing-instructions.md with full accumulation sequence, rolling-window rules, and persistence contract

## Task Commits

Each task was committed atomically:

1. **Task 1: Add discovered-source state schema and accumulation fixture** - `f656752` (feat)
2. **Task 2: Add pipeline-stage and accumulation rules for source discovery** - `c679b36` (feat)

## Files Created/Modified
- `references/data-models.md` - Added DiscoveredSourcesState section with full schema, field notes, normalization rules, and defaults
- `data/fixtures/discovered-sources-sample.json` - Three-record fixture proving domain-level identity with representative URLs and decision history
- `SKILL.md` - Added Source Discovery Phase section with 6 pipeline responsibilities
- `references/processing-instructions.md` - Added Section 0G with accumulation sequence, rolling-window rules, and persistence contract

## Decisions Made
- Discovery state is stored at `data/provenance/discovered-sources.json`, explicitly separate from `config/sources.json` (the live source inventory)
- Domain-level identity is used for counting but representative URLs are preserved for path-sensitive rule-library expansion
- Source Discovery Phase runs after Processing Phase and before Output Phase in pipeline ordering
- Section 0G is positioned after provenance persistence (0F) and before batch LLM processing (Section 1) in processing-instructions.md
- Decision history uses append-only array with machine-readable reason strings (observed, deferred, enabled, disabled, rejected)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Discovery state schema and accumulation contract are ready for Plan 14-02 to add auto-enable/auto-disable thresholds
- The fixture provides concrete examples that Plan 14-02 can extend with enabled/disabled/rejected decision history entries
- The accumulation sequence in Section 0G provides the upstream contract that enable/disable evaluation will consume

## Self-Check: PASSED

- FOUND: references/data-models.md
- FOUND: data/fixtures/discovered-sources-sample.json
- FOUND: SKILL.md
- FOUND: references/processing-instructions.md
- FOUND: f656752 (Task 1 commit)
- FOUND: c679b36 (Task 2 commit)

---
*Phase: 14-source-discovery-automation*
*Completed: 2026-04-03*
