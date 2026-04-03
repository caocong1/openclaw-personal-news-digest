# Phase 15: Provenance-Aware Ranking & Delivery - Research

**Researched:** 2026-04-03
**Domain:** Provenance-aware scoring, tier-based alert gating, event representative selection, provenance-chain rendering, and weekly source-discovery reporting
**Confidence:** HIGH

## Summary

Phase 15 is the consumer phase for provenance and discovery. Phases 13 and 14 built the upstream foundation: provenance classification, persistent provenance records keyed by `NewsItem.id`, discovery accumulation in `data/provenance/discovered-sources.json`, auto-enable/disable evaluation, and pattern-library expansion. Phase 15 takes those artifacts and makes them influence what the user actually sees: ranking order, alert eligibility, event representative selection, output rendering, and a weekly discovery report.

The repo currently has a 7-dimension scoring formula (`references/scoring-formula.md`) that does not reference provenance at all. The `source_trust` dimension (weight 0.10) uses `config/preferences.json` trust values or the source's `credibility` field, but never consults `ProvenanceRecord.tier`. Alerts use a flat `importance_score >= 0.85` threshold with form_type and daily-cap guards but have no tier-awareness. Event merging creates events and links items to them, but there is no "representative selection" step that picks the best single item per event for output. Output templates render `source_name` but never show tier, provenance chain, or original-source attribution. Weekly reports have a "Source Health Overview" section but no discovery-specific reporting.

The primary modification targets are: (1) `references/scoring-formula.md` for provenance boost/decay, (2) `references/processing-instructions.md` Section 4 for representative selection and Section 5A for tier-aware alert gating, (3) `references/output-templates.md` for provenance-chain and English-title rendering, and (4) a new weekly source-discovery report section or template.

**Primary recommendation:** Add provenance as a scoring modifier and rendering dimension without changing the 7-dimension weight structure -- use conditional multipliers (boost for T1/T2, decay for T4 when direct coverage exists) on `final_score` after the existing formula, then add representative selection as a post-scoring filter before quota allocation.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PIPE-01 | Final ranking adds provenance boost/penalty so T1/T2 items outrank redundant T4 aggregation when the underlying event is the same | The current scoring formula in `references/scoring-formula.md` has no provenance dimension. The `ProvenanceRecord` join path (`NewsItem.id -> provenance-db.json`) and tier fields (`tier`, `propagation_hops`, `tier_confidence`) are already available from Phase 13. The `Event` model in `data/events/active.json` already groups items by `event_id`, making same-event T4 detection feasible. |
| PIPE-02 | T4 items use a stricter breaking-alert threshold, and event-level alert suppression runs before the importance gate | The current alert decision tree (Section 5A) uses a flat `importance_score >= 0.85` threshold. The `ProvenanceRecord.tier` field is available for every item via the provenance-db join. Event-level `last_alerted_at` already exists on the `Event` model for delta-alert routing. |
| PIPE-03 | Each merged event keeps exactly one representative item chosen by highest tier first, then credibility and score tie-breakers | Event merging (Section 1C) links items to events via `item_ids` and `event_id`, but no representative selection step currently exists. The `Event.item_ids` array plus provenance-db joins provide tier, and `config/sources.json` provides credibility. A selection step must be added between scoring and quota allocation. |
| PIPE-04 | Digest and alert rendering show source tier, provenance chain, and normalized English-title display without leaking internal fields | Output templates (`references/output-templates.md`) currently render `source_name`, `importance_score`, and `form_type` but not tier, provenance chain, or original-source attribution. The rendering contract defines user-facing vs internal-only fields. New user-facing fields must be added to both the template and the rendering contract. |
| PIPE-05 | A weekly source-discovery report summarizes newly discovered sources, auto-enable/disable actions, tier mix, and watchlist changes | The weekly report (Section 7) has a "Source Health Overview" section but no discovery-specific content. Discovery state in `data/provenance/discovered-sources.json` already has `decision_history`, rolling metrics, and tier ratios needed for the report. `data/provenance/tier-stats.json` provides daily tier distribution. |

</phase_requirements>

## Standard Stack

### Core

This project is a prompt/config/script skill for OpenClaw, not a traditional code project. There are no npm packages or external libraries. The "stack" consists of:

