#!/bin/bash
# Safe backlog archival: snapshot-first workflow to prevent archiving empty files
# Usage: bash scripts/archive-backlog.sh <source_file> [archive_dir]
#
# Safety guards (ND-20260403-11):
#   1. Source file must exist and be non-empty (> 10 bytes)
#   2. Archive copy is written first and verified (checksum match)
#   3. Only after verification does the new blank file get created
#   4. Original is never deleted -- renamed to .bak as extra safety net
#
# Exit code: 0 on success, 1 on any safety check failure

set -euo pipefail

SOURCE="${1:-}"
ARCHIVE_DIR="${2:-./data/backlog/archives}"

if [ -z "$SOURCE" ]; then
  echo "ERROR: Usage: archive-backlog.sh <source_file> [archive_dir]"
  exit 1
fi

if [ ! -f "$SOURCE" ]; then
  echo "ERROR: Source file does not exist: $SOURCE"
  exit 1
fi

# --- Guard 1: Source must be non-empty ---
SOURCE_SIZE=$(wc -c < "$SOURCE" | tr -d ' ')
if [ "$SOURCE_SIZE" -le 10 ]; then
  echo "ERROR: Source file is empty or near-empty ($SOURCE_SIZE bytes): $SOURCE"
  echo "       Refusing to archive an empty file. Check if the file was already replaced."
  exit 1
fi

SOURCE_LINES=$(wc -l < "$SOURCE" | tr -d ' ')
echo "Source: $SOURCE ($SOURCE_SIZE bytes, $SOURCE_LINES lines)"

# --- Guard 2: Compute checksum before copy ---
SOURCE_HASH=$(shasum -a 256 "$SOURCE" | cut -d' ' -f1)
echo "Source SHA256: $SOURCE_HASH"

# --- Create archive directory ---
mkdir -p "$ARCHIVE_DIR"

# --- Generate archive filename ---
BASENAME=$(basename "$SOURCE" .md)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE_PATH="$ARCHIVE_DIR/${BASENAME}-${TIMESTAMP}.md"

# --- Copy to archive ---
cp "$SOURCE" "$ARCHIVE_PATH"

# --- Guard 3: Verify archive copy matches source ---
ARCHIVE_HASH=$(shasum -a 256 "$ARCHIVE_PATH" | cut -d' ' -f1)
if [ "$SOURCE_HASH" != "$ARCHIVE_HASH" ]; then
  echo "ERROR: Archive verification failed!"
  echo "  Source hash:  $SOURCE_HASH"
  echo "  Archive hash: $ARCHIVE_HASH"
  echo "  Removing bad archive: $ARCHIVE_PATH"
  rm -f "$ARCHIVE_PATH"
  exit 1
fi

ARCHIVE_SIZE=$(wc -c < "$ARCHIVE_PATH" | tr -d ' ')
echo "Archived to: $ARCHIVE_PATH ($ARCHIVE_SIZE bytes)"
echo "Archive SHA256: $ARCHIVE_HASH (verified match)"

# --- Guard 4: Rename original as .bak before creating blank ---
BAK_PATH="${SOURCE}.bak-${TIMESTAMP}"
mv "$SOURCE" "$BAK_PATH"
echo "Backup: $BAK_PATH"

# --- Create new blank file with template header ---
cat > "$SOURCE" << 'TEMPLATE'
# News Digest Skill Improvement Backlog

<!-- New round. Only append "still needs work / not yet resolved / newly found" items.
Do not repeat items already completed. When ready to archive this round,
run: bash scripts/archive-backlog.sh IMPROVEMENTS.md -->

TEMPLATE

NEW_SIZE=$(wc -c < "$SOURCE" | tr -d ' ')
echo "New blank file: $SOURCE ($NEW_SIZE bytes)"

echo ""
echo "=== Archive complete ==="
echo "  Archived: $ARCHIVE_PATH"
echo "  Backup:   $BAK_PATH"
echo "  New file: $SOURCE"
echo ""
echo "To undo: mv '$BAK_PATH' '$SOURCE'"
