#!/bin/bash
# Health check: validate data consistency, alert conditions, and weekly inspection
# Usage: bash scripts/health-check.sh [base_dir] [--mode daily|weekly]
#
# Modes:
#   daily  (default) - Quick checks + MON-02 alert conditions
#   weekly           - Full inspection (daily checks + MON-03 inspection checklist)
#
# Output prefixes:
#   ALERT: - Actionable alert condition (grep-filterable)
#   WARN:  - Warning, non-critical finding
#   INFO:  - Informational note
#   OK:    - Check passed

set -euo pipefail

BASE_DIR="${1:-.}"
MODE="daily"

# Parse --mode flag
shift
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "$MODE" != "daily" && "$MODE" != "weekly" ]]; then
  echo "ERROR: Invalid mode '$MODE'. Use 'daily' or 'weekly'."
  exit 1
fi

ERRORS=0
ALERTS=0
WARNINGS=0

echo "=== News Digest Health Check (mode: $MODE) ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ─────────────────────────────────────────────────────────
# DAILY MODE: Existing checks (1-6) + MON-02 alert conditions (7-11)
# ─────────────────────────────────────────────────────────

echo "--- Basic Checks ---"

# 1. Check dedup-index exists and is valid JSON
if [ -f "$BASE_DIR/data/news/dedup-index.json" ]; then
  DEDUP_VALID=true
  DEDUP_COUNT=0
  python3 - "$BASE_DIR" <<'PY' 2>/dev/null
import json, os, sys
base = sys.argv[1]
path = os.path.join(base, "data", "news", "dedup-index.json")
try:
    data = json.load(open(path))
    print(f"VALID:{len(data)}")
except (json.JSONDecodeError, OSError):
    print("INVALID")
PY
  DEDUP_RESULT=$?
  DEDUP_OUTPUT=$(python3 - "$BASE_DIR" <<'PY' 2>/dev/null
import json, os, sys
base = sys.argv[1]
path = os.path.join(base, "data", "news", "dedup-index.json")
try:
    data = json.load(open(path))
    print(len(data))
except (json.JSONDecodeError, OSError):
    print("-1")
PY
)
  if [ "$DEDUP_OUTPUT" = "-1" ]; then
    echo "ERROR: dedup-index.json is not valid JSON"
    ERRORS=$((ERRORS + 1))
  elif [ "$DEDUP_OUTPUT" = "0" ]; then
    echo "OK: dedup-index.json is valid but empty"
  else
    echo "OK: dedup-index.json has $DEDUP_OUTPUT entries"
  fi
else
  echo "WARN: dedup-index.json not found"
  WARNINGS=$((WARNINGS + 1))
fi

# 2. Check budget.json date is current
if [ -f "$BASE_DIR/config/budget.json" ]; then
  python3 - "$BASE_DIR" <<'PY' 2>/dev/null
import json, os, sys
from datetime import datetime
base = sys.argv[1]
path = os.path.join(base, "config", "budget.json")
try:
    b = json.load(open(path))
    budget_date = b.get("current_date", "")
    today = datetime.now().strftime("%Y-%m-%d")
    calls = b.get("calls_today", 0)
    limit = b.get("daily_llm_call_limit", 0)
    if budget_date != today:
        print(f"DATE_MISMATCH:{budget_date}:{today}")
    else:
        print(f"OK:{calls}:{limit}")
except (json.JSONDecodeError, OSError, KeyError):
    print("ERROR")
