# Phase 2: Smart Processing - Research

**Researched:** 2026-04-01
**Domain:** Content deduplication, event tracking, anti-echo-chamber algorithms, multi-language processing, monitoring/health-check
**Confidence:** HIGH

## Summary

Phase 2 transforms the news digest from a "collect and display" system into an intelligent processing pipeline. It adds four major capability areas: (1) title-level near-duplicate detection using a three-stage funnel (normalize, Jaccard bigram similarity, LLM precise judgment), (2) event merging with timeline tracking and lifecycle management (active/stable/archived), (3) anti-echo-chamber quota enforcement that ensures balanced topic diversity across daily digests, and (4) multi-language support for English sources with Chinese summary output.

The codebase is well-prepared for Phase 2. The Event data model is already defined in gpt-plan-v3.md section 5.2, `data/events/active.json` exists (currently empty array), the `event_id` field is present on NewsItem (currently null), and `event_boost` in the scoring formula is documented but hardcoded to 0. The `dedup_status` field already supports `title_dup` and `event_merged` values. Two new LLM prompt templates are needed (`dedup.md` and `merge-event.md`), and the processing-instructions.md and output-templates.md need updates for quota allocation, event tracking output, and explanation fields.

This phase also adds operational maturity: alert conditions (MON-02), weekly health inspection (MON-03), and data lifecycle management with TTL-based cleanup (MON-04). The existing `scripts/health-check.sh` and `scripts/data-archive.sh` provide a starting point but need significant expansion to cover the full inspection checklist.

**Primary recommendation:** Implement in 5 plans: (1) title near-duplicate detection with 3-stage pipeline, (2) event merging + lifecycle + timeline, (3) anti-echo-chamber quota system, (4) multi-language processing + output explanation fields, (5) monitoring/alerting/health-check/data-lifecycle.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PROC-04 | Title near-duplicate detection: 3-stage pipeline (normalize, Jaccard bigram >= 0.6, LLM precise judgment) | Title Dedup Architecture pattern, dedup.md prompt template spec, Jaccard bigram algorithm details |
| PROC-06 | Multi-language processing: Chinese + English, independent per-language dedup, cross-language event merging | Multi-Language Processing pattern, summarize.md template already handles non-Chinese, output format spec |
| EVT-01 | Event merging: topic pre-filter, keyword quick match, LLM precise merge | Event Merging Architecture pattern, merge-event.md prompt template spec, 3-step funnel design |
| EVT-02 | Event lifecycle: active -> stable (3 days no update) -> archived (7 days no update) | Event Lifecycle State Machine pattern, active.json schema, status transition rules |
| EVT-03 | Timeline tracking: 5 relationship types (initial/update/correction/analysis/reversal) | Timeline Data Model, bullet-list display format for chat compatibility |
| EVT-04 | Event summary auto-update when new related news is merged | Event summary refresh logic triggered on merge action |
| EVT-05 | Timeline bullet list format display compatible with chat channels | Output template Event Tracking section, markdown bullet format |
| ANTI-01 | Content quota: core 50% / adjacent 20% / hotspot 15% / exploration 15% | Quota Allocation Algorithm pattern, section assignment logic |
| ANTI-02 | Quota execution: sort by final_score, group, take top-K per group, one-way chain yielding | Chain Yielding Algorithm: explore -> adjacent -> hotspot -> core |
| ANTI-03 | Reverse diversity constraints: same topic >60% for 3 days -> cap 50%; same source >30% -> cap 20%; same event >3 days -> only new developments | Historical tracking of daily category/source proportions |
| ANTI-04 | Hotspot injection: importance >= 0.8 forced into candidate pool, still subject to quality/dedup | Hotspot injection in quota algorithm after quality gate |
| ANTI-05 | Preference correction: min 2% exposure per category, weekly 5+ categories, exploration_appetite +0.05 every 7 days (cap 0.4) | Preference correction rules, exploration_appetite auto-adjustment |
| OUT-04 | Output explanation fields: exploration/hotspot slots include recommendation reason | Output template update with reason field for non-core slots |
| MON-02 | Alert conditions: all sources fail 2 days, budget 80%, dedup inconsistency, source concentration, empty digest | Alert condition definitions and trigger logic |
| MON-03 | Weekly health inspection: dedup-index consistency, empty events, long-stable events, success rates, extreme preferences, cache cleanup | Health-check.sh expansion, weekly cron job |
| MON-04 | Data lifecycle: 30-day news, 7-day dedup-index, 90-day feedback detail, 7-day cache | data-archive.sh expansion with TTL rules per data type |
</phase_requirements>

