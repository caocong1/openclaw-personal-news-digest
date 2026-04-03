#!/bin/bash
set -euo pipefail

BASE_DIR="${1:-.}"
SOURCE_QUERY="${2:-}"

python3 - "$BASE_DIR" "$SOURCE_QUERY" <<'PY'
import glob
import json
import os
import sys


def load_json(path):
    with open(path, "r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def latest_metrics(base_dir):
    pattern = os.path.join(base_dir, "data", "metrics", "daily-*.json")
    for path in sorted(glob.glob(pattern), reverse=True):
        try:
            payload = load_json(path)
        except (OSError, json.JSONDecodeError):
            continue
        per_source = payload.get("per_source", {})
        if isinstance(per_source, dict):
            return per_source
    return {}


def fmt_bool(value):
    return "true" if bool(value) else "false"


def fmt_ratio(value):
    try:
        return f"{float(value):.2f}"
    except (TypeError, ValueError):
        return "0.00"


def fmt_count(value):
    try:
        return str(int(value))
    except (TypeError, ValueError):
        return "0"


def fmt_text(value, fallback="null"):
    if value in (None, ""):
        return fallback
    return str(value)


def merged_sources(base_dir):
    sources_path = os.path.join(base_dir, "config", "sources.json")
    if not os.path.exists(sources_path):
        raise SystemExit("Missing config/sources.json")

    sources = load_json(sources_path)
    recent = latest_metrics(base_dir)
    merged = []

    for source in sources:
        stats = dict(source.get("stats") or {})
        recent_metrics = recent.get(source.get("id"), {})
        fetched = recent_metrics.get("fetched")
        deduped = recent_metrics.get("deduped", 0)
        title_deduped = recent_metrics.get("title_deduped", 0)
        selected = recent_metrics.get("selected", 0)

        if stats.get("dedup_rate") is None and fetched:
            stats["dedup_rate"] = (deduped + title_deduped) / fetched
        if stats.get("selection_rate") is None and fetched:
            stats["selection_rate"] = selected / fetched
        if recent_metrics.get("error"):
            stats["last_error"] = recent_metrics["error"]

        merged.append(
            {
                **source,
                "stats": stats,
                "recent_metrics": recent_metrics,
            }
        )

    return merged


def find_matches(sources, query):
    needle = query.strip().lower()
    exact = [
        source
        for source in sources
        if source.get("id", "").lower() == needle or source.get("name", "").lower() == needle
    ]
    if exact:
        return exact

    return [
        source
        for source in sources
        if needle in source.get("id", "").lower() or needle in source.get("name", "").lower()
    ]


sources = merged_sources(sys.argv[1])
query = sys.argv[2].strip() if len(sys.argv) > 2 else ""

if not query:
    enabled_count = sum(1 for source in sources if source.get("enabled", True))
    disabled_count = sum(1 for source in sources if not source.get("enabled", True))
    degraded_count = sum(1 for source in sources if source.get("status") == "degraded")

    print("=== Source Status ===")
    print(
        f"Enabled: {enabled_count} | Disabled: {disabled_count} | Degraded: {degraded_count}"
    )
    print("")

    for source in sources:
        stats = source.get("stats", {})
        line = (
            f"- {source.get('name', '?')} | {source.get('id', '?')} | "
            f"Enabled: {fmt_bool(source.get('enabled', True))} | "
            f"Status: {fmt_text(source.get('status'), 'unknown')} | "
            f"Quality score: {fmt_ratio(stats.get('quality_score'))} | "
            f"Dedup rate: {fmt_ratio(stats.get('dedup_rate'))} | "
            f"Selection rate: {fmt_ratio(stats.get('selection_rate'))} | "
            f"Consecutive failures: {fmt_count(stats.get('consecutive_failures'))}"
        )
        if source.get("auto_discovered") is True:
            line += " | Auto discovered: true"
        print(line)
    raise SystemExit(0)

matches = find_matches(sources, query)
if not matches:
    print(f"Source not found: {query}")
    raise SystemExit(1)

if len(matches) > 1:
    print(f"Ambiguous source query: {query}")
    for source in matches:
        print(f"- {source.get('name', '?')} ({source.get('id', '?')})")
    raise SystemExit(1)

source = matches[0]
stats = source.get("stats", {})

print(f"## Source: {source.get('name', '?')}")
print(f"Type: {fmt_text(source.get('type'), 'unknown')}")
print(f"Status: {fmt_text(source.get('status'), 'unknown')}")
print(f"Enabled: {fmt_bool(source.get('enabled', True))}")
print(f"Quality score: {fmt_ratio(stats.get('quality_score'))}")
print(f"Dedup rate: {fmt_ratio(stats.get('dedup_rate'))}")
print(f"Selection rate: {fmt_ratio(stats.get('selection_rate'))}")
print(f"Total fetched: {fmt_count(stats.get('total_fetched'))}")
print(f"Last fetch: {fmt_text(stats.get('last_fetch'))}")
print(f"Consecutive failures: {fmt_count(stats.get('consecutive_failures'))}")

last_error = stats.get("last_error")
if last_error not in (None, ""):
    print(f"Last error: {last_error}")

if source.get("status") == "degraded" and stats.get("degraded_since"):
    print(f"Degraded since: {stats.get('degraded_since')}")

if source.get("auto_discovered") is True:
    print(f"Auto discovered: true")
    print(f"Discovery domain: {fmt_text(source.get('discovery_domain'))}")
    print(f"Discovery tier: {fmt_text(source.get('discovery_tier'))}")
    print(f"Discovery decision: {fmt_text(source.get('discovery_decision'))}")
    print(f"Discovery decided at: {fmt_text(source.get('discovery_decided_at'))}")
PY