PY
  BUDGET_CHECK=$(python3 - "$BASE_DIR" <<'PY' 2>/dev/null
import json, os, sys
from datetime import datetime
base = sys.argv[1]
path = os.path.join(base, "config", "budget.json")
try:
    b = json.load(open(path))
    budget_date = b.get("current_date", "")
    today = datetime.now().strftime("%Y-%m-%d")
    calls = b.get("calls_today", 0)
    limit = b.get("daily_llm_call_limit", 0)
    if budget_date != today:
        print(f"DATE_MISMATCH:{budget_date}:{today}")
    else:
        print(f"OK:{calls}:{limit}")
except (json.JSONDecodeError, OSError, KeyError):
    print("ERROR")
PY
)
  if [[ "$BUDGET_CHECK" == ERROR ]]; then
    echo "INFO: budget.json read error"
  elif [[ "$BUDGET_CHECK" == DATE_MISMATCH:* ]]; then
    BUDGET_DATE="${BUDGET_CHECK#DATE_MISMATCH:}"
    BUDGET_DATE="${BUDGET_DATE%:*}"
    TODAY_DATE="${BUDGET_CHECK##*:}"
    echo "INFO: budget.json date is $BUDGET_DATE (today: $TODAY_DATE) -- counters will reset on next run"
  else
    BUDGET_CALLS="${BUDGET_CHECK#OK:}"
    BUDGET_CALLS="${BUDGET_CALLS%:*}"
    BUDGET_LIMIT="${BUDGET_CHECK##*:}"
    echo "OK: budget today: ${BUDGET_CALLS}/${BUDGET_LIMIT} calls"
  fi
fi

# 3. Check for stale lock files
LOCK_AGE="0"
if [ -f "$BASE_DIR/data/.lock" ]; then
  LOCK_AGE=$(python3 - "$BASE_DIR/data/.lock" <<'PY' 2>/dev/null
import json, datetime, sys
try:
    lock = json.load(open(sys.argv[1]))
    started = datetime.datetime.fromisoformat(lock["started_at"].replace("Z", "+00:00"))
    age = (datetime.datetime.now(datetime.timezone.utc) - started).total_seconds() / 60
    print(f"{age:.0f}")
except (json.JSONDecodeError, OSError, KeyError):
    print("-1")
PY
)
  if [ -n "$LOCK_AGE" ] && [ "$LOCK_AGE" != "-1" ] && [ "$LOCK_AGE" -gt 15 ]; then
    echo "WARN: Stale lock file found (age: ${LOCK_AGE}min > 15min)"
    WARNINGS=$((WARNINGS + 1))
  elif [ -n "$LOCK_AGE" ] && [ "$LOCK_AGE" != "-1" ]; then
    echo "INFO: Active lock file (age: ${LOCK_AGE}min)"
  fi
fi

# 4. Check for orphaned temp files
TEMP_COUNT=$(find "$BASE_DIR/data" -name "*.tmp.*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TEMP_COUNT" -gt 0 ]; then
  echo "WARN: $TEMP_COUNT orphaned temp files found in data/"
  WARNINGS=$((WARNINGS + 1))
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
echo "--- MON-02 Alert Conditions ---"

# 7. All-source failure alert: 2 consecutive days with all sources failed
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
base = sys.argv[1]
from datetime import datetime, timedelta

today = datetime.now()
metrics_files = []
for d in range(1, 3):
    date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
    path = os.path.join(base, "data", "metrics", f"daily-{date_str}.json")
    if os.path.exists(path):
        try:
            m = json.load(open(path))
            metrics_files.append(m)
        except (json.JSONDecodeError, KeyError):
            pass

if len(metrics_files) == 2:
    all_failed = True
    for m in metrics_files:
        src = m.get("sources", {})
        total = src.get("total", 0)
        failed = src.get("failed", 0)
        if total == 0 or failed != total:
            all_failed = False
            break
    if all_failed:
        print("ALERT: All sources failed for 2 consecutive days")
    else:
        print("OK: Source availability within normal range")
elif len(metrics_files) < 2:
    print("INFO: Not enough metrics history for source failure check (need 2 days)")
else:
    print("OK: Source availability within normal range")
PY

# 8. Budget alert: 80% or 100% of daily LLM call limit
if [ -f "$BASE_DIR/config/budget.json" ]; then
  python3 - "$BASE_DIR" <<'PY'