| Component | Location | Purpose | Why Standard |
|-----------|----------|---------|--------------|
| Scoring formula | `references/scoring-formula.md` | Defines the 7-dimension ranking formula | Single source of truth for all scoring behavior |
| Processing instructions | `references/processing-instructions.md` | Pipeline stage definitions and algorithms | Contains Section 4 (output), Section 5A/5B (alerts), Section 1C (events) |
| Output templates | `references/output-templates.md` | Digest and alert Markdown format | Defines rendering contract and display mappings |
| Data models | `references/data-models.md` | JSON schemas for all data structures | Authoritative field definitions and defaults |
| SKILL.md | `SKILL.md` | Pipeline phase ordering and operator surface | Master pipeline orchestration |
| Provenance DB | `data/provenance/provenance-db.json` | Per-item provenance records | Phase 13 artifact, keyed by `NewsItem.id` |
| Discovery state | `data/provenance/discovered-sources.json` | Domain-level discovery accumulation | Phase 14 artifact with rolling metrics and decision history |
| Tier stats | `data/provenance/tier-stats.json` | Daily tier distribution counters | Phase 13 artifact with per-day and per-source breakdowns |
| T1/T2 pattern libraries | `config/t1-sources.json`, `config/t2-sources.json` | URL-rule preclassification patterns | Phase 13 artifact, expandable by Phase 14 |

### Supporting

| Component | Location | Purpose | When to Use |
|-----------|----------|---------|-------------|
| Event store | `data/events/active.json` | Active/stable event objects with timelines | Representative selection needs `item_ids` and provenance joins |
| Alert state | `data/alerts/alert-state-{date}.json` | Per-day alert tracking | Tier-aware gating modifies the decision tree entry point |
| Source config | `config/sources.json` | Live source inventory with credibility | Tie-breaking in representative selection |
| Digest history | `data/digest-history.json` | Rolling 5-run digest snapshots | Cross-digest repetition penalty interaction |

## Architecture Patterns

### Modification Targets and Sequencing

Phase 15 modifies existing reference documents and templates rather than creating new code files. The three plans map naturally to distinct modification surfaces:

```
Plan 15-01: Scoring + Representative Selection
  references/scoring-formula.md        -- add provenance boost/decay
  references/processing-instructions.md -- add representative selection step
  references/data-models.md            -- add representative_item_id to Event
  data/fixtures/                       -- add provenance scoring fixtures

Plan 15-02: Alert Gating + Output Rendering
  references/processing-instructions.md -- modify Section 5A alert tree
  references/output-templates.md        -- add provenance rendering rules
  references/data-models.md            -- add new user-facing fields
  SKILL.md                             -- update Output Phase rendering notes

Plan 15-03: Weekly Discovery Report + E2E Verification
  references/processing-instructions.md -- add Section 7A or extend Section 7
  references/output-templates.md        -- add discovery report template
  data/fixtures/                       -- add E2E verification fixtures
```

### Pattern 1: Provenance Score Modifier (Post-Formula Multiplier)

**What:** Apply a provenance-based multiplier to `final_score` after the existing 7-dimension formula, rather than adding an 8th dimension that would require rebalancing all weights.

**When to use:** When provenance should influence ranking without restructuring the existing formula.

**Rationale:** The current formula weights sum to 1.00 and have been tuned across phases 0-4. Adding a new weighted dimension would require redistributing weights. A post-formula multiplier preserves the existing balance while introducing provenance influence.

**Design:**

```
# After computing final_score from the 7-dimension formula:

provenance_modifier = lookup_provenance_modifier(item)

adjusted_score = final_score * provenance_modifier
```

The modifier values by tier:

| Tier | Modifier | Rationale |
|------|----------|-----------|
| T0 (eyewitness/primary) | 1.15 | Rare, highest-value original content |
| T1 (direct/official) | 1.10 | Direct source, high provenance value |
| T2 (original reporting) | 1.05 | Original journalism, moderate boost |
| T3 (commentary/analysis) | 1.00 | Neutral -- no boost or penalty |
| T4 (aggregation) -- no direct coverage exists for same event | 1.00 | Aggregation is fine when no alternative exists |
| T4 (aggregation) -- direct T1/T2 coverage exists for same event | 0.75 | Aggregation is redundant, decay the score |

