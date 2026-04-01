---
phase: 00-mvp-pipeline
plan: 02
subsystem: pipeline-references
tags: [llm-prompts, rss-collection, url-normalization, dedup, batch-processing, error-handling, breakpoint-resume, quality-gate]

# Dependency graph
requires:
  - phase: 00-mvp-pipeline/01
    provides: Directory structure, SKILL.md, config files (categories.json, budget.json), data-models.md, scoring-formula.md, output-templates.md
provides:
  - LLM classification prompt template (12 categories, importance scoring, JSON output)
  - LLM summarization prompt template (2-3 sentence Chinese summaries, JSON output)
  - RSS collection procedure (web_fetch + feedparser fallback, URL normalization, link-level dedup)
  - Batch processing instructions (5-10 items/call, error handling matrix, breakpoint resume)
  - Output generation instructions (quality gate, section assignment, digest assembly)
  - Dedup-index rebuild shell script for recovery/maintenance
  - Initialized empty dedup-index.json
affects: [00-03]

# Tech tracking
tech-stack:
  added: []
  patterns: [batch-llm-processing, breakpoint-resume, quality-gate-output, url-normalization-pipeline]

key-files:
  created:
    - references/prompts/classify.md
    - references/prompts/summarize.md
    - references/collection-instructions.md
    - references/processing-instructions.md
    - scripts/dedup-index-rebuild.sh
    - data/news/dedup-index.json
  modified: []

key-decisions:
  - "classify.md lists all 12 category IDs inline (not just referencing categories.json) so the LLM has full context without extra file reads"
  - "summarize.md includes quality criteria (concrete facts required, avoid generic phrases) to improve LLM output consistency"

patterns-established:
  - "Batch LLM processing: group 5-10 items per call, classify and summarize as separate steps"
  - "Error handling matrix: 4 failure types with specific recovery actions and status transitions"
  - "Breakpoint resume: scan processing_status to determine which step is needed per item"
  - "Quality gate: 0/1-2/3-14/15+ item thresholds determine output format"

requirements-completed: [SRC-01, PROC-01, PROC-02, PROC-03, PROC-05, PROC-07, PROC-08, OUT-01, OUT-05]

# Metrics
duration: 3min
completed: 2026-04-01
---

# Phase 0 Plan 02: Pipeline Reference Documents Summary

**LLM prompt templates for classification and summarization, RSS collection with URL normalization and dedup, batch processing with error handling and breakpoint resume, output generation with quality gates**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-01T02:52:24Z
- **Completed:** 2026-04-01T02:55:59Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created classification prompt template with all 12 categories inline, importance score reference scale, and strict JSON array output format
- Created summarization prompt template with quality criteria (concrete facts, no generic phrases) and Chinese summary requirements
- Wrote comprehensive collection instructions covering RSS fetch (web_fetch text mode + feedparser fallback), 6-step URL normalization, link-level dedup against dedup-index.json, and JSONL atomic write format
- Wrote processing instructions covering batch LLM processing, 4-type error handling matrix, breakpoint resume for raw/partial items, output generation with quality gate (4 thresholds), and budget tracking integration
- Created dedup-index rebuild shell script for recovery/maintenance, verified working with empty data

## Task Commits

Each task was committed atomically:

1. **Task 1: Create LLM prompt templates and collection instructions** - `424076d` (feat)
2. **Task 2: Create processing instructions and dedup-index rebuild script** - `ce5c556` (feat)

## Files Created/Modified
- `references/prompts/classify.md` - Classification prompt template with 12 categories, importance scoring, JSON output format
- `references/prompts/summarize.md` - Summarization prompt template for 2-3 sentence Chinese summaries with quality criteria
- `references/collection-instructions.md` - RSS collection procedure: web_fetch + fallback, URL normalization (6 rules + SHA256), link-level dedup, JSONL write format
- `references/processing-instructions.md` - Batch LLM processing, error handling matrix (4 types), breakpoint resume, output generation with quality gate, budget tracking
- `scripts/dedup-index-rebuild.sh` - Shell script to rebuild dedup-index from last 7 days of JSONL files
- `data/news/dedup-index.json` - Initialized empty JSON object for URL-based dedup tracking

## Decisions Made
- classify.md lists all 12 category IDs inline with descriptions (not just referencing categories.json) so the LLM has full context without requiring extra file reads during classification
- summarize.md includes explicit quality criteria (require concrete facts, avoid generic phrases like "attracted attention") to improve LLM output consistency beyond the basic format requirements

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All pipeline reference documents are in place for Plan 03 (cron jobs, platform verification, integration testing)
- SKILL.md's Collection Phase references `references/collection-instructions.md` patterns (web_fetch, URL normalization, dedup-index)
- SKILL.md's Processing Phase references `references/prompts/classify.md` and `references/prompts/summarize.md` which now exist
- Processing instructions reference `references/scoring-formula.md` and `references/output-templates.md` (created in Plan 01) for output generation
- dedup-index-rebuild.sh provides a recovery path for index corruption scenarios

## Self-Check: PASSED

All 6 created files verified present. Both task commits (424076d, ce5c556) verified in git log.

---
*Phase: 00-mvp-pipeline*
*Completed: 2026-04-01*
