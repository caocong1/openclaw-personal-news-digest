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
  Recommendation reason: {reason}
  {Examples: "High-importance event (score: {importance_score})" / "Widely covered across {N} sources" / "Hotspot injection: importance >= 0.8"}

## Exploration

{Exploration content with recommendation reasons:}
- **{title}** -- {1 sentence summary}
  Recommendation reason: {reason}
  {Examples: "Low-exposure category -- broadening your perspective" / "Trending topic outside your usual interests" / "Cross-domain signal worth noting"}

## Event Tracking

{For each active/stable event that had new items merged today:}
### {event_title}
{event_summary (1-2 sentences, current state of the event)}
Timeline:
- [{date}] {brief} ({relation}) -- Source: {source_name}
- [{date}] {brief} ({relation}) -- Source: {source_name}
Status: {active|stable} | Items: {item_count} | First seen: {first_seen_date}

---
Sources: {source_count} | Processed: {total_items} items | Selected: {selected_items} items
LLM calls: {llm_calls} | Cache hits: {cache_hits}

Append Transparency Footer (see "Transparency Footer" section below) after all content sections.
```

**OUT-04: Recommendation reasons are mandatory for exploration and hotspot items.** They explain WHY the item was included despite not matching the user's core interests. Core Focus and Adjacent Dynamics items do NOT include recommendation reasons (these match user preferences, reasons are self-evident).

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
- "Event Tracking" section appears only when active/stable events received new items merged today. Show most recent 5 timeline entries per event. Older entries omitted with "... and N earlier developments".
- "Exploration" section only appears when exploration_appetite > 0

---

## Output Control Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Daily item count | 15-25 | Number of selected items in daily digest |
| Summary length | depth_preference-dependent | brief=1 sentence, moderate=2-3, detailed=3-5, technical=3-5+specs |
| Exploration content | Enabled | Include exploration recommendations |
| Low-content shortening | Enabled | Shorten output when insufficient content |

---

## Breaking News Alert (Kuaixun)

**Trigger condition:** Any item with `importance_score >= 0.85` during a quick-check run.

**Conservative threshold policy:** Prefer to MISS a breaking story rather than send a false alarm. The threshold of 0.85 is deliberately high. Only events of genuine breaking significance (major policy changes, critical security incidents, landmark product launches by tier-1 companies, significant market events) should reach 0.85.

**Additional safeguards:**
- Only items classified with `form_type: "news"` or `form_type: "announcement"` qualify (no opinion/analysis alerts)
- Maximum 3 alerts per day. If 3 alerts have already been sent today (tracked in daily metrics `alerts_sent_today`), skip further alerts.
- Same-URL dedup: Do not alert for an item whose URL was already alerted (track in metrics `alerted_urls` array)

**Alert format:**
```
[Breaking] {title}

{1-sentence summary}

Source: {source_name} | Importance: {importance_score}
Time: {published_at or fetch time}
```

**No-alert behavior:** If no items meet the threshold after a quick-check run, produce NO output. Do not send "no breaking news" messages. Silence means no breaking news.

---

## Transparency Footer

Appended at the bottom of every daily digest output:

```
---
Stats: {source_count} sources checked | {items_processed} items processed | {llm_calls} LLM calls | {cache_hits} cache hits
```

Where:
- `source_count`: Number of enabled sources in sources.json at time of run
- `items_processed`: Number of items that reached processing_status "complete" today
- `llm_calls`: Value of budget.json calls_today at end of run
- `cache_hits`: Sum of classify + summarize cache hits for this run (from daily metrics)

If circuit-breaker was triggered, append: ` | Budget: EXHAUSTED`
If budget warning was triggered, append: ` | Budget: {percentage}% used`

---

## Weekly Report Template (OUT-03)

```markdown
# Weekly News Digest: {start_date} - {end_date}

## One Week Overview
{LLM-generated trend narrative, 2-3 paragraphs. Cross-domain synthesis highlighting connections between categories. Written by strong model.}

## Key Events & Timelines
{Top 5-8 events by importance, each with full timeline:}
### {event_title}
{event_summary (current state)}
Timeline:
- [{date}] {brief} ({relation}) -- Source: {source_name}
- [{date}] {brief} ({relation}) -- Source: {source_name}
Status: {status} | Items: {item_count} | First seen: {first_seen_date}

## Category Trends
{Per-category highlights with comparison to previous week:}
### {category_name}
- This week: {item_count} items ({proportion}%)
- Trend: {up/down/stable compared to previous week}
- Key stories: {top 2-3 stories from this category}

## Source Health Summary
{Source performance overview:}
- Active sources: {count}
- Degraded sources: {count and names}
- Quality changes: {sources with significant quality_score changes}
- New sources added this week: {count}

## Cross-Domain Connections
{LLM-synthesized insights identifying connections across categories. E.g., "AI regulation developments (macro-policy) may affect developer tools adoption (dev-tools)" -- written by strong model.}

---
Week stats: {total_items_processed} items from {source_count} sources | {event_count} events tracked | {llm_calls} LLM calls total
```

### Quality Rules for Weekly Report

- Must cover >= 5 different categories (ANTI-05 weekly requirement)
- Use weekly quota: core 40% / adjacent 20% / hotspot 20% / explore 20% (more exploration than daily)
- If fewer than 3 days of data available: output shortened version, omit trend comparisons
- Use strong model tier for "One Week Overview" and "Cross-Domain Connections" sections (COST-04)
