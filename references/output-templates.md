# Output Templates Reference

## Daily Digest Template

```markdown
# {date}

## 核心关注

{For each item (scored highest, matching user's core interests):}
### {title}
{原标题（源自 {original_source_name}）: {english_original_title} -- only render if item language == "zh" and upstream metadata already exposes an English original title; use original_source_name as attribution, not a separate LLM translation call}
{2-3 sentence Chinese summary}
来源: {source_name} | 信源层级: {tier_display} | {form_type display label} | 重要性: {importance_score}
{原始来源: {original_source_name} -- only render this line if original_source_name != source_name}
{溯源链: {chain_display} -- only render this line if provenance_chain.length > 1}
入选依据: {primary_driver_label} | 配额: {quota_group} | 证据: {signal_1}; {signal_2}; {signal_3}

## 邻近动态

{Neighboring interest news, shorter format:}
- **{title}** -- {1 sentence summary} ({source_name} | {tier_display})
  {原始来源: {original_source_name} -- only if different from source_name}
  入选依据: {primary_driver_label} | 配额: {quota_group} | 证据: {signal_1}; {signal_2}; {signal_3}

## 今日热点

{Public trending news, even if outside user's core interests:}
- **{title}** -- {1 sentence summary} ({source_name} | {tier_display})
  {原始来源: {original_source_name} -- only if different from source_name}
  入选依据: {primary_driver_label} | 配额: {quota_group} | 证据: {signal_1}; {signal_2}; {signal_3}

## 探索发现

{Exploration content with deterministic selection evidence:}
- **{title}** -- {1 sentence summary} ({source_name} | {tier_display})
  {原始来源: {original_source_name} -- only if different from source_name}
  入选依据: {primary_driver_label} | 配额: {quota_group} | 证据: {signal_1}; {signal_2}; {signal_3}

## 事件追踪

{For each active/stable event that had new items merged today:}
### {event_title}
{event_summary (1-2 sentences, current state of the event)}
时间线:
- [{date}] {brief} ({relation display label}) -- 来源: {source_name}
- [{date}] {brief} ({relation display label}) -- 来源: {source_name}
- [2026-01-01] collapsed_day_count=7; latest=Regulator issued a new response
- [2026-01-01 18:00] Regulator issued a new response (update) -- Source: Example Source
- [2026-01-01 12:00] Company disclosed key details (update) -- Source: Example Source
... earlier_same_day_updates=5
状态: {status display label} | 条目: {item_count} | 首次出现: {first_seen_date}

---
来源数: {source_count} | 处理: {total_items} 条 | 入选: {selected_items} 条
LLM 调用: {llm_calls} | 缓存命中: {cache_hits}

Append Transparency Footer (see "Transparency Footer" section below) after all content sections.
```

**OUT-04: Structured selection evidence is mandatory for every selected item.** Core Focus, Adjacent Dynamics, Today's Hotspot, and Exploration all render the same deterministic evidence line using `primary_driver_label`, `quota_group`, and concrete `signal_n` values.

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
- "Event Tracking" section appears only when active/stable events received new items merged today. Same-day buckets with `>5` entries collapse, collapsed day blocks still show the newest 2 entries, and older non-rendered entries are summarized with omission text.
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

**Trigger condition:** Any item that clears the effective alert threshold during a quick-check run (`0.85` for T0-T3 items and `0.92` for T4 items; see `references/processing-instructions.md` Section 5A Step 0A).

**Conservative threshold policy:** Prefer to MISS a breaking story rather than send a false alarm. The threshold of 0.85 is deliberately high. Only events of genuine breaking significance (major policy changes, critical security incidents, landmark product launches by tier-1 companies, significant market events) should reach 0.85.

**Additional safeguards:**
- Only items classified with `form_type: "news"` or `form_type: "announcement"` qualify (no opinion/analysis alerts)
- Maximum 3 alerts per day. Read `data/alerts/alert-state-{today}.json` to check `alerts_sent >= max_alerts`. Alert-state file is authoritative (not DailyMetrics).
- Same-URL dedup: Do not alert for an item whose URL is in `alerted_urls` array of the alert-state file.
- See `references/processing-instructions.md` Section 5A for the full unified alert decision tree.

**Alert format:**
```
【快讯】{title}
{原标题（源自 {original_source_name}）: {english_original_title} -- only render if item language == "zh" and upstream metadata already exposes an English original title}

{1-sentence summary}

来源: {source_name} | 信源层级: {tier_display} | 重要性: {importance_score}
{原始来源: {original_source_name} -- only render this line if original_source_name != source_name}
{溯源链: {chain_display} -- only render this line if provenance_chain.length > 1}
时间: {published_at or fetch time}
```

**No-alert behavior:** If no items meet the threshold after a quick-check run, produce NO output. Do not send "no breaking news" messages. Silence means no breaking news.