import json, os, sys
base = sys.argv[1]
path = os.path.join(base, "config", "budget.json")
try:
    b = json.load(open(path))
    calls = b.get("calls_today", 0)
    limit = b.get("daily_llm_call_limit", 1)
    if limit == 0:
        limit = 1
    ratio = calls / limit
    if ratio >= 1.0:
        print(f"ALERT: LLM budget EXHAUSTED -- circuit breaker active ({calls}/{limit} calls, {ratio*100:.0f}%)")
    elif ratio >= 0.80:
        print(f"ALERT: LLM budget at {ratio*100:.0f}% ({calls}/{limit} calls)")
    else:
        print(f"OK: LLM budget at {ratio*100:.0f}% ({calls}/{limit} calls)")
except (json.JSONDecodeError, OSError, KeyError):
    print("INFO: Could not read budget.json")
PY
else
  echo "INFO: budget.json not found, skipping budget alert"
fi

# 9. Dedup-index consistency: orphaned entries
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
base = sys.argv[1]
from datetime import datetime, timedelta
import glob

dedup_path = os.path.join(base, "data", "news", "dedup-index.json")
if not os.path.exists(dedup_path):
    print("INFO: dedup-index.json not found, skipping consistency check")
    exit(0)

try:
    dedup = json.load(open(dedup_path))
except (json.JSONDecodeError, OSError):
    print("INFO: Could not read dedup-index.json")
    exit(0)

total = len(dedup)
if total == 0:
    print("OK: dedup-index is empty, no consistency check needed")
    exit(0)

jsonl_ids = set()
today = datetime.now()
for d in range(0, 8):
    date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
    for ext in ("json", "jsonl"):
        jsonl_path = os.path.join(base, "data", "news", f"{date_str}.{ext}")
        if os.path.exists(jsonl_path):
            try:
                with open(jsonl_path) as f:
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
                pass

orphaned = 0
for url_hash, entry in dedup.items():
    news_id = entry.get("news_id", "")
    if news_id not in jsonl_ids:
        orphaned += 1

pct = (orphaned / total * 100) if total > 0 else 0
if pct > 10:
    print(f"ALERT: Dedup-index has {orphaned} orphaned entries ({pct:.0f}% of {total} total)")
else:
    print(f"OK: Dedup-index consistency -- {orphaned}/{total} orphaned entries ({pct:.0f}%)")
PY

# 10. Source concentration alert: any single source > 50%
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
base = sys.argv[1]
from datetime import datetime

base = sys.argv[1]
today_str = datetime.now().strftime("%Y-%m-%d")
metrics_path = os.path.join(base, "data", "metrics", f"daily-{today_str}.json")

if not os.path.exists(metrics_path):
    print("INFO: No metrics for today, skipping source concentration check")
    exit(0)

try:
    m = json.load(open(metrics_path))
except (json.JSONDecodeError, OSError):
    print("INFO: Could not read today's metrics")
    exit(0)

per_source = m.get("per_source", {})
total_fetched = m.get("items", {}).get("fetched", 0)

if total_fetched == 0:
    print("INFO: No items fetched today, skipping source concentration check")
    exit(0)

if per_source:
    for source_id, stats in per_source.items():
        source_fetched = stats.get("fetched", 0)
        pct = (source_fetched / total_fetched * 100) if total_fetched > 0 else 0
        if pct > 50:
            print(f"ALERT: Source concentration -- {source_id} accounts for {pct:.0f}% of items")
            exit(0)
    print("OK: No single source exceeds 50% concentration")
else:
    print("INFO: No per-source breakdown available in today's metrics")
PY

# 11. Empty digest alert: items fetched but no digest generated
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
base = sys.argv[1]
from datetime import datetime

today_str = datetime.now().strftime("%Y-%m-%d")
metrics_path = os.path.join(base, "data", "metrics", f"daily-{today_str}.json")

if not os.path.exists(metrics_path):
    print("INFO: No metrics for today, skipping empty digest check")
    exit(0)

try:
    m = json.load(open(metrics_path))
