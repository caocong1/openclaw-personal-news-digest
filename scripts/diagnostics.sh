#!/bin/bash
# Diagnostics: consolidated system status report
# Usage: bash scripts/diagnostics.sh [base_dir]
#
# Reads: daily metrics, alert-state, digest-history, sources, budget
# Output: Structured text report for operator inspection
#
# This is an ON-DEMAND inspection tool (not automated/cron).
# For automated alerting, use health-check.sh instead.

set -euo pipefail

BASE_DIR="${1:-.}"

echo "=== News Digest System Diagnostics ==="
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# --- Section 1: Pipeline Status ---
echo "--- 1. Pipeline Status ---"
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
from datetime import datetime, timedelta

base = sys.argv[1]

metrics = None
metrics_date = None
today = datetime.now()
for d in range(0, 8):
    date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
    path = os.path.join(base, "data", "metrics", f"daily-{date_str}.json")
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8-sig") as f:
                metrics = json.load(f)
            metrics_date = date_str
            break
        except (json.JSONDecodeError, OSError):
            continue

if not metrics:
    print("No metrics files found in last 7 days")
else:
    print(f"Latest metrics: {metrics_date}")
    print(f"Run ID: {metrics.get('run_id', 'unknown')}")
    items = metrics.get("items", {})
    print(f"Items: fetched={items.get('fetched', 0)}, processed={items.get('classified', 0)}, selected={items.get('selected_for_output', 0)}")
    llm = metrics.get("llm", {})
    print(f"LLM: calls={llm.get('calls', 0)}, cache_hits={llm.get('cache_hits', 0)}, failures={llm.get('failures', 0)}")
    output = metrics.get("output", {})
    print(f"Output: type={output.get('type', 'none')}, items={output.get('item_count', 0)}, generated={output.get('generated', False)}")
    run_log = metrics.get("run_log", [])
    if run_log:
        first = run_log[0].get("timestamp", "?")
        last = run_log[-1].get("timestamp", "?")
        duration = run_log[-1].get("details", {}).get("duration_seconds", "?")
        print(f"Run log: {len(run_log)} entries, started={first}, duration={duration}s")
    else:
        print("Run log: not available (pre-Phase 11 metrics)")
PY

echo ""

# --- Section 2: Source Health ---
echo "--- 2. Source Health ---"
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
from datetime import datetime, timedelta

base = sys.argv[1]
sources_path = os.path.join(base, "config", "sources.json")
if not os.path.exists(sources_path):
    print("sources.json not found")
else:
    sources = json.load(open(sources_path))
    enabled = [s for s in sources if s.get("enabled", True)]
    disabled = [s for s in sources if not s.get("enabled", True)]
    degraded = [s for s in sources if s.get("status") == "degraded"]
    print(f"Sources: {len(enabled)} enabled, {len(disabled)} disabled, {len(degraded)} degraded")
    if degraded:
        for s in degraded:
            print(f"  DEGRADED: {s['id']} ({s.get('name', '?')}), since={s.get('stats', {}).get('degraded_since', '?')}")
    today = datetime.now()
    for d in range(0, 3):
        date_str = (today - timedelta(days=d)).strftime("%Y-%m-%d")
        path = os.path.join(base, "data", "metrics", f"daily-{date_str}.json")
        if os.path.exists(path):
            try:
                m = json.load(open(path))
                per_source = m.get("per_source", {})
                if per_source:
                    failed = [sid for sid, st in per_source.items() if st.get("status") == "failed"]
                    if failed:
                        print(f"  Failed sources ({date_str}): {', '.join(failed)}")
                    else:
                        print(f"  All sources succeeded ({date_str})")
                break
            except (json.JSONDecodeError, OSError):
                continue
PY

echo ""

# --- Section 3: Alert Activity ---
echo "--- 3. Alert Activity ---"
python3 - "$BASE_DIR" <<'PY'
import json, os, sys
from datetime import datetime

base = sys.argv[1]
today_str = datetime.now().strftime("%Y-%m-%d")
alert_path = os.path.join(base, "data", "alerts", f"alert-state-{today_str}.json")

if not os.path.exists(alert_path):
    print(f"No alert-state for today ({today_str})")