**Critical distinction for T4 decay:** The T4 penalty only applies when a T1 or T2 item covers the **same event** (`event_id` match). This prevents penalizing T4 items that cover events with no direct-source alternative.

**Join path for same-event detection:**
1. For each T4 item, read `item.event_id`
2. If `event_id` is null, modifier = 1.00 (no event context)
3. Load `Event.item_ids` from `data/events/active.json`
4. For each sibling item_id, look up `ProvenanceRecord.tier` in `provenance-db.json`
5. If any sibling has tier T0, T1, or T2, apply 0.75 decay to this T4 item

### Pattern 2: Event Representative Selection (Post-Score, Pre-Quota)

**What:** After scoring and provenance modifier application, but before quota allocation, select exactly one representative item per event for digest inclusion. Other items in the same event remain linked but are excluded from the digest scoring pool.

**When to use:** Always, for events with more than one item in the scored pool.

**Selection criteria (ordered by priority):**
1. **Highest tier** (T0 > T1 > T2 > T3 > T4) -- prefer the most authoritative source
2. **Highest source credibility** (from `config/sources.json`) -- tie-break within same tier
3. **Highest adjusted_score** -- final tie-break

**Design:**
```
For each unique event_id in the scored item pool:
  1. Collect all items with this event_id
  2. If only 1 item -> it is the representative (no action needed)
  3. If multiple items:
     a. Sort by tier rank (T0=0, T1=1, T2=2, T3=3, T4=4) ascending
     b. Among items with the same tier rank, sort by source credibility descending
     c. Among items with the same tier and credibility, sort by adjusted_score descending
     d. The first item is the representative
  4. Mark the representative: set Event.representative_item_id = item.id
  5. Exclude non-representative items from the digest scoring pool
     (set digest_eligible: false for this run only -- do not persist)
```

**Where in the pipeline:** Between "provenance modifier application" (new) and "quota allocation" (Section 4, Step 1). This goes after the cross-digest repetition penalty (Section 4A) and before quota group classification.

### Pattern 3: Tier-Aware Alert Gating (Decision Tree Modification)

**What:** Modify the existing unified alert decision tree (Section 5A) to add a provenance-based threshold adjustment for T4 items and event-level alert suppression.

**Design -- insert two new steps before the existing Step 1:**

```
STEP 0 (new): Event-level alert suppression
  If item has event_id AND event.last_alerted_at is not null:
    Count how many alerts exist in alert_log for this event_id today
    If count >= 1: skip (event already alerted today, even if new item)
  Continue to Step 0A

STEP 0A (new): Tier-aware threshold adjustment
  Look up ProvenanceRecord for item
  If tier == "T4":
    Effective threshold = 0.92 (stricter than default 0.85)
  Else:
    Effective threshold = 0.85 (standard)
  
  Item has importance_score >= effective_threshold?
    NO  -> skip
    YES -> continue to existing Step 2 (form_type check)
```

**Rationale:**
- Event-level suppression prevents multiple alerts for the same event in one day, which is especially important when both T1 and T4 items exist for the same event
- T4 items must clear a higher bar (0.92 vs 0.85) because aggregated content is less likely to represent genuinely breaking news the user has not already seen

### Pattern 4: Provenance-Chain and English-Title Rendering

**What:** Add provenance metadata to digest and alert output rendering. Display source tier, provenance chain (for non-trivial chains), and original-source attribution without leaking internal fields.

**New user-facing fields to add to the rendering contract:**

| Field | Display Label | Render Condition |
|-------|---------------|------------------|
| `ProvenanceRecord.tier` | 信源层级 | Always, for every item |
| `ProvenanceRecord.original_source_name` | 原始来源 | Only when `original_source_name != current_source_name` |
| `ProvenanceRecord.provenance_chain` | 溯源链 | Only when `provenance_chain.length > 1` |
| English title (original) | (rendered as-is after Chinese title) | Only when item `language == "zh"` and original English title is available |

**Digest rendering additions:**

For Core Focus items (full format):
```markdown
### {title}
{English original title if language == zh and English title available}
{2-3 sentence Chinese summary}
来源: {source_name} | 信源层级: {tier_display} | {form_type label} | 重要性: {importance_score}
{原始来源: {original_source_name} -- only if different from current source}
{溯源链: {chain_display} -- only if chain length > 1}
入选依据: {primary_driver_label} | 配额: {quota_group} | 证据: {signal_1}; {signal_2}; ...
```