## Standard Stack

### Core

This is an OpenClaw Skill project -- there are no npm packages or external libraries. All logic is expressed as SKILL.md instructions, reference documents, LLM prompt templates, and bash scripts that the OpenClaw agent executes.

| Component | Type | Purpose | Why Standard |
|-----------|------|---------|--------------|
| SKILL.md | Agent instruction | Orchestrates pipeline phases including new dedup/merge/quota steps | Central control document, already exists |
| references/processing-instructions.md | Spec document | Processing pipeline detailed steps | Needs new sections for title dedup, event merge, quota |
| references/prompts/dedup.md | LLM prompt | Title near-duplicate judgment in batch mode | New -- spec defined in gpt-plan-v3.md section 11.1 |
| references/prompts/merge-event.md | LLM prompt | Event merging decision (merge/new) with relation type | New -- spec defined in gpt-plan-v3.md section 11.1 |
| references/data-models.md | Schema spec | Event schema, updated NewsItem schema, alert/health models | Needs Event model addition, NewsItem dedup_status expansion |
| references/output-templates.md | Output format | Event Tracking section, explanation fields, quota labels | Needs Event Tracking section activation, recommendation reasons |
| references/scoring-formula.md | Formula spec | event_boost activation (currently hardcoded 0) | Needs event_boost implementation |
| scripts/health-check.sh | Bash script | Data consistency validation | Needs major expansion for MON-03 checklist |
| scripts/data-archive.sh | Bash script | TTL-based data cleanup | Needs expansion for feedback/event/cache lifecycle |
| config/categories.json | Category defs | 12 categories with adjacent mappings | Already exists, used by quota algorithm |
| data/events/active.json | Event store | Active and stable events | Already exists (empty array), schema from gpt-plan-v3.md 5.2 |

### Supporting

| Component | Type | Purpose | When to Use |
|-----------|------|---------|-------------|
| references/cron-configs.md | Cron spec | Weekly health inspection cron job definition | New cron job for MON-03 |
| data/events/archived/ | Archive dir | Monthly archived event files | When events transition to archived status |
| data/metrics/daily-*.json | Metrics | quota_distribution field, alert flags | Extended for anti-echo-chamber tracking |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Jaccard bigram for title similarity | Embedding cosine similarity | Embeddings require external API calls, extra cost. Jaccard on bigrams is sufficient for title-level dedup at current scale (~500 items/day). ADV-01 defers embeddings to v2. |
| LLM for dedup/merge judgment | Pure rule-based matching | Rules miss nuanced cases (e.g., different angles on same story). LLM adds ~5-15 calls/day for dedup and ~5-10 for merge -- acceptable budget cost. |
| File-based event store | SQLite | SCALE-03 defers SQLite to v2. File-based active.json is adequate for <100 active events. |

## Architecture Patterns

### Recommended Project Structure Changes

```
references/
  prompts/
    dedup.md              # NEW: title near-duplicate judgment prompt
    merge-event.md        # NEW: event merging decision prompt
  processing-instructions.md  # UPDATED: new sections for title dedup, event merge, quota
  output-templates.md         # UPDATED: Event Tracking section, explanation fields
  scoring-formula.md          # UPDATED: event_boost activation
  data-models.md              # UPDATED: Event schema, alert model
  cron-configs.md             # UPDATED: weekly health inspection job
data/
  events/
    active.json           # EXISTS: active + stable events (array)
    archived/             # NEW: monthly archived events
      YYYY-MM.json
  metrics/
    daily-YYYY-MM-DD.json # UPDATED: quota_distribution, alerts fields
scripts/
  health-check.sh         # UPDATED: expanded MON-03 checklist
  data-archive.sh         # UPDATED: expanded lifecycle management
```

