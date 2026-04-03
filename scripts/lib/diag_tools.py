from __future__ import annotations

import json
import os
from datetime import datetime, timedelta


def latest_metrics(base_dir: str) -> dict | None:
    """Find and return the most recent daily-*.json as a parsed dict.

    Searches up to 7 days back. Returns None if no file found.
    """
    base_dir = base_dir.rstrip("/")
    today = datetime.now()
    for d in range(0, 8):
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        path = os.path.join(base_dir, "data", "metrics", f"daily-{date_str}.json")
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8-sig") as f:
                    return json.load(f)
            except (json.JSONDecodeError, OSError):
                continue
    return None


def latest_metrics_date(base_dir: str) -> str | None:
    """Return the date string (YYYY-MM-DD) of the latest metrics file."""
    base_dir = base_dir.rstrip("/")
    today = datetime.now()
    for d in range(0, 8):
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        path = os.path.join(base_dir, "data", "metrics", f"daily-{date_str}.json")
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8-sig") as f:
                    json.load(f)
                return date_str
            except (json.JSONDecodeError, OSError):
                continue
    return None


def per_source_status(base_dir: str) -> dict[str, dict]:
    """Return per-source status from today's or most recent metrics."""
    m = latest_metrics(base_dir)
    if m is None:
        return {}
    return m.get("per_source", {})


def digest_history_summary(base_dir: str) -> list[dict]:
    """Return the last 5 runs from data/digest-history.json."""
    base_dir = base_dir.rstrip("/")
    history_path = os.path.join(base_dir, "data", "digest-history.json")
    if not os.path.exists(history_path):
        return []
    try:
        with open(history_path, "r", encoding="utf-8") as f:
            history = json.load(f)
        runs = history.get("runs", [])
        return runs[-5:]
    except (json.JSONDecodeError, OSError):
        return []


def active_events_summary(base_dir: str) -> dict:
    """Return counts of active/stable/total events from data/events/active.json."""
    base_dir = base_dir.rstrip("/")
    events_path = os.path.join(base_dir, "data", "events", "active.json")
    if not os.path.exists(events_path):
        return {"total": 0, "active": 0, "stable": 0, "valid": False}
    try:
        with open(events_path, "r", encoding="utf-8") as f:
            events = json.load(f)
        if not isinstance(events, list):
            return {"total": 0, "active": 0, "stable": 0, "valid": False}
        active = len([e for e in events if e.get("status") == "active"])
        stable = len([e for e in events if e.get("status") == "stable"])
        return {"total": len(events), "active": active, "stable": stable, "valid": True}
    except (json.JSONDecodeError, OSError):
        return {"total": 0, "active": 0, "stable": 0, "valid": False}


def budget_status(base_dir: str) -> dict:
    """Return budget counters and effective usage from config/budget.json."""
    base_dir = base_dir.rstrip("/")
    budget_path = os.path.join(base_dir, "config", "budget.json")
    if not os.path.exists(budget_path):
        return {"valid": False}
    try:
        with open(budget_path, "r", encoding="utf-8") as f:
            b = json.load(f)
        calls = b.get("calls_today", 0)
        call_limit = b.get("daily_llm_call_limit", 0)
        tokens = b.get("tokens_today", 0)
        token_limit = b.get("daily_token_limit", 0)
        date = b.get("current_date", "?")
        call_pct = (calls / call_limit * 100) if call_limit > 0 else 0
        token_pct = (tokens / token_limit * 100) if token_limit > 0 else 0
        effective = max(call_pct, token_pct)
        return {
            "valid": True,
            "date": date,
            "calls": calls,
            "call_limit": call_limit,
            "tokens": tokens,
            "token_limit": token_limit,
            "call_pct": call_pct,
            "token_pct": token_pct,
            "effective": effective,
        }
    except (json.JSONDecodeError, OSError, KeyError):
        return {"valid": False}


if __name__ == "__main__":
    pass
