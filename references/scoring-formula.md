# Scoring Formula Reference

## Full 7-Dimension Formula

```
final_score =
    importance_score      * 0.25
  + topic_weight(primary) * 0.20
  + source_trust          * 0.10
  + form_preference_norm  * 0.10
  + feedback_boost        * 0.10
  + recency_score         * 0.15
  + event_boost           * 0.10
```

Total weight: 1.00

---

## Dimension Details

### 1. Importance (weight: 0.25)

Value: `NewsItem.importance_score` (0.0-1.0), set by LLM during classification.

Reference scale:
- 0.9-1.0: Major events with broad impact
- 0.7-0.8: Significant industry/community events
- 0.5-0.6: Noteworthy developments
- 0.3-0.4: General news
- 0.0-0.2: Low information density

### 2. Topic Weight (weight: 0.20)

Value: `preferences.topic_weights[item.categories.primary]` (0.0-1.0)

Lookup the user's weight for the item's primary category from `config/preferences.json`.

### 3. Source Trust (weight: 0.10)

Value: `preferences.source_trust[item.source_id]` if set, otherwise fall back to `source.credibility` from `config/sources.json`.

Range: 0.0-1.0

**Degraded source penalty:** If `source.status == "degraded"` (see `config/sources.json`),
multiply the `source_trust` value by **0.5** before including it in the weighted sum.
This deprioritizes items from degraded sources without completely excluding them.
See `references/processing-instructions.md` Section 6 for the full demotion/recovery state machine.

### 4. Form Preference (weight: 0.10)

Value: Normalized form preference for the item's `form_type`.

Normalization formula:
```
form_preference_norm = (preferences.form_preference[item.form_type] + 1) / 2
```

This maps the [-1, 1] preference range to [0, 1] for scoring.

### 5. Feedback Boost (weight: 0.10)

Value: Computed from `preferences.feedback_samples`, `preferences.source_trust`, and `preferences.feedback_samples.blocked_patterns`.

**feedback_boost calculation:**

```
Read config/preferences.json -> feedback_samples, source_trust

Initialize boost = 0

1. Category match (liked):
   If item.primary_category matches any liked_item's category
   -> boost += 0.3

2. Source trust:
   If item.source_id exists in source_trust AND source_trust[source_id] > 0
   -> boost += min(source_trust[source_id], 0.2)

3. Category match (disliked):
   If item.primary_category matches any disliked_item's category
   -> boost -= 0.3

4. Source distrust:
   If item.source_id exists in source_trust AND source_trust[source_id] < 0
   -> boost -= min(abs(source_trust[source_id]), 0.2)

5. Blocked pattern:
   If item matches any blocked_pattern (substring match on title or tags)
   -> boost -= 0.5

6. Clamp result to [0.0, 1.0]
```

**Cold-start behavior:** If feedback_samples is empty (no liked/disliked items, no trusted/distrusted sources, no blocked patterns), the boost resolves to zero. This preserves Phase 0 behavior until the user provides feedback.

**5-Layer Preference Model (fully active):**
- Layer 1: `topic_weights` -- used in topic_match dimension (weight 0.20)
- Layer 2: `source_trust` -- used in source_score dimension (weight 0.10) and feedback_boost
- Layer 3: `form_preference` -- used in form_match dimension (weight 0.10)
- Layer 4: `style` -- used in output generation for density, exploration appetite
- Layer 5: `feedback_samples` -- used in feedback_boost dimension (weight 0.10)

See `references/feedback-rules.md` for how user feedback updates each layer.

### 6. Recency (weight: 0.15)

Value: Time-decay score based on article age.

Formula:
```
recency_score = max(0, 1 - hours_since_published / 48)
```

- Published just now: 1.0
- Published 24h ago: 0.5
- Published 48h+ ago: 0.0

If `published_at` is null, use `fetched_at` instead.

### 7. Event Boost (weight: 0.10)

Value: Computed from the item's linked event status and importance.

```
event_boost = 0.5  if item.event_id is not null
                     AND event.status == "active"
                     AND event.importance >= 0.7
event_boost = 0    otherwise
```

**Lookup procedure:**
1. If `item.event_id` is null -> `event_boost = 0`
2. Read `data/events/active.json`, find event with matching id
3. If event not found (may have been archived) -> `event_boost = 0`
4. If `event.status == "active"` AND `event.importance >= 0.7` -> `event_boost = 0.5`
5. Otherwise -> `event_boost = 0`

