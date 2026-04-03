from __future__ import annotations

import glob
import json
import os
import sys
from datetime import datetime, timedelta


def rebuild_index(base_dir: str, days: int = 7) -> dict:
    """Rebuild dedup-index.json from recent JSONL files.

    Scans data/news/YYYY-MM-DD.jsonl files from the last `days` days.
    For each line, reads id, source_id, fetched_at fields.
    Writes entries to data/news/dedup-index.json atomically.

    Returns a dict with jsonl_count and entry_count.
    """
    base_dir = base_dir.rstrip("/")
    news_dir = os.path.join(base_dir, "data", "news")
    index_file = os.path.join(news_dir, "dedup-index.json")
    temp_file = index_file + ".tmp.rebuild"

    if not os.path.isdir(news_dir):
        raise SystemExit(f"Error: News directory not found: {news_dir}")

    jsonl_count = 0
    entry_count = 0

    # Collect all entries from JSONL files in memory
    entries: dict[str, dict] = {}
    today = datetime.now()
    for d in range(0, days + 1):
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        pattern = os.path.join(news_dir, f"{date_str}.json")
        # Also match .jsonl extension
        for filepath in sorted(glob.glob(pattern)):
            jsonl_count += 1
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            item = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        item_id = item.get("id", "")
                        if not item_id:
                            continue
                        entries[item_id] = {
                            "news_id": item_id,
                            "source_id": item.get("source_id", ""),
                            "fetched_at": item.get("fetched_at", ""),
                        }
                        entry_count += 1
            except OSError:
                continue

    # Atomic write
    tmp_path = temp_file
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2, ensure_ascii=False)
    os.rename(tmp_path, index_file)

    return {"jsonl_count": jsonl_count, "entry_count": entry_count}


def count_index_entries(index_path: str) -> int:
    """Read dedup-index.json and return entry count."""
    if not os.path.exists(index_path):
        return 0
    try:
        with open(index_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return len(data)
    except (json.JSONDecodeError, OSError):
        return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 -m scripts.lib.dedup_tools <base_dir> [days]")
        raise SystemExit(1)
    base = sys.argv[1]
    days = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    result = rebuild_index(base, days)
    print(f"Rebuilt dedup-index from {result['jsonl_count']} JSONL files")
    print(f"Total entries: {result['entry_count']}")
