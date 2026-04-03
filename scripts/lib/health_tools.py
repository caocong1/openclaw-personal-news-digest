from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from typing import Any


def determine_pipeline_state(
    sources_attempted: int,
    sources_success: int,
    sources_failed: int,
    items_fetched: int,
    items_qualifying: int,
    circuit_breaker: bool,
) -> str:
    """Determine pipeline state from collection counters.

    Returns one of four states:
      - "failed-no-scan": sources were attempted but all failed
      - "partial-degraded": some succeeded, some failed, or circuit breaker triggered
      - "success-empty": collection ran (items_fetched > 0) but no items qualified
      - "success": normal run with qualifying items
    """
    if sources_attempted > 0 and sources_success == 0:
        return "failed-no-scan"
    elif sources_failed > 0 or circuit_breaker:
        return "partial-degraded"
    elif items_fetched > 0 and items_qualifying == 0:
        return "success-empty"
    else:
        return "success"


def check_dedup_consistency(base_dir: str) -> dict[str, Any]:
    """Check for orphaned entries in dedup-index (in index but not in any recent JSONL).

    Returns {"orphaned": int, "total": int, "pct": float}.
    """
    base_dir = base_dir.rstrip("/")
    dedup_path = os.path.join(base_dir, "data", "news", "dedup-index.json")
    if not os.path.exists(dedup_path):
        return {"orphaned": 0, "total": 0, "pct": 0.0}

    try:
        with open(dedup_path, "r", encoding="utf-8") as f:
            dedup = json.load(f)
    except (json.JSONDecodeError, OSError):
        return {"orphaned": 0, "total": 0, "pct": 0.0}

    total = len(dedup)
    if total == 0:
        return {"orphaned": 0, "total": 0, "pct": 0.0}

    # Collect all news IDs from last 7 days of JSONL files
    jsonl_ids: set[str] = set()
    today = datetime.now()
    for d in range(0, 8):
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        for ext in ("json", "jsonl"):
            jsonl_path = os.path.join(base_dir, "data", "news", f"{date_str}.{ext}")
            if os.path.exists(jsonl_path):
                try:
                    with open(jsonl_path, "r", encoding="utf-8") as f:
                        for line in f:
                            line = line.strip()
                            if not line:
                                continue
                            try:
                                item = json.loads(line)
                                jsonl_ids.add(item.get("id", ""))
                            except json.JSONDecodeError:
                                pass
                except OSError:
                    continue

    orphaned = sum(
        1 for url_hash, entry in dedup.items()
        if entry.get("news_id", "") not in jsonl_ids
    )
    pct = (orphaned / total * 100) if total > 0 else 0.0
    return {"orphaned": orphaned, "total": total, "pct": pct}


def check_source_concentration(base_dir: str) -> list[tuple[str, float]]:
    """Check source concentration: any single source > 50% of items.

    Returns list of (source_id, pct) where pct > 50.
    """
    base_dir = base_dir.rstrip("/")
    today_str = datetime.now().strftime("%Y-%m-%d")
    metrics_path = os.path.join(base_dir, "data", "metrics", f"daily-{today_str}.json")

    if not os.path.exists(metrics_path):
        return []

    try:
        with open(metrics_path, "r", encoding="utf-8") as f:
            m = json.load(f)
    except (json.JSONDecodeError, OSError):
        return []

    per_source = m.get("per_source", {})
    total_fetched = m.get("items", {}).get("fetched", 0)

    if total_fetched == 0 or not per_source:
        return []

    result: list[tuple[str, float]] = []
    for source_id, stats in per_source.items():
        source_fetched = stats.get("fetched", 0)
        pct = (source_fetched / total_fetched * 100) if total_fetched > 0 else 0.0
        if pct > 50:
            result.append((source_id, pct))
    return result


