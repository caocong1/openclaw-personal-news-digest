---
phase: 09-noise-floor-classification-quality
plan: 02
subsystem: classification
tags: [llm-prompt, classification, categories, disambiguation, noise-floor]

# Dependency graph
requires: []
provides:
  - "Hardened classify-v2 prompt with low-end calibration, disambiguation rules, and negative examples"
  - "Per-category negative_examples in categories.json for boundary case guidance"
  - "Prompt assembly wiring in processing-instructions.md to inject negative_examples into LLM context"
affects: [classification-pipeline, digest-quality]

# Tech tracking
tech-stack:
  added: []
  patterns: ["negative_examples pattern for category boundary disambiguation"]

key-files:
  created: []
  modified:
    - references/prompts/classify.md
    - config/categories.json
    - references/processing-instructions.md

key-decisions:
  - "Prompt version bumped to classify-v2 to force cache invalidation of all v1 entries"
  - "Negative examples use consistent format: description (-> correct_category) for clear alternative routing"
  - "Disambiguation rules classify by PRIMARY ACTION not subject domain"

patterns-established:
  - "Negative examples pattern: each category includes what does NOT belong with alternative category suggestion"
  - "Borderline Examples table: calibration anchors across the full score range for LLM consistency"

requirements-completed: [CLASS-01, CLASS-02, CLASS-03]

# Metrics
duration: 3min
completed: 2026-04-02
---

# Phase 09 Plan 02: Classification Prompt Hardening Summary

**Classify-v2 prompt with 7 low-end example types, 6 borderline calibration anchors, 9 disambiguation rules, and 36 negative examples across 12 categories**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-02T08:16:15Z
- **Completed:** 2026-04-02T08:18:49Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Expanded 0.0-0.2 importance tier from a single line to 7 concrete example types for better LLM calibration at the noise floor
- Added Borderline Examples table with 6 calibration anchors spanning the full 0.1-0.9 score range
- Added Disambiguation Rules section with 9 rules covering commonly confused category pairs plus a general classification principle
- Added negative_examples (3 per category, 36 total) to categories.json with alternative category suggestions
- Wired negative_examples into prompt assembly step in processing-instructions.md with NOT this category format

## Task Commits

Each task was committed atomically:

1. **Task 1: Harden classify.md prompt and wire negative_examples into prompt assembly** - `73d07fb` (feat)
2. **Task 2: Add negative_examples to all categories in categories.json** - `b7a0202` (feat)

## Files Created/Modified
- `references/prompts/classify.md` - Bumped to classify-v2 with expanded 0.0-0.2 tier, Borderline Examples, Disambiguation Rules, negative_examples guidance
- `config/categories.json` - Added negative_examples array (3 entries each) to all 12 categories
- `references/processing-instructions.md` - Updated Section 1 Step 2 Fill categories to format negative_examples into {categories_list} placeholder

## Decisions Made
- Prompt version bumped to classify-v2 to force cache invalidation -- all previously cached classify-v1 results will miss on next pipeline run
- Negative examples use consistent format with -> arrow pointing to correct alternative category
- Disambiguation rules follow the principle of classifying by PRIMARY ACTION, not subject domain

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Classification prompt is fully hardened for better noise floor detection
- Cache invalidation will force re-classification on next pipeline run
- Ready for plan 03 (if any remaining plans in phase 09)

---
*Phase: 09-noise-floor-classification-quality*
*Completed: 2026-04-02*