except (json.JSONDecodeError, OSError):
    print("INFO: Could not read today's metrics")
    exit(0)

fetched = m.get("items", {}).get("fetched", 0)
generated = m.get("output", {}).get("generated", False)

if fetched > 0 and not generated:
    print(f"ALERT: Items fetched ({fetched}) but no digest generated")
elif fetched == 0:
    print("INFO: No items fetched today")
else:
    print("OK: Digest generated successfully")
PY

# ─────────────────────────────────────────────────────────
# WEEKLY MODE: Additional MON-03 inspection checks (12-17)
# ─────────────────────────────────────────────────────────

if [ "$MODE" = "weekly" ]; then

echo ""
echo "--- MON-03 Weekly Inspection ---"

# 12. Dedup-index rebuild check: drift between index and JSONL
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
from datetime import datetime, timedelta

base = sys.argv[1]
dedup_path = os.path.join(base, "data", "news", "dedup-index.json")
if not os.path.exists(dedup_path):
    print("INFO: dedup-index.json not found, skipping rebuild check")
    exit(0)

try:
    dedup = json.load(open(dedup_path))
    index_count = len(dedup)
except (json.JSONDecodeError, OSError):
    print("INFO: Could not read dedup-index.json")
    exit(0)

jsonl_urls = set()
today = datetime.now()
for d in range(0, 8):
    date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
    for ext in ("json", "jsonl"):
        jsonl_path = os.path.join(base, "data", "news", f"{date_str}.{ext}")
        if os.path.exists(jsonl_path):
            try:
                with open(jsonl_path) as f:
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
                pass

jsonl_count = len(jsonl_urls)
if index_count == 0 and jsonl_count == 0:
    print("OK: Both dedup-index and JSONL are empty")
    exit(0)

diff_pct = abs(index_count - jsonl_count) / max(index_count, jsonl_count, 1) * 100
if diff_pct > 20:
    print(f"WARN: Dedup-index drift -- index has {index_count} entries, JSONL has {jsonl_count} unique URLs. Consider rebuilding.")
else:
    print(f"OK: Dedup-index aligned with JSONL (index: {index_count}, JSONL URLs: {jsonl_count}, drift: {diff_pct:.0f}%)")
PY

# 13. Empty events check: events with empty item_ids
python3 - "$BASE_DIR" <<'PY'
import json, os, sys

base = sys.argv[1]
events_path = os.path.join(base, "data", "events", "active.json")
if not os.path.exists(events_path):
    print("INFO: active.json not found, skipping empty events check")
    exit(0)

try:
    events = json.load(open(events_path))
except (json.JSONDecodeError, OSError):
    print("WARN: Could not read active.json")
    exit(0)

if not isinstance(events, list):
    print("WARN: active.json is not a list")
    exit(0)

empty_events = [e for e in events if len(e.get("item_ids", [])) == 0]
if empty_events:
    ids = ", ".join(e.get("id", "?") for e in empty_events)
    print(f"WARN: {len(empty_events)} events with empty item_ids: {ids}")
else:
    print(f"OK: All {len(events)} events have items")
PY

# 14. Long-stable events: stable for > 14 days
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
from datetime import datetime, timezone

base = sys.argv[1]
events_path = os.path.join(base, "data", "events", "active.json")
if not os.path.exists(events_path):
    print("INFO: active.json not found, skipping long-stable check")
    exit(0)

try:
    events = json.load(open(events_path))
except (json.JSONDecodeError, OSError):
    exit(0)

if not isinstance(events, list):
    exit(0)

now = datetime.now(timezone.utc)
long_stable = []
for e in events:
    if e.get("status") == "stable":
        try:
            last_updated = datetime.fromisoformat(e["last_updated"].replace("Z", "+00:00"))
            days = (now - last_updated).days
            if days > 14:
                long_stable.append((e.get("id", "?"), e.get("title", "?"), days))
        except (KeyError, ValueError):
            pass