For compact format items (Adjacent, Hotspot, Explore):
```markdown
- **{title}** -- {1 sentence summary} ({source_name} | {tier_display})
  {原始来源: {original_source_name} -- only if different}
  入选依据: {primary_driver_label} | 配额: {quota_group} | 证据: {signal_1}; ...
```

**Tier display mapping (new):**

| Tier | Chinese Display |
|------|----------------|
| T0 | 一手来源 |
| T1 | 直接来源 |
| T2 | 原创报道 |
| T3 | 评论分析 |
| T4 | 聚合转载 |

**Provenance chain display format:**
```
溯源链: {name_1} ({tier_1}) -> {name_2} ({tier_2}) -> {name_3} ({tier_3})
```
Example: `溯源链: OpenAI Blog (直接来源) -> TechCrunch (原创报道) -> 36Kr (聚合转载)`

Only render this line when `provenance_chain.length > 1`. A single-hop chain (item is the original source) does not need a chain display.

### Pattern 5: Weekly Source-Discovery Report

**What:** Extend the weekly report to include a source-discovery section that surfaces newly enabled sources, auto-disable actions, tier distribution changes, and a watchlist of sources approaching enable thresholds.

**Data sources:**
- `data/provenance/discovered-sources.json` -- decision history, rolling metrics
- `data/provenance/tier-stats.json` -- daily tier distribution for trend comparison
- `config/sources.json` -- current enabled source inventory

**Report section template:**

```markdown
## 来源发现动态

### 本周新增来源
{For each source with decision_history entry "enabled" in last 7 days:}
- **{domain}** ({tier}) -- {representative_titles[0]}
  启用原因: {reason} | 发现时间: {first_seen} | 7日命中: {hit_count_7d}

### 本周停用来源
{For each source with decision_history entry "disabled" in last 7 days:}
- **{domain}** -- 停用原因: {reason_display}

### 信源层级分布
| 层级 | 本周 | 上周 | 变化 |
|------|------|------|------|
| T1 | {count} | {prev_count} | {delta} |
| T2 | {count} | {prev_count} | {delta} |
| T3 | {count} | {prev_count} | {delta} |
| T4 | {count} | {prev_count} | {delta} |

### 观察名单
{For sources approaching enable thresholds (e.g., hit_count_7d >= 3 but < 5, or age approaching 3 days):}
- **{domain}** ({tier}) -- 当前: {hit_count_7d}次/7天, {t1_ratio} T1率
  距启用: {describe gap to thresholds}
```

### Anti-Patterns to Avoid

- **Adding an 8th scoring dimension:** This would force redistribution of existing weights (totaling > 1.0 or requiring all weights to shrink). A post-formula multiplier is cleaner and preserves backward compatibility with the existing formula.
- **Persisting `digest_eligible: false` for representative selection:** Non-representative items should be excluded from the digest pool for the current run only. Persisting this flag would prevent the item from ever appearing in future digests if the event representative changes.
- **Rendering internal ProvenanceRecord fields directly:** Fields like `tier_source`, `tier_confidence`, `rule_result`, and `llm_result` are internal diagnostics. Only `tier`, `original_source_name`, and `provenance_chain` should be rendered.
- **Applying T4 decay without same-event check:** Penalizing all T4 items blindly would harm aggregator coverage of events that have no direct-source alternative. The decay must be conditional on the existence of a higher-tier sibling in the same event.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Provenance join | Custom per-plan join logic | Single documented join path: `NewsItem.id -> provenance-db.json` | The join path is already established in Phase 13 and used by Phase 14. Adding alternative join paths creates divergence. |
| Tier rank comparison | Ad-hoc string comparison | Ordered tier rank map: `{T0:0, T1:1, T2:2, T3:3, T4:4}` | String comparison of "T1" < "T4" happens to work but is fragile and not self-documenting. |
| Same-event sibling detection | Scanning all provenance records | `Event.item_ids` from `data/events/active.json` | The event model already maintains the item-to-event grouping. Scanning provenance-db to reconstruct event membership would be slower and fragile. |
| Discovery decision filtering | Custom date arithmetic | `decision_history[].ts` filtering with 7-day window | The decision history array already carries timestamps. Rolling-window filtering is already established in Phase 14's accumulation logic. |
| English title extraction | LLM call to translate or extract | `ProvenanceRecord.original_source_name` + original title if present | If the original English title is not available in the item record, the provenance chain's source name provides partial attribution without extra LLM cost. |

