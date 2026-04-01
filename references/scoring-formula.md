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

## Phase Activation Status

**Phase 0 (MVP):** feedback_boost and event_boost were both hardcoded to 0.

**Phase 1:** feedback_boost activated -- computed from user feedback data in `preferences.feedback_samples` and `preferences.source_trust`. At cold start (no feedback data), feedback_boost remains 0.

**Phase 2 (current):** event_boost is now **active** -- computed from event status and importance in `data/events/active.json`. Items linked to active events with importance >= 0.7 receive `event_boost = 0.5`. Items not linked to events or linked to non-active/low-importance events receive 0.

Current effective formula (Phase 2, with both feedback and events active):

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