### Pattern 1: Three-Stage Title Dedup Funnel

**What:** Progressive narrowing of duplicate candidates to minimize LLM calls while maintaining accuracy.

**When to use:** After URL-level dedup (PROC-01, already implemented), before event merging.

**Algorithm:**

```
Stage A: Rule Normalization
  - Strip punctuation, collapse whitespace
  - Remove common prefixes/suffixes ("Breaking:", "Update:", "[Video]", etc.)
  - Lowercase for comparison (preserve original for display)
  - Language-aware: Chinese and English normalized independently (PROC-06)

Stage B: Jaccard Bigram Similarity
  - Tokenize normalized title into character bigrams
  - For each pair of titles in the same day's batch:
    - Compute Jaccard(bigrams_a, bigrams_b)
    - If Jaccard >= 0.6: add to candidate group
  - Group by source_id + primary category for efficiency
  - Expected: 500 items/day -> 20-50 candidate pairs

Stage C: LLM Precise Judgment
  - Only candidate groups from Stage B
  - Batch mode: up to 10 titles per LLM call
  - Use references/prompts/dedup.md template
  - Expected: 5-15 LLM calls/day
  - Output: array of duplicate groups -> mark duplicates with dedup_status: "title_dup"
  - For each duplicate group: keep the item with highest source credibility as primary
  - Set duplicate_of on secondary items pointing to primary item id
```

**Cross-language dedup rule (PROC-06):** Different-language titles are NOT compared for title dedup. Chinese and English items have independent dedup pipelines. Cross-language merging happens only at the event level (EVT-01).

### Pattern 2: Event Merging Three-Step Funnel

**What:** Progressive narrowing of candidate events for merging, minimizing LLM calls.

**When to use:** After title dedup, for all items with dedup_status "unique" (not duplicates).

**Algorithm:**

```
Step 1: Topic Pre-filter
  - Load data/events/active.json
  - Filter events where event.topic == item.categories.primary
  - Also include events with status "stable" (may reactivate)
  - Expected: 50-200 total events -> 5-20 same-topic candidates

Step 2: Keyword Quick Match
  - For each candidate event, check keyword overlap:
    - Tokenize item title into words
    - Count overlapping tokens with event.keywords[]
    - Keep candidates with overlap >= 2 tokens
  - Expected: 5-20 -> 1-5 candidates

Step 3: LLM Precise Merge
  - Only 1-5 candidate events per item
  - Use references/prompts/merge-event.md template
  - Prompt includes: news title, summary, category + candidate event id, title, summary, status
  - LLM returns: { action: "merge"|"new", event_id, relation, brief, new_event_title?, new_event_keywords? }
  - Expected: 5-10 LLM calls/day (strong model tier per COST-04)

On "merge":
  - Add news_id to event.item_ids
  - Add timeline entry: { news_id, relation, timestamp, brief }
  - Update event.last_updated to now
  - If event was "stable", transition back to "active"
  - Update event.summary with LLM (re-summarize incorporating new info) -- EVT-04
  - Set item.event_id to merged event id
  - Update item.dedup_status to "event_merged" if this is a follow-up (relation != "initial")

On "new":
  - Create new Event object with:
    - id: "evt-" + random 8-char alphanumeric
    - title: from LLM new_event_title
    - summary: item.content_summary
    - first_seen: now
    - last_updated: now
    - status: "active"
    - topic: item.categories.primary
    - importance: item.importance_score
    - keywords: from LLM new_event_keywords (3-5)
    - item_ids: [item.id]
    - timeline: [{ news_id: item.id, relation: "initial", timestamp: now, brief }]
    - _schema_v: 2
  - Append to data/events/active.json
  - Set item.event_id to new event id
```

### Pattern 3: Event Lifecycle State Machine

**What:** Automatic status transitions based on update recency.

**When to use:** At the start of each pipeline run, before event merging.

