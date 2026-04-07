#!/bin/bash
# Preflight: unified baseDir validation before any pipeline run
# Usage: bash scripts/preflight.sh [base_dir]
#
# Checks:
#   1. SKILL.md anchor exists and contains news-digest identity
#   2. config/sources.json exists
#   3. Required directories exist (creates missing ones)
#   4. No baseDir drift (workspace root != skill root)
#
# Exit code: 0 if all checks pass, 1 if any fail
# Designed to be sourced or called from other pipeline scripts

set -euo pipefail

BASE_DIR="${1:-.}"
BASE_DIR="$(cd "$BASE_DIR" && pwd)"  # resolve to absolute path

ERRORS=0

echo "=== Preflight Check ==="
echo "Checking baseDir: $BASE_DIR"
echo ""

# 1. Anchor file check: SKILL.md must exist and identify as news-digest
if [ ! -f "$BASE_DIR/SKILL.md" ]; then
  echo "FAIL: SKILL.md not found at $BASE_DIR/SKILL.md"
  echo "      This directory is not the news-digest skill root."
  ERRORS=$((ERRORS + 1))
elif ! grep -q 'name: news-digest' "$BASE_DIR/SKILL.md" 2>/dev/null; then
  echo "FAIL: SKILL.md at $BASE_DIR/SKILL.md does not contain 'name: news-digest'"
  echo "      BaseDir drift detected -- wrong directory."
  ERRORS=$((ERRORS + 1))
else
  echo "OK: SKILL.md anchor verified"
fi

# 2. sources.json exists
if [ ! -f "$BASE_DIR/config/sources.json" ]; then
  echo "FAIL: Missing $BASE_DIR/config/sources.json"
  ERRORS=$((ERRORS + 1))
else
  # Validate JSON
  if python3 -c "import json; json.load(open('$BASE_DIR/config/sources.json'))" 2>/dev/null; then
    echo "OK: config/sources.json exists and is valid JSON"
  else
    echo "FAIL: config/sources.json exists but is not valid JSON"
    ERRORS=$((ERRORS + 1))
  fi
fi

# 3. Required directories
REQUIRED_DIRS=(
  "data" "data/news" "data/cache" "data/events" "data/events/archived"
  "data/alerts" "data/feedback" "data/metrics" "data/provenance"
  "data/backlog" "output" "config"
)

CREATED=0
for dir in "${REQUIRED_DIRS[@]}"; do
  if [ ! -d "$BASE_DIR/$dir" ]; then
    mkdir -p "$BASE_DIR/$dir"
    CREATED=$((CREATED + 1))
  fi
done

if [ "$CREATED" -gt 0 ]; then
  echo "OK: Created $CREATED missing directories"
else
  echo "OK: All required directories exist"
fi

# 4. Drift guard: check we are not at workspace root
# A workspace root typically has a skills/ subdirectory but no config/sources.json at top level
if [ -d "$BASE_DIR/skills" ] && [ -f "$BASE_DIR/skills/news-digest/SKILL.md" ]; then
  echo "FAIL: baseDir appears to be workspace root (found skills/news-digest/ subdirectory)"
  echo "      Expected: $BASE_DIR/skills/news-digest"
  echo "      Got:      $BASE_DIR"
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
  echo "PREFLIGHT: FAILED ($ERRORS error(s))"
  echo "Aborting pipeline. Fix baseDir and retry."
  exit 1
else
  echo "PREFLIGHT: PASSED"
  echo "Resolved baseDir: $BASE_DIR"
  exit 0
fi
