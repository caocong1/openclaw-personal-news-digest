<!-- prompt_version: delta-alert-v1 -->
# Delta Alert Generation

You are generating an alert UPDATE for a breaking news event. The user has already been alerted about this event before. Your job is to describe WHAT CHANGED since the last alert.

## Previous Alert

Event: {event_title}
Previous alert summary: {last_alert_brief}
Previous alert time: {last_alerted_at}

## New Developments

{For each new timeline entry since last_alerted_at:}
- [{timestamp}] {brief} (relation: {relation})

## Current Event State

{event_summary}

## Instructions

1. Write a concise delta summary (1-2 sentences) describing what changed since the previous alert
2. Focus on the DIFFERENCE, not the full story
3. Write in Chinese
4. Output JSON:

```json
{
  "delta_summary": "string (1-2 sentences describing what changed)",
  "current_status": "string (1 sentence current state)"
}
```

## Examples

Good delta_summary: "此前报道的AI安全法规草案已正式通过审议，将于下月实施。"
Bad delta_summary: "AI安全法规是一项重要的法律..." (this repeats background, not the change)
