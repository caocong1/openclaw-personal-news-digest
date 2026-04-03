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

# Verify news directory exists
if [ ! -d "$NEWS_DIR" ]; then
  echo "Error: News directory not found: $NEWS_DIR" >&2
  exit 1
fi

# Rebuild index using dedup_tools module
python3 - "$BASE_DIR" "$NEWS_DIR" "$INDEX_FILE" <<'PY'
import os
import sys

# Add project root to path for module import
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scripts.lib import dedup_tools

base_dir = sys.argv[1]
days = 7  # fixed: last 7 days

result = dedup_tools.rebuild_index(base_dir, days)
print(f"Rebuilt dedup-index from {result['jsonl_count']} JSONL files")
print(f"Total entries: {result['entry_count']}")
PY

echo "Index rebuild complete."
