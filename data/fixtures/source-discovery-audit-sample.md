# Source Discovery Audit Sample

Human-readable audit artifact showing the full discovery lifecycle for `example-direct-source.com`. This fixture demonstrates how discovery decisions are preserved across the complete lifecycle: observed -> enabled -> disabled.

---

## Domain: example-direct-source.com

| Field | Value |
|-------|-------|
| domain | example-direct-source.com |
| tier | T1 |
| first_seen | 2026-03-15T10:00:00Z |
| last_seen | 2026-04-02T14:00:00Z |
| hit_count_7d | 1 |
| t1_ratio | 0.00 |
| decision | disabled |
| reason | tier_ratio_below_disable_threshold |
| representative_urls | https://example-direct-source.com/releases/v3.0, https://example-direct-source.com/blog/product-update |
| representative_titles | Example Direct Source v3.0 Released, Product Update: New API Endpoints, Breaking: Platform Migration Complete |

### Decision History

| Timestamp | Decision | Reason | Details |
|-----------|----------|--------|---------|
| 2026-03-18T09:00:00Z | observed | first_observation | Domain first seen via provenance T1 classification |
| 2026-03-20T09:00:00Z | enabled | all_gates_passed | hit_count_7d: 7, t1_ratio: 0.57, unique_events: 3, age_days: 5 |
| 2026-04-02T09:00:00Z | disabled | tier_ratio_below_disable_threshold | hit_count_7d: 1, t1_ratio: 0.0, days_without_t1_t2: 14 |

### Lifecycle Summary

This domain progressed through the complete discovery lifecycle:

1. **Observed** (2026-03-18): First seen via provenance T1 classification. Domain entered the accumulation store with initial rolling metrics.
2. **Enabled** (2026-03-20): All five auto-enable gates passed -- frequency (7 hits), quality (t1_ratio 0.57), uniqueness (3 unique events), age (5 days), and not already enabled. A generated source entry was added to `config/sources.json`.
3. **Disabled** (2026-04-02): Tier ratio collapsed to 0.0 with only 1 hit in the rolling 7-day window and 14 days without T1/T2 items. The source was auto-disabled but its discovery record and full decision history are preserved in `data/provenance/discovered-sources.json`.

The lifecycle phrase `observed -> enabled -> disabled` captures this three-state transition. Other possible lifecycle paths include `observed -> deferred -> enabled`, `observed -> rejected`, and `observed -> enabled -> disabled -> enabled` (re-enable after recovery).

---

## Domain: venturebeat.com

| Field | Value |
|-------|-------|
| domain | venturebeat.com |
| tier | T2 |
| first_seen | 2026-03-28T12:00:00Z |
| last_seen | 2026-04-02T08:30:00Z |
| hit_count_7d | 3 |
| t1_ratio | 0.00 |
| decision | deferred |
| reason | below_frequency_threshold |
| representative_urls | https://venturebeat.com/ai/new-llm-benchmark-results, https://venturebeat.com/ai/enterprise-ai-adoption-2026 |
| representative_titles | Enterprise AI Adoption Surges in Q1 2026, New LLM Benchmark Results Show Diminishing Returns |

### Decision History

| Timestamp | Decision | Reason | Details |
|-----------|----------|--------|---------|
| 2026-03-31T09:00:00Z | observed | first_observation | Domain first seen via provenance T2 classification |
| 2026-04-02T09:00:00Z | deferred | below_frequency_threshold | hit_count_7d: 3 (requires >= 5), t1_ratio: 0.0 (requires >= 0.3) |

---

## Rule-library promotion evidence

When a discovered source reaches the `enabled` decision and its representative URLs show path-scoped content, the rule-library promotion must preserve that path evidence:

- T1 promotion target: config/t1-sources.json -> openai.com/blog
- T2 promotion target: config/t2-sources.json -> venturebeat.com/ai

These entries demonstrate that the pattern added to the rule library reflects the specific path where provenance-relevant content was observed, not the bare root domain. For `openai.com`, the representative URLs pointed to `/blog/*` paths, so the rule targets `openai.com/blog`. For `venturebeat.com`, the representative URLs pointed to `/ai/*` paths, so the rule targets `venturebeat.com/ai`.
