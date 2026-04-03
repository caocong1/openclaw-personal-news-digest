---
phase: 16-operational-hardening
plan: "01"
subsystem: infra
tags: [python3, bash, heredoc, pipeline, metrics, jsonl]

# Dependency graph
requires:
  - phase: 15-provenance-aware-output
    provides: Full pipeline with provenance scoring, event tracking, and output rendering
provides:
  - scripts/lib/ Python module infrastructure (5 modules)
  - Explicit pipeline_state enum in DailyMetrics for failure transparency
  - All 4 operational scripts refactored to use auditable heredoc Python
affects:
  - Phase 16-02 (roundup atomization -- HARD-02)
  - Phase 16-03 (run journal, version drift -- OPER-01/02)
  - SKILL.md Output Phase (pipeline_state computation)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Heredoc Python pattern (python3 - ARG <<'PY') for all operational scripts
    - Atomic .tmp rename for JSON/JSONL writes
    - Explicit pipeline_state enum for silent-failure distinction
    - UTC timezone for all timestamp operations

key-files:
  created:
    - scripts/lib/jsonl_tools.py
    - scripts/lib/dedup_tools.py
    - scripts/lib/health_tools.py
    - scripts/lib/diag_tools.py
    - scripts/lib/archive_tools.py
  modified:
    - scripts/dedup-index-rebuild.sh
    - scripts/health-check.sh
    - scripts/diagnostics.sh
    - scripts/data-archive.sh
    - references/data-models.md
    - SKILL.md

key-decisions:
  - "Dedup index rebuild uses in-memory collection then single atomic write (not per-item writes)"
  - "Data-archive.sh consolidation: all sections 2-4 run in one Python heredoc call"
  - "JSON result parsing uses python3 - ARG <<'PY' (pass JSON as argv) not echo | python3 -"
  - "pipeline_state backward-compat default is 'success' for historical metrics files"
  - "source-status.sh remains unmodified as the reference model"

patterns-established:
  - "All operational scripts must use heredoc Python (not inline python3 -c) for auditable modules"
  - "scripts/lib/ modules must have entry-point guard if __name__ == '__main__': pass"
  - "All UTC timestamps via datetime.now(timezone.utc)"
  - "determine_pipeline_state in health_tools mirrors the SKILL.md Output Phase step 7 logic"

requirements-completed: [HARD-01, HARD-03]

# Metrics
duration: 9min
completed: 2026-04-03
---

# Phase 16 Plan 01: Operational Hardening Summary

**5 auditable Python modules in scripts/lib/ with heredoc pattern replacing all 26 inline python3 -c snippets, plus pipeline_state enum in DailyMetrics for operator failure transparency**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-03T21:51:33Z
- **Completed:** 2026-04-03T22:01:13Z
- **Tasks:** 5
- **Commits:** 6
- **Files created:** 5
- **Files modified:** 6

## Accomplishments

- Extracted all inline `python3 -c` snippets from 4 operational scripts into 5 auditable Python modules under `scripts/lib/`
- Replaced 26 inline Python snippets using the heredoc pattern pioneered by `scripts/source-status.sh`
- Added `pipeline_state` enum to DailyMetrics schema enabling operators to distinguish success-empty, failed-no-scan, and partial-degraded from item_count: 0 alone
- Wired `pipeline_state` computation into SKILL.md Output Phase step 7
- Registered `pipeline_state` in New Fields Registry under Phase 16

## Task Commits

1. **Task 1: jsonl_tools.py foundation** - `c29d447` (feat)
2. **Task 2: dedup_tools extraction** - `5cad574` (feat)
3. **Task 3: health_tools extraction** - `d676d4e` (feat)
4. **Task 4: diag_tools and archive_tools extraction** - `c2745a3` (feat)
5. **Task 5: pipeline_state enum in DailyMetrics** - `7887d0a` (feat)
6. **Fix: remaining python3 -c one-liners** - `90b614e` (fix)

## Files Created/Modified

- `scripts/lib/jsonl_tools.py` - Shared JSONL foundation (atomic_write, read, append, latest_jsonl_dir)
- `scripts/lib/dedup_tools.py` - Dedup index rebuild (rebuild_index, count_index_entries)
- `scripts/lib/health_tools.py` - Health check logic (determine_pipeline_state, dedup consistency, source concentration, long-stable events, success rates, and 5 additional helpers)
- `scripts/lib/diag_tools.py` - Diagnostics data gathering (latest_metrics, per_source_status, digest_history, active_events, budget_status)
- `scripts/lib/archive_tools.py` - TTL-based cleanup (cleanup_dedup_index, cleanup_feedback, cleanup_cache_entry)
- `scripts/dedup-index-rebuild.sh` - Now uses heredoc calling dedup_tools module
- `scripts/health-check.sh` - Now uses heredoc calling health_tools module (17 checks preserved)
- `scripts/diagnostics.sh` - Now uses heredoc calling diag_tools module (6 sections preserved)
- `scripts/data-archive.sh` - Now uses single consolidated Python heredoc for sections 2-4
- `references/data-models.md` - Added pipeline_state to DailyMetrics schema, field notes, and New Fields Registry
- `SKILL.md` - Updated Output Phase step 7 to compute and write pipeline_state

## Decisions Made

- Dedup index rebuild collects all entries in memory then writes atomically (not per-item writes which caused the original TEMP_FILE pattern)
- Data-archive.sh runs all Python cleanup operations (dedup, feedback, cache) in a single heredoc call to avoid double-execution
- JSON result parsing from heredoc uses `python3 - ARG <<'PY'` pattern (pass JSON as argv) because `echo | python3 - <<'PY'` fails -- the pipe consumes stdin before the heredoc can read it
- `pipeline_state` backward-compatibility default is `"success"` matching the most common case
- `scripts/source-status.sh` left completely unmodified as the reference implementation

## Deviations from Plan

**None - plan executed exactly as written.**

## Issues Encountered

**1. Data-archive.sh double-execution of Python cleanup**
- **Issue:** Original design called Python heredoc once for cleanup, then captured output via DEDUP_CHECK variable. The cleanup itself modifies files (removes entries), so running it twice would delete twice.
- **Fix:** Consolidated all three cleanup operations (dedup, feedback, cache) into a single Python heredoc that returns JSON, then parsed results from JSON.
- **Files modified:** scripts/data-archive.sh
- **Committed in:** `c2745a3`

**2. JSON parsing heredoc using echo | pipe fails**
- **Issue:** `echo "$RESULTS" | python3 - <<'PY'` fails because the pipe provides stdin to python3, leaving nothing for the heredoc.
- **Fix:** Used `python3 - "$RESULTS" <<'PY'` pattern (pass JSON as argv[1], read from sys.argv[1]).
- **Files modified:** scripts/data-archive.sh
- **Committed in:** `90b614e`

**3. health-check.sh output format preserved**
- **Issue:** Bash counters ERRORS/ALERTS/WARNINGS needed to stay in bash while Python functions returned structured data for formatting.
- **Fix:** Python heredocs still print ALERT/WARN/INFO/OK lines directly; bash counters remain as-is for the summary line.

## Next Phase Readiness

- scripts/lib/ module infrastructure is in place for Phase 16-02 (HARD-02 roundup atomization) and Phase 16-03 (OPER-01 run journal, OPER-02 version drift)
- `pipeline_state` enum is documented and wired into SKILL.md -- provenance-aware output pipeline can proceed
- All operational scripts are now auditable Python modules with type hints

---
*Phase: 16-01*
*Completed: 2026-04-03*
