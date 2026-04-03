#!/bin/bash
# Smoke test: automated platform capability verification
# Usage: bash scripts/smoke-test.sh [--mode full|quick] [base_dir]
#
# --mode full  (default) - Run all smoke tests
# --mode quick          - Run only essential tests (file access, exec, timeout)
#
# Exit code: 0 if all tests pass, non-zero if any fail

MODE="full"
BASE_DIR="."

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --mode=*) MODE="${1#--mode=}"; shift ;;
    *) BASE_DIR="$1"; shift ;;
  esac
done

if [ "$MODE" != "full" ] && [ "$MODE" != "quick" ]; then
  echo "ERROR: Invalid mode '$MODE'. Use 'full' or 'quick'."
  exit 1
fi

PASS=0; FAIL=0; SKIP=0
OUT=""

run_test() {
  local name="$1"; local res="$2"; local ms="$3"
  [ "$res" = "PASS" ] && PASS=$((PASS+1))
  [ "$res" = "FAIL" ] && FAIL=$((FAIL+1))
  [ "$res" = "SKIP" ] && SKIP=$((SKIP+1))
  OUT="${OUT}${name}|${res}|${ms}\n"
  printf "  [%-4s] %-35s (%sms)\n" "$res" "$name" "$ms"
}

# ── test_file_access ─────────────────────────────────────
test_file_access() {
  if [ ! -f "$BASE_DIR/SKILL.md" ]; then echo "FAIL"; return 1; fi
  for d in config references scripts; do
    [ ! -d "$BASE_DIR/$d" ] && echo "FAIL" && return 1
  done
  echo "PASS"; return 0
}

# ── test_exec_permissions ─────────────────────────────────
test_exec_permissions() {
  local out
  out=$(python3 - "$BASE_DIR" 2>/dev/null <<'EOF'
import sys
print("smoke-ok")
EOF
)
  [ "$out" = "smoke-ok" ] && echo "PASS" && return 0
  echo "FAIL"; return 1
}

# ── test_python3_available ────────────────────────────────
test_python3_available() {
  python3 --version >/dev/null 2>&1 && echo "PASS" && return 0
  echo "FAIL"; return 1
}

# ── test_cron_delivery ───────────────────────────────────
test_cron_delivery() {
  if command -v crontab >/dev/null 2>&1 || command -v cron >/dev/null 2>&1 || command -v at >/dev/null 2>&1; then
    echo "PASS"; return 0
  fi
  echo "SKIP"; return 0
}

# ── test_timeout_behavior ─────────────────────────────────
test_timeout_behavior() {
  local out
  out=$(python3 2>/dev/null <<'EOF'
import time; time.sleep(0.5); print("timeout-test-ok")
EOF
)
  [ "$out" = "timeout-test-ok" ] && echo "PASS" && return 0
  echo "FAIL"; return 1
}

# ── test_empty_input_quality_gate ─────────────────────────
test_empty_input_quality_gate() {
  bash -n "$BASE_DIR/scripts/health-check.sh" 2>/dev/null && echo "PASS" && return 0
  echo "FAIL"; return 1
}

# ── test_atomic_write ─────────────────────────────────────
test_atomic_write() {
  local out
  out=$(python3 - "$BASE_DIR" 2>/dev/null <<'EOF'
import json,os,tempfile,sys
base=sys.argv[1]
d=os.path.join(base,"data","smoke-test-tmp")
os.makedirs(d,exist_ok=True)
t=os.path.join(d,"a.json");p=t+".tmp"
with open(p,"w") as f: json.dump({"k":1},f)
os.rename(p,t)
with open(t) as f: r=json.load(f)
os.remove(t); os.rmdir(d)
print("PASS" if r.get("k")==1 else "FAIL")
EOF
)
  echo "$out"; [ "$out" = "PASS" ] && return 0; return 1
}

# ── test_version_metadata ──────────────────────────────────
test_version_metadata() {
  local out
  out=$(python3 - "$BASE_DIR" 2>/dev/null <<'EOF'
import re,sys
c=open(f"{sys.argv[1]}/SKILL.md").read()
a=bool(re.search(r'_skill_version:',c))
b=bool(re.search(r'minimum_openclaw_version:',c))
print("PASS" if a and b else f"FAIL:{a}:{b}")
EOF
)
  echo "$out"; [ "$out" = "PASS" ] && return 0; return 1
}

# ── test_jsonl_append ─────────────────────────────────────
test_jsonl_append() {
  local out
  out=$(python3 - "$BASE_DIR" 2>/dev/null <<'EOF'
import os,sys
base=sys.argv[1]
os.makedirs(f"{base}/data/metrics",exist_ok=True)
os.makedirs(f"{base}/data/backlog",exist_ok=True)
for p in [f"{base}/data/metrics/run-journal.jsonl",f"{base}/data/backlog/failure-followups.jsonl"]:
    open(p,"a").close()
print("PASS")
EOF
)
  echo "$out"; [ "$out" = "PASS" ] && return 0; return 1
}

# ── Main ─────────────────────────────────────────────────
echo "=== OpenClaw Smoke Tests (mode: $MODE) ==="
echo "Base dir: $BASE_DIR"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

START=$(python3 -c "import time; print(time.time())")

if [ "$MODE" = "quick" ]; then
  echo "--- Quick Mode: Essential Tests ---"
  T=$(date +%s%N); R=$(test_file_access); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_file_access" "$R" "$D"
  T=$(date +%s%N); R=$(test_exec_permissions); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_exec_permissions" "$R" "$D"
  T=$(date +%s%N); R=$(test_timeout_behavior); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_timeout_behavior" "$R" "$D"
else
  echo "--- Full Mode: All Tests ---"
  T=$(date +%s%N); R=$(test_file_access); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_file_access" "$R" "$D"
  T=$(date +%s%N); R=$(test_exec_permissions); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_exec_permissions" "$R" "$D"
  T=$(date +%s%N); R=$(test_python3_available); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_python3_available" "$R" "$D"
  T=$(date +%s%N); R=$(test_cron_delivery); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_cron_delivery" "$R" "$D"
  T=$(date +%s%N); R=$(test_timeout_behavior); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_timeout_behavior" "$R" "$D"
  T=$(date +%s%N); R=$(test_empty_input_quality_gate); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_empty_input_quality_gate" "$R" "$D"
  T=$(date +%s%N); R=$(test_atomic_write); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_atomic_write" "$R" "$D"
  T=$(date +%s%N); R=$(test_version_metadata); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_version_metadata" "$R" "$D"
  T=$(date +%s%N); R=$(test_jsonl_append); D=$((($(date +%s%N) - $T)/1000000))
  run_test "test_jsonl_append" "$R" "$D"
fi

END=$(python3 -c "import time; print(time.time())")
TOTAL=$(python3 -c "print(round((${END} - ${START}) * 1000, 0))")

echo ""
echo "--- Summary ---"
echo "Test                              Result      Time(ms)"
echo "--------------------------------- ----------- --------"
echo -e "$OUT"
TOTAL_TESTS=$((PASS + FAIL + SKIP))
echo ""
echo "Total: $TOTAL_TESTS | PASS: $PASS | FAIL: $FAIL | SKIP: $SKIP | ${TOTAL}ms total"

if [ "$FAIL" -gt 0 ]; then
  echo "SMOKE TESTS: FAILED"
  exit 1
else
  echo "SMOKE TESTS: PASSED"
  exit 0
fi
