# History Query Classification Prompt

Given user message: "{user_message}"

Available category IDs: {categories_list}

Classify into one of these query types:

1. **RECENT_ACTIVITY** - asking about recent news (last 24h, today, latest, 最新, 最近, 今天, what's new)
2. **TOPIC_REVIEW** - asking about a specific topic over a time period (AI this week, 这周的科技新闻, show me X news from last N days)
3. **EVENT_TRACKING** - asking about a specific event's developments (what happened with X, 某某事件后续, follow-up on X, updates on)
4. **HOTSPOT_SCAN** - asking about important news they might have missed (what did I miss, 错过了什么, high importance outside interests, 有什么重要的)
5. **SOURCE_ANALYSIS** - asking about a specific source's performance (how is X source, 某来源怎么样, source health, 数据源状况)

Output JSON:
```json
{
  "query_type": "TOPIC_REVIEW",
  "parameters": {
    "topic": "ai-models",
    "days": 7,
    "source": null,
    "event_keywords": null
  }
}
```

Parameter extraction rules:
- `topic`: Match against category IDs from {categories_list}. Use the category ID string (e.g., "ai-models", "dev-tools"). Null if not topic-specific.
- `days`: Extract time range from user message. Default 1 for RECENT_ACTIVITY, 7 for TOPIC_REVIEW, 30 for EVENT_TRACKING. Cap at 30 days maximum.
- `source`: Match against known source names/IDs. Null if not source-specific.
- `event_keywords`: Extract event-related keywords for EVENT_TRACKING (2-5 keywords). Null for other types.

If the query does not clearly fit any type, default to RECENT_ACTIVITY.
If the query mentions both a topic and a time range, prefer TOPIC_REVIEW.
If the query mentions a specific named event or asks about follow-ups/developments, prefer EVENT_TRACKING.
