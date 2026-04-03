# Phase 16: Operational Hardening & Verification - Research

**Researched:** 2026-04-03
**Domain:** Pipeline hardening, operator safety, failure transparency, and live-run verification for an OpenClaw news digest skill
**Confidence:** HIGH

## Summary

Phase 16 closes the remaining P0/P1 hardening backlog accumulated across the v1.0 and v2.0 milestones. The codebase has a solid operational foundation -- atomic writes, file locks, schema versioning, run_log arrays in metrics, existing health-check scripts, and documented platform verification. However, several brittle patterns and coverage gaps remain.

The three HARD requirements address code quality: inline `python3 -c` snippets embedded in bash scripts are scattered across 4 scripts (26 instances total), making execution hard to audit and debug; collection roundup items have no atomization path (e.g., "AI Weekly: 10 articles" vs. individual articles); and pipeline state is conflated -- "no output" could mean "nothing happened" or "everything failed silently."

The six OPER requirements address operator experience: failures are logged in run_log arrays but not as structured journal entries with severity; health checks have no version drift detection; no external backlog sync path exists; the single-source default offers no production baseline; CLI and docs are not parity-checked; and the platform verification doc exists but has not been re-run post-provenance rollout.

The four pre-defined plans (16-01 through 16-04) map cleanly onto these 9 requirements: 16-01 handles HARD-01 and HARD-03, 16-02 handles HARD-02, 16-03 handles OPER-01/02/03/04, and 16-04 handles OPER-05/06.

**Primary recommendation:** Extract all inline Python into `scripts/lib/` shared modules using the heredoc pattern already pioneered by `scripts/source-status.sh`. Add explicit `pipeline_state` enum to metrics output. Create `data/metrics/run-journal.jsonl` as a separate append-only audit log. Add version metadata to SKILL.md and health-check.sh. Document the OPER-05 recovery matrix as a new reference doc. Re-run platform verification against OPER-06 criteria.

## Standard Stack

### Core

This is a prompt/config/script OpenClaw skill. No npm packages or external libraries. The "stack" is entirely local:

| Component | Location | Purpose | Why Standard |
|-----------|----------|---------|--------------|
| Pipeline scripts | `scripts/*.sh` | Operational tooling | Already established -- health-check, data-archive, dedup-rebuild, source-status, diagnostics |
| Health checks | `scripts/health-check.sh` | Daily/weekly monitoring | Already exists with OK/WARN/ALERT/INFO prefixes |
| Metrics | `data/metrics/daily-*.json` | Per-run telemetry | Already exists with run_log array |
| SKILL.md | `SKILL.md` | Pipeline orchestration | Already the authoritative entry point |
| Platform verification | `references/platform-verification.md` | Cron/session/exec validation | Already exists, needs re-run |

### Supporting

| Component | Location | Purpose | When to Use |
|-----------|----------|---------|-------------|
| Source status | `scripts/source-status.sh` | Source health queries | Already uses heredoc Python pattern -- reference for script extraction |
| Source config | `config/sources.json` | Live source inventory | Current single-source default -- needs multi-source profile |
| Cron configs | `references/cron-configs.md` | Job registration | Already documents delivery channels |
| Data models | `references/data-models.md` | Schema definitions | NewsItem schema needs atomization fields |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `scripts/lib/` Python modules | Single monolithic scripts | Python modules enable import sharing; single scripts are simpler but duplicate code |
| `run-journal.jsonl` append log | Write failures into `daily-*.json` metrics | JSONL is append-only and survives crashes; embedding in metrics mixes concerns |
| Version field in SKILL.md frontmatter | Version file at `config/version.json` | Frontmatter is self-contained; separate file is easier to grep externally |

**Installation:** No packages needed. All tools are `bash` + `python3` (already validated by platform-verification.md).

## Architecture Patterns

### Recommended Project Structure

