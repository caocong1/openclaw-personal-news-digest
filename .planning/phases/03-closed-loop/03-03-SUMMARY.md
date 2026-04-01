---
phase: 03-closed-loop
plan: 03
subsystem: output
tags: [weekly-report, cross-domain-synthesis, strong-model, cron, trend-analysis]

# Dependency graph
requires:
  - phase: 03-01
    provides: depth_preference and judgment_angles for weekly summary depth and perspective emphasis
  - phase: 03-02
    provides: source auto-demotion status for source health summary section
provides:
  - Weekly report template with 6 sections (Overview, Events, Trends, Source Health, Cross-Domain, Stats)
  - LLM prompt for cross-domain synthesis using strong model tier
  - Weekly report generation procedure with pre-filtering and weekly quota
  - Weekly report cron job (Sunday 20:00 CST)
  - SKILL.md Output Phase weekly report routing
affects: [output-delivery, cron-scheduling]

# Tech tracking
tech-stack:
  added: []
  patterns: [weekly-aggregation-with-prefiltering, weekly-quota-40-20-20-20, strong-model-for-synthesis]

key-files:
  created: [references/prompts/weekly-report.md]
  modified: [references/output-templates.md, references/processing-instructions.md, references/cron-configs.md, SKILL.md]

key-decisions:
  - "Weekly quota 40/20/20/20 vs daily 50/20/15/15 for broader exploration in weekly context"
  - "Pre-filter to digest-selected items (quota_group set) then cap at 150 to prevent LLM context overflow"
  - "Strong model tier for One Week Overview and Cross-Domain Connections sections"

patterns-established:
  - "Weekly aggregation: collect 7 days of JSONL + metrics + events, pre-filter before LLM call"
  - "Distinct cron message text enables agent routing without explicit type field"

requirements-completed: [OUT-03]

# Metrics
duration: 2min
completed: 2026-04-01
---

# Phase 3 Plan 03: Weekly Report Summary

**Weekly trend report with cross-domain synthesis using strong model, 40/20/20/20 quota, and Sunday 20:00 cron**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-01T07:41:20Z
- **Completed:** 2026-04-01T07:43:42Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Weekly report template covering 6 sections: One Week Overview, Key Events & Timelines, Category Trends, Source Health Summary, Cross-Domain Connections, and stats footer
- LLM synthesis prompt using strong model tier with depth_preference and judgment_angles integration
- Generation procedure with 7-day data aggregation, pre-filtering to avoid context overflow, weekly quota ratios, and 5-category minimum
- Weekly report cron job firing Sunday 20:00 CST with SKILL.md routing

## Task Commits

Each task was committed atomically:

1. **Task 1: Create weekly report template, LLM prompt, and generation procedure** - `43330d2` (feat)
2. **Task 2: Add weekly report cron job and wire into SKILL.md** - `331af1e` (feat)

## Files Created/Modified
- `references/output-templates.md` - Added Weekly Report Template (OUT-03) section with 6-section template and quality rules
- `references/prompts/weekly-report.md` - New LLM prompt for weekly cross-domain synthesis
- `references/processing-instructions.md` - Added Section 7: Weekly Report Generation with data collection, pre-filtering, weekly quota, LLM synthesis, and assembly steps
- `references/cron-configs.md` - Added weekly report cron job (Sunday 20:00 CST, 10-min timeout) and updated setup order
- `SKILL.md` - Added Output Phase step 4b for weekly report routing

## Decisions Made
- Weekly quota uses 40/20/20/20 ratios (vs daily 50/20/15/15) to provide broader exploration and hotspot coverage in the weekly context
- Pre-filtering uses only items that were selected for daily digests (have quota_group set), then caps at 150 items to prevent LLM context overflow on 7-day aggregation
- Strong model tier used for "One Week Overview" and "Cross-Domain Connections" sections per COST-04

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Weekly report infrastructure complete, ready for 03-04 (remaining closed-loop items)
- The weekly report cron job needs to be registered on OpenClaw platform (step 7 in recommended setup order)

---
## Self-Check: PASSED

*Phase: 03-closed-loop*
*Completed: 2026-04-01*
