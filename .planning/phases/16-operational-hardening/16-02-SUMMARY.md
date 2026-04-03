---
phase: 16-operational-hardening
plan: "02"
subsystem: pipeline
tags: [roundup-atomization, data-models, pattern-matching, pipeline-hardening]

# Dependency graph
requires:
  - phase: 16-01
    provides: heredoc Python extraction pattern, pipeline_state enum in DailyMetrics
provides:
  - NewsItem schema v6 with is_roundup and roundup_children fields
  - config/roundup-patterns.json with 11 fast-path detection patterns
  - Roundup Classification directive in LLM classify prompt
  - Collection Phase step 7b atomization wiring
  - Output Phase PIPE-03 confirmation before quota allocation
affects: [16-03, 16-04]

# Tech tracking
tech-stack:
  added: [config/roundup-patterns.json]
  patterns:
    - Fast-path pattern matching as default, LLM classify as fallback
    - Parent roundup preserved in JSONL for audit, excluded from scoring via digest_eligible:false
    - Child items inherit source metadata and carry parent_roundup_id for traceability

key-files:
  created:
    - config/roundup-patterns.json
  modified:
    - references/data-models.md
    - references/prompts/classify.md
    - SKILL.md

key-decisions:
  - "is_roundup null means unevaluated (pre-Phase 16), false means confirmed not-a-roundup, true means atomize and exclude"
  - "Parent roundup item stays in JSONL for audit trail, child items carry parent_roundup_id"
  - "Fast-path pattern match is the default detection; LLM classify in Processing Phase is the fallback"
  - "Output Phase excludes is_roundup:true items as a safety double-check (already excluded via digest_eligible:false)"
  - "PIPE-03 (one representative per merged event) is explicitly confirmed in Output Phase step 1"

patterns-established:
  - "Roundup atomization pattern: fast-path regex -> mark is_roundup -> write children -> set digest_eligible:false -> double-exclude in scoring"

requirements-completed: [HARD-02]

# Metrics
duration: 3min
completed: 2026-04-03
---

# Phase 16 Plan 02: Roundup Atomization and PIPE-03 Confirmation Summary

**Roundup items are atomized into child items before scoring via fast-path pattern detection, parent is excluded from output, and PIPE-03 one-representative-per-event is explicitly confirmed before quota allocation**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-03T14:04:50Z
- **Completed:** 2026-04-03T14:07:59Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments

- NewsItem schema v6 adds `is_roundup: boolean | null` and `roundup_children: string[]` fields with full semantics documented
- Fast-path roundup detection via `config/roundup-patterns.json` (11 regex patterns, priorities 1-4)
- Roundup Classification section added to LLM classify prompt, enabling fallback confirmation
- Collection Phase step 7b wires atomization into the pipeline, writing child items to JSONL with parent_roundup_id
- Output Phase step 1 explicitly excludes `is_roundup: true` items and confirms PIPE-03 before quota allocation

## Task Commits

Each task was committed atomically:

1. **Task 1: Add is_roundup and roundup_children fields to NewsItem schema** - `81fe9df` (feat)
2. **Task 2: Add roundup detection pattern library and classify.md directive** - `975a704` (feat)
3. **Task 3: Wire roundup atomization into SKILL.md Collection Phase and Output Phase** - `cb64803` (feat)

## Files Created/Modified

- `references/data-models.md` - NewsItem schema v6 with is_roundup/roundup_children fields, updated Schema Version Registry and Field Migration Table
- `config/roundup-patterns.json` - 11 regex patterns for fast-path roundup detection (Top N, Best N, weekly roundup, monthly digest, N articles/links, highlights, curated lists, etc.)
- `references/prompts/classify.md` - Roundup Classification section documenting is_roundup true/false/null semantics and roundup_children guidance for LLM
- `SKILL.md` - Collection Phase step 7b (Atomize roundups) and Output Phase step 1 (exclude is_roundup:true, confirm PIPE-03)

## Decisions Made

- `is_roundup` uses three-state semantics: `null` = unevaluated (backward compat), `false` = confirmed not-a-roundup, `true` = atomize and exclude
- Parent roundup stays in JSONL for audit while child items inherit source metadata and carry `parent_roundup_id`
- Fast-path pattern matching is the default; LLM classify (Processing Phase step 2) is the fallback that confirms or overrides
- Output Phase double-checks `is_roundup: true` exclusion from scoring pool as a safety measure
- PIPE-03 is explicitly confirmed in SKILL.md Output Phase step 1 with documentation that representative selection runs before quota allocation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

- HARD-02 complete: roundup atomization fully wired into Collection Phase, fast-path + LLM fallback implemented
- PIPE-03 explicitly confirmed in SKILL.md Output Phase
- All 4 files modified cleanly; no breaking changes to existing schema or pipeline flow
- Ready for Phase 16 Plan 03 (OPER-01/02/03/04 requirements)

---
*Phase: 16-operational-hardening*
*Completed: 2026-04-03*