```
scripts/
├── health-check.sh          # MODIFY: add version check, HARD-03 state checks, OPER-02 hints
├── data-archive.sh          # MODIFY: extract inline Python to lib/
├── dedup-index-rebuild.sh  # MODIFY: extract inline Python to lib/
├── diagnostics.sh          # MODIFY: extract inline Python to lib/
├── source-status.sh        # ALREADY CORRECT: heredoc Python pattern
├── run-journal.sh          # NEW: append structured entries to run-journal.jsonl
├── smoke-test.sh           # NEW: OPER-06 live platform smoke tests
└── lib/
    ├── jsonl_tools.py      # NEW: shared JSONL processing utilities
    ├── dedup_tools.py      # NEW: dedup index operations
    ├── archive_tools.py    # NEW: TTL-based cleanup operations
    └── diag_tools.py       # NEW: diagnostics data gathering

data/metrics/
├── daily-YYYY-MM-DD.json   # EXISTING: per-run metrics with run_log
└── run-journal.jsonl       # NEW: append-only failure/security journal

references/
├── recovery-matrix.md       # NEW: OPER-05 channel recovery docs
└── source-profiles.md       # NEW: OPER-04 production multi-source profiles
```

### Pattern 1: Inline Python Extraction

**What:** Replace all `python3 -c "..."` inline snippets in bash scripts with calls to shared Python modules in `scripts/lib/`.

**When to use:** Any script with more than 2 inline Python snippets, or any Python logic that needs testing, reuse, or error handling.

**Example:**
The heredoc pattern in `source-status.sh` is the model to follow:

```bash
# GOOD (source-status.sh - already correct)
python3 - "$BASE_DIR" "$SOURCE_QUERY" <<'PY'
import json, os, sys
# Python logic here
PY

# BAD (dedup-index-rebuild.sh line 42)
python3 -c "
import json, sys
idx = json.load(open('$TEMP_FILE'))
idx['$id'] = {'news_id': '$id', ...}
json.dump(idx, open('$TEMP_FILE', 'w'), ...)
"
```

**Why extract:** Inline Python is fragile because:
- Variable escaping is error-prone (quote nesting, `$id` interpolation in single-quoted strings)
- Error handling is minimal (no tracebacks)
- Logic cannot be unit tested
- Hard to audit -- what does this actually do?

### Pattern 2: Explicit Pipeline State (HARD-03)

**What:** Add a `pipeline_state` enum to DailyMetrics output so operators can distinguish three outcomes that currently produce silence.

**When to use:** After the Output Phase writes metrics but before lock release.

**Three states:**

| State | Condition | Meaning |
|-------|-----------|---------|
| `success-empty` | fetched > 0 but all items filtered/deduped/zero-scored | Collection worked, no qualifying items today |
| `failed-no-scan` | sources_attempted > 0 but all sources failed (status=failed) | No collection happened at all |
| `partial-degraded` | Some sources succeeded, some failed, or circuit-breaker triggered | Mixed results, some degradation |

**Example:**
```bash
# After collection, before output:
if [ "$SOURCES_ATTEMPTED" -gt 0 ] && [ "$SOURCES_SUCCESS" -eq 0 ]; then
  PIPELINE_STATE="failed-no-scan"
elif [ "$SOURCES_FAILED" -gt 0 ] || [ "$CIRCUIT_BREAKER" = "true" ]; then
  PIPELINE_STATE="partial-degraded"
elif [ "$ITEMS_FETCHED" -gt 0 ] && [ "$ITEMS_QUALIFYING" -eq 0 ]; then
  PIPELINE_STATE="success-empty"
else
  PIPELINE_STATE="success"
fi
```

### Pattern 3: Run Journal Append Log (OPER-01)

**What:** A separate JSONL file that appends structured failure/security entries, independent of daily metrics.

**When to use:** Whenever a failure, exception, or security block occurs anywhere in the pipeline.

