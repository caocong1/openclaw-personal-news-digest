---
phase: 02-smart-processing
plan: 01
subsystem: processing
tags: [dedup, jaccard, bigram, multi-language, llm-prompt, title-similarity]

# Dependency graph
requires:
  - phase: 01-multi-source-preferences
    provides: "Multi-source collection pipeline, data models with dedup_status field"
provides:
  - "dedup.md LLM prompt for batch title near-duplicate judgment"
  - "3-stage title dedup pipeline spec (normalize, Jaccard bigram >= 0.6, LLM judgment)"
  - "Multi-language processing rules (zh/en independent dedup, Chinese summaries for all)"
  - "Updated NewsItem schema with title_dup, event_merged, language detection, _schema_v 3"
  - "SKILL.md wiring: title dedup step in Processing Phase, dedup exclusion in Output Phase"
affects: [02-02-event-merging, 02-03-anti-echo-chamber, 02-04-monitoring]

# Tech tracking
tech-stack:
  added: []
  patterns: ["3-stage funnel (rule normalize, Jaccard bigram, LLM judge)", "per-language independent dedup pipelines", "cross-language prohibition at title level"]

key-files:
  created: [references/prompts/dedup.md]
  modified: [references/processing-instructions.md, references/data-models.md, SKILL.md]

key-decisions:
  - "Jaccard threshold 0.6 with LLM safety net for false positives"
  - "CJK character ratio >50% for language detection (zh vs en)"
  - "Cross-language title comparison prohibited; cross-language merging deferred to event level in Plan 02"

patterns-established:
  - "3-stage dedup funnel: cheap rule filter -> similarity threshold -> expensive LLM judgment"
  - "Per-language independent pipelines for title-level operations"

requirements-completed: [PROC-04, PROC-06]

# Metrics
duration: 3min
completed: 2026-04-01
---

# Phase 2 Plan 01: Title Dedup + Multi-Language Summary

**3-stage title near-duplicate detection pipeline (normalize, Jaccard bigram >= 0.6, LLM judgment) with per-language independent dedup and English source display format**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-01T06:51:03Z
- **Completed:** 2026-04-01T06:53:39Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Created dedup.md LLM prompt template with Chinese instructions, batch title comparison, and JSON output format
- Documented full 3-stage title dedup funnel in processing-instructions.md Section 1A with cross-language prohibition
- Added multi-language processing rules in Section 1B including English item display format with Chinese translation
- Updated NewsItem schema: dedup_status enum expanded to include title_dup and event_merged, schema bumped to v3
- Wired title dedup into SKILL.md Processing Phase (step 8) and excluded duplicates from Output Phase scoring

## Task Commits

Each task was committed atomically:

1. **Task 1: Create dedup prompt and add title dedup + multi-language sections** - `8502b92` (feat)
2. **Task 2: Wire title dedup into SKILL.md Processing Phase** - `6f83be5` (feat)

## Files Created/Modified
- `references/prompts/dedup.md` - LLM prompt for batch title near-duplicate judgment with Chinese instructions
- `references/processing-instructions.md` - Added Section 1A (3-stage title dedup funnel) and Section 1B (multi-language processing rules)
- `references/data-models.md` - Expanded dedup_status enum, bumped _schema_v to 3, added language field notes and defaults
- `SKILL.md` - Added title dedup step 8 in Processing Phase, excluded dedup items from Output Phase scoring (779/800 words)

## Decisions Made
- Jaccard threshold set at 0.6 per design doc, with LLM Stage C as safety net for false positives
- Language detection uses CJK character ratio (>50% CJK = zh, otherwise en) -- simple and reliable for the two target languages
- Cross-language title comparison explicitly prohibited at Stage B; cross-language merging deferred to event level (Plan 02)
- Efficiency constraint: only compare items sharing same primary category OR same source_id to avoid O(n^2) comparisons

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Title dedup pipeline fully specified, ready for event merging (Plan 02) to build on top
- data-models.md already includes event_merged status for Plan 02
- Cross-language event merging explicitly deferred and documented as Plan 02 scope

## Self-Check: PASSED

All files exist. All commits verified.

---
*Phase: 02-smart-processing*
*Completed: 2026-04-01*