else:
    state = json.load(open(alert_path))
    sent = state.get("alerts_sent", 0)
    cap = state.get("max_alerts", 3)
    remaining = cap - sent
    print(f"Alerts today: {sent}/{cap} (remaining: {remaining})")
    alert_log = state.get("alert_log", [])
    if alert_log:
        print(f"Alert log ({len(alert_log)} entries):")
        for a in alert_log:
            title = a.get("title", "?")
            if len(title) > 60:
                title = title[:60] + "..."
            print(f"  - [{a.get('alert_type', '?')}] {title} (sent: {a.get('sent_at', '?')})")
    else:
        print("No alerts sent today")
PY

echo ""

# --- Section 4: Digest History ---
echo "--- 4. Digest History ---"
python3 - "$BASE_DIR" <<'PY'
import json, os, sys

base = sys.argv[1]
history_path = os.path.join(base, "data", "digest-history.json")

if not os.path.exists(history_path):
    print("No digest-history.json found")
else:
    history = json.load(open(history_path))
    runs = history.get("runs", [])
    print(f"Digest history: {len(runs)} runs (max 5)")
    for r in runs[-5:]:
        run_id = r.get("run_id", "?")
        date = r.get("date", "?")
        events = len(r.get("selected_event_ids", []))
        snapshots = len(r.get("event_timeline_snapshot", {}))
        print(f"  - {date} ({run_id}): {events} events selected, {snapshots} snapshots")
PY

echo ""

# --- Section 5: Budget Status ---
echo "--- 5. Budget Status ---"
python3 - "$BASE_DIR" <<'PY'
import json, os, sys

base = sys.argv[1]
budget_path = os.path.join(base, "config", "budget.json")

if not os.path.exists(budget_path):
    print("budget.json not found")
else:
    b = json.load(open(budget_path))
    calls = b.get("calls_today", 0)
    call_limit = b.get("daily_llm_call_limit", 0)
    tokens = b.get("tokens_today", 0)
    token_limit = b.get("daily_token_limit", 0)
    date = b.get("current_date", "?")
    call_pct = (calls / call_limit * 100) if call_limit > 0 else 0
    token_pct = (tokens / token_limit * 100) if token_limit > 0 else 0
    effective = max(call_pct, token_pct)
    print(f"Budget date: {date}")
    print(f"Calls: {calls}/{call_limit} ({call_pct:.0f}%)")
    print(f"Tokens: {tokens}/{token_limit} ({token_pct:.0f}%)")
    print(f"Effective usage: {effective:.0f}%")
    if effective >= 100:
        print("STATUS: EXHAUSTED (circuit breaker active)")
    elif effective >= 80:
        print("STATUS: WARNING")
    else:
        print("STATUS: OK")
PY

echo ""

# --- Section 6: Data Integrity ---
echo "--- 6. Data Integrity ---"
python3 - "$BASE_DIR" <<'PY'
import json, os, sys, subprocess

base = sys.argv[1]

dedup_path = os.path.join(base, "data", "news", "dedup-index.json")
if os.path.exists(dedup_path):
    try:
        dedup = json.load(open(dedup_path))
        print(f"Dedup-index: {len(dedup)} entries")
    except (json.JSONDecodeError, OSError):
        print("Dedup-index: error reading file")
else:
    print("Dedup-index: not found")

events_path = os.path.join(base, "data", "events", "active.json")
if os.path.exists(events_path):
    try:
        events = json.load(open(events_path))
        if isinstance(events, list):
            active = len([e for e in events if e.get("status") == "active"])
            stable = len([e for e in events if e.get("status") == "stable"])
            print(f"Events: {len(events)} total ({active} active, {stable} stable)")
        else:
            print("Events: invalid format")
    except (json.JSONDecodeError, OSError):
        print("Events: error reading file")
else:
    print("Events: active.json not found")

lock_path = os.path.join(base, "data", ".lock")
if os.path.exists(lock_path):
    try:
        lock = json.load(open(lock_path))
        print(f"Lock: ACTIVE (run_id={lock.get('run_id', '?')}, started={lock.get('started_at', '?')})")
    except (json.JSONDecodeError, OSError):
        print("Lock: present but unreadable")
else:
    print("Lock: none")

result = subprocess.run(
    ["find", base + "/data", "-name", "*.tmp.*"],
    capture_output=True, text=True
)
temp_count = len([l for l in result.stdout.strip().split("\n") if l])
if temp_count > 0:
    print(f"Temp files: {temp_count} orphaned")
else:
    print("Temp files: none")
PY

echo ""
echo "=== Diagnostics complete ==="
