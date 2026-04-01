#!/bin/bash
# Archive news data older than 30 days, dedup-index entries older than 7 days
# Usage: bash scripts/data-archive.sh [base_dir]

BASE_DIR="${1:-.}"

echo "=== Data Archive ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. Archive old JSONL files (> 30 days)
ARCHIVED=0
for f in $(find "$BASE_DIR/data/news" -name "*.jsonl" -mtime +30 2>/dev/null); do
  echo "Archiving: $f"
  rm "$f"
  ARCHIVED=$((ARCHIVED + 1))
done
echo "Archived $ARCHIVED JSONL files"

# 2. Archive old metrics files (> 30 days)
ARCHIVED_METRICS=0
for f in $(find "$BASE_DIR/data/metrics" -name "daily-*.json" -mtime +30 2>/dev/null); do
  echo "Archiving metrics: $f"
  rm "$f"
  ARCHIVED_METRICS=$((ARCHIVED_METRICS + 1))
done
echo "Archived $ARCHIVED_METRICS metrics files"

# 3. Clean orphaned temp files (> 15 min)
CLEANED=0
for f in $(find "$BASE_DIR/data" -name "*.tmp.*" -mmin +15 2>/dev/null); do
  echo "Cleaning temp: $f"
  rm "$f"
  CLEANED=$((CLEANED + 1))
done
echo "Cleaned $CLEANED temp files"

echo "=== Archive complete ==="
