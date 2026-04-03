#!/bin/bash
# activate-profile.sh -- Activate a named source profile by updating sources.json
#
# Usage:
#   bash scripts/activate-profile.sh <profile_name> [base_dir]
#
# Arguments:
#   profile_name  - One of: minimal, production, full
#   base_dir     - Base directory (defaults to .)
#
# Examples:
#   bash scripts/activate-profile.sh production
#   bash scripts/activate-profile.sh full ~/my-skills/news-digest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROFILE_NAME="${1:-}"
BASE_DIR="${2:-.}"

if [ -z "$PROFILE_NAME" ]; then
  echo "Usage: bash scripts/activate-profile.sh <profile_name> [base_dir]" >&2
  echo "  profile_name: minimal, production, or full" >&2
  exit 1
fi

python3 - "$SCRIPT_DIR" "$BASE_DIR" "$PROFILE_NAME" <<'PY'
import json
import os
import sys

script_dir = sys.argv[1]
base_dir = sys.argv[2]
profile_name = sys.argv[3]

profiles_path = os.path.join(base_dir, "config", "source-profiles.json")
sources_path = os.path.join(base_dir, "config", "sources.json")

if not os.path.exists(profiles_path):
    print(f"ERROR: {profiles_path} not found", file=sys.stderr)
    sys.exit(1)

profiles = json.load(open(profiles_path, encoding="utf-8"))
if profile_name not in profiles.get("profiles", {}):
    print(f"ERROR: Unknown profile '{profile_name}'. Available: {list(profiles.get('profiles', {}).keys())}", file=sys.stderr)
    sys.exit(1)

profile = profiles["profiles"][profile_name]
target_sources = profile.get("sources", [])

sources = json.load(open(sources_path, encoding="utf-8"))

if target_sources == "*":
    # Enable all sources
    for source in sources:
        source["enabled"] = True
    action = f"enabled all {len(sources)} sources"
else:
    enabled_ids = set(target_sources)
    for source in sources:
        source["enabled"] = source["id"] in enabled_ids
    enabled_count = sum(1 for s in sources if s.get("enabled", True))
    disabled_count = len(sources) - enabled_count
    action = f"enabled {enabled_count} source(s), disabled {disabled_count}"

# Write atomically
tmp_path = sources_path + ".tmp"
with open(tmp_path, "w", encoding="utf-8") as f:
    json.dump(sources, f, ensure_ascii=False, indent=2)
    f.write("\n")
os.rename(tmp_path, sources_path)

print(f"Profile '{profile_name}' activated: {action}")
print(f"Description: {profile.get('description', '')}")
PY
