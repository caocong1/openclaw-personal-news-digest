"""Structured run journal for append-only failure/security/audit entries.

This module provides append-only journal operations for the pipeline's audit trail.
Entries are never overwritten -- they survive across runs via JSONL persistence.
"""

import json
import os
import sys
from datetime import datetime, timezone
from typing import Optional


JOURNAL_PATH = "data/metrics/run-journal.jsonl"

VALID_SEVERITIES = {"error", "warning", "security", "info"}
VALID_STAGES = {"collection", "processing", "output", "delivery"}


def journal_append(
    run_id: str,
    severity: str,
    stage: str,
    code: str,
    message: str,
    hint: str = "",
    details: Optional[dict] = None,
    source_id: Optional[str] = None,
    base_dir: Optional[str] = None,
) -> None:
    """Append a structured entry to the run journal.

    Args:
        run_id: Unique run identifier (e.g. "run-20260403-1200-abcd")
        severity: One of "error", "warning", "security", "info"
        stage: One of "collection", "processing", "output", "delivery"
        code: Uppercase error code string (e.g. "SRC_TIMEOUT", "LLM_FAILURE")
        message: Human-readable description
        hint: Recovery hint for operators (optional)
        details: Additional structured details (optional)
        source_id: Source identifier if applicable (optional)
        base_dir: Base directory for resolving JOURNAL_PATH (optional, defaults to cwd)
    """
    if severity not in VALID_SEVERITIES:
        raise ValueError(f"Invalid severity '{severity}', must be one of: {VALID_SEVERITIES}")
    if stage not in VALID_STAGES:
        raise ValueError(f"Invalid stage '{stage}', must be one of: {VALID_STAGES}")

    if base_dir is None:
        base_dir = sys.argv[1] if len(sys.argv) > 1 else "."

    journal_path = os.path.join(base_dir, JOURNAL_PATH)
    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "severity": severity,
        "stage": stage,
        "code": code.upper(),
        "message": message,
        "hint": hint,
        "details": details or {},
        "source_id": source_id,
    }

    tmp_path = journal_path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    os.rename(tmp_path, journal_path)


def journal_query(
    journal_path: str,
    run_id: Optional[str] = None,
    severity: Optional[str] = None,
    stage: Optional[str] = None,
    limit: int = 100,
) -> list[dict]:
    """Read and filter the journal.

    Args:
        journal_path: Path to the journal file
        run_id: Filter by run_id (optional)
        severity: Filter by severity (optional)
        stage: Filter by stage (optional)
        limit: Maximum number of entries to return (default 100)

    Returns:
        List of matching journal entries (newest first)
    """
    if not os.path.exists(journal_path):
        return []

    entries = []
    with open(journal_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            if run_id and entry.get("run_id") != run_id:
                continue
            if severity and entry.get("severity") != severity:
                continue
            if stage and entry.get("stage") != stage:
                continue

            entries.append(entry)

    # Newest first, then apply limit
    entries.sort(key=lambda e: e.get("ts", ""), reverse=True)
    return entries[:limit]


def journal_summary(journal_path: str, days: int = 7) -> dict:
    """Return a summary of journal entries in the last N days.

    Args:
        journal_path: Path to the journal file
        days: Number of days to look back (default 7)

    Returns:
        Dict with count_by_severity, count_by_stage, unique_run_ids, total_count
    """
    if not os.path.exists(journal_path):
        return {
            "count_by_severity": {"error": 0, "warning": 0, "security": 0, "info": 0},
            "count_by_stage": {"collection": 0, "processing": 0, "output": 0, "delivery": 0},
            "unique_run_ids": [],
            "total_count": 0,
        }

    cutoff = datetime.now(timezone.utc)
    from datetime import timedelta

    cutoff = cutoff - timedelta(days=days)
    cutoff_iso = cutoff.isoformat()

    by_severity = {"error": 0, "warning": 0, "security": 0, "info": 0}
    by_stage = {"collection": 0, "processing": 0, "output": 0, "delivery": 0}
    run_ids = set()
    total = 0

    with open(journal_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            ts = entry.get("ts", "")
            if ts < cutoff_iso:
                continue

            total += 1
            sev = entry.get("severity", "")
            stg = entry.get("stage", "")
            rid = entry.get("run_id", "")

            if sev in by_severity:
                by_severity[sev] += 1
            if stg in by_stage:
                by_stage[stg] += 1
            if rid:
                run_ids.add(rid)

    return {
        "count_by_severity": by_severity,
        "count_by_stage": by_stage,
        "unique_run_ids": sorted(run_ids),
        "total_count": total,
    }


# CLI interface for run-journal.sh heredoc
if __name__ == "__main__":
    cmd = sys.argv[2] if len(sys.argv) > 2 else ""
    base_dir = sys.argv[1] if len(sys.argv) > 1 else "."

    if cmd == "query":
        run_id = None
        severity = None
        stage = None
        limit = 100
        i = 3
        while i < len(sys.argv):
            if sys.argv[i] == "--run-id" and i + 1 < len(sys.argv):
                run_id = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--severity" and i + 1 < len(sys.argv):
                severity = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--stage" and i + 1 < len(sys.argv):
                stage = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--limit" and i + 1 < len(sys.argv):
                limit = int(sys.argv[i + 1])
                i += 2
            else:
                i += 1

        journal_path = os.path.join(base_dir, JOURNAL_PATH)
        results = journal_query(journal_path, run_id, severity, stage, limit)
        for entry in results:
            print(json.dumps(entry, ensure_ascii=False))

    elif cmd == "summary":
        days = 7
        i = 3
        while i < len(sys.argv):
            if sys.argv[i] == "--days" and i + 1 < len(sys.argv):
                days = int(sys.argv[i + 1])
                i += 2
            else:
                i += 1

        journal_path = os.path.join(base_dir, JOURNAL_PATH)
        result = journal_summary(journal_path, days)
        print(json.dumps(result, ensure_ascii=False))

    else:
        print(f"Usage: python3 journal_tools.py BASE_DIR [query|summary] [...]", file=sys.stderr)
        sys.exit(1)