def check_long_stable_events(
    base_dir: str, threshold_days: int = 14
) -> list[tuple[str, str, int]]:
    """Check for events that have been stable for > threshold_days.

    Returns list of (event_id, title, days_stable).
    """
    base_dir = base_dir.rstrip("/")
    events_path = os.path.join(base_dir, "data", "events", "active.json")
    if not os.path.exists(events_path):
        return []

    try:
        with open(events_path, "r", encoding="utf-8") as f:
            events = json.load(f)
    except (json.JSONDecodeError, OSError):
        return []

    if not isinstance(events, list):
        return []

    now = datetime.now(timezone.utc)
    result: list[tuple[str, str, int]] = []
    for e in events:
        if e.get("status") == "stable":
            try:
                last_updated = datetime.fromisoformat(
                    e["last_updated"].replace("Z", "+00:00")
                )
                days = (now - last_updated).days
                if days > threshold_days:
                    result.append((e.get("id", "?"), e.get("title", "?"), days))
            except (KeyError, ValueError):
                pass
    return result


def check_source_success_rates(
    base_dir: str, days: int = 7
) -> list[tuple[str, float, int, int]]:
    """Check source success rates over the last N days.

    Returns list of (source_id, rate_pct, successes, totals).
    Only includes sources with < 50% success rate.
    """
    base_dir = base_dir.rstrip("/")
    sources_path = os.path.join(base_dir, "config", "sources.json")
    if not os.path.exists(sources_path):
        return []

    try:
        with open(sources_path, "r", encoding="utf-8") as f:
            sources = json.load(f)
    except (json.JSONDecodeError, OSError):
        return []

    # Collect per-source stats from last N days of metrics
    today = datetime.now()
    source_stats: dict[str, dict[str, int]] = {}
    for d in range(0, days + 1):
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        metrics_path = os.path.join(base_dir, "data", "metrics", f"daily-{date_str}.json")
        if os.path.exists(metrics_path):
            try:
                with open(metrics_path, "r", encoding="utf-8") as f:
                    m = json.load(f)
                per_source = m.get("per_source", {})
                for sid, stats in per_source.items():
                    if sid not in source_stats:
                        source_stats[sid] = {"success": 0, "total": 0}
                    if stats.get("status") == "success":
                        source_stats[sid]["success"] += 1
                    source_stats[sid]["total"] += 1
            except (json.JSONDecodeError, KeyError, OSError):
                pass

    if not source_stats:
        return []

    result: list[tuple[str, float, int, int]] = []
    for sid, stats in source_stats.items():
        if stats["total"] > 0:
            rate = stats["success"] / stats["total"] * 100
            result.append((sid, rate, stats["success"], stats["total"]))
    return result


def check_all_source_failure(base_dir: str) -> bool:
    """Check if all sources failed for the last 2 consecutive days.

    Returns True if all sources failed on both days.
    """
    base_dir = base_dir.rstrip("/")
    today = datetime.now()
    metrics_files: list[dict] = []
    for d in range(1, 3):  # yesterday and day before
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        path = os.path.join(base_dir, "data", "metrics", f"daily-{date_str}.json")
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    m = json.load(f)
                metrics_files.append(m)
            except (json.JSONDecodeError, KeyError, OSError):
                pass

    if len(metrics_files) != 2:
        return False

    for m in metrics_files:
        src = m.get("sources", {})
        total = src.get("total", 0)
        failed = src.get("failed", 0)
        if total == 0 or failed != total:
            return False
    return True


def check_budget_ratio(base_dir: str) -> tuple[float, int, int]:
    """Check LLM budget usage ratio.

    Returns (ratio, calls, limit). ratio is 0.0 if budget.json not found.
    """
    base_dir = base_dir.rstrip("/")
    budget_path = os.path.join(base_dir, "config", "budget.json")
    if not os.path.exists(budget_path):
        return (0.0, 0, 0)
    try:
        with open(budget_path, "r", encoding="utf-8") as f:
            b = json.load(f)
        calls = b.get("calls_today", 0)
        limit = b.get("daily_llm_call_limit", 1)
        if limit == 0:
            limit = 1
        ratio = calls / limit
        return (ratio, calls, limit)
    except (json.JSONDecodeError, OSError, KeyError):
        return (0.0, 0, 0)


