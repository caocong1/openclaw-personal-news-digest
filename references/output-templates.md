# Output Templates Reference

## Daily Digest Template

```markdown
# {date}

## 核心关注

{For each item (scored highest, matching user's core interests):}
### {title}
{2-3 sentence Chinese summary}
来源: {source_name} | {form_type display label} | 重要性: {importance_score}
{If exploration/hotspot slot: "推荐理由: {reason}"}

## 邻近动态

{Neighboring interest news, shorter format:}
- **{title}** -- {1 sentence summary} ({source_name})

## 今日热点

{Public trending news, even if outside user's core interests:}
- **{title}** -- {1 sentence summary} ({source_name})
  推荐理由: {reason}
  {Examples: "High-importance event (score: {importance_score})" / "Widely covered across {N} sources" / "Hotspot injection: importance >= 0.8"}

## 探索发现

{Exploration content with recommendation reasons:}
- **{title}** -- {1 sentence summary}
  推荐理由: {reason}
  {Examples: "Low-exposure category -- broadening your perspective" / "Trending topic outside your usual interests" / "Cross-domain signal worth noting"}

## 事件追踪

{For each active/stable event that had new items merged today:}
### {event_title}
{event_summary (1-2 sentences, current state of the event)}
时间线:
- [{date}] {brief} ({relation display label}) -- 来源: {source_name}
- [{date}] {brief} ({relation display label}) -- 来源: {source_name}
状态: {status display label} | 条目: {item_count} | 首次出现: {first_seen_date}

---
来源数: {source_count} | 处理: {total_items} 条 | 入选: {selected_items} 条
LLM 调用: {llm_calls} | 缓存命中: {cache_hits}

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
【快讯】{title}

{1-sentence summary}

来源: {source_name} | 重要性: {importance_score}
时间: {published_at or fetch time}
```

**No-alert behavior:** If no items meet the threshold after a quick-check run, produce NO output. Do not send "no breaking news" messages. Silence means no breaking news.

---

## Transparency Footer

Appended at the bottom of every daily digest output:

```
---
统计: {source_count} 个来源已检查 | {items_processed} 条已处理 | {llm_calls} 次 LLM 调用 | {cache_hits} 次缓存命中
```

Where:
- `source_count`: Number of enabled sources in sources.json at time of run
- `items_processed`: Number of items that reached processing_status "complete" today
- `llm_calls`: Value of budget.json calls_today at end of run
- `cache_hits`: Sum of classify + summarize cache hits for this run (from daily metrics)

If circuit-breaker was triggered, append: ` | 预算: 已耗尽`
If budget warning was triggered, append: ` | 预算: 已使用 {percentage}%`

---

## Weekly Report Template (OUT-03)

```markdown
# 每周新闻摘要: {start_date} - {end_date}

## 本周概览
{LLM-generated trend narrative, 2-3 paragraphs. Cross-domain synthesis highlighting connections between categories. Written by strong model.}

## 重要事件与时间线
{Top 5-8 events by importance, each with full timeline:}
### {event_title}
{event_summary (current state)}
时间线:
- [{date}] {brief} ({relation display label}) -- 来源: {source_name}
- [{date}] {brief} ({relation display label}) -- 来源: {source_name}
状态: {status display label} | 条目: {item_count} | 首次出现: {first_seen_date}

## 分类趋势
{Per-category highlights with comparison to previous week:}
### {category_name}
- 本周: {item_count} items ({proportion}%)
- 趋势: {up/down/stable compared to previous week}
- 重要报道: {top 2-3 stories from this category}

## 来源健康概况
{Source performance overview:}
- 活跃来源: {count}
- 降级来源: {count and names}
- 质量变化: {sources with significant quality_score changes}
- 本周新增来源: {count}

## 跨领域关联
{LLM-synthesized insights identifying connections across categories. E.g., "AI regulation developments (macro-policy) may affect developer tools adoption (dev-tools)" -- written by strong model.}

---
周统计: {total_items_processed} 条来自 {source_count} 个来源 | {event_count} 个事件追踪中 | {llm_calls} 次 LLM 调用
```

### Quality Rules for Weekly Report

- Must cover >= 5 different categories (ANTI-05 weekly requirement)
- Use weekly quota: core 40% / adjacent 20% / hotspot 20% / explore 20% (more exploration than daily)
- If fewer than 3 days of data available: output shortened version, omit trend comparisons
- Use strong model tier for "One Week Overview" and "Cross-Domain Connections" sections (COST-04)

---

## Display Mapping Tables

These tables define how internal English enum values are rendered as Chinese labels in user-facing output. Internal JSON field values remain in English; only the displayed text is translated.

### form_type Display Mapping

| Internal Value | Chinese Display Label |
|----------------|----------------------|
| `news` | 新闻 |
| `analysis` | 分析 |
| `opinion` | 观点 |
| `announcement` | 公告 |
| `other` | 其他 |

### Event Status Display Mapping

| Internal Value | Chinese Display Label |
|----------------|----------------------|
| `active` | 活跃 |
| `stable` | 稳定 |
| `archived` | 已归档 |

### Timeline Relation Display Mapping

| Internal Value | Chinese Display Label |
|----------------|----------------------|
| `initial` | 首报 |
| `update` | 更新 |
| `correction` | 更正 |
| `analysis` | 分析 |
| `reversal` | 反转 |

---

## Rendering Contract

This section defines which fields are user-facing (rendered in output with Chinese labels) and which are internal-only (never shown to users). When rendering alerts or digest items, use ONLY user-facing fields. If a field is internal-only, it must not appear in any user-visible output. JSON field names (e.g., `importance_score`, `form_type`) must be replaced with their Chinese display labels, never shown raw.

### User-Facing Fields

These fields are rendered in output with their corresponding Chinese labels:

| Field | Display Label | Notes |
|-------|---------------|-------|
| `title` | (rendered as-is) | Item or event title |
| `content_summary` | (rendered as-is) | LLM-generated Chinese summary |
| `source_name` | 来源 | Source display name |
| `importance_score` | 重要性 | Rendered as number (e.g., 0.85) |
| `form_type` | (use Display Mapping) | Rendered as Chinese label (新闻, 分析, etc.) |
| `categories.primary` | (use category display name) | Display name from categories.json |
| Event: `title` | (rendered as-is) | Event title |
| Event: `summary` | (rendered as-is) | Event summary text |
| Event: `timeline[].brief` | (rendered as-is) | Timeline entry description |
| Event: `timeline[].relation` | (use Display Mapping) | Rendered as Chinese label (首报, 更新, etc.) |
| Event: `status` | 状态 | Rendered as Chinese label (活跃, 稳定, 已归档) |
| Event: `importance` | 重要性 | Event importance score |

### Internal-Only Fields

These fields must NEVER appear in any user-visible output:

| Field | Purpose |
|-------|---------|
| `id` | Internal identifier |
| `url` | Original fetch URL |
| `normalized_url` | Dedup-normalized URL |
| `content_hash` | Content fingerprint for dedup |
| `processing_status` | Pipeline processing state |
| `dedup_status` | Deduplication result |
| `duplicate_of` | Reference to original item |
| `_schema_v` | Schema version marker |
| `event_id` | Internal event reference |
| `language` | Detected language code |
| `categories.secondary` | Secondary category assignments |
| `categories.tags` | Processing tags |
| `cached_at` | Cache timestamp |
| `prompt_version` | Cache version key |
