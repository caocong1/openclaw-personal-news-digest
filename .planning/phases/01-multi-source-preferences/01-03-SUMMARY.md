---
phase: 01-multi-source-preferences
plan: 03
subsystem: pipeline
tags: [llm-cache, circuit-breaker, cost-control, tiered-models, budget]

# Dependency graph
requires:
  - phase: 00-mvp-pipeline
    provides: "processing-instructions.md batch processing, budget.json, data-models.md schemas"
provides:
  - "Circuit-breaker enforcement logic (3-state: normal, warning, break)"
  - "LLM result cache pattern with 7-day TTL and URL SHA keys"
  - "Tiered model strategy (fast vs strong) for LLM task routing"
  - "CacheEntry schema for classify-cache and summary-cache"
  - "Initialized empty cache files"
affects: [02-event-tracking, 03-weekly-report]

# Tech tracking
tech-stack:
  added: []
  patterns: ["cache-before-call with atomic write", "circuit-breaker with exemption for essential operations", "tiered model routing by task complexity"]

key-files:
  created:
    - data/cache/classify-cache.json
    - data/cache/summary-cache.json
  modified:
    - references/processing-instructions.md
    - references/data-models.md

key-decisions:
  - "Cache keyed by same URL SHA as dedup-index for consistency across pipeline"
  - "Circuit-breaker uses higher of call ratio and token ratio as effective usage"
  - "Daily digest assembly exempt from circuit-breaker (1 final LLM call allowed)"
  - "Tiered model strategy documented but activation deferred until platform confirms model selection support"

patterns-established:
  - "Cache-before-call: always check cache before LLM invocation, write after"
  - "Circuit-breaker: check budget before each batch, 3 states (normal/warning/break)"
  - "Atomic cache writes: tmp + rename pattern for cache file updates"

requirements-completed: [COST-02, COST-03, COST-04]

# Metrics
duration: 9min
completed: 2026-04-01
---

# Phase 1 Plan 3: LLM Cost Controls Summary

**LLM result caching with URL SHA keys and 7-day TTL, circuit-breaker enforcement at 80% warning / 100% hard stop, and tiered model routing for fast vs strong tasks**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-01T04:28:00Z
- **Completed:** 2026-04-01T04:37:00Z
- **Tasks:** 1
- **Files modified:** 4

## Accomplishments
- Circuit-breaker enforcement with 3-state logic (normal < 80%, warning 80-99%, break at 100%) with daily digest exemption
- LLM result cache with lookup-before-call pattern, 7-day TTL, atomic writes, and cleanup at pipeline start
- Tiered model strategy documenting fast model for structured tasks and strong model for nuanced reasoning
- CacheEntry schema added to data-models.md with classify and summary entry formats
- Budget tracking updated to include cache_hits metric in daily metrics

## Task Commits

Each task was committed atomically:

1. **Task 1: Add LLM cache, circuit-breaker, and tiered model sections** - `df5290f` (feat)

## Files Created/Modified
- `references/processing-instructions.md` - Added Sections 0A (circuit-breaker), 0B (LLM cache), 0C (tiered model); updated budget tracking with cache_hits
- `references/data-models.md` - Added CacheEntry schema with classify and summary cache entry formats
- `data/cache/classify-cache.json` - Initialized empty JSON cache for classification results
- `data/cache/summary-cache.json` - Initialized empty JSON cache for summary results

## Decisions Made
- Cache keyed by same URL SHA as dedup-index (SHA256(normalized_url)[:16]) for consistency across the entire pipeline
- Circuit-breaker uses the higher of call ratio and token ratio as effective_usage, preventing budget overrun on either dimension
- Daily digest assembly is exempt from circuit-breaker to ensure users always receive output even when budget is exhausted
- Tiered model strategy is documented but activation deferred until OpenClaw platform confirms model selection support

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Cache infrastructure ready for implementation when pipeline code processes items
- Circuit-breaker logic documented and ready to be enforced during batch processing
- Plan 01-04 (preference integration) can proceed -- it does not depend on this plan

## Self-Check: PASSED

- [x] references/processing-instructions.md exists
- [x] references/data-models.md exists
- [x] data/cache/classify-cache.json exists
- [x] data/cache/summary-cache.json exists
- [x] Commit df5290f exists

---
*Phase: 01-multi-source-preferences*
*Completed: 2026-04-01*
