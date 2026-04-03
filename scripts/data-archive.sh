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

set -euo pipefail

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
# 2-4. Dedup-index, Feedback, and Cache cleanup (single Python call)
# ─────────────────────────────────────────────────────────

RESULTS=$(python3 - "$BASE_DIR" <<'PY'
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from scripts.lib import archive_tools

base = sys.argv[1]
results = {"dedup": 0, "feedback": 0, "cache": 0}

# Dedup-index cleanup
dedup_path = os.path.join(base, "data", "news", "dedup-index.json")
if os.path.exists(dedup_path):
    results["dedup"] = archive_tools.cleanup_dedup_index(dedup_path, ttl_days=7)
else:
    results["dedup"] = None  # signals NOT_FOUND

# Feedback cleanup
feedback_path = os.path.join(base, "data", "feedback", "log.jsonl")
if os.path.exists(feedback_path):
    results["feedback"] = archive_tools.cleanup_feedback(feedback_path, ttl_days=90)
else:
    results["feedback"] = None  # signals NOT_FOUND

# Cache cleanup
for name in ("classify-cache.json", "summary-cache.json"):
    cache_path = os.path.join(base, "data", "cache", name)
    if os.path.exists(cache_path):
        removed = archive_tools.cleanup_cache_entry(cache_path, ttl_days=7)
        results["cache"] += removed

print(json.dumps(results))
PY
)

DEDUP_REMOVED=$(python3 - "$RESULTS" <<'PY' 2>/dev/null
import json, sys
d = json.loads(sys.argv[1])
v = d.get("dedup")
print(v if v is not None else "skip")
PY
)
FEEDBACK_REMOVED=$(python3 - "$RESULTS" <<'PY' 2>/dev/null
import json, sys
d = json.loads(sys.argv[1])
v = d.get("feedback")
print(v if v is not None else "skip")
PY
)
CACHE_TOTAL_REMOVED=$(python3 - "$RESULTS" <<'PY' 2>/dev/null
import json, sys
d = json.loads(sys.argv[1])
print(d.get("cache", 0))
PY
)

if [ "$DEDUP_REMOVED" = "skip" ] || [ -z "$DEDUP_REMOVED" ]; then
  echo "Dedup-index: file not found, skipping"
  DEDUP_REMOVED=0
fi
echo "Dedup-index entries: removed $DEDUP_REMOVED entries (TTL: 7 days)"

if [ "$FEEDBACK_REMOVED" = "skip" ] || [ -z "$FEEDBACK_REMOVED" ]; then
  echo "Feedback: log.jsonl not found, skipping"
  FEEDBACK_REMOVED=0
fi
echo "Feedback entries: removed $FEEDBACK_REMOVED entries (TTL: 90 days)"

# Per-file cache breakdown (no additional cleanup -- just report)
for CACHE_NAME in "classify-cache.json" "summary-cache.json"; do
  CACHE_PATH="$BASE_DIR/data/cache/$CACHE_NAME"
  if [ -f "$CACHE_PATH" ]; then
    echo "  $CACHE_NAME: present (cleanup included in total above)"
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
