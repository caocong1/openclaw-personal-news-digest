# Recovery Matrix

**Purpose:** Map failure types to recovery actions across all three operator channels: Web UI, Terminal, and Discord.
**Audience:** Operators who need to recover from failures regardless of which channel they use.
**Update cadence:** Update when new failure types are discovered or recovery steps change.

---

## Recovery Matrix Overview

This document maps failure types to recovery actions across all three operator channels. Each row covers a distinct failure mode. Recovery actions are ordered by operator effort (easiest first).

## Recovery Matrix Table

| Failure Type | Web UI Action | Terminal Action | Discord Action |
|---|---|---|---|
| Lock stuck (pipeline hung) | Restart session via UI refresh | `rm data/.lock && bash scripts/health-check.sh` | Same as terminal |
| All sources failed | Inspect sources via Sources panel | `bash scripts/source-status.sh && bash scripts/diagnostics.sh` | Same as terminal |
| Budget exhausted (circuit breaker) | Check usage via UI | `cat config/budget.json` | Same as terminal |
| Cron not firing | Check schedule via cron UI | `bash scripts/health-check.sh` (checks lock age) | Same as terminal |
| Empty digest (expected) | N/A | `bash scripts/diagnostics.sh` | Same as terminal |
| Degraded source | Enable/disable via Sources panel | `bash scripts/source-status.sh <source-id>` | Same as terminal |
| version drift | Check platform version | `bash scripts/health-check.sh` | Same as terminal |
| Stale dedup-index | N/A | `bash scripts/dedup-index-rebuild.sh` | Same as terminal |
| Pipeline state: failed-no-scan | Check sources online | Re-enable failed sources via sources.json | Same as terminal |
| Pipeline state: partial-degraded | Check degraded sources | `bash scripts/source-status.sh` for degraded list | Same as terminal |
| Provenance classification gap | N/A | `bash scripts/diagnostics.sh` (check provenance stats) | Same as terminal |
| Run journal shows security events | N/A | `bash scripts/run-journal.sh query --severity security` | Same as terminal |

---

## Source Recovery

### Auto-disable

Sources auto-disable after 3 consecutive failures or sustained quality drops. See `references/processing-instructions.md` Section 6.

### Auto-recovery

Sources auto-recover after 3 consecutive successful runs.

### Manual re-enable

Set `"enabled": true` in `config/sources.json` or use the `activate-profile.sh` script.

---

## Backlog Follow-up

Failure follow-ups are written to `data/backlog/failure-followups.jsonl` and optionally mirrored to the path set in `OPER_BACKLOG_PATH` in `config/preferences.json`.

Query the backlog:

```bash
bash scripts/run-journal.sh query --severity error
```

---

## Version Recovery

- If `health-check.sh` reports a version drift, update OpenClaw to `minimum_openclaw_version` or higher.
- If the skill version (`_skill_version`) is outdated, pull the latest skill from the skill registry.
- Version metadata is declared in `SKILL.md` frontmatter (`_skill_version` and `minimum_openclaw_version`).

---

## Health Check Reference

| Mode | Command | Description |
|------|---------|-------------|
| Daily | `bash scripts/health-check.sh --mode daily` | Quick checks + MON-02 alert conditions |
| Weekly | `bash scripts/health-check.sh --mode weekly` | Full inspection (daily checks + MON-03 checklist) |
| Diagnostics | `bash scripts/diagnostics.sh` | Detailed pipeline diagnostics |

Run diagnostics when the health check reports issues:

```bash
bash scripts/diagnostics.sh
```

---

## Lock Recovery

If the pipeline is stuck (lock file exists with age > 15 min):

```bash
# Option 1: Clean stale lock and re-run
rm data/.lock
bash scripts/health-check.sh

# Option 2: Inspect the lock first
cat data/.lock
# If the run_id looks stale, delete it
rm data/.lock
```

---

## Pipeline State Recovery

### failed-no-scan

All sources failed to fetch. Recovery steps:
1. Check if sources are online: `bash scripts/source-status.sh`
2. Check source URLs in `config/sources.json` -- verify they are still valid
3. Re-enable disabled sources manually
4. Re-run the pipeline

### partial-degraded

Some sources succeeded, some failed. This is usually self-recovering (auto-recovery after 3 successes). If it persists:
1. Identify degraded sources: `bash scripts/source-status.sh`
2. Check individual source health
3. Manually disable persistently failing sources if needed

---

## Security Event Recovery

If the run journal shows security events:

```bash
bash scripts/run-journal.sh query --severity security
```

Review each event. If a source has been compromised or is producing malicious content:
1. Immediately disable the source in `config/sources.json`
2. Clear the source's cache: `rm -rf data/cache/<source-id>/`
3. Rebuild the dedup index if needed: `bash scripts/dedup-index-rebuild.sh`
4. Report to platform security if the issue originates from the platform