def check_dedup_drift(base_dir: str) -> tuple[int, int, float]:
    """Check drift between dedup-index and JSONL.

    Returns (index_count, jsonl_count, drift_pct).
    """
    base_dir = base_dir.rstrip("/")
    dedup_path = os.path.join(base_dir, "data", "news", "dedup-index.json")
    if not os.path.exists(dedup_path):
        return (0, 0, 0.0)

    try:
        with open(dedup_path, "r", encoding="utf-8") as f:
            dedup = json.load(f)
        index_count = len(dedup)
    except (json.JSONDecodeError, OSError):
        return (0, 0, 0.0)

    # Count unique URLs from last 7 days
    jsonl_urls: set[str] = set()
    today = datetime.now()
    for d in range(0, 8):
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        for ext in ("json", "jsonl"):
            jsonl_path = os.path.join(base_dir, "data", "news", f"{date_str}.{ext}")
            if os.path.exists(jsonl_path):
                try:
                    with open(jsonl_path, "r", encoding="utf-8") as f:
                        for line in f:
                            line = line.strip()
                            if not line:
                                continue
                            try:
                                item = json.loads(line)
                                url = item.get("normalized_url", item.get("url", ""))
                                if url:
                                    jsonl_urls.add(url)
                            except json.JSONDecodeError:
                                pass
                except OSError:
                    continue

    jsonl_count = len(jsonl_urls)
    if index_count == 0 and jsonl_count == 0:
        return (index_count, jsonl_count, 0.0)
    diff_pct = abs(index_count - jsonl_count) / max(index_count, jsonl_count, 1) * 100
    return (index_count, jsonl_count, diff_pct)


def check_empty_events(base_dir: str) -> list[str]:
    """Check for events with empty item_ids.

    Returns list of event IDs.
    """
    base_dir = base_dir.rstrip("/")
    events_path = os.path.join(base_dir, "data", "events", "active.json")
    if not os.path.exists(events_path):
        return []
    try:
        with open(events_path, "r", encoding="utf-8") as f:
            events = json.load(f)
    except (json.JSONDecodeError, OSError):
        return []
    if not isinstance(events, list):
        return []
    return [e.get("id", "?") for e in events if len(e.get("item_ids", [])) == 0]


def check_preference_extremes(base_dir: str) -> list[tuple[str, float, str]]:
    """Check topic_weights for extreme values (> 0.95 or < 0.05).

    Returns list of (topic, weight, direction).
    """
    base_dir = base_dir.rstrip("/")
    prefs_path = os.path.join(base_dir, "config", "preferences.json")
    if not os.path.exists(prefs_path):
        return []
    try:
        with open(prefs_path, "r", encoding="utf-8") as f:
            prefs = json.load(f)
    except (json.JSONDecodeError, OSError):
        return []
    weights = prefs.get("topic_weights", {})
    result: list[tuple[str, float, str]] = []
    for topic, weight in weights.items():
        if weight > 0.95:
            result.append((topic, weight, "high"))
        elif weight < 0.05:
            result.append((topic, weight, "low"))
    return result


def check_cache_sizes(base_dir: str) -> list[tuple[str, int, bool]]:
    """Check cache file sizes.

    Returns list of (name, count, is_large) where is_large means > 5000 entries.
    """
    base_dir = base_dir.rstrip("/")
    caches = [
        ("classify-cache.json", os.path.join(base_dir, "data", "cache", "classify-cache.json")),
        ("summary-cache.json", os.path.join(base_dir, "data", "cache", "summary-cache.json")),
    ]
    result: list[tuple[str, int, bool]] = []
    for name, path in caches:
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                count = len(data)
                result.append((name, count, count > 5000))
            except (json.JSONDecodeError, OSError):
                result.append((name, -1, False))
    return result


if __name__ == "__main__":
    pass