**Schema:**
```json
{"ts":"ISO8601","run_id":"run-YYYYMMDD-HHmmss-XXXX","severity":"error|warning|security","stage":"collection|processing|output|delivery","source_id":"src-xxx or null","code":"ERR_CODE","message":"Human-readable description","hint":"Recovery action if available","details":{}}
```

**Why separate from daily metrics:** The daily metrics file is overwritten each run. A JSONL journal is append-only and survives across runs -- operators can query the full history. It also decouples failure logging from metrics aggregation.

### Pattern 4: Version Drift Detection (OPER-02)

**What:** A `_openclaw_version` field in SKILL.md frontmatter and a version check in health-check.sh that compares expected vs. actual.

**Example SKILL.md frontmatter addition:**
```yaml
---
name: news-digest
version: "16.0.0"
minimum_openclaw_version: "1.4.0"
---
```

**Example health check:**
```bash
# Check version compatibility
EXPECTED_VERSION="1.4.0"
ACTUAL_VERSION=$(python3 -c "
import re, sys
content = open('$BASE_DIR/SKILL.md').read()
m = re.search(r'minimum_openclaw_version:\s*[\"\']?([\d.]+)', content)
print(m.group(1) if m else 'unknown')
" 2>/dev/null || echo "unknown")
if [ "$ACTUAL_VERSION" != "unknown" ] && [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
  echo "ALERT: OpenClaw version drift -- expected >=$EXPECTED_VERSION, found $ACTUAL_VERSION"
  echo "HINT: Update OpenClaw or pin skill version. See references/platform-verification.md"
fi
```

### Pattern 5: External Backlog Sync (OPER-03)

**What:** A configurable external path (env var or config) where the skill appends structured failure follow-ups. Operators track these in their own issue tracker.

**Schema:**
```json
{"ts":"ISO8601","run_id":"run-YYYYMMDD-HHmmss-XXXX","failure_type":"source_timeout|llm_failure|version_drift|degraded_sources","summary":"3 sources failed (src-X, src-Y, src-Z)","recovery_hint":"Re-enable sources manually or wait for auto-recovery after 3 consecutive successes","source_ids":["src-x","src-y","src-z"]}
```

**Path:** `data/backlog/failure-followups.jsonl` (repo-managed) + optionally `OPENCLAW_BACKLOG_PATH` env var for external sync.

### Pattern 6: Channel Recovery Matrix (OPER-05)

**What:** A new reference doc `references/recovery-matrix.md` that documents recovery actions for each failure type across Web UI, terminal, and Discord channels.

**Structure:**
| Failure | Web UI Action | Terminal Action | Discord Action |
|---------|---------------|-----------------|----------------|
| Lock stuck | Clear via session restart | `rm data/.lock` then re-run | Same as terminal |
| All sources failed | Inspect sources.json | `bash scripts/source-status.sh` | Same as terminal |
| Budget exhausted | Check budget.json | `cat config/budget.json` | Same as terminal |
| Cron not firing | Check cron jobs via platform UI | `cron list` (if tool available) | Same as terminal |
| Empty digest | Run diagnostics | `bash scripts/diagnostics.sh` | Same as terminal |
| Degraded source | Enable/disable via chat | `bash scripts/source-status.sh` | Same as terminal |

### Pattern 7: Source Profiles (OPER-04)

**What:** Named source profiles at `config/source-profiles.json` enabling multi-source baseline instead of single-source default.