**Key insight:** Phase 15 is a consumer of existing data contracts. Every data structure it needs already exists from Phases 13-14. The work is wiring provenance data into scoring, alerting, rendering, and reporting paths that currently ignore it.

## Common Pitfalls

### Pitfall 1: T4 Decay Without Same-Event Guard
**What goes wrong:** All T4 items receive a 0.75 decay even when no T1/T2 alternative exists, causing T4-only events to lose visibility.
**Why it happens:** The implementer applies the decay based solely on tier without checking whether a higher-tier sibling covers the same event.
**How to avoid:** The decay conditional MUST check `Event.item_ids` for at least one sibling with tier T0/T1/T2. If no such sibling exists, modifier stays at 1.00.
**Warning signs:** Events that only appear through aggregators (e.g., 36Kr recapping a story nobody else covered) disappear from the digest entirely.

### Pitfall 2: Representative Selection Persisting Exclusion
**What goes wrong:** Non-representative items have `digest_eligible: false` written back to the JSONL file, permanently excluding them from future digests.
**Why it happens:** The implementer treats representative selection as a persistent field update rather than a runtime-only filter.
**How to avoid:** Representative selection exclusion must be applied only to the in-memory scoring pool for the current run. The persistent `digest_eligible` field on the NewsItem must not be modified by representative selection.
**Warning signs:** Items that lost representative status never appear in any future digest even when they become the only remaining coverage of an event.

### Pitfall 3: Breaking the Rendering Contract
**What goes wrong:** Internal provenance fields (`tier_source`, `tier_confidence`, `llm_result`) appear in user-facing output.
**Why it happens:** The implementer renders all available provenance fields rather than consulting the rendering contract whitelist.
**How to avoid:** Explicitly add new user-facing fields to the rendering contract table in `references/output-templates.md`. Any field not in the user-facing table is internal-only by default.
**Warning signs:** Users see raw JSON field names or diagnostic data (e.g., "tier_source: resolved_disagreement") in their digest.

### Pitfall 4: Alert Suppression Race Condition
**What goes wrong:** Two quick-check runs process the same event's T1 and T4 items concurrently, both check event `last_alerted_at` as null, and both send alerts.
**Why it happens:** The alert-state file and event memory update are not coordinated across concurrent runs.
**How to avoid:** The existing file-lock mechanism (`data/.lock`) prevents concurrent pipeline runs. Event-level alert suppression should check `alert_log` entries in the alert-state file (which is run-scoped and already written atomically) rather than relying solely on `Event.last_alerted_at`.
**Warning signs:** Duplicate alerts for the same event from different tiers within the same quick-check cycle.

### Pitfall 5: Provenance Chain Display for T0/T1 Items
**What goes wrong:** A T1 item from OpenAI Blog shows a trivial provenance chain "OpenAI Blog (T1)" as a single-element chain, adding visual noise.
**Why it happens:** The rendering rule displays the chain for all items with a provenance record, not filtering on chain length.
**How to avoid:** Only display the provenance chain line when `provenance_chain.length > 1`. Single-hop chains provide no information beyond what `source_name` and tier already show.
**Warning signs:** Every item in the digest has a redundant "chain" line showing just one entry.

### Pitfall 6: Weekly Report Missing Discovery Data on First Run
**What goes wrong:** The first weekly report after Phase 15 deployment has empty discovery sections because no decision_history entries fall within the 7-day window yet.
**Why it happens:** Discovery state may have been accumulating during Phase 14 but no enable/disable decisions have yet occurred.
**How to avoid:** If no discovery actions occurred in the reporting week, display "No new discovery actions this week" rather than an empty or malformed section. Also include the watchlist section which shows approaching-threshold domains even if no decisions fired.
**Warning signs:** Empty weekly report section with no explanation for the absence.

## Code Examples

### Provenance Score Modifier Lookup

