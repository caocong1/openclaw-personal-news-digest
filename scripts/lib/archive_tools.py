from __future__ import annotations

import json
import os
from datetime import datetime, timezone, timedelta


def cleanup_dedup_index(path: str, ttl_days: int = 7) -> int:
    """Remove entries older than ttl_days from dedup-index.json.

    Uses atomic write via .tmp rename.
    Returns number of entries removed.
    """
    if not os.path.exists(path):
        return 0

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return 0

    original_count = len(data)
    cutoff = datetime.now(timezone.utc) - timedelta(days=ttl_days)
    cleaned: dict = {}

    for key, entry in data.items():
        fetched_at = entry.get("fetched_at", "")
        if fetched_at:
            try:
                ts = datetime.fromisoformat(fetched_at.replace("Z", "+00:00"))
                if ts >= cutoff:
                    cleaned[key] = entry
                    continue
            except ValueError:
                pass
        # Keep entries without valid fetched_at
        cleaned[key] = entry

    removed = original_count - len(cleaned)

    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(cleaned, f, indent=2, ensure_ascii=False)
    os.rename(tmp_path, path)

    return removed


def cleanup_feedback(path: str, ttl_days: int = 90) -> int:
    """Remove entries older than ttl_days from feedback log.jsonl.

    Uses atomic write via .tmp rename.
    Returns number of entries removed.
    """
    if not os.path.exists(path):
        return 0

    cutoff = datetime.now(timezone.utc) - timedelta(days=ttl_days)
    kept: list[str] = []
    removed = 0

    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    ts_str = entry.get("timestamp", "")
                    if ts_str:
                        ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                        if ts < cutoff:
                            removed += 1
                            continue
                    kept.append(line)
                except (json.JSONDecodeError, ValueError):
                    kept.append(line)
    except OSError:
        return 0

    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        for line in kept:
            f.write(line + "\n")
    os.rename(tmp_path, path)

    return removed


def cleanup_cache_entry(cache_path: str, ttl_days: int = 7) -> int:
    """Remove entries older than ttl_days from a cache JSON file.

    Works on classify-cache.json and summary-cache.json.
    Uses atomic write via .tmp rename.
    Returns number of entries removed.
    """
    if not os.path.exists(cache_path):
        return 0

    try:
        with open(cache_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, OSError):
        return 0

    original_count = len(data)
    cutoff = datetime.now(timezone.utc) - timedelta(days=ttl_days)
    cleaned: dict = {}

    for key, entry in data.items():
        cached_at = entry.get("cached_at", "")
        if cached_at:
            try:
                ts = datetime.fromisoformat(cached_at.replace("Z", "+00:00"))
                if ts < cutoff:
                    continue
            except ValueError:
                pass
        cleaned[key] = entry

    removed = original_count - len(cleaned)

    tmp_path = cache_path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(cleaned, f, indent=2, ensure_ascii=False)
    os.rename(tmp_path, cache_path)

    return removed


if __name__ == "__main__":
    pass