**Schema:**
```json
{
  "profiles": {
    "minimal": {
      "description": "Single source, quick feedback loop",
      "sources": ["src-36kr"]
    },
    "production": {
      "description": "Multi-source baseline with balanced coverage",
      "sources": ["src-36kr", "src-official-openai-blog", "src-github-langchain", "src-search-ai-regulation"]
    },
    "full": {
      "description": "All configured sources",
      "sources": "*"
    }
  }
}
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSONL processing | Inline `python3 -c` with subshells | `scripts/lib/` Python modules using the heredoc pattern from source-status.sh | Auditable, testable, no quote escaping hell |
| Failure logging | Embedding in per-run metrics | Separate `run-journal.jsonl` append log | Append-only, survives metrics overwrite, decoupled |
| Version tracking | Remembering to check manually | `_openclaw_version` in SKILL.md frontmatter + health-check integration | Automated, always in sync with skill definition |
| Source baselines | Manual editing of sources.json each time | Named profiles in `config/source-profiles.json` with one-command activation | Repeatable, auditable, operator-friendly |

## Common Pitfalls

### Pitfall 1: Inline Python Quote Escaping

**What goes wrong:** When embedding Python inline in bash with variables, quote nesting creates subtle bugs. `$id` inside a single-quoted Python string passed to `python3 -c '...'` needs careful handling. The dedup-index-rebuild.sh line 42 does `json.dump(idx, open('$TEMP_FILE'))` -- if `$TEMP_FILE` contains special characters, this breaks silently.

**Why it happens:** Bash variable expansion, Python string quoting, and JSON serialization interact in non-obvious ways. The `'$VAR'` syntax does NOT expand variables in single quotes.

**How to avoid:** Always use the heredoc pattern (`python3 - "$BASE_DIR" <<'PY' ... PY`) which avoids all quoting issues. Variables become `sys.argv[1]` and Python code is fully readable.

**Warning signs:** Scripts that work for 6 months then fail on a URL with a single quote in the title.

### Pitfall 2: Confusing Silence with Failure

**What goes wrong:** When a pipeline run produces no digest, operators cannot tell if it means "no news today" or "everything broke silently." The current pipeline handles this implicitly -- if `selected_for_output` is 0, the output is just the transparency footer. But there is no explicit state tag.

**Why it happens:** No `pipeline_state` enum exists in the metrics schema. `success-empty` and `failed-no-scan` both result in `item_count: 0`.

**How to avoid:** Add the three-state `pipeline_state` field to DailyMetrics output and surface it in health-check.sh.

**Warning signs:** Operators report "the digest is empty today" without knowing if it's expected or a failure.

### Pitfall 3: Version Drift After Skill Updates

**What goes wrong:** SKILL.md or reference docs are updated but the running cron jobs use stale cached versions. Operators do not realize the skill has changed until a run starts behaving differently.

**Why it happens:** OpenClaw may cache skill context between runs. No version tag exists to detect drift.

**How to avoid:** Add `minimum_openclaw_version` to SKILL.md frontmatter and check it in health-check.sh.

### Pitfall 4: Brittle Source Default

**What goes wrong:** `config/sources.json` has exactly 1 source enabled by default. When operators set up a new deployment, they enable one source, get results, and never explore multi-source configurations. The single-source setup becomes the de facto production baseline by accident.

**Why it happens:** No documented multi-source profile exists. The "minimal" setup is the only documented path.

**How to avoid:** Create `config/source-profiles.json` with named profiles and document the "production" profile as the recommended baseline.

## Code Examples

### Extraction: From inline Python to heredoc module

**Before (brittle -- dedup-index-rebuild.sh lines 37-49):**
```bash
for f in $(find "$NEWS_DIR" -name "*.jsonl" -mtime -7 2>/dev/null | sort); do
  JSONL_COUNT=$((JSONL_COUNT + 1))
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    id=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    # ... more inline Python
  done < "$f"
done
```

**After (auditable -- dedup-index-rebuild.sh calls scripts/lib/dedup_tools.py):**
```bash
python3 - "$BASE_DIR" "$NEWS_DIR" "$INDEX_FILE" "$TEMP_FILE" <<'PY'
import json, os, sys

def rebuild_index(base_dir, news_dir, index_file, temp_file):
    # All JSONL processing logic here -- testable, readable
    ...
