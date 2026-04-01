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

**MVP: Always 0.** No feedback data available at cold start.

Future: Computed from matching patterns in `preferences.feedback_samples`.

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

**MVP: Always 0.** No event tracking in Phase 0.

Future: Items linked to active events receive a boost based on event recency and importance.

---

## MVP Simplification

In MVP (Phase 0), feedback_boost and event_boost are both 0, so the effective formula is:

```
mvp_score =
    importance_score      * 0.25
  + topic_weight(primary) * 0.20
  + source_trust          * 0.10
  + form_preference_norm  * 0.10
  + recency_score         * 0.15

Effective max: 0.80 (relative ordering is what matters)
```

The remaining 0.20 weight (feedback + event) activates in later phases.
