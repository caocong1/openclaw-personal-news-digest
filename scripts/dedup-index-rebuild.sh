#!/bin/bash
# Rebuild dedup-index.json from recent JSONL files (last 7 days)
# Usage: bash scripts/dedup-index-rebuild.sh [base_dir]
#
# This script scans JSONL news files from the last 7 days and reconstructs
# the dedup-index.json file. Useful for:
#   - Recovery from index corruption
#   - Periodic index cleanup (removing entries older than 7 days)
#   - Manual maintenance

set -euo pipefail

BASE_DIR="${1:-.}"
NEWS_DIR="$BASE_DIR/data/news"
INDEX_FILE="$NEWS_DIR/dedup-index.json"
TEMP_FILE="$INDEX_FILE.tmp.rebuild"

# Verify news directory exists
if [ ! -d "$NEWS_DIR" ]; then
  echo "Error: News directory not found: $NEWS_DIR" >&2
  exit 1
fi

# Start with empty index
echo "{}" > "$TEMP_FILE"

# Process JSONL files from last 7 days
JSONL_COUNT=0
ENTRY_COUNT=0

for f in $(find "$NEWS_DIR" -name "*.jsonl" -mtime -7 2>/dev/null | sort); do
  JSONL_COUNT=$((JSONL_COUNT + 1))
  while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    id=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
    source_id=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('source_id',''))" 2>/dev/null)
    fetched_at=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('fetched_at',''))" 2>/dev/null)

    if [ -n "$id" ]; then
      python3 -c "
import json, sys
idx = json.load(open('$TEMP_FILE'))
idx['$id'] = {'news_id': '$id', 'source_id': '$source_id', 'fetched_at': '$fetched_at'}
json.dump(idx, open('$TEMP_FILE', 'w'), ensure_ascii=False, indent=2)
"
      ENTRY_COUNT=$((ENTRY_COUNT + 1))
    fi
  done < "$f"
done

# Atomic rename
mv "$TEMP_FILE" "$INDEX_FILE"

echo "Rebuilt dedup-index from $JSONL_COUNT JSONL files"
echo "Total entries: $(python3 -c "import json; print(len(json.load(open('$INDEX_FILE'))))" 2>/dev/null || echo "$ENTRY_COUNT")"
