#!/bin/bash
# Data lifecycle management: TTL-based cleanup for all data types
# Usage: bash scripts/data-archive.sh [base_dir]
#
# TTL rules:
#   News JSONL:       30 days
#   Dedup-index:       7 days (per-entry by fetched_at)
#   Feedback detail:  90 days (per-entry by timestamp)
#   Cache files:       7 days (per-entry by cached_at)
#   Metrics files:    30 days
#   Temp files:       15 minutes
#   Archived events:  permanent (no TTL)

BASE_DIR="${1:-.}"

echo "=== Data Lifecycle Management ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─────────────────────────────────────────────────────────
# 1. News JSONL (30-day TTL) -- delete files older than 30 days
# ─────────────────────────────────────────────────────────

ARCHIVED_JSONL=0
for f in $(find "$BASE_DIR/data/news" -name "*.jsonl" -mtime +30 2>/dev/null); do
  echo "Removing old JSONL: $f"
  rm "$f"
  ARCHIVED_JSONL=$((ARCHIVED_JSONL + 1))
done
echo "News JSONL: removed $ARCHIVED_JSONL files (TTL: 30 days)"

# ─────────────────────────────────────────────────────────
# 2. Dedup-index entries (7-day TTL) -- remove entries by fetched_at
# ─────────────────────────────────────────────────────────

