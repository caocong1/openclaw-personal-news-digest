#!/bin/bash
# Health check: validate data consistency
# Usage: bash scripts/health-check.sh [base_dir]

BASE_DIR="${1:-.}"
ERRORS=0

echo "=== News Digest Health Check ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. Check dedup-index exists and is valid JSON
if [ -f "$BASE_DIR/data/news/dedup-index.json" ]; then
  python3 -c "import json; json.load(open('$BASE_DIR/data/news/dedup-index.json'))" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "ERROR: dedup-index.json is not valid JSON"
    ERRORS=$((ERRORS + 1))
  else
    COUNT=$(python3 -c "import json; print(len(json.load(open('$BASE_DIR/data/news/dedup-index.json'))))")
    echo "OK: dedup-index.json has $COUNT entries"
  fi
else
  echo "WARN: dedup-index.json not found"
fi

# 2. Check budget.json date is current
if [ -f "$BASE_DIR/config/budget.json" ]; then
  BUDGET_DATE=$(python3 -c "import json; print(json.load(open('$BASE_DIR/config/budget.json')).get('current_date',''))")
  TODAY=$(date +%Y-%m-%d)
  if [ "$BUDGET_DATE" != "$TODAY" ]; then
    echo "INFO: budget.json date is $BUDGET_DATE (today: $TODAY) -- counters will reset on next run"
  else
    CALLS=$(python3 -c "import json; b=json.load(open('$BASE_DIR/config/budget.json')); print(f\"{b['calls_today']}/{b['daily_llm_call_limit']}\")")
    echo "OK: budget today: $CALLS calls"
  fi
fi

# 3. Check for stale lock files
if [ -f "$BASE_DIR/data/.lock" ]; then
  LOCK_AGE=$(python3 -c "
import json, datetime
lock = json.load(open('$BASE_DIR/data/.lock'))
started = datetime.datetime.fromisoformat(lock['started_at'].replace('Z','+00:00'))
age = (datetime.datetime.now(datetime.timezone.utc) - started).total_seconds() / 60
print(f'{age:.0f}')
" 2>/dev/null)
  if [ -n "$LOCK_AGE" ] && [ "$LOCK_AGE" -gt 15 ]; then
    echo "WARN: Stale lock file found (age: ${LOCK_AGE}min > 15min)"
  else
    echo "INFO: Active lock file (age: ${LOCK_AGE}min)"
  fi
fi

# 4. Check for orphaned temp files
TEMP_COUNT=$(find "$BASE_DIR/data" -name "*.tmp.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TEMP_COUNT" -gt 0 ]; then
  echo "WARN: $TEMP_COUNT orphaned temp files found in data/"
  ERRORS=$((ERRORS + 1))
fi

# 5. Check today's JSONL exists (after first run)
TODAY_FILE="$BASE_DIR/data/news/$(date +%Y-%m-%d).jsonl"
if [ -f "$TODAY_FILE" ]; then
  LINES=$(wc -l < "$TODAY_FILE" | tr -d ' ')
  echo "OK: today's JSONL has $LINES items"
else
  echo "INFO: no JSONL file for today yet"
fi

# 6. Check latest digest
if [ -f "$BASE_DIR/output/latest-digest.md" ]; then
  DIGEST_DATE=$(head -1 "$BASE_DIR/output/latest-digest.md" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' || echo "unknown")
  echo "OK: latest digest date: $DIGEST_DATE"
else
  echo "INFO: no digest generated yet"
fi

echo ""
echo "=== Health check complete: $ERRORS error(s) ==="
exit $ERRORS
