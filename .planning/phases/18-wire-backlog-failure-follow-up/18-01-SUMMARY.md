---
phase: 18-wire-backlog-failure-follow-up
plan: "01"
subsystem: operational-robustness
tags: [operational, backlog, failure-tracking, OPER-03]
dependency_graph:
  requires: []
  provides: [OPER-03]
  affects: [SKILL.md, scripts/run-journal.sh, scripts/lib/backlog_tools.py]
tech_stack:
  added: []
  patterns: [backlog failure follow-up, dual-write (journal + backlog)]
key_files:
  created: []
  modified:
    - SKILL.md
    - scripts/run-journal.sh
    - scripts/lib/backlog_tools.py
decisions:
  - "[18-01]: backlog subcommand argument order: run_id, failure_type, summary, recovery_hint, [source_ids...] matching the plan specification"
  - "[18-01]: DIGEST_FAILED maps to llm_failure per plan (digest generation is an LLM-tier issue)"
  - "[18-01]: SECURITY_BLOCK journal entries do NOT trigger backlog follow-ups (audit-only events)"
metrics:
  duration: "< 5 min"
  completed: "2026-04-04"
---

# Phase 18 Plan 01: Wire Backlog Failure Follow-up Summary

## One-liner

Wired `run-journal.sh backlog` calls into SKILL.md so every error journal entry creates a failure follow-up in the configured backlog path, completing OPER-03.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Add version_drift to VALID_FAILURE_TYPES | no-op (already present) | scripts/lib/backlog_tools.py |
| 2 | Add backlog subcommand to run-journal.sh | 290174e | scripts/run-journal.sh |
| 3 | Wire backlog calls into SKILL.md | 760ff9f | SKILL.md |

## What Was Built

### Task 2: backlog subcommand (`scripts/run-journal.sh`)
- Added `backlog` subcommand to the heredoc Python routing layer
- Imports `append_failure_followup` from `backlog_tools`
- Parses arguments: `run_id`, `failure_type`, `summary`, `recovery_hint`, optional `source_ids`
- Updated usage comment with backlog examples
- Follows existing heredoc Python pattern consistent with `append`, `query`, `summary`

### Task 3: SKILL.md wired backlog calls
Three error journal entries now trigger backlog follow-ups:

1. **Collection Phase step 4** (SRC_TIMEOUT -> `source_timeout`, SRC_MALFORMED -> `degraded_sources`)
2. **Processing Phase step 5** (LLM_FAILURE -> `llm_failure`)
3. **Output Phase step 4** (DIGEST_FAILED -> `llm_failure`)
4. **Operational Rules Rule 4** updated to document the wired mechanism and add DIGEST_FAILED to the mapping

SECURITY_BLOCK entries remain journal-only (audit-only, not failure follow-up).

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

```
grep -c 'run-journal.sh backlog' SKILL.md         => 4 (3 in phases + 1 in Rule 4)
grep -c 'version_drift' scripts/lib/backlog_tools.py => 2 (VALID_FAILURE_TYPES + docstring)
grep -q 'backlog_tools' scripts/run-journal.sh    => FOUND
```

All backlog calls are placed immediately after their corresponding journal entries within the same step sentence.

## Auth Gates

None.

## Deferred Issues

None.
