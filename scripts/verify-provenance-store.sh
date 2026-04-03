#!/bin/bash
# verify-provenance-store.sh
# Validates all 5 provenance artifact files are readable as valid JSON (or JSONL)
# and match the expected schema shapes. Exits 0 if all pass, 1 if any fail.

set -e

PROV_DIR="data/provenance"
ERRORS=0

echo "=== Provenance Store Verification ==="

# 1. provenance-db.json: parses as JSON object
echo -n "1. provenance-db.json ... "
if python3 -c "import json; d=json.load(open('$PROV_DIR/provenance-db.json')); assert isinstance(d, dict)" 2>/dev/null; then
    echo "OK"
else
    echo "FAIL"
    ERRORS=$((ERRORS + 1))
fi

# 2. citation-graph.json: parses as JSON with _schema_v, nodes, edges
echo -n "2. citation-graph.json ... "
if python3 -c "import json; d=json.load(open('$PROV_DIR/citation-graph.json')); assert '_schema_v' in d and 'nodes' in d and 'edges' in d" 2>/dev/null; then
    echo "OK"
else
    echo "FAIL"
    ERRORS=$((ERRORS + 1))
fi

# 3. tier-stats.json: parses as JSON with _schema_v, days, sources, last_updated
echo -n "3. tier-stats.json ... "
if python3 -c "import json; d=json.load(open('$PROV_DIR/tier-stats.json')); assert '_schema_v' in d and 'days' in d and 'sources' in d and 'last_updated' in d" 2>/dev/null; then
    echo "OK"
else
    echo "FAIL"
    ERRORS=$((ERRORS + 1))
fi

# 4. provenance-discrepancies.jsonl: all lines parse as valid JSON (handle empty file)
echo -n "4. provenance-discrepancies.jsonl ... "
if python3 -c "
import json
with open('$PROV_DIR/provenance-discrepancies.jsonl') as f:
    for i, line in enumerate(f):
        line = line.strip()
        if line:
            json.loads(line)
" 2>/dev/null; then
    echo "OK"
else
    echo "FAIL"
    ERRORS=$((ERRORS + 1))
fi

# 5. discovered-sources.json: parses as JSON with _schema_v, sources, last_evaluated, last_updated
echo -n "5. discovered-sources.json ... "
if python3 -c "import json; d=json.load(open('$PROV_DIR/discovered-sources.json')); assert '_schema_v' in d and 'sources' in d and 'last_evaluated' in d and 'last_updated' in d" 2>/dev/null; then
    echo "OK"
else
    echo "FAIL"
    ERRORS=$((ERRORS + 1))
fi

echo "=== Results ==="
if [ $ERRORS -eq 0 ]; then
    echo "All 5 provenance artifact files passed validation."
    exit 0
else
    echo "$ERRORS file(s) failed validation."
    exit 1
fi
