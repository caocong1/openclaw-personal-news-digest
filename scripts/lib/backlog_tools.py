"""External backlog sync for failure follow-ups.

This module provides the configurable backlog path and atomic append for
failure follow-up entries, enabling operators to mirror entries to an
external path (shared drive, issue tracker, etc.) via OPER_BACKLOG_PATH.
"""

import json
import os
import sys
from datetime import datetime, timezone
from typing import Optional


DEFAULT_BACKLOG_PATH = "data/backlog/failure-followups.jsonl"

VALID_FAILURE_TYPES = {"source_timeout", "llm_failure", "version_drift", "degraded_sources"}


def get_backlog_path(base_dir: str = ".") -> str:
    """Return the configured backlog path.

    Reads config/preferences.json and returns OPER_BACKLOG_PATH if non-null,
    otherwise returns the repo-managed default path.

    Args:
        base_dir: Base directory for resolving paths (defaults to cwd)

    Returns:
        Absolute path to the backlog file
    """
    prefs_path = os.path.join(base_dir, "config", "preferences.json")
    if os.path.exists(prefs_path):
        try:
            prefs = json.load(open(prefs_path, encoding="utf-8"))
            external_path = prefs.get("OPER_BACKLOG_PATH")
            if external_path and isinstance(external_path, str) and external_path.strip():
                return os.path.expanduser(external_path.strip())
        except (OSError, json.JSONDecodeError):
            pass
    return os.path.join(base_dir, DEFAULT_BACKLOG_PATH)


def append_failure_followup(
    run_id: str,
    failure_type: str,
    summary: str,
    recovery_hint: str,
    source_ids: Optional[list[str]] = None,
    base_dir: str = ".",
) -> None:
    """Append a failure follow-up entry to the configured backlog path.

    Args:
        run_id: Unique run identifier (e.g. "run-20260403-1200-abcd")
        failure_type: One of "source_timeout", "llm_failure", "version_drift", "degraded_sources"
        summary: Human-readable summary of the failure
        recovery_hint: Suggested recovery action for operators
        source_ids: List of affected source IDs (optional)
        base_dir: Base directory for resolving paths (defaults to cwd)
    """
    if failure_type not in VALID_FAILURE_TYPES:
        raise ValueError(
            f"Invalid failure_type '{failure_type}', must be one of: {VALID_FAILURE_TYPES}"
        )

    backlog_path = get_backlog_path(base_dir)
    backlog_dir = os.path.dirname(backlog_path)
    if backlog_dir and not os.path.exists(backlog_dir):
        os.makedirs(backlog_dir, exist_ok=True)

    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "run_id": run_id,
        "failure_type": failure_type,
        "summary": summary,
        "recovery_hint": recovery_hint,
        "source_ids": source_ids or [],
    }

    existing = ""
    if os.path.exists(backlog_path):
        with open(backlog_path, "r", encoding="utf-8") as f:
            existing = f.read()
    tmp_path = backlog_path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        if existing:
            f.write(existing)
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    os.rename(tmp_path, backlog_path)
