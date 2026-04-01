---
phase: 00-mvp-pipeline
plan: 01
subsystem: framework
tags: [openclaw-skill, json-schema, rss, scoring, data-models]

# Dependency graph
requires:
  - phase: none
    provides: first plan in project
provides:
  - Complete directory tree (config/, references/, data/, output/)
  - SKILL.md orchestration entry point (< 500 words)
  - NewsItem, Source, DedupIndex, DailyMetrics JSON schemas with _schema_v versioning
  - 7-dimension scoring formula with MVP simplification
  - Daily digest output template with quality rules
  - Cold-start preferences (all topic_weights 0.5, exploration_appetite 0.3)
  - 12-category taxonomy with adjacent category mappings
  - LLM budget tracking config (500 calls/day, 1M tokens/day)
affects: [00-02, 00-03]

# Tech tracking
tech-stack:
  added: []
  patterns: [modular-skill-md, atomic-writes, schema-versioning, file-lock-mutual-exclusion]

key-files:
  created:
    - SKILL.md
    - config/sources.json
    - config/preferences.json
    - config/categories.json
    - config/budget.json
    - references/data-models.md
    - references/scoring-formula.md
    - references/output-templates.md
    - data/events/active.json
    - data/feedback/log.jsonl
  modified: []

key-decisions:
  - "SKILL.md kept to 499 words -- well under 3000 token budget, leaving room for future additions"
  - "Category adjacency mappings defined for anti-echo-chamber quota calculations in Phase 2"

patterns-established:
  - "Modular SKILL.md: orchestration only, detailed specs in references/ loaded on demand"
  - "Atomic writes: all data files written via .tmp.{run_id} then rename"
  - "Schema versioning: _schema_v field on all JSON records with missing-field defaults"
  - "File lock mutual exclusion: acquire-or-skip with 15 min expiry"

requirements-completed: [FRMW-01, FRMW-02, FRMW-03, FRMW-04, FRMW-05, FRMW-06, PREF-02, COST-01]

# Metrics
duration: 4min
completed: 2026-04-01
---

# Phase 0 Plan 01: Scaffold & SKILL.md Summary

**Directory structure, config files, data model references, scoring formula, output templates, and SKILL.md orchestration framework with Standing Orders**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-01T02:45:29Z
- **Completed:** 2026-04-01T02:49:12Z
- **Tasks:** 2
- **Files modified:** 14

## Accomplishments
- Scaffolded complete directory tree matching design doc structure (config/, references/, data/news|events|feedback|cache|metrics/, output/)
- Created all 4 config files with exact schemas: sources.json (36Kr RSS), preferences.json (cold-start with all weights 0.5), categories.json (12 categories with adjacency), budget.json (500/1M limits)
- Created 3 reference documents: data-models.md (4 schemas with versioning), scoring-formula.md (7-dim formula with MVP simplification), output-templates.md (daily digest + quality rules + kuaixun)
- Wrote SKILL.md orchestration framework (499 words) with 6 sections including Standing Orders matching design doc Section 3.4

## Task Commits

Each task was committed atomically:

1. **Task 1: Create directory structure, config files, and data model references** - `7fb196f` (feat)
2. **Task 2: Write SKILL.md with modular orchestration, Standing Orders, and operational patterns** - `30abb19` (feat)

## Files Created/Modified
- `SKILL.md` - Orchestration entry point with Collection/Processing/Output phases, Standing Orders, Operational Rules
- `config/sources.json` - Single RSS source definition (36Kr) with complete stats schema
- `config/preferences.json` - Cold-start preferences (12 topic_weights at 0.5, exploration_appetite 0.3)
- `config/categories.json` - 12 top-level categories with adjacent field mappings
- `config/budget.json` - LLM budget tracking (500 calls/day, 1M tokens/day)
- `references/data-models.md` - NewsItem, Source, DedupIndex, DailyMetrics JSON schemas with _schema_v versioning rules
- `references/scoring-formula.md` - Full 7-dimension scoring formula with MVP simplification (feedback_boost=0, event_boost=0)
- `references/output-templates.md` - Daily digest template with quality rules (shorten on low content, skip on empty) plus kuaixun template
- `data/events/active.json` - Empty array for MVP
- `data/feedback/log.jsonl` - Empty file for MVP
- `data/news/.gitkeep`, `data/cache/.gitkeep`, `data/metrics/.gitkeep`, `output/.gitkeep` - Directory placeholders

## Decisions Made
- SKILL.md kept to 499 words -- well under the 3000 token budget, intentionally leaving headroom for future additions without needing restructuring
- Category adjacency mappings were defined proactively (e.g., ai-models adjacent to dev-tools, science, open-source) to support anti-echo-chamber quota calculations in Phase 2

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Directory structure and all config/reference files are in place for Plan 02 (LLM prompts, RSS collection, processing instructions)
- SKILL.md references `references/prompts/classify.md` and `references/prompts/summarize.md` which will be created in Plan 02
- Data schemas are defined and ready for Plan 02's processing pipeline implementation

## Self-Check: PASSED

All 14 created files verified present. Both task commits (7fb196f, 30abb19) verified in git log.

---
*Phase: 00-mvp-pipeline*
*Completed: 2026-04-01*