if long_stable:
    print(f"WARN: {len(long_stable)} events stable for >14 days (consider forced archival):")
    for eid, title, days in long_stable:
        print(f"  - {eid}: \"{title}\" ({days} days)")
else:
    print("OK: No long-stable events found")
PY

# 15. Source success rates: flag sources with < 50% success over last 7 days
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
from datetime import datetime, timedelta

base = sys.argv[1]
sources_path = os.path.join(base, "config", "sources.json")
if not os.path.exists(sources_path):
    print("INFO: sources.json not found, skipping success rate check")
    exit(0)

sources = json.load(open(sources_path))
source_ids = [s["id"] for s in sources if s.get("enabled", True)]

today = datetime.now()
source_stats = {}
for d in range(0, 8):
    date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
    metrics_path = os.path.join(base, "data", "metrics", f"daily-{date_str}.json")
    if os.path.exists(metrics_path):
        try:
            m = json.load(open(metrics_path))
            per_source = m.get("per_source", {})
            for sid, stats in per_source.items():
                if sid not in source_stats:
                    source_stats[sid] = {"success": 0, "total": 0}
                if stats.get("status") == "success":
                    source_stats[sid]["success"] += 1
                source_stats[sid]["total"] += 1
        except (json.JSONDecodeError, KeyError):
            pass

if not source_stats:
    print("INFO: No per-source metrics history available")
    exit(0)

flagged = []
for sid, stats in source_stats.items():
    if stats["total"] > 0:
        rate = stats["success"] / stats["total"] * 100
        if rate < 50:
            flagged.append((sid, rate, stats["success"], stats["total"]))

if flagged:
    print(f"WARN: {len(flagged)} sources with <50% success rate (last 7 days):")
    for sid, rate, s, t in flagged:
        print(f"  - {sid}: {rate:.0f}% ({s}/{t} days successful)")
else:
    print(f"OK: All {len(source_stats)} sources above 50% success rate")
PY

# 16. Preference extreme values: topic_weight > 0.95 or < 0.05
python3 - "$BASE_DIR" <<'PY'
import json, os, sys

base = sys.argv[1]
prefs_path = os.path.join(base, "config", "preferences.json")
if not os.path.exists(prefs_path):
    print("INFO: preferences.json not found, skipping preference check")
    exit(0)

try:
    prefs = json.load(open(prefs_path))
except (json.JSONDecodeError, OSError):
    print("INFO: Could not read preferences.json")
    exit(0)

weights = prefs.get("topic_weights", {})

extremes = []
for topic, weight in weights.items():
    if weight > 0.95:
        extremes.append((topic, weight, "high"))
    elif weight < 0.05:
        extremes.append((topic, weight, "low"))

if extremes:
    print(f"WARN: {len(extremes)} preference extreme values (may indicate runaway feedback):")
    for topic, weight, direction in extremes:
        print(f"  - {topic}: {weight:.3f} (extremely {direction})")
else:
    print(f"OK: All {len(weights)} topic weights within normal range (0.05-0.95)")
PY

# 17. Cache size check: flag caches with > 5000 entries
python3 - "$BASE_DIR" <<'PY'
import json, os, sys

base = sys.argv[1]
caches = [
    ("classify-cache.json", os.path.join(base, "data", "cache", "classify-cache.json")),
    ("summary-cache.json", os.path.join(base, "data", "cache", "summary-cache.json")),
]

for name, path in caches:
    if os.path.exists(path):
        try:
            data = json.load(open(path))
            count = len(data)
            if count > 5000:
                print(f"WARN: Cache large -- {name} has {count} entries. TTL cleanup may be needed.")
            else:
                print(f"OK: {name} has {count} entries")
        except json.JSONDecodeError:
            print(f"WARN: {name} is not valid JSON")
    else:
        print(f"INFO: {name} not found")
PY

fi  # end weekly mode

# ─────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────

echo ""
echo "=== Health check complete (mode: $MODE): $ERRORS error(s), $ALERTS alert(s), $WARNINGS warning(s) ==="
exit $ERRORS
