---
gsd_state_version: 1.0
milestone: v2.0
milestone_name: Quality & Robustness
status: verifying
stopped_at: Completed 12-03-PLAN.md
last_updated: "2026-04-02T17:43:37.126Z"
last_activity: 2026-04-02
progress:
  total_phases: 6
  completed_phases: 6
  total_plans: 16
  completed_plans: 16
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-31)

**Core value:** Replace "pushing messages to user" with "continuously observing the world on behalf of the user" -- deep personalization with anti-echo-chamber awareness
**Current focus:** Phase 12 — interaction-surface-deployment-ux

## Current Position

Phase: 12 (interaction-surface-deployment-ux) — VERIFYING
Plan: 3 of 3
Status: Phase complete — ready for verification
Last activity: 2026-04-03

Progress: [██████████] 100%

## Performance Metrics

**Velocity:**

- Total plans completed: 10
- Average duration: 6.5 min
- Total execution time: 1.03 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 0. MVP Pipeline | 3/3 | 10 min | 3.3 min |
| 1. Multi-Source + Preferences | 4/4 | 46 min | 11.5 min |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
| Phase 00 P02 | 3min | 2 tasks | 6 files |
| Phase 00 P03 | 4min | 2 tasks | 4 files |
| Phase 01 P02 | 9min | 2 tasks | 3 files |
| Phase 01 P03 | 9min | 1 tasks | 4 files |
| Phase 01 P01 | 23min | 2 tasks | 6 files |
| Phase 01 P04 | 5min | 2 tasks | 3 files |
| Phase 02 P01 | 3min | 2 tasks | 4 files |
| Phase 02 P04 | 3min | 2 tasks | 4 files |
| Phase 02 P02 | 3min | 2 tasks | 6 files |
| Phase 02 P03 | 3min | 2 tasks | 4 files |
| Phase 03 P02 | 3min | 2 tasks | 4 files |
| Phase 03 P01 | 3min | 2 tasks | 5 files |
| Phase 03 P03 | 2min | 2 tasks | 5 files |
| Phase 03 P04 | 4min | 2 tasks | 3 files |
| Phase 04 P01 | 2min | 2 tasks | 5 files |
| Phase 09 P02 | 3min | 2 tasks | 3 files |
| Phase 09 P01 | 3min | 2 tasks | 4 files |
| Phase 09 P03 | 2min | 2 tasks | 4 files |
| Phase 10 P02 | 2min | 2 tasks | 5 files |
| Phase 10 P03 | 2min | 2 tasks | 6 files |
| Phase 11 P02 | 3min | 2 tasks | 4 files |
| Phase 11 P01 | 2min | 2 tasks | 3 files |
| Phase 11 P03 | 3 | 2 tasks | 3 files |
| Phase 12 P01 | 5min | 2 tasks | 5 files |
| Phase 12 P02 | 12m11s | 2 tasks | 8 files |
| Phase 12 P03 | 5 min | 2 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- SKILL.md modular split (< 3000 tokens), detailed specs in references/
- File lock: acquire-or-skip, 15 min expiry
- Phase 0 merged into single stage (was 0A/0B/0C)
- 5-layer preference model for Phase 0-2, expand to 7 in Phase 3
- classify.md lists all 12 category IDs inline so LLM has full context without extra file reads
- summarize.md includes explicit quality criteria to improve LLM output consistency
- lightContext must be false for cron jobs -- with true, workspace skills are not loaded
- sessionTarget isolated ensures clean sessions per cron run, preventing state leakage
- Per-session cumulative cap of +/- 0.3 per field per run to prevent feedback loop runaway
- Backup-before-write pattern with 10-backup retention for preference safety
- 6-step disambiguation cascade for resolving feedback references
- Cache keyed by same URL SHA as dedup-index for consistency across pipeline
- Circuit-breaker uses higher of call ratio and token ratio as effective usage
- Daily digest assembly exempt from circuit-breaker (1 final LLM call allowed)
- Tiered model strategy documented but activation deferred until platform confirms model selection support
- SKILL.md type routing uses compact inline If-type-== pattern to stay within word budget (646/700)
- New example sources disabled by default for safety -- user must explicitly enable
- Collection-instructions.md headers use descriptive names without numbering for cleaner SKILL.md cross-references
- Compact Quick-Check Flow in SKILL.md delegates detail to reference files to stay within 750-word budget
- Jaccard bigram threshold 0.6 with LLM Stage C as safety net for false positives
- CJK character ratio >50% for language detection (zh vs en)
- Cross-language title comparison prohibited; cross-language merging deferred to event level
- Health-check.sh uses --mode daily|weekly flag for multi-mode execution (daily alerts + weekly full inspection)
- All JSON modifications in data-archive.sh use atomic writes (tmp+mv) to prevent corruption
- Weekly health inspection cron delivers only when alerts/warnings found to avoid noise
- Event re-summarization skipped for analysis relation type to save LLM budget
- Cross-language event merging enabled (unlike per-language title dedup)
- event_boost requires both active status AND importance >= 0.7
- [Phase 02]: Cold-start uses top-3 topics by weight as pseudo-core when no topic >= 0.7
- [Phase 02]: Chain yielding is strictly one-way: explore -> adjacent -> hotspot -> core
- [Phase 02]: ANTI-03 grace period skips diversity constraints when < 3 days of history exist
- [Phase 02]: Recommendation reasons mandatory for hotspot and exploration, not for core/adjacent
- [Phase 03]: Asymmetric demotion/recovery thresholds (0.2/14d vs 0.3/7d) with hysteresis counters to prevent oscillation
- [Phase 03]: Decay runs as step 0 in Processing Phase, before all LLM calls and feedback processing
- [Phase 03]: depth_preference and judgment_angles wired into summarize prompt, NOT scoring formula
- [Phase 03]: Schema v2 with backward-compatible defaults for v1 readers (depth_preference="moderate", judgment_angles=[])
- [Phase 03]: Weekly quota 40/20/20/20 vs daily 50/20/15/15 for broader exploration in weekly context
- [Phase 03]: Pre-filter weekly items to digest-selected (quota_group set) then cap at 150 to prevent LLM context overflow
- [Phase 03]: Strong model tier for weekly One Week Overview and Cross-Domain Connections sections
- [Phase 03]: SKILL.md compacted Processing Phase steps 8-13 to accommodate history query routing within 950-word budget
- [Phase 04]: All integration fixes are additive-only with backward-compatible defaults -- no existing behavior changed
- [Phase 04]: depth_preference/judgment_angles wired into summarize prompt only, confirmed NOT scoring formula
- [Phase 04]: moderate depth produces identical 2-3 sentence output to preserve backward compatibility
- [Phase 09]: Prompt version bumped to classify-v2 to force cache invalidation of all v1 entries
- [Phase 09]: Negative examples use description (-> correct_category) format for clear alternative routing
- [Phase 09]: Disambiguation rules classify by PRIMARY ACTION not subject domain
- [Phase 09]: Empty noise_patterns arrays for all sources as conservative default
- [Phase 09]: noise_filtered items stay in JSONL for history queryability, not deleted
- [Phase 09]: digest_eligible defaults to true for backward compatibility with v3 items
- [Phase 09]: Post-classify filter keeps processing_status as-is (not noise_filtered) since classification DID succeed
- [Phase 09]: noise_filter_suppressed is single counter summing pre-classify and post-classify filtered items
- [Phase 09]: Importance threshold 0.25 defined as single-point constant for easy tuning
- [Phase 10]: AlertState stored in dedicated data/alerts/ directory, separate from DailyMetrics, as authoritative source for alert tracking
- [Phase 10]: DailyMetrics alert fields (alerts_sent_today, alerted_urls) become derived from alert-state file at metrics write time
- [Phase 10]: Event v3 schema adds alert memory (last_alerted_at, last_alert_news_id, last_alert_brief) with null defaults for backward compatibility
- [Phase 10]: Delta alerts filter for update/correction/reversal/escalation relations only -- initial and analysis excluded as non-substantive
- [Phase 10]: Delta alert writes current_status (not delta_summary) to last_alert_brief for future delta comparison baseline
- [Phase 10]: Standard alerts seed event memory on first alert to enable future delta alerts
- [Phase 10]: DigestHistory uses rolling 5-run window comparing only against last digest (non-compounding 0.7x penalty)
- [Phase 10]: repeat_suppressed_count tracks only items penalized AND excluded from digest (not all penalized items)
- [Phase 10]: DigestHistory written after output, before lock release, using atomic write
- [Phase 11]: 8 run_log milestone steps cover pipeline_start through pipeline_end with step-specific detail schemas
- [Phase 11]: run_log defaults to empty array for backward compatibility with pre-Phase-11 metrics
- [Phase 11]: pipeline_end entry written via atomic update to already-persisted metrics file before lock release
- [Phase 11]: Failed source names derived from existing per_source data -- no new collection logic
- [Phase 11]: Diagnostics is on-demand inspection tool (operator triggered), health-check.sh is automated alerting (cron triggered)
- [Phase 11]: Schema Version Registry maintained alongside New Fields Registry, both updated on schema changes
- [Phase 12]: Scheduling presets live in config/schedule-profiles.json with stable profile IDs and active_profile selection.
- [Phase 12]: Intent recognition examples are centralized in references/feedback-rules.md; SKILL.md only dispatches.
- [Phase 12]: Use config/sources.json as the authoritative source list and enrich with recent DailyMetrics.per_source data instead of relying on metrics presence.
- [Phase 12]: Derive recommendation evidence from scoring and quota state only; do not allow LLM-authored selection rationale.
- [Phase 12]: Document recommendation_evidence as NewsItem schema v5 so explainability defaults are explicit for older records.
- [Phase 12]: Evaluate dense-day collapse thresholds per same-day bucket instead of total event timeline length.
- [Phase 12]: Keep same-day collapse presentation-only so raw event.timeline storage and digest-history behavior remain unchanged.
- [Phase 12]: Back the collapsed Event Tracking render contract with a deterministic schema-valid dense-day fixture.

### Pending Todos

None yet.

### Blockers/Concerns

- (Resolved) Platform capability verification documented in Phase 0 -- references/platform-verification.md provides 5-capability checklist

## Session Continuity

Last session: 2026-04-02T17:43:37.120Z
Stopped at: Completed 12-03-PLAN.md
Resume file: None
