#!/bin/bash
set -e

PROJECT_DIR="/Users/dongli/Workspace/openclaw-personal-news-digest"
cd "$PROJECT_DIR"

for phase in 0 1 2 3; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " PHASE $phase — PLAN + EXECUTE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  claude -p "Run /gsd:plan-phase $phase — create detailed execution plans for phase $phase. After plans are created and committed, run /gsd:execute-phase $phase to execute all plans. Complete both steps in this session." \
    --dangerously-skip-permissions \
    --max-turns 200 \
    --verbose

  echo ""
  echo "✓ Phase $phase done"
  echo ""
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " ALL PHASES COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