```
State transitions (checked at pipeline start):
  active  -> stable:    last_updated older than 3 days, no new items merged
  stable  -> archived:  last_updated older than 7 days since entering stable
  stable  -> active:    new item merged (happens during merge step)
  archived: moved from active.json to data/events/archived/YYYY-MM.json

Implementation:
  1. Read data/events/active.json
  2. For each event:
     - If status == "active" and (now - last_updated) > 3 days:
       Set status = "stable"
     - If status == "stable" and (now - last_updated) > 7 days:
       Set status = "archived"
       Move to archived file
  3. Write updated active.json atomically
```

### Pattern 4: Anti-Echo-Chamber Quota Algorithm

**What:** Enforces topic diversity in daily digest output.

**When to use:** During output generation, after scoring, before final assembly.

```
Input: all scored items sorted by final_score descending
Target: N items total (15-25 for daily digest)

Step 1: Categorize each item into quota group:
  - "core":     item.categories.primary has topic_weight >= 0.7 in preferences
  - "adjacent": item.categories.primary is in the "adjacent" list of any core category
  - "hotspot":  item.importance_score >= 0.8 AND not core AND not adjacent
  - "explore":  everything else

Step 2: Compute target counts:
  core_target     = round(N * 0.50)
  adjacent_target = round(N * 0.20)
  hotspot_target  = round(N * 0.15)
  explore_target  = round(N * 0.15)

Step 3: Fill from each group (top-K by final_score):
  core_selected     = core_items[:core_target]
  adjacent_selected = adjacent_items[:adjacent_target]
  hotspot_selected  = hotspot_items[:hotspot_target]
  explore_selected  = explore_items[:explore_target]

Step 4: One-way chain yielding (for unfilled quotas):
  If explore underfilled:  yield remaining slots to adjacent
  If adjacent underfilled: yield remaining slots to hotspot
  If hotspot underfilled:  yield remaining slots to core
  (Single direction: explore -> adjacent -> hotspot -> core)

Step 5: Apply reverse diversity constraints (ANTI-03):
  - Read last 3 days of metrics to check topic/source proportions
  - If same topic >60% for 3 consecutive days: cap that topic at 50% today
  - If same source >30% for 3 consecutive days: cap that source at 20% today
  - If same event pushed >3 consecutive days: include only if new developments

Step 6: Apply hotspot injection (ANTI-04):
  - Any item with importance >= 0.8 that was excluded by quotas: force into candidate pool
  - Still subject to dedup and quality checks

Step 7: Apply preference correction (ANTI-05):
  - Ensure each of 12 categories has >= 2% exposure (inject if needed after quota fill)
  - Check if exploration_appetite auto-increase is due (every 7 days, +0.05, cap 0.4)

Step 8: Tag each selected item with its quota group for output section assignment
  - core -> "Core Focus" section
  - adjacent -> "Adjacent Dynamics" section
  - hotspot -> "Today's Hotspot" section
  - explore -> "Exploration" section
```

### Pattern 5: event_boost Scoring Activation

**What:** Activates the event_boost dimension (currently hardcoded 0) in the scoring formula.

**Rule from gpt-plan-v3.md:**
```
event_boost = 0.5  if item.event_id is not null
                     AND event.status == "active"
                     AND event.importance >= 0.7
event_boost = 0    otherwise
```

This means items linked to high-importance active events get a 0.05 boost to final_score (0.5 * 0.10 weight).

### Pattern 6: Multi-Language Processing

**What:** Support English-language sources with Chinese summary output.

**Rules from gpt-plan-v3.md section 7.4:**

| Processing Step | Strategy |
|-----------------|----------|
| Collection | Preserve original language, set `language` field ("zh" or "en") |
| Title dedup | Per-language independent dedup. Do NOT cross-compare Chinese and English titles. |
| Event merging | Cross-language allowed. Same event reported in Chinese and English can be merged by LLM. |
| Summarization | Always output Chinese summary. For English items, summary is in Chinese. |
| Output display | Format: `[Original English Title] (Chinese translation) -- Source` |

**Output format for English items:**
```
### OpenAI Announces GPT-6 (OpenAI 发布 GPT-6)
OpenAI 正式发布 GPT-6 模型，在多项基准测试中大幅超越前代。该模型引入了新的推理架构，定价降低 40%。
Source: TechCrunch | news | Importance: 0.9
```