PY
```

### State: Pipeline state enum in metrics

```python
def determine_pipeline_state(sources_attempted, sources_success, sources_failed,
                             items_fetched, items_qualifying, circuit_breaker):
    if sources_attempted > 0 and sources_success == 0:
        return "failed-no-scan"
    elif sources_failed > 0 or circuit_breaker:
        return "partial-degraded"
    elif items_fetched > 0 and items_qualifying == 0:
        return "success-empty"
    else:
        return "success"
```

### Journal: Run journal append

```python
import json
from datetime import datetime

def journal_append(run_id, severity, stage, code, message, hint="", details=None, source_id=None):
    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "severity": severity,
        "stage": stage,
        "code": code,
        "message": message,
        "hint": hint,
        "details": details or {},
        "source_id": source_id
    }
    journal_path = os.path.join(BASE_DIR, "data", "metrics", "run-journal.jsonl")
    with open(journal_path + ".tmp", "w") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    os.rename(journal_path + ".tmp", journal_path)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline Python in bash | Heredoc Python (source-status.sh) | Phase 1-2 era | Improved readability but not yet propagated |
| No pipeline state tracking | Implicit silence | Current (pre-16) | Operators cannot distinguish empty-success from failure |
| Per-run metrics only | Daily metrics overwrite each run | Phase 11 (observability) | No persistent failure history |
| No version metadata | SKILL.md without version | v1.0 MVP | No version drift detection |
| Single-source default | One enabled source in sources.json | v1.0 MVP | No multi-source production baseline |
| platform-verification.md exists | Written but never re-run post-provenance | Phase 0 era | OPER-06 smoke tests need refresh |

**Deprecated/outdated:**
- `run_log` array in DailyMetrics: Still useful for step-level timing, but insufficient for OPER-01's structured failure logging -- should coexist with the new journal
- Manual platform verification: Should be automated via OPER-06 smoke tests

## Open Questions

1. **OPER-03 External Backlog Path Format**
   - What we know: OPER-03 requires an external path for failure follow-ups. The repo-managed path should be `data/backlog/failure-followups.jsonl`.
   - What's unclear: Whether the external path is a second copy (git-tracked journal synced to a URL) or just the repo path with operator instructions. No `OPENCLAW_BACKLOG_URL` or similar env var is defined.
   - Recommendation: Define `OPER_BACKLOG_PATH` in `config/preferences.json` as an optional external path. If set, the skill mirrors journal entries there. If absent, uses the repo-only path.

2. **OPER-06 Smoke Test Automation**
   - What we know: `references/platform-verification.md` has 5 manual test procedures. OPER-06 asks for smoke tests covering cron delivery, isolated session loading, exec permissions, timeout behavior, and empty-input quality gates.
   - What's unclear: Can cron jobs be programmatically created/deleted in the OpenClaw platform? Is there an API, or must smoke tests be run manually? The existing verification doc was designed for manual execution.
   - Recommendation: Create `scripts/smoke-test.sh` that automates as much as possible via the cron tool and exec. Manual steps (checking Telegram delivery) remain manual but are clearly documented.

3. **HARD-02 Round Detection Trigger**
   - What we know: `classify.md` classifies "Aggregation roundup, no original content" with 0.1 importance. No dedicated roundup detection exists.
   - What's unclear: Should atomization be triggered by the LLM (classify returns `is_roundup: true`) or by pattern matching on titles (e.g., regex for "Top 10", "Weekly Roundup", "N items" patterns)?
   - Recommendation: Use pattern matching as a fast-path (title regex for common roundup patterns) + LLM classify flag as a fallback for ambiguous cases.