```
// Source: references/scoring-formula.md (to be added)
// Pseudocode for provenance modifier computation

function lookup_provenance_modifier(item, provenance_db, events):
  record = provenance_db[item.id]
  if record is null:
    return 1.00  // no provenance data, neutral modifier
  
  tier = record.tier
  
  // T0-T3: direct modifier lookup
  if tier == "T0": return 1.15
  if tier == "T1": return 1.10
  if tier == "T2": return 1.05
  if tier == "T3": return 1.00
  
  // T4: conditional decay based on same-event siblings
  if tier == "T4":
    if item.event_id is null:
      return 1.00  // no event context, no penalty
    
    event = events[item.event_id]
    if event is null:
      return 1.00
    
    for sibling_id in event.item_ids:
      if sibling_id == item.id: continue
      sibling_record = provenance_db[sibling_id]
      if sibling_record is not null and sibling_record.tier in ["T0", "T1", "T2"]:
        return 0.75  // direct coverage exists, apply decay
    
    return 1.00  // no direct coverage, aggregation is the only option
```

### Representative Selection

```
// Source: references/processing-instructions.md (to be added)
// Pseudocode for event representative selection

TIER_RANK = { "T0": 0, "T1": 1, "T2": 2, "T3": 3, "T4": 4 }

function select_representatives(scored_items, provenance_db, events, sources):
  // Group by event_id
  event_groups = group_by(scored_items, item -> item.event_id)
  
  excluded_ids = set()
  
  for event_id, items in event_groups:
    if event_id is null: continue  // ungrouped items are all eligible
    if items.length == 1: continue  // single item is the representative
    
    // Sort by: tier rank ASC, credibility DESC, adjusted_score DESC
    items.sort(by: [
      (item) -> TIER_RANK[provenance_db[item.id]?.tier ?? "T4"],     // lower rank = better tier
      (item) -> -(sources[item.source_id]?.credibility ?? 0.5),      // higher credibility first
      (item) -> -item.adjusted_score                                  // higher score first
    ])
    
    representative = items[0]
    events[event_id].representative_item_id = representative.id
    
    for item in items[1:]:
      excluded_ids.add(item.id)  // exclude non-representatives from digest pool
  
  return scored_items.filter(item -> item.id not in excluded_ids)
```

### Tier-Aware Alert Decision Tree Entry

```
// Source: references/processing-instructions.md Section 5A (to be modified)
// New steps 0 and 0A inserted before existing step 1

STEP 0: Event-level alert suppression
  if item.event_id is not null:
    alert_state = read alert-state-{today}.json
    event_alerts_today = count(alert_state.alert_log where event_id == item.event_id)
    if event_alerts_today >= 1:
      -> skip (event already alerted today)

STEP 0A: Tier-aware threshold
  record = provenance_db[item.id]
  tier = record?.tier ?? "T4"  // default to T4 if no provenance
  
  if tier == "T4":
    threshold = 0.92
  else:
    threshold = 0.85
  
  if item.importance_score < threshold:
    -> skip (below tier-adjusted threshold)
  
  // Continue to existing Step 2 (form_type check)
```

### Provenance Chain Display

```
// Source: references/output-templates.md (to be added)
// Rendering logic for provenance chain

function render_provenance_line(record):
  if record is null: return ""
  
  lines = []
  
  // Tier display (always)
  lines.append("信源层级: " + TIER_DISPLAY[record.tier])
  
  // Original source attribution (only if different from current)
  if record.original_source_name != record.current_source_name:
    lines.append("原始来源: " + record.original_source_name)
  
  // Provenance chain (only if multi-hop)
  if record.provenance_chain.length > 1:
    chain_parts = []
    for node in record.provenance_chain:
      chain_parts.append(node.name + " (" + TIER_DISPLAY[node.tier] + ")")
    lines.append("溯源链: " + " -> ".join(chain_parts))
  
  return lines

TIER_DISPLAY = {
  "T0": "一手来源",
  "T1": "直接来源",
  "T2": "原创报道",
  "T3": "评论分析",
  "T4": "聚合转载"
}
```

## State of the Art

