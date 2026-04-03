---
phase: 13-provenance-core
plan: 02
subsystem: data
tags: [provenance, citations, prompt, fixtures]
requires:
  - phase: 13-provenance-core
    provides: dedicated T1/T2 rule libraries and provenance-store contracts from 13-01
provides:
  - deterministic provenance-stage rules for URL matching and citation extraction
  - structured provenance prompt contract for unresolved items
  - sample provenance inputs covering direct, report, and aggregator cases
affects: [13-03-cross-validation, provenance-verification, source-discovery]
tech-stack:
  added: []
  patterns: [deterministic citation extraction before LLM provenance, provenance fixtures mapped to chain examples]
key-files:
  created: [references/prompts/provenance-classify.md, data/fixtures/news-items-provenance-sample.jsonl]
  modified: [references/collection-instructions.md, references/processing-instructions.md]
key-decisions:
  - "Deterministic citation extraction runs before provenance LLM classification and feeds cited_sources into the prompt."
  - "Only items with null or low-confidence rule matches enter provenance batching, preserving existing budget controls."
patterns-established:
  - "Collection preserves upstream URLs inside content_snippet instead of reconstructing them later."
  - "Provenance prompt inputs are backed by representative direct-source, report, and aggregator fixtures."
requirements-completed: [PROV-03, PROV-04]
duration: 8 min
completed: 2026-04-03
---

# Phase 13 Plan 02: Provenance Inference Summary

**Deterministic citation extraction and a batch-safe provenance prompt contract with fixtures for direct, report, and aggregator coverage**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-03T03:24:30Z
- **Completed:** 2026-04-03T03:32:24Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added a dedicated provenance-stage section to `references/processing-instructions.md` covering URL-rule pre-classification, citation graph extension, and unresolved-item batching.
- Tightened `references/collection-instructions.md` so `content_snippet` preserves upstream link targets as stable provenance input.
- Added `references/prompts/provenance-classify.md` and `data/fixtures/news-items-provenance-sample.jsonl` to exercise direct-source, original-report, and aggregator provenance paths.

## Task Commits

Each task was committed atomically:

1. **Task 1: Document URL-rule matching, citation extraction, and unresolved-item batching in the provenance stage** - `bb6d27a` (docs)
2. **Task 2: Add the provenance prompt contract and representative provenance input fixtures** - `4541bd5` (feat)

## Files Created/Modified

- `references/collection-instructions.md` - Collection guarantees now preserve upstream link targets in `content_snippet`.
- `references/processing-instructions.md` - Provenance-stage rules document deterministic URL matching, citation extraction, and unresolved-item batching before the standard classify/summarize flow.
- `references/prompts/provenance-classify.md` - Batch provenance prompt contract with explicit tier, source, citation, hop-count, confidence, and reasoning outputs.
- `data/fixtures/news-items-provenance-sample.jsonl` - Three sample items for official-source, report, and aggregator provenance scenarios.

## Decisions Made

- Provenance LLM calls consume pre-extracted citation evidence instead of rediscovering sources from scratch.
- The provenance stage reuses the repo's existing retry and budget controls rather than introducing a separate cost path.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase `13-03` can now define cross-validation and persistence fixtures against a stable prompt contract and representative sample inputs.
- The wave 2 key-links verify cleanly: collection preserves upstream evidence, and processing now routes unresolved items into the provenance prompt.

## Self-Check: PASSED

- Verified `references/processing-instructions.md` contains `URL Rule Pre-classification`, `Citation Graph Extension`, and `Provenance Classification Batch`.
- Verified `references/prompts/provenance-classify.md` exposes `original_source_url`, `cited_sources`, `propagation_hops`, and `confidence`.
- Verified `data/fixtures/news-items-provenance-sample.jsonl` parses as JSONL and contains the OpenAI Blog, TechCrunch, and 36Kr provenance cases.
- Verified task commits `bb6d27a` and `4541bd5` are present in git history.

---
*Phase: 13-provenance-core*
*Completed: 2026-04-03*
