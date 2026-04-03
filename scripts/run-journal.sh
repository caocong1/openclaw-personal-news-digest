#!/bin/bash
# run-journal.sh -- Append/query/summarize the run journal
#
# Usage:
#   bash scripts/run-journal.sh append  <run_id> <severity> <stage> <code> <message> [hint] [source_id]
#   bash scripts/run-journal.sh query   [--run-id RUN_ID] [--severity SEV] [--stage STAGE] [--limit N]
#   bash scripts/run-journal.sh summary [--days N]
#
# Examples:
#   bash scripts/run-journal.sh append "run-20260403-1200-abcd" "error" "collection" "SRC_TIMEOUT" \
#     "Source src-36kr timed out after 30s" "Re-enable manually" "src-36kr"
#   bash scripts/run-journal.sh query --severity error --limit 20
#   bash scripts/run-journal.sh summary --days 7

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${1:-.}"

if [ $# -lt 1 ]; then
  echo "Usage: bash scripts/run-journal.sh append|query|summary [args...]" >&2
  echo "  append: <run_id> <severity> <stage> <code> <message> [hint] [source_id]" >&2
  echo "  query:  [--run-id RUN_ID] [--severity SEV] [--stage STAGE] [--limit N]" >&2
  echo "  summary: [--days N]" >&2
  exit 1
fi

CMD="${2:-}"

python3 - "$SCRIPT_DIR" "$BASE_DIR" "$CMD" "${@:3}" <<'PY'
import json
import os
import sys

# SCRIPT_DIR passed from bash as sys.argv[1]
script_dir = sys.argv[1]
base_dir = sys.argv[2]
cmd = sys.argv[3]
args = sys.argv[4:]

lib_dir = os.path.join(script_dir, "lib")
sys.path.insert(0, lib_dir)

from journal_tools import journal_append, journal_query, journal_summary, JOURNAL_PATH

journal_path = os.path.join(base_dir, JOURNAL_PATH)

if cmd == "append":
    # args: run_id severity stage code message [hint] [source_id]
    run_id = args[0] if len(args) > 0 else ""
    severity = args[1] if len(args) > 1 else ""
    stage = args[2] if len(args) > 2 else ""
    code = args[3] if len(args) > 3 else ""
    message = args[4] if len(args) > 4 else ""
    hint = args[5] if len(args) > 5 else ""
    source_id = args[6] if len(args) > 6 else None

    journal_append(run_id, severity, stage, code, message, hint=hint,
                   details=None, source_id=source_id, base_dir=base_dir)
    print(f"Journal entry appended: [{severity}] {code} in {stage}")

elif cmd == "query":
    run_id = None
    severity = None
    stage = None
    limit = 100

    i = 0
    while i < len(args):
        if args[i] == "--run-id" and i + 1 < len(args):
            run_id = args[i + 1]
            i += 2
        elif args[i] == "--severity" and i + 1 < len(args):
            severity = args[i + 1]
            i += 2
        elif args[i] == "--stage" and i + 1 < len(args):
            stage = args[i + 1]
            i += 2
        elif args[i] == "--limit" and i + 1 < len(args):
            limit = int(args[i + 1])
            i += 2
        else:
            i += 1

    results = journal_query(journal_path, run_id, severity, stage, limit)
    for entry in results:
        print(json.dumps(entry, ensure_ascii=False))

elif cmd == "summary":
    days = 7
    i = 0
    while i < len(args):
        if args[i] == "--days" and i + 1 < len(args):
            days = int(args[i + 1])
            i += 2
        else:
            i += 1

    result = journal_summary(journal_path, days)
    print(json.dumps(result, ensure_ascii=False, indent=2))

else:
    print(f"Unknown command: {cmd}", file=sys.stderr)
    sys.exit(1)
PY
