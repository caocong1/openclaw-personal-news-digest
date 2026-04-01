# Output Templates Reference

## Daily Digest Template

```markdown
# {date}

## Core Focus

{For each item (scored highest, matching user's core interests):}
### {title}
{2-3 sentence Chinese summary}
Source: {source_name} | {form_type} | Importance: {importance_score}
{If exploration/hotspot slot: "Recommendation reason: {reason}"}

## Adjacent Dynamics

{Neighboring interest news, shorter format:}
- **{title}** -- {1 sentence summary} ({source_name})

## Today's Hotspot

{Public trending news, even if outside user's core interests:}
- **{title}** -- {1 sentence summary} ({source_name})

## Exploration

{Exploration content with recommendation reasons:}
- **{title}** -- {1 sentence summary}
  Recommendation reason: {reason}
  {Examples: "Topic trending recently" / "Follow-up to an event you track" / "High-signal cross-domain content"}

## Event Tracking

{Active events with new developments -- timeline format:}
### {event_title}
- {date}: {development summary}
- {date}: {development summary}

---
Sources: {source_count} | Processed: {total_items} items | Selected: {selected_items} items
LLM calls: {llm_calls} | Cache hits: {cache_hits}
```

---

## Quality Rules

### Insufficient Content

If fewer than 3 items pass the scoring threshold:
- Output a shortened version with only the available items
- Do NOT pad with low-quality filler content
- Do NOT add empty section headers with no items

### Empty Input

If 0 items are available (all filtered, all duplicates, or source failure):
- Do NOT generate an empty digest
- Stay silent or output a brief notice: "No significant news today"
- Never output a digest with section headers but no content

### Section Omission

- Omit any section that has 0 items (do not render empty sections)
- "Event Tracking" section only appears when active events have new developments
- "Exploration" section only appears when exploration_appetite > 0

---

## Output Control Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Daily item count | 15-25 | Number of selected items in daily digest |
| Summary length | 2-3 sentences | Per-item summary length |
| Exploration content | Enabled | Include exploration recommendations |
| Low-content shortening | Enabled | Shorten output when insufficient content |

---

## Breaking News (Kuaixun) Template

For future use -- triggered when an item has importance >= 0.85.

```markdown
**Breaking** -- {timestamp}

**{title}**
{2-3 sentence summary}

Importance: {importance}/10 | Source: {source_name}
{If linked event: "Related event: {event.title}"}
```
