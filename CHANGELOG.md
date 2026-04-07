# Changelog

## [16.5.0] - 2026-04-07

### Fixed
- fix(quick-check): add freshness gate to Quick-Check Flow step 2 — filter items with age > 24h before scoring (ND-20260407-01)
- fix(cron): Quick-Check job timeout increased from 300s to 600s (ND-20260407-02)

### Changed
- fix(delivery): Quick-Check Flow step 3 now uses `message action=send channel=discord target=#新闻` for delivery instead of relying on cron announce (ND-20260407-02)

## [16.4.0] - 2026-04-07

### Added
- feat(skill): add Standing Orders Language mandate — all output (digests, alerts, status messages) must be in Chinese
- feat(output): add Quick-Check Scored Items Report template (【速览】format showing all items with scores)

### Changed
- feat(skill): Quick-Check Flow removes alert_score threshold gate (0.85) and daily cap gate — all scored items are output
- feat(skill): Quick-Check per-run cap raised from 20 to 50
- feat(processing): Section 5A disables threshold, form_type filter, and daily cap gates; URL dedup remains active
- feat(processing): alert_log entries use `alert_type: "scored_report"` for new output format

## [16.3.0] - 2026-04-07

### Added
- feat(collection): add 24-hour freshness gate — discard items with `published_at` older than 24h before writing to JSONL (SKILL.md step 6b, collection-instructions.md Section 2B)

### Changed
- feat(prompts): alert-score.md now receives `published_at` field; LLM uses publication time as hard urgency signal
- fix(prompts): filter-search.md tighten stale result discard from 48h to 24h

## [16.2.0] - 2026-04-07

### Added
- feat(prompts): create translate.md — AI batch title translation template (non-Chinese to Chinese)
- feat(prompts): create alert-score.md — AI breaking news importance scoring template for Quick-Check

### Changed
- refactor(skill): rewrite Collection Phase for pure agent-native fetching (web_fetch/browser/web_search, no Python)
- refactor(skill): rewrite Processing Phase with LLM translate batch step and LLM event similarity dedup
- refactor(skill): rewrite Quick-Check Flow with alert-score.md assessment and summarize.md alert generation
- docs(cron): verify and update cron-configs.md for pure agentTurn triggers
- docs(references): remove Python-specific instructions, update to agent-native approach

### Removed
- chore(cleanup): delete debug_quick_check.py (566-line Python pipeline script)
- Remove all Python/regex/fcntl/urllib references from SKILL.md and reference docs

## [16.1.9] - 2026-04-06

### Changed
- chore: increase MAX_ALERTS_PER_RUN from 3 to 20 to send all candidates per run

## [16.1.8] - 2026-04-06

### Fixed
- fix: change alert cap from daily cumulative to per-run limit — URL dedup already prevents re-sending

## [16.1.7] - 2026-04-06

### Changed
- data: add AIBase Daily seed and new candidate sources to pending-seeds.json
- chore: disable research workflow toggle in planning config

## [16.1.6] - 2026-04-06

### Changed
- chore: remove dead constant MAX_ALERTS_PER_DAY = None (CLEAN-01 / B15)
- chore: remove dead constant ALERT_THRESHOLD = 0.85 (CLEAN-02 / B14)
- chore: remove dead function normalize_event_key() — deferred to v5.0 EVENT-01 (CLEAN-03 / B13)

## [16.1.5] - 2026-04-06

### Fixed
- Use enumerate for union-find cluster lookup, eliminating wrong-cluster bug with value-equal dicts (LOGIC-03 / B11)
- Require second non-dollar anchor for event merge, preventing unrelated dollar-amount-only merges (LOGIC-04 / B9)

## [16.1.4] - 2026-04-06

### Fixed
- Remove duplicate alert sort that erased importance_score tiebreaker (LOGIC-01 / B8)
- Enforce daily alert cap of 3 per SKILL.md spec (LOGIC-02 / B5)

## [16.1.3] - 2026-04-06

### Fixed
- Reordered file writes: state and metrics persisted before alert/digest output to prevent duplicate alerts after crash

## [16.1.2] - 2026-04-06

### Added
- atomic_write_text helper using tmp+fsync+os.replace for crash-safe writes
- All JSON state writes (STATE_FILE, METRICS_FILE, NEWS_FILE) now use atomic_write_text

## [16.1.1] - 2026-04-06

### Added
- fcntl-based concurrency guard in debug_quick_check.py — second cron invocation exits cleanly without corrupting state

## [16.1.0] - 2026-04-05

### Fixed
- Provenance classify prompt: added explicit tier definitions (T0-T4) with clear semantics — tier reflects "who published", not "how important the event is"
- LLM no longer misclassifies media outlets (e.g., 36Kr) as T0 when reporting on official announcements
- Added null fallback ("未分类") to tier Display Mapping in output-templates.md

### Changed
- Bumped provenance-classify prompt version to v2