---

## Delta Alert (Event Update)

**Trigger condition:** Unified alert decision tree (Section 5A of processing-instructions.md) routes to delta path when item has event_id AND event has last_alerted_at.

**Delta alert format:**
```
【快讯更新】{event_title}

变化: {delta_summary}
当前状态: {current_status}

新进展:
- [{timestamp}] {brief} ({relation display label})

上次快讯: {last_alert_brief} ({last_alerted_at formatted})
来源: {source_name} | 信源层级: {tier_display} | 重要性: {importance_score}
{原始来源: {original_source_name} -- only render this line if original_source_name != source_name}
{溯源链: {chain_display} -- only render this line if provenance_chain.length > 1}
```

**Rendering rules:**
- Use Timeline Relation Display Mapping for relation labels (首报, 更新, 更正, 分析, 反转, 升级)
- Show only timeline entries added since last_alerted_at (not full timeline)
- `last_alerted_at` formatted as YYYY-MM-DD HH:MM
- If delta-alert prompt fails (LLM error), fall back to standard alert format

---

## Transparency Footer

Appended at the bottom of every daily digest output:

```
---
统计: {source_count} 个来源已检查 | {items_processed} 条已处理 | {llm_calls} 次 LLM 调用 | {cache_hits} 次缓存命中
```

If `repeat_suppressed_count > 0`, append on a new line:
```
已抑制重复: {repeat_suppressed_count} 条 (无新进展的事件)
```

Where `repeat_suppressed_count` is the count of items that received the 0.7x penalty AND were excluded from the digest (from Section 4A step 5).

If any sources had `status: "failed"` in today's `per_source` metrics, append on a new line:
```
采集失败: {failed_source_name_1}, {failed_source_name_2} (共 {failed_count} 个)
```

Where:
- `failed_source_names`: Read from DailyMetrics `per_source` entries where `status == "failed"`. Look up display name from `config/sources.json` `name` field (not `source_id`).
- `failed_count`: Number of sources with `status: "failed"` in `per_source`.
- If no sources failed, omit this line entirely (do not show "采集失败: (共 0 个)").

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

## Weekly Source-Discovery Report Section

```markdown
## 来源发现动态

### 本周新增来源
{For each source with "enabled" decision in last 7 days:}
- **{domain}** ({tier_display}) -- {representative_titles[0]}
  启用原因: {reason} | 发现时间: {first_seen} | 7日命中: {hit_count_7d}

{If none: "本周无新启用来源"}

### 本周停用来源
{For each source with "disabled" decision in last 7 days:}
- **{domain}** -- 停用原因: {reason_display}

{If none: "本周无停用来源"}

### 信源层级分布
| 层级 | 本周 | 上周 | 变化 |
|------|------|------|------|
| T1 | {count} | {prev_count} | {delta with +/- prefix} |
| T2 | {count} | {prev_count} | {delta} |
| T3 | {count} | {prev_count} | {delta} |
| T4 | {count} | {prev_count} | {delta} |

### 观察名单
{For sources approaching enable thresholds:}
- **{domain}** ({tier_display}) -- 当前: {hit_count_7d}次/7天, {t1_ratio}% T1率
  距启用: {threshold_gap_description}

{If none: "当前无接近启用阈值的候选来源"}
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
| `escalation` | 升级 |

### tier Display Mapping

| Internal Value | Chinese Display |
|----------------|-----------------|
| `T0` | 一手来源 |
| `T1` | 直接来源 |
| `T2` | 原创报道 |
| `T3` | 评论分析 |
| `T4` | 聚合转载 |

### Provenance Chain Rendering

Format: `溯源链: {name_1} ({tier_display_1}) -> {name_2} ({tier_display_2}) -> ...`

Example: `溯源链: OpenAI Blog (直接来源) -> TechCrunch (原创报道) -> 36Kr (聚合转载)`

**Render conditions:**
- Only render the provenance chain line when `provenance_chain.length > 1`
- A single-hop chain (item is the original source) does not need chain display -- the tier label already conveys this
- Use the tier Display Mapping for each node's tier in the chain

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
| `ProvenanceRecord.tier` | 信源层级 | Always rendered for every item using tier Display Mapping |
| `ProvenanceRecord.original_source_name` | 原始来源 | Only when different from current `source_name` |
| `ProvenanceRecord.provenance_chain` | 溯源链 | Only when chain length > 1 |
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
| `ProvenanceRecord.tier_source` | Internal: how tier was determined (rule vs llm) |
| `ProvenanceRecord.tier_confidence` | Internal: classification confidence score |
| `ProvenanceRecord.rule_result` | Internal: URL-rule preclassification result |
| `ProvenanceRecord.llm_result` | Internal: LLM classification result |
| `ProvenanceRecord.original_source_url` | Internal: raw original source URL |