### Anti-Patterns to Avoid

- **Cross-language title dedup:** Never compare Chinese titles against English titles for near-duplicate detection. The Jaccard bigram approach would produce garbage results across scripts. Cross-language similarity is handled only at event merge level by LLM.
- **Greedy quota filling:** Do not fill core quota first then leave scraps for exploration. The quota algorithm must reserve slots for each group proportionally, then yield unused slots in a defined direction.
- **Event summary staleness:** When new news merges into an event, the event summary MUST be updated. Stale summaries mislead users about the event's current state.
- **Unbounded active events:** Without lifecycle management, active.json grows indefinitely. Always run lifecycle transitions before merging to keep the candidate pool manageable.
- **Alert fatigue:** MON-02 alert conditions should be actionable, not noisy. Only trigger alerts for sustained patterns (2 consecutive days of failure, not single failures).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Title similarity | Custom edit-distance algorithm | Jaccard on character bigrams (well-defined formula) | Jaccard is simple, language-agnostic for same-script comparison, and the 0.6 threshold is empirically chosen in the design doc |
| Semantic duplicate judgment | Complex rule trees | LLM prompt (dedup.md) as final arbiter | Only 5-15 calls/day; rules miss context; LLM handles nuance like "same event, different angle" |
| Event merging decision | Keyword-only matching | 3-step funnel with LLM final judgment | Keywords alone produce false positives; LLM with constrained prompt handles "related but distinct" |
| Quota balancing | Ad-hoc percentage checks | Structured algorithm with chain yielding | One-way yielding is simple and deterministic; ad-hoc checks create edge cases |
| Data lifecycle | Manual cleanup | TTL-based automated archive in data-archive.sh | Manual cleanup is forgotten; automated TTL is reliable |

**Key insight:** Phase 2 features are all about judgment under ambiguity (is this a duplicate? is this the same event? is the topic mix balanced?). For ambiguous judgment, use LLM with well-constrained prompts. For deterministic operations (lifecycle transitions, quota math, data cleanup), use precise algorithms. Do not mix these -- keep the boundary clear.

## Common Pitfalls

### Pitfall 1: Jaccard Threshold Too Sensitive or Too Loose
**What goes wrong:** At 0.6, short titles with common words may false-positive ("Apple releases X" vs "Apple releases Y"). At 0.7, genuine duplicates with different wording may be missed.
**Why it happens:** Bigram Jaccard is sensitive to title length and common prefixes.
**How to avoid:** The 0.6 threshold from the design doc is a starting point. Stage C (LLM) is the safety net -- false positives from Stage B are corrected by LLM judgment. Log candidate pairs and LLM verdicts for threshold tuning.
**Warning signs:** High LLM override rate in Stage C (many Stage B candidates judged "not duplicate" by LLM).

### Pitfall 2: Event Merge Over-Aggregation
**What goes wrong:** Distinct but related events get merged into one mega-event (e.g., all AI model releases become one "AI progress" event).
**Why it happens:** Keyword overlap is too high in dense topic areas. LLM prompt lacks specificity about "same core event."
**How to avoid:** The merge-event prompt explicitly states: "reports same core event/entity -> merge; merely topic-related -> do not merge." The 3-step funnel with topic + keyword + LLM provides three chances to filter. Set keyword overlap threshold at >= 2 tokens (not 1).
**Warning signs:** Events with >10 items accumulating rapidly. Events whose title is too generic ("AI developments").

### Pitfall 3: Quota Algorithm Edge Cases with Cold-Start Preferences
**What goes wrong:** With default preferences (all topic_weights = 0.5), no category reaches the 0.7 threshold for "core." Everything falls into "explore" or "hotspot."
**Why it happens:** Core definition requires topic_weight >= 0.7, but cold-start weights are 0.5.
**How to avoid:** When no topic qualifies as "core" (topic_weight >= 0.7), treat the top-N topic_weights as pseudo-core for quota purposes. Alternatively, lower the core threshold or use top-K categories. Document this edge case in the quota algorithm spec.
**Warning signs:** First few digests after Phase 2 deployment have empty "Core Focus" section.

