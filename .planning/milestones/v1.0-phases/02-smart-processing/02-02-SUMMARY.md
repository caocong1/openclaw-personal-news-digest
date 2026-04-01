---
phase: 02-smart-processing
plan: 02
subsystem: processing
tags: [event-tracking, event-merging, timeline, lifecycle, scoring, llm-prompt]

# Dependency graph
requires:
  - phase: 02-01
    provides: "Title dedup pipeline (Section 1A/1B), dedup.md prompt, language detection"
provides:
  - "merge-event.md LLM prompt for event merge/new decisions"
  - "Event schema with timeline array and lifecycle states"
  - "Event merging 3-step funnel (topic filter, keyword match, LLM judgment)"
  - "Event lifecycle management (active -> stable -> archived)"
  - "event_boost scoring dimension activated (was hardcoded 0)"
  - "Event Tracking output section with timeline bullet-list format"
affects: [02-03, 02-04, output-generation, scoring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "3-step event merging funnel: topic pre-filter -> keyword quick match -> LLM precise merge"
    - "Event lifecycle state machine: active (3d) -> stable (7d) -> archived"
    - "Cross-language event merging (unlike title dedup which is per-language only)"
    - "Selective re-summarization: only for update/correction/reversal relations, not analysis"

key-files:
  created:
    - references/prompts/merge-event.md
  modified:
    - references/data-models.md
    - references/processing-instructions.md
    - references/scoring-formula.md
    - references/output-templates.md
    - SKILL.md

key-decisions:
  - "Event re-summarization skipped for analysis relation type to save LLM budget"
  - "Cross-language event merging enabled (Chinese and English reports of same event can merge)"
  - "event_boost = 0.5 threshold requires both active status and importance >= 0.7"

patterns-established:
  - "Event merging funnel: progressive narrowing from topic -> keyword -> LLM to minimize calls"
  - "Lifecycle transitions run before merging to keep candidate pool manageable"
  - "Timeline entries tagged with 5 relation types for narrative context"

requirements-completed: [EVT-01, EVT-02, EVT-03, EVT-04, EVT-05]

# Metrics
duration: 3min
completed: 2026-04-01
---

# Phase 2 Plan 02: Event Tracking Summary

**Event merging 3-step funnel with lifecycle management, timeline tracking, and event_boost scoring activation**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-01T06:57:10Z
- **Completed:** 2026-04-01T07:00:35Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created merge-event.md LLM prompt with merge/new actions and 5 relation types (initial/update/correction/analysis/reversal)
- Documented 3-step event merging funnel in processing-instructions.md (topic pre-filter -> keyword quick match -> LLM precise merge)
- Added Event schema to data-models.md with timeline array, lifecycle states, and keyword matching support
- Documented event lifecycle management (active -> stable after 3d -> archived after 7d with archive file storage)
- Activated event_boost scoring dimension (0.5 for active high-importance events, effective max now 1.00)
- Added Event Tracking timeline bullet-list output format to output-templates.md
- Wired event lifecycle and merge steps into SKILL.md Processing Phase, Event Tracking into Output Phase (847/850 words)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create merge-event prompt, add Event schema, and document event merging + lifecycle** - `6f28e49` (feat)
2. **Task 2: Activate event_boost in scoring, add Event Tracking output, wire SKILL.md** - `0abe17d` (feat)

## Files Created/Modified
- `references/prompts/merge-event.md` - LLM prompt for event merge/new decision with relation types
- `references/data-models.md` - Added Event schema with timeline array, lifecycle states, keywords
- `references/processing-instructions.md` - Added Section 1C (event merging 3-step funnel) and Section 1D (event lifecycle management)
- `references/scoring-formula.md` - Activated event_boost (0.5 conditional) and updated Phase Activation Status to Phase 2
- `references/output-templates.md` - Activated Event Tracking section with timeline bullet-list format
- `SKILL.md` - Added event lifecycle + merge steps in Processing Phase, Event Tracking in Output Phase

## Decisions Made
- Event re-summarization skipped for "analysis" relation type (opinion/interpretation, not new facts) to conserve LLM budget per EVT-04
- Cross-language event merging explicitly enabled -- unlike title dedup, the LLM handles Chinese and English titles together for merge decisions
- event_boost requires both active status AND importance >= 0.7 (not just event linkage) to avoid boosting low-signal events

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Event merging and lifecycle infrastructure fully documented
- event_boost scoring active, completing all 7 scoring dimensions
- Ready for Plan 02-03 (anti-echo-chamber quota system) which builds on the scoring and output changes
- data/events/active.json exists (empty array) and is ready for pipeline use

---
*Phase: 02-smart-processing*
*Completed: 2026-04-01*
