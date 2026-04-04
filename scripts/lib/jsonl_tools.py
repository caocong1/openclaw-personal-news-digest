from __future__ import annotations

import glob
import json
import os
from datetime import datetime, timedelta, timezone


def atomic_write_jsonl(path: str, entries: list[dict]) -> None:
    """Write a JSONL file atomically using .tmp rename pattern."""
    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        for entry in entries:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    os.rename(tmp_path, path)


def read_jsonl(path: str) -> list[dict]:
    """Read a JSONL file and return a list of dicts."""
    if not os.path.exists(path):
        return []
    entries = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entries.append(json.loads(line))
    return entries


def append_jsonl(path: str, entry: dict) -> None:
    """Append a single JSON dict as a newline to a JSONL file atomically."""
    existing = ""
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            existing = f.read()
    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        if existing:
            f.write(existing)
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    os.rename(tmp_path, path)


def latest_jsonl_dir(
    dir_path: str, pattern: str
) -> tuple[str, list[dict]] | None:
    """Find the most recent file matching pattern in dir_path.

    Searches up to 7 days back for files matching the glob pattern.
    Returns (path, parsed entries) or None if no file found.
    """
    today = datetime.now()
    for d in range(0, 8):
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        # Replace {date} placeholder with actual date
        search_pattern = pattern.replace("{date}", date_str)
        full_pattern = os.path.join(dir_path, search_pattern)
        candidates = sorted(glob.glob(full_pattern), reverse=True)
        for path in candidates:
            try:
                entries = read_jsonl(path)
                if entries:
                    return path, entries
            except (OSError, json.JSONDecodeError):
                continue
    return None


if __name__ == "__main__":
    pass