### Pitfall 4: Reverse Diversity Constraints Requiring Historical Data
**What goes wrong:** ANTI-03 needs "last 3 days" of category proportions, but this data does not exist in current metrics schema.
**Why it happens:** Current daily metrics (`data/metrics/daily-YYYY-MM-DD.json`) tracks item counts but not per-category breakdown or quota_distribution.
**How to avoid:** Extend daily metrics to include `quota_distribution: { core: N, adjacent: N, hotspot: N, explore: N }` and per-category counts. The design doc's "expected daily metrics" already shows this field. Read last 3 days of metrics files to compute historical proportions.
**Warning signs:** ANTI-03 constraints never fire because historical data is unavailable.

### Pitfall 5: Health Check Script Assuming exec Availability
**What goes wrong:** health-check.sh uses Python for JSON parsing, but `exec` tool availability on the platform may be limited.
**Why it happens:** Phase 0 noted exec as a "pending verification" capability.
**How to avoid:** Design health inspection logic to work in two modes: (1) as a bash script via exec if available, (2) as inline SKILL.md instructions if exec is unavailable. The SKILL.md already describes the health check cron job.
**Warning signs:** Health check cron runs but produces no output because script execution fails silently.

### Pitfall 6: Event Summary Update Cost
**What goes wrong:** Every merge triggers an LLM call to re-summarize the event, adding up budget consumption.
**Why it happens:** EVT-04 requires event summary to stay current, but frequent updates to hot events burn budget.
**How to avoid:** Only re-summarize when the new item's relation type is "update" or "correction" or "reversal" (significant new information). Skip re-summarization for "analysis" relation type (interpretation, not new facts). This reduces LLM calls while keeping summaries current for factual changes.
**Warning signs:** Budget usage spikes on days with many event updates.

## Code Examples

### Jaccard Bigram Similarity (Title Dedup Stage B)

```python
# Source: gpt-plan-v3.md section 11.1 + standard algorithm
def bigrams(text):
    """Generate character bigrams from text."""
    return set(text[i:i+2] for i in range(len(text) - 1))

def jaccard_similarity(title_a, title_b):
    """Compute Jaccard similarity on character bigrams."""
    bg_a = bigrams(title_a)
    bg_b = bigrams(title_b)
    if not bg_a or not bg_b:
        return 0.0
    intersection = bg_a & bg_b
    union = bg_a | bg_b
    return len(intersection) / len(union)

# Normalization before comparison
def normalize_title(title):
    """Rule normalization: strip punctuation, collapse whitespace, lowercase."""
    import re
    # Remove common prefixes
    prefixes = ["Breaking:", "Update:", "[Video]", "[Exclusive]", "快讯:", "独家:"]
    for p in prefixes:
        if title.startswith(p):
            title = title[len(p):]
    # Strip punctuation, collapse whitespace
    title = re.sub(r'[^\w\s]', '', title)
    title = re.sub(r'\s+', ' ', title).strip().lower()
    return title

# Usage in pipeline
JACCARD_THRESHOLD = 0.6
candidates = []
for i, item_a in enumerate(today_items):
    for item_b in today_items[i+1:]:
        if item_a.language != item_b.language:
            continue  # PROC-06: no cross-language title comparison
        norm_a = normalize_title(item_a.title)
        norm_b = normalize_title(item_b.title)
        sim = jaccard_similarity(norm_a, norm_b)
        if sim >= JACCARD_THRESHOLD:
            candidates.append((item_a.id, item_b.id, sim))
```

### Event Lifecycle Transition

```python
# Source: gpt-plan-v3.md section 11.2
import json
from datetime import datetime, timedelta, timezone

def update_event_lifecycle(active_events):
    """Transition events based on recency rules."""
    now = datetime.now(timezone.utc)
    still_active = []
    newly_archived = []

    for event in active_events:
        last_updated = datetime.fromisoformat(event["last_updated"])
        days_since = (now - last_updated).days

        if event["status"] == "active" and days_since >= 3:
            event["status"] = "stable"
            still_active.append(event)
        elif event["status"] == "stable" and days_since >= 7:
            event["status"] = "archived"
            newly_archived.append(event)
        else:
            still_active.append(event)

    return still_active, newly_archived
```