**Effect:** Items linked to high-importance active events receive a 0.05 boost to final_score (0.5 * 0.10 weight). This surfaces continuing stories that the user is likely tracking.

---

## Selection Evidence Mapping

`recommendation_evidence` may only use deterministic scoring and quota signals already produced by the pipeline.

**Legal `primary_driver` values:**
- `topic_match`: Use for core or adjacent items selected because topic affinity was the dominant factor.
- `high_importance`: Use when strong `importance_score` was the primary reason an item stayed in the selected set.
- `event_followup`: Use when event continuity or `event_boost` materially contributed to selection.
- `diversity_balance`: Use when reverse-diversity replacement changed the final selection set.
- `hotspot_injection`: Use when Step 6 hotspot injection forced inclusion.
- `exploration_balance`: Use for exploration quota selections.

**Legal evidence signals:**
- Always allowed: `importance_score`, `quota_group`, `repeat_penalty`
- Include when available from scored/quota state: `topic_weight`, `event_boost`, `source_quality`

---

## Phase Activation Status

**Phase 0 (MVP):** feedback_boost and event_boost were both hardcoded to 0.

**Phase 1:** feedback_boost activated -- computed from user feedback data in `preferences.feedback_samples` and `preferences.source_trust`. At cold start (no feedback data), feedback_boost remains 0.

**Phase 2:** event_boost is now **active** -- computed from event status and importance in `data/events/active.json`. Items linked to active events with importance >= 0.7 receive `event_boost = 0.5`. Items not linked to events or linked to non-active/low-importance events receive 0.

**Phase 4 (current):** Added degraded source penalty documentation. When `source.status == "degraded"`, `source_trust` is multiplied by 0.5 before inclusion in the weighted sum. No formula weights changed -- this is a conditional modifier on the source_trust input value. See Section 3 above.

Current effective formula (Phase 4, with degraded penalty documented):

```
phase2_score =
    importance_score      * 0.25
  + topic_weight(primary) * 0.20
  + source_trust          * 0.10
  + form_preference_norm  * 0.10
  + feedback_boost        * 0.10    <-- ACTIVE (since Phase 1)
  + recency_score         * 0.15
  + event_boost           * 0.10    <-- NOW ACTIVE (was 0 in Phase 0-1)

Effective max: 1.00 (with both feedback data and active high-importance events)
```

## Provenance Modifier (Post-Formula)

Apply provenance as a post-formula multiplier after the 7-dimension weighted sum computes `final_score`.
This does NOT add an eighth dimension and does NOT change any of the existing weights above.

| Tier / Condition | `provenance_modifier` | Notes |
|------------------|-----------------------|-------|
| `T0` | `1.15` | Rare, highest-value original content |
| `T1` | `1.10` | Direct source |
| `T2` | `1.05` | Original reporting |
| `T3` | `1.00` | Neutral |
| `T4` with no direct-coverage sibling in the same event | `1.00` | Neutral when aggregation is the only coverage |
| `T4` with a `T0`/`T1`/`T2` sibling in the same event | `0.75` | Decay redundant aggregation when direct coverage exists |

```
adjusted_score = final_score * provenance_modifier
```

`final_score` remains the output of the existing 7-dimension formula. `adjusted_score` is the provenance-aware score used by downstream ranking, repetition-penalty, representative-selection, and quota steps.

### `lookup_provenance_modifier(item, provenance_db, events)`

```text
# Join path: NewsItem.id -> data/provenance/provenance-db.json
record = provenance_db[item.id]
if record is null:
  return 1.00

tier = record.tier

if tier == "T0":
  return 1.15
if tier == "T1":
  return 1.10
if tier == "T2":
  return 1.05
if tier == "T3":
  return 1.00

if tier != "T4":
  return 1.00

if item.event_id is null:
  return 1.00

# Same-event sibling lookup: Event.item_ids from data/events/active.json
event = events[item.event_id]
if event is null:
  return 1.00

for sibling_id in event.item_ids:
  if sibling_id == item.id:
    continue

  sibling_record = provenance_db[sibling_id]
  if sibling_record is not null and sibling_record.tier in ["T0", "T1", "T2"]:
    return 0.75

return 1.00
```

If an item has no provenance record, use the neutral modifier `1.00`. If a `T4` item has no `event_id`, or its event cannot be found, also use `1.00` because there is no same-event context for sibling detection.

These modifier values are configurable starting points. Tune them after deployment observation if ranking outcomes show over- or under-correction.
