---
phase: 13-provenance-core
plan: 03
subsystem: data
tags: [provenance, persistence, discrepancy-log, fixtures]
requires:
  - phase: 13-provenance-core
    provides: provenance-stage rules, prompt contract, and sample inputs from 13-01 and 13-02
provides:
  - fixed rule-vs-llm precedence for provenance classification
  - documented discrepancy logging and provenance-store writeback contracts
  - sample stores that reconstruct a direct-to-report-to-aggregator provenance chain
affects: [phase-verification, source-discovery, provenance-aware-ranking]
tech-stack:
  added: []
  patterns: [explicit provenance precedence policy, append-only discrepancy logging, reconstructable file-backed provenance chain]
key-files:
  created: [data/fixtures/provenance-db-sample.json, data/fixtures/citation-graph-sample.json, data/fixtures/provenance-discrepancies-sample.jsonl, data/fixtures/tier-stats-sample.json]
  modified: [references/processing-instructions.md, references/data-models.md]
key-decisions:
  - "T1 classifications keep URL-rule authority, while T0 and T2-T4 classifications defer to the provenance LLM."
  - "Disagreement logs must preserve both candidates and the winning resolver so provenance decisions remain auditable."
patterns-established:
  - "Provenance persistence uses four coordinated stores: provenance DB, citation graph, discrepancy log, and tier stats."
  - "Aggregator cases must be reconstructable from the originating source through each intermediate report."
requirements-completed: [PROV-05, PROV-06]
duration: 5 min
completed: 2026-04-03
---

# Phase 13 Plan 03: Provenance Persistence Summary

**Explicit provenance precedence rules with discrepancy logging and sample stores that reconstruct the OpenAI-to-TechCrunch-to-36Kr chain**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-03T03:32:30Z
- **Completed:** 2026-04-03T03:37:25Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added explicit provenance cross-validation and writeback rules to `references/processing-instructions.md`, including fixed precedence and discrepancy-log shape.
- Expanded `references/data-models.md` so provenance records, tier sources, and the append-only discrepancy log are documented together.
- Added four sample provenance stores that prove chain reconstruction, discrepancy handling, and daily/source tier counters.

## Task Commits

Each task was committed atomically:

1. **Task 1: Encode cross-validation precedence and provenance-store writeback contracts** - `9514cbe` (docs)
2. **Task 2: Add provenance persistence fixtures that prove chain reconstruction and disagreement auditability** - `1d97d00` (feat)

## Files Created/Modified

- `references/processing-instructions.md` - Cross-validation policy and authoritative provenance-store writeback rules.
- `references/data-models.md` - Provenance field notes plus append-only discrepancy-log contract.
- `data/fixtures/provenance-db-sample.json` - Three authoritative provenance records keyed by `NewsItem.id`.
- `data/fixtures/citation-graph-sample.json` - Citation nodes and edges that mirror the sample provenance chain.
- `data/fixtures/provenance-discrepancies-sample.jsonl` - Resolved rule-vs-LLM disagreement record for the 36Kr aggregator case.
- `data/fixtures/tier-stats-sample.json` - Daily and per-source provenance tier counters for the sample set.

## Decisions Made

- Provenance disagreement handling uses a fixed policy rather than case-by-case judgment, so the final tier is reproducible.
- Sample persistence stores intentionally share the same URLs and IDs so auditors can trace a single item across every provenance artifact.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase `13` now has complete provenance contracts, prompt inputs, and persistence fixtures needed for full verification.
- Downstream source-discovery work can reuse the same IDs, URLs, and provenance-chain semantics without redesigning the storage model.

## Self-Check: PASSED

- Verified `references/processing-instructions.md` contains `T1: URL-rule wins`, `T0: LLM wins`, and `T2/T3/T4: LLM wins`.
- Verified the provenance DB, citation graph, and tier stats fixtures parse as valid JSON.
- Verified the discrepancy fixture contains `final_winner` and the shared OpenAI/TechCrunch/36Kr URLs referenced by the provenance DB and citation graph.
- Verified task commits `9514cbe` and `1d97d00` are present in git history.

---
*Phase: 13-provenance-core*
*Completed: 2026-04-03*