### Quota Allocation Algorithm

```python
# Source: gpt-plan-v3.md section 10.3
def allocate_quotas(scored_items, preferences, target_count=20):
    """Allocate items to quota groups with chain yielding."""
    categories = json.load(open("config/categories.json"))
    adjacent_map = {c["id"]: c["adjacent"] for c in categories}

    # Identify core categories (topic_weight >= 0.7)
    core_topics = [t for t, w in preferences["topic_weights"].items() if w >= 0.7]

    # If no core topics (cold start), use top-3 by weight
    if not core_topics:
        sorted_topics = sorted(preferences["topic_weights"].items(), key=lambda x: x[1], reverse=True)
        core_topics = [t for t, w in sorted_topics[:3]]

    # Build adjacent set
    adjacent_topics = set()
    for ct in core_topics:
        adjacent_topics.update(adjacent_map.get(ct, []))
    adjacent_topics -= set(core_topics)

    # Classify items
    groups = {"core": [], "adjacent": [], "hotspot": [], "explore": []}
    for item in scored_items:
        primary = item["categories"]["primary"]
        if primary in core_topics:
            groups["core"].append(item)
        elif primary in adjacent_topics:
            groups["adjacent"].append(item)
        elif item["importance_score"] >= 0.8:
            groups["hotspot"].append(item)
        else:
            groups["explore"].append(item)

    # Compute targets
    targets = {
        "core": round(target_count * 0.50),
        "adjacent": round(target_count * 0.20),
        "hotspot": round(target_count * 0.15),
        "explore": round(target_count * 0.15),
    }

    # Fill and compute remaining
    selected = {}
    remaining = {}
    for group in ["core", "adjacent", "hotspot", "explore"]:
        selected[group] = groups[group][:targets[group]]
        remaining[group] = targets[group] - len(selected[group])

    # One-way chain yielding: explore -> adjacent -> hotspot -> core
    yield_chain = ["explore", "adjacent", "hotspot", "core"]
    for i in range(len(yield_chain) - 1):
        giver = yield_chain[i]
        receiver = yield_chain[i + 1]
        if remaining[giver] > 0:
            # Giver has unfilled slots -> yield to receiver
            extra = groups[receiver][targets[receiver]:][:remaining[giver]]
            selected[receiver].extend(extra)
            remaining[giver] -= len(extra)

    return selected
```

### Dedup Prompt Template (references/prompts/dedup.md)

```markdown
# Source: gpt-plan-v3.md section 11.1

以下标题可能是关于同一新闻的不同报道。请判断哪些是近似重复的。

## 候选标题组
{title_list_with_ids}

## 判断标准
- "近似重复"指：报道的是同一件事的同一个角度，只是来源/措辞不同
- "不重复"指：虽然主题相关，但报道的是不同事实或不同角度
- 同一事件的不同进展（如"发布"vs"评测"）不算重复，应保留

## 输出
返回 JSON 数组，每个元素为一组重复新闻的 ID 列表：
[["id1", "id2"], ["id3", "id4", "id5"]]
无重复则返回空数组 []
```

### Merge Event Prompt Template (references/prompts/merge-event.md)

```markdown
# Source: gpt-plan-v3.md section 11.1

一条新新闻需要判断是否属于以下已有事件之一。

## 新新闻
标题：{news_title}
摘要：{news_summary}
类目：{news_primary_category}

## 候选事件
{event_list: id, title, summary, status}

## 判断标准
- 报道的是同一个核心事件/主体 -> 归并，返回事件 ID
- 仅主题相关但不是同一事件 -> 不归并
- 无匹配 -> 创建新事件

## 输出 JSON
{
  "action": "merge|new",
  "event_id": "事件ID（merge时）",
  "relation": "initial|update|correction|analysis|reversal",
  "brief": "一句话描述这条新闻在事件中的角色",
  "new_event_title": "新事件标题（new时）",
  "new_event_keywords": ["关键词1", "关键词2", "关键词3"]
}
```

