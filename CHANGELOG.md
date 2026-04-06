# Changelog

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