| Old Approach (pre-Phase 15) | Current Approach (Phase 15) | Impact |
|------------------------------|----------------------------|--------|
| Flat `source_trust` from preferences/credibility | Provenance-aware scoring with tier-based multipliers | T1/T2 items rank higher than redundant T4 aggregation for the same event |
| All items from same event compete in digest | Representative selection picks one item per event | Cleaner digest without redundant event coverage |
| Flat `importance_score >= 0.85` alert threshold | Tier-aware thresholds (0.85 for T0-T3, 0.92 for T4) | Fewer false alerts from aggregated content |
| No event-level alert suppression | Event-level alert suppression prevents duplicate event alerts | At most one alert per event per day |
| `source_name` only in output | Tier, original-source, and provenance chain displayed | Users understand information provenance |
| Weekly report shows source health only | Weekly report includes discovery dynamics | Operators see new sources, disables, tier trends |

## Open Questions

1. **English-title source for Chinese-language items**
   - What we know: PIPE-04 requires "English-title formatting" in output. The `NewsItem` schema has `title` and `language` but no separate `original_title` field.
   - What's unclear: Where does the English original title come from for items fetched from Chinese sources that reference an English original? The provenance chain has `name` and `url` but not the original item's title.
   - Recommendation: If the provenance chain traces back to an English-language original, use `ProvenanceRecord.original_source_name` as attribution text (e.g., "Originally from: OpenAI Blog"). Do NOT add an LLM call to extract or translate titles. If a future phase adds `original_title` to the provenance record, the rendering template can be updated.

2. **Scoring modifier values**
   - What we know: The multiplier values (1.15, 1.10, 1.05, 1.00, 0.75) are reasonable starting points based on the relative trust levels of the tier system.
   - What's unclear: Whether these values produce the right ranking behavior in practice. A T4 item with importance 0.9 and a T1 item with importance 0.6 -- should the T1 still win?
   - Recommendation: Document the modifier values as configurable constants. After initial deployment, they can be tuned based on digest quality observation. The 0.75 T4 decay is deliberately modest to avoid over-penalizing.

3. **`representative_item_id` persistence on Event model**
   - What we know: Representative selection is a runtime operation, but storing the result on the Event model avoids recomputation and provides audit trail.
   - What's unclear: Whether `representative_item_id` should be persisted to `data/events/active.json` or computed fresh each run.
   - Recommendation: Persist it. The representative can change across runs as new items arrive, and persisting the current choice provides operator visibility. Add `representative_item_id` as a nullable field to the Event schema with default null for older records.

## Sources

### Primary (HIGH confidence)
- `references/scoring-formula.md` -- current 7-dimension formula, all weight values, phase activation history
- `references/processing-instructions.md` -- Sections 0G (discovery), 1C (events), 4 (output), 4A (repetition), 5A (alerts), 5B (delta alerts), 7 (weekly)
- `references/output-templates.md` -- digest template, alert templates, rendering contract, display mappings
- `references/data-models.md` -- NewsItem, ProvenanceRecord, Event, Source, DiscoveredSourcesState, TierStats schemas
- `SKILL.md` -- pipeline phase ordering, Output Phase and Quick-Check flow definitions
- `.planning/phases/14-source-discovery-automation/14-CONTEXT.md` -- Phase 14 decisions confirming Phase 15 scope boundary
- `.planning/phases/14-source-discovery-automation/14-RESEARCH.md` -- Phase 14 upstream contracts available to Phase 15
- `data/fixtures/provenance-db-sample.json` -- concrete provenance record examples with T1, T2, T4 tiers
- `data/fixtures/discovered-sources-sample.json` -- concrete discovery state with decision history

### Secondary (MEDIUM confidence)
- Provenance modifier values (1.15/1.10/1.05/1.00/0.75) -- based on reasoning about tier trust hierarchy; tuning may be needed after deployment
- T4 alert threshold (0.92) -- chosen to be meaningfully stricter than 0.85 while not completely blocking T4 alerts; exact value is a judgment call

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all referenced files, schemas, and data paths are verified directly from the repo
- Architecture: HIGH -- patterns are direct modifications to existing well-documented systems (scoring formula, alert tree, output templates)
- Pitfalls: HIGH -- identified from actual repo state and data model constraints (representative persistence, T4 same-event guard, rendering contract)
- Modifier values: MEDIUM -- reasonable starting points but not empirically validated

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (30 days -- stable domain, all dependencies are within this repo)