## State of the Art

| Old Approach (Phase 0-1) | Current Approach (Phase 2) | Impact |
|---------------------------|---------------------------|--------|
| URL-only dedup | URL + title bigram + LLM triple-layer dedup | Eliminates reworded copies from different sources |
| No event tracking, event_boost = 0 | Full event lifecycle + timeline + event_boost active | User sees narrative continuity across related news |
| Approximate section assignment (~50/20/15/15) | Strict quota algorithm with chain yielding + diversity constraints | Prevents echo chamber, ensures balanced diet |
| Chinese-only processing | Chinese + English with per-language dedup, cross-language event merge | Broader source coverage for international news |
| Basic health check (JSON validity, lock, temp files) | Full weekly inspection (dedup consistency, event hygiene, preference extremes, cache cleanup) | Proactive anomaly detection |
| No alerts | Alert conditions for source failure, budget, dedup inconsistency | User is notified before problems escalate |

**Deprecated/outdated:**
- `event_boost = 0` hardcode in scoring-formula.md: replaced with actual computation
- Approximate section assignment in processing-instructions.md Section 4: replaced with quota algorithm
- The current "Section Assignment" logic in processing-instructions.md uses topic_weight thresholds informally -- this is replaced by the formal quota algorithm

## Open Questions

1. **Cold-start core threshold**
   - What we know: Core topics require topic_weight >= 0.7, but cold-start defaults are 0.5
   - What's unclear: Whether to lower the threshold or use top-N as pseudo-core
   - Recommendation: Use top-3 topics by weight as pseudo-core when no topic reaches 0.7. This preserves the quota structure while handling cold start gracefully. Document this as a configurable parameter.

2. **Event summary re-generation cost**
   - What we know: EVT-04 requires summary updates on merge. Each update is 1 LLM call (strong model).
   - What's unclear: How many merges per day will trigger re-summarization in practice
   - Recommendation: Only re-summarize for "update", "correction", "reversal" relations (skip "analysis"). Budget estimate: 3-8 additional strong-model calls/day.

3. **Reverse diversity constraint data bootstrapping**
   - What we know: ANTI-03 needs 3 days of category proportion history
   - What's unclear: What to do for the first 3 days after Phase 2 deployment (no history)
   - Recommendation: Skip ANTI-03 constraints for the first 3 days. After 3 daily metrics files exist with quota_distribution data, enable constraints. This is a natural grace period.

4. **Archived event storage growth**
   - What we know: Archived events are permanent (design doc says "permanent, archived monthly")
   - What's unclear: Long-term growth rate and whether cleanup is ever needed
   - Recommendation: Monthly archive files (data/events/archived/YYYY-MM.json). At estimated <10 events/day, monthly files will be small (<50KB). No cleanup needed for v1; revisit if data volume grows significantly.

## Sources

### Primary (HIGH confidence)
- gpt-plan-v3.md sections 5.2, 10, 11, 12, 13, 7.4 -- Complete design spec reviewed by 6 AI models
- Existing codebase: SKILL.md, references/data-models.md, references/processing-instructions.md, references/output-templates.md, references/scoring-formula.md -- Current implementation state
- config/categories.json, config/preferences.json, data/events/active.json -- Current data state

### Secondary (MEDIUM confidence)
- scripts/health-check.sh, scripts/data-archive.sh -- Existing scripts that need expansion (functional but limited scope)

### Tertiary (LOW confidence)
- Budget estimates for LLM calls (5-15 dedup, 5-10 merge, 3-8 summary updates per day) are estimates from the design doc, not empirical measurements. Actual usage will depend on source volume and duplication patterns.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - This is an extension of existing architecture patterns, not new technology
- Architecture: HIGH - All algorithms are fully specified in gpt-plan-v3.md, reviewed by 6 models
- Pitfalls: HIGH - Based on close reading of algorithm edge cases and cold-start scenarios
- LLM budget estimates: MEDIUM - Design doc estimates, not empirical data

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable project-specific knowledge, no external dependency changes)