DEDUP_REMOVED=0
DEDUP_PATH="$BASE_DIR/data/news/dedup-index.json"
if [ -f "$DEDUP_PATH" ]; then
  DEDUP_REMOVED=$(python3 -c "
import json, os
from datetime import datetime, timezone, timedelta

path = '$DEDUP_PATH'
data = json.load(open(path))
cutoff = datetime.now(timezone.utc) - timedelta(days=7)
original_count = len(data)

cleaned = {}
for key, entry in data.items():
    fetched_at = entry.get('fetched_at', '')
    if fetched_at:
        try:
            ts = datetime.fromisoformat(fetched_at.replace('Z', '+00:00'))
            if ts >= cutoff:
                cleaned[key] = entry
                continue
        except ValueError:
            pass
    # Keep entries without valid fetched_at (don't delete unknowns)
    cleaned[key] = entry

removed = original_count - len(cleaned)

# Atomic write: write to .tmp, then rename
tmp_path = path + '.tmp'
with open(tmp_path, 'w') as f:
    json.dump(cleaned, f, indent=2, ensure_ascii=False)
os.rename(tmp_path, path)

print(removed)
" 2>/dev/null)
  if [ -z "$DEDUP_REMOVED" ]; then
    DEDUP_REMOVED=0
    echo "Dedup-index: error during cleanup"
  fi
else
  echo "Dedup-index: file not found, skipping"
fi
echo "Dedup-index entries: removed $DEDUP_REMOVED entries (TTL: 7 days)"

# ─────────────────────────────────────────────────────────
# 3. Feedback detail (90-day TTL) -- remove entries by timestamp
# ─────────────────────────────────────────────────────────

FEEDBACK_REMOVED=0
FEEDBACK_PATH="$BASE_DIR/data/feedback/log.jsonl"
if [ -f "$FEEDBACK_PATH" ]; then
  FEEDBACK_REMOVED=$(python3 -c "
import json, os
from datetime import datetime, timezone, timedelta

path = '$FEEDBACK_PATH'
cutoff = datetime.now(timezone.utc) - timedelta(days=90)

kept = []
removed = 0
with open(path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            ts_str = entry.get('timestamp', '')
            if ts_str:
                ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                if ts < cutoff:
                    removed += 1
                    continue
            kept.append(line)
        except (json.JSONDecodeError, ValueError):
            kept.append(line)  # Keep entries we can't parse

# Atomic write: write to .tmp, then rename
tmp_path = path + '.tmp'
with open(tmp_path, 'w') as f:
    for line in kept:
        f.write(line + '\n')
os.rename(tmp_path, path)

print(removed)
" 2>/dev/null)
  if [ -z "$FEEDBACK_REMOVED" ]; then
    FEEDBACK_REMOVED=0
    echo "Feedback: error during cleanup"
  fi
else
  echo "Feedback: log.jsonl not found, skipping"
fi
echo "Feedback entries: removed $FEEDBACK_REMOVED entries (TTL: 90 days)"

# ─────────────────────────────────────────────────────────
# 4. Cache files (7-day TTL) -- remove entries by cached_at
# ─────────────────────────────────────────────────────────

CACHE_TOTAL_REMOVED=0
for CACHE_NAME in "classify-cache.json" "summary-cache.json"; do
  CACHE_PATH="$BASE_DIR/data/cache/$CACHE_NAME"
  if [ -f "$CACHE_PATH" ]; then
    CACHE_REMOVED=$(python3 -c "
import json, os
from datetime import datetime, timezone, timedelta

path = '$CACHE_PATH'
data = json.load(open(path))
cutoff = datetime.now(timezone.utc) - timedelta(days=7)
original_count = len(data)

cleaned = {}
for key, entry in data.items():
    cached_at = entry.get('cached_at', '')
    if cached_at:
        try:
            ts = datetime.fromisoformat(cached_at.replace('Z', '+00:00'))
            if ts < cutoff:
                continue  # Skip expired entry
        except ValueError:
            pass
    cleaned[key] = entry

removed = original_count - len(cleaned)

# Atomic write: write to .tmp, then rename
tmp_path = path + '.tmp'
with open(tmp_path, 'w') as f:
    json.dump(cleaned, f, indent=2, ensure_ascii=False)
os.rename(tmp_path, path)

print(removed)
" 2>/dev/null)
    if [ -z "$CACHE_REMOVED" ]; then
      CACHE_REMOVED=0
    fi
    CACHE_TOTAL_REMOVED=$((CACHE_TOTAL_REMOVED + CACHE_REMOVED))
    echo "  $CACHE_NAME: removed $CACHE_REMOVED entries"
  else
    echo "  $CACHE_NAME: not found, skipping"
  fi
done
echo "Cache entries: removed $CACHE_TOTAL_REMOVED total (TTL: 7 days)"

# ─────────────────────────────────────────────────────────
# 5. Metrics files (30-day TTL) -- delete files older than 30 days
# ─────────────────────────────────────────────────────────

ARCHIVED_METRICS=0
for f in $(find "$BASE_DIR/data/metrics" -name "daily-*.json" -mtime +30 2>/dev/null); do
  echo "Removing old metrics: $f"
  rm "$f"
  ARCHIVED_METRICS=$((ARCHIVED_METRICS + 1))
done
echo "Metrics files: removed $ARCHIVED_METRICS files (TTL: 30 days)"

# ─────────────────────────────────────────────────────────
# 6. Orphaned temp files (15-min TTL) -- delete old temp files
# ─────────────────────────────────────────────────────────

CLEANED_TEMP=0
for f in $(find "$BASE_DIR/data" -name "*.tmp.*" -mmin +15 2>/dev/null); do
  echo "Cleaning temp: $f"
  rm "$f"
  CLEANED_TEMP=$((CLEANED_TEMP + 1))
done
echo "Temp files: cleaned $CLEANED_TEMP files (TTL: 15 min)"

# ─────────────────────────────────────────────────────────
# 7. Archived events -- permanent storage, log count for awareness
# ─────────────────────────────────────────────────────────

ARCHIVED_EVENTS=0
if [ -d "$BASE_DIR/data/events/archived" ]; then
  ARCHIVED_EVENTS=$(find "$BASE_DIR/data/events/archived" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
fi
echo "Archived events: $ARCHIVED_EVENTS files (permanent, no TTL)"

# ─────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────

echo ""
echo "=== Data lifecycle summary ==="
echo "  News JSONL:       $ARCHIVED_JSONL files removed"
echo "  Dedup-index:      $DEDUP_REMOVED entries removed"
echo "  Feedback:         $FEEDBACK_REMOVED entries removed"
echo "  Cache:            $CACHE_TOTAL_REMOVED entries removed"
echo "  Metrics:          $ARCHIVED_METRICS files removed"
echo "  Temp files:       $CLEANED_TEMP files cleaned"
echo "  Archived events:  $ARCHIVED_EVENTS files (permanent)"
echo "=== Archive complete ==="