4. **OPER-02 Version Field Semantics**
   - What we know: SKILL.md has no version field. No version tracking exists.
   - What's unclear: Is "version" the skill's own semantic version or the OpenClaw platform's version? The requirement says "OpenClaw version drift" -- does this mean the platform version or the skill version?
   - Recommendation: Track both: `_skill_version` (skill's own version, e.g., "16.0.0") and `minimum_openclaw_version` (platform minimum). Health check fails if either is violated.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HARD-01 | Inline Python or brittle here-doc execution paths are replaced with auditable scripts under `scripts/` | All 4 scripts (dedup-index-rebuild.sh, diagnostics.sh, health-check.sh, data-archive.sh) have 26 total inline `python3 -c` snippets. `source-status.sh` proves the heredoc pattern works. Extraction target: `scripts/lib/*.py` modules. |
| HARD-02 | Collection-style roundup items can be atomized into child items, and the parent roundup is excluded from scoring and output | No atomization fields in NewsItem schema. classify.md already flags "Aggregation roundup" at 0.1 importance. Need `is_roundup`, `roundup_children[]` fields and a roundup detection pattern. |
| HARD-03 | Pipeline output distinguishes success-empty, failed-no-scan, and partial-degraded states so silence is not confused with failure | No `pipeline_state` enum in DailyMetrics. All three states currently produce `item_count: 0` with no distinction. Add enum to metrics and surface in health-check.sh. |
| OPER-01 | Failures, exceptions, and security blocks append structured entries to `data/metrics/run-journal.jsonl` | `run_log` exists in DailyMetrics but only captures step progress, not failures/exceptions/security. New JSONL append log needed. Journal schema defined in this research. |
| OPER-02 | Health checks surface OpenClaw version drift and documented recovery hints for blocked runs | No version metadata in SKILL.md. `scripts/health-check.sh` has no version check. Add `_skill_version`/`minimum_openclaw_version` to SKILL.md frontmatter and integrate into health-check.sh with recovery hints. |
| OPER-03 | The skill appends failure follow-up to the external backlog path and keeps repo docs aligned with that path | No external backlog path exists. Define `OPER_BACKLOG_PATH` in config, create `data/backlog/failure-followups.jsonl`, and document in recovery-matrix.md. |
| OPER-04 | A documented production source profile enables a multi-source baseline instead of a single-source default | `config/sources.json` has 1 enabled source by default. No profile system exists. Create `config/source-profiles.json` with minimal/production/full profiles. |
| OPER-05 | CLI/docs parity checks and a channel recovery matrix document how operators recover across Web UI, terminal, and Discord workflows | `scripts/` and `SKILL.md` commands are not parity-checked. No recovery matrix document exists. Create `references/recovery-matrix.md` with channel-by-channel recovery actions. |
| OPER-06 | Live platform smoke tests cover cron delivery, isolated session loading, exec permissions, timeout behavior, and empty-input quality gates after the provenance rollout | `references/platform-verification.md` has 5 manual tests written for v1.0. Needs refresh for OPER-06 criteria and automation via `scripts/smoke-test.sh`. |

## Sources

### Primary (HIGH confidence)
- Source: Existing codebase -- 5 scripts, SKILL.md, 7 reference docs, config files, and data fixtures
- Topics: Inline Python patterns, heredoc Python pattern, DailyMetrics schema, run_log structure, health-check modes, platform verification doc

### Secondary (MEDIUM confidence)
- Source: Prior phase research (Phases 13-15) -- establishes the provenance and discovery artifacts that feed into OPER requirements
- Source: STATE.md, ROADMAP.md, REQUIREMENTS.md, PROJECT.md, v3.0-MILESTONE-AUDIT.md -- establish the backlog context for HARD/OPER requirements

### Tertiary (LOW confidence)
- Source: General shell scripting best practices -- applicable but not verified against this specific project's conventions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- entirely local bash/Python, no external dependencies
- Architecture: HIGH -- patterns derived directly from existing codebase inspection (source-status.sh heredoc, health-check.sh modes, DailyMetrics schema, run_log structure)
- Pitfalls: HIGH -- all pitfalls identified by examining the actual brittle code patterns in the existing scripts

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (30 days -- operational hardening patterns are stable, codebase conventions unlikely to change)
