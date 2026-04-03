---
phase: 16-operational-hardening
plan: "03"
subsystem: infra
tags: [journal, backlog, source-profiles, operator-tools]

# Dependency graph
requires:
  - phase: 16-01
    provides: scripts/lib/ infrastructure pattern, heredoc Python convention
affects:
  - SKILL.md (Operational Rules)
  - config/preferences.json
  - references/

# Tech tracking
tech-stack:
  added: [journal_tools.py, backlog_tools.py, run-journal.sh, activate-profile.sh]
  patterns: [append-only JSONL journal, configurable external backlog path, named source profiles]

key-files:
  created:
    - scripts/lib/journal_tools.py
    - scripts/lib/backlog_tools.py
    - scripts/run-journal.sh
    - scripts/activate-profile.sh
    - config/source-profiles.json
    - references/source-profiles.md
    - data/metrics/run-journal.jsonl
    - data/backlog/failure-followups.jsonl
  modified:
    - SKILL.md
    - config/preferences.json

key-decisions:
  - "Journal uses atomic .tmp rename pattern for crash-safe appends"
  - "SCRIPT_DIR passed as argv from bash to avoid __file__ issue in heredoc Python"
  - "Backlog path defaults to data/backlog/failure-followups.jsonl when OPER_BACKLOG_PATH is null"
  - "Every error journal entry maps to a backlog follow-up via failure_type"
  - "production profile sources match current enabled list; full enables all configured sources"

patterns-established:
  - "Append-only JSONL for cross-run audit trails (run journal)"
  - "Configurable external path via OPER_BACKLOG_PATH with repo-managed fallback"
  - "Named source profiles as reproducible baselines"

requirements-completed: [OPER-01, OPER-03, OPER-04]

# Metrics
duration: 5min
completed: 2026-04-03
---

# Phase 16: Operational Hardening - Plan 03 Summary

**Append-only run journal, configurable external backlog sync, and named source profiles enabling operator audit trail, follow-up tracking, and multi-source baseline switching.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-03T14:04:30Z
- **Completed:** 2026-04-03T14:09:52Z
- **Tasks:** 4
- **Files modified:** 11 (3 created, 2 modified, 6 staged for state updates)

## Accomplishments

- Created append-only run journal (`data/metrics/run-journal.jsonl`) with `journal_tools.py` providing `journal_append`, `journal_query`, and `journal_summary`
- Built `run-journal.sh` CLI with append/query/summary subcommands using the heredoc Python pattern
- Wired 4 failure points into SKILL.md: stale lock cleanup (Collection), source fetch failures (Collection), LLM failures (Processing), digest generation failures (Output), plus security block journal
- Added `OPER_BACKLOG_PATH` to `config/preferences.json` with configurable external path support
- Created `backlog_tools.py` with `get_backlog_path` and `append_failure_followup`
- Added Operational Rules in SKILL.md mapping every error journal entry to a backlog follow-up
- Created `config/source-profiles.json` with minimal/production/full named profiles
- Built `activate-profile.sh` for one-command profile activation
- Documented all profiles in `references/source-profiles.md`

## Task Commits

Each task was committed atomically:

1. **Task 1: Create append-only run-journal.jsonl with journal_tools.py and run-journal.sh** - `7f0a640` (feat)
2. **Task 2: Wire run-journal.sh into SKILL.md for failure/security logging** - `ce28353` (docs)
3. **Task 3: Add OPER_BACKLOG_PATH to preferences.json and backlog_tools.py** - `d0ec2c1` (feat)
4. **Task 4: Create config/source-profiles.json with minimal/production/full profiles** - `71559a8` (feat)

**Plan metadata commit:** (pending final state update)

## Files Created/Modified

- `scripts/lib/journal_tools.py` - Journal append/query/summary with atomic .tmp rename
- `scripts/run-journal.sh` - CLI tool with append/query/summary subcommands
- `scripts/lib/backlog_tools.py` - Backlog path resolution and failure follow-up append
- `scripts/activate-profile.sh` - One-command source profile activation
- `data/metrics/run-journal.jsonl` - Empty git-tracked append-only journal file
- `data/backlog/failure-followups.jsonl` - Empty git-tracked backlog file
- `config/source-profiles.json` - Named profiles (minimal/production/full) schema v1
- `config/preferences.json` - Added OPER_BACKLOG_PATH key
- `references/source-profiles.md` - Profile documentation with usage guidance
- `SKILL.md` - Added journal entries at 4 failure points and Operational Rules 3-7

## Decisions Made

- Used atomic .tmp rename pattern for all append operations (crash-safe)
- Passed `SCRIPT_DIR` as `sys.argv[1]` from bash to avoid `__file__` being `<stdin>` in heredoc Python
- OPER_BACKLOG_PATH defaults to null (repo-managed `data/backlog/failure-followups.jsonl`) -- external path is optional
- Every error journal entry maps to a backlog follow-up via `failure_type`: `SRC_TIMEOUT` -> `source_timeout`, `LLM_FAILURE` -> `llm_failure`
- production profile includes all currently enabled sources; minimal includes first enabled source; full enables all 6 configured sources

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Fixed `__file__` issue in heredoc Python: `__file__` resolves to `<stdin>` when running `python3 - <<'PY'` so the script path must be passed from bash as an argument.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Run journal is ready to receive entries from the pipeline at all documented failure points
- Backlog path is configurable via `OPER_BACKLOG_PATH` in preferences.json
- Source profiles are ready for activation with `bash scripts/activate-profile.sh <name>`
- Phase 16 Plan 04 (OPER-05 CLI parity, OPER-06 smoke tests) can proceed

---
*Phase: 16-operational-hardening Plan 03*
*Completed: 2026-04-03*
