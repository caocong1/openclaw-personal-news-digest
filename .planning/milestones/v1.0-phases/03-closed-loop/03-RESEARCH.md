# Phase 3: Closed Loop - Research

**Researched:** 2026-04-01
**Domain:** Preference decay, weekly reports, natural language history queries, 7-layer preference model, source auto-demotion/recovery
**Confidence:** HIGH

## Summary

Phase 3 closes the feedback loop of the news digest system by adding five interconnected capabilities: (1) preference decay that prevents interest fixation over time, (2) weekly trend reports with cross-domain synthesis, (3) natural language history queries against JSONL data, (4) preference state visualization as human-readable text, and (5) self-healing source management that auto-demotes low-quality sources and auto-recovers improved ones. These capabilities build entirely on the existing infrastructure from Phases 0-2 -- the JSONL storage, event tracking, 5-layer preference model, quota system, source health metrics, and daily metrics pipeline are all already in place.

The key technical challenge is that all "intelligence" here is LLM-driven within the OpenClaw Skill framework -- there are no databases, no embedding indexes, no external services. History queries scan JSONL files by date range and filter by field values. Weekly reports aggregate 7 days of daily metrics and news items via LLM synthesis. Preference decay is a simple arithmetic operation on existing preference fields. The 7-layer model extension adds two new JSON fields. Source auto-demotion reads existing `quality_score` stats and flips a `status` field. All of this fits naturally into the established patterns.

**Primary recommendation:** Organize into 4 plans: (1) preference decay + 7-layer model + preference visualization (all touch `config/preferences.json`), (2) source auto-demotion/recovery (touches `config/sources.json` + SKILL.md pipeline), (3) weekly report generation (new output type + cron job), (4) history query system (new SKILL.md user command routing + query handlers).

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SRC-09 | Source auto-demotion (quality_score < 0.2 for 14 days) and auto-recovery (> 0.3 for 7 days) | Source model already has `stats.quality_score` and `status` field with `"degraded"` value. Need to add tracking fields (`degraded_since`, `recovery_streak`) and insert check into pipeline. Design doc specifies exact thresholds. |
| PREF-04 | Preference decay -- every 30 days, weights regress 5% toward 0.5 mean | `preferences.json` already has `last_decay_at` field (currently null). Design doc specifies formula `w_new = w + (0.5 - w) * 0.05`. Simple arithmetic on `topic_weights`, `source_trust`, `form_preference`. |
| PREF-06 | Preference visualization -- text description of current preference state | Read `preferences.json`, generate human-readable summary of what the system has learned. LLM-assisted formatting of structured data into natural language. |
| PREF-07 | Extend to 7-layer preference model -- add `depth_preference` and `judgment_angles` | Add two new fields to `preferences.json`. Wire into scoring formula or output generation. Schema version bump. |
| OUT-03 | Weekly report -- trend analysis, event timelines, cross-domain summary, 30-50 items | New output template in `references/output-templates.md`. New cron job (Sunday 20:00). Aggregates 7 days of data. Different quota ratios (40/20/20/20). |
| HIST-01 | Recent activity query -- last 24 hours | Read today's JSONL, filter by `processing_status: "complete"`, present sorted results. |
| HIST-02 | Topic review -- filter by category over N days | Read N days of JSONL files, filter by `categories.primary`, summarize via LLM. |
| HIST-03 | Event tracking query -- check active event follow-ups | Read `data/events/active.json`, find matching events, present timeline. |
| HIST-04 | Hotspot scan -- high importance items outside user preferences | Read recent JSONL, filter `importance_score >= 0.7` AND `topic_weight < 0.5`, present as "things you might have missed". |
| HIST-05 | Source analysis and health query | Read `config/sources.json` stats fields, format as health dashboard. |
| HIST-06 | Preference state query (overlaps PREF-06) | Same as PREF-06 -- read `preferences.json`, generate text description. |
</phase_requirements>

## Standard Stack

### Core

This phase adds no new libraries or external dependencies. Everything is built within the existing OpenClaw Skill framework using:

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| OpenClaw Skill framework | current | All execution happens as SKILL.md instructions | Platform constraint -- must run as Skill |
| JSONL files (by-date) | N/A | Primary data store for news items | Established in Phase 0, no migration needed |
| JSON config files | N/A | Preferences, sources, categories, budget | Established in Phase 0 |
| LLM (via OpenClaw agent) | platform default | Weekly report synthesis, history query summarization, preference visualization | Same as all prior phases |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `references/prompts/*.md` | LLM prompt templates | New prompts needed for weekly report and history query |
| `scripts/health-check.sh` | Source health monitoring | Already exists, may need minor extension for degradation tracking |
| `data/metrics/daily-*.json` | Aggregation source for weekly reports | Already written by daily pipeline |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| JSONL scan for history | SQLite index | Better query performance but adds dependency; design doc explicitly defers SQLite to "if performance becomes bottleneck" |
| LLM-based query interpretation | Regex pattern matching | Simpler but brittle; LLM handles natural language variation much better |
| Manual preference decay formula | Exponential decay | Exponential converges faster but the 5% linear regression is specified in the design doc and is simpler to reason about |

## Architecture Patterns

### Recommended Changes to Existing Structure

```
references/
├── output-templates.md          # ADD: weekly report template section
├── processing-instructions.md   # ADD: preference decay procedure, source auto-demotion
├── feedback-rules.md            # ADD: preference visualization procedure
├── prompts/
│   ├── weekly-report.md         # NEW: weekly report synthesis prompt
│   └── history-query.md         # NEW: history query interpretation + response prompt
config/
├── preferences.json             # MODIFY: add depth_preference, judgment_angles fields
├── sources.json                 # MODIFY: add degraded_since, recovery_streak to stats
SKILL.md                         # MODIFY: add decay check, degradation check, weekly output, history query routing
references/cron-configs.md       # ADD: weekly report cron job definition
```

### Pattern 1: Preference Decay as Pipeline Pre-Step

**What:** Check `last_decay_at` at the start of each daily pipeline run. If >= 30 days ago (or null), apply decay formula to all numeric preference fields, then continue with normal pipeline.

**When to use:** Every daily pipeline run, as a pre-processing step before feedback processing.

**Implementation approach:**
```
1. Read preferences.json
2. If last_decay_at is null OR (now - last_decay_at) >= 30 days:
   a. For each topic_weights[key]: w_new = w + (0.5 - w) * 0.05
   b. For each source_trust[key]: w_new = w + (0.0 - w) * 0.05  (decay toward 0 = neutral/absent)
   c. For each form_preference[key]: w_new = w + (0.0 - w) * 0.05  (decay toward 0 = neutral)
   d. Set last_decay_at = now
   e. Backup-before-write, atomic write
3. Continue with normal pipeline
```

**Key design decisions:**
- `topic_weights` decay toward 0.5 (cold-start neutral)
- `source_trust` decays toward 0 (absent = use source.credibility default)
- `form_preference` decays toward 0 (neutral = no preference)
- Decay runs AT MOST once per 30-day period, not accumulating missed periods
- Design doc explicitly says "no catch-up" -- if 60 days passed, still only one decay application

### Pattern 2: Source Auto-Demotion State Machine

**What:** After computing source health stats (already done each run), check if any source should transition to `degraded` or recover to `active`.

**When to use:** During Processing Phase, after source stats computation.

**Implementation approach:**
```
For each source in sources.json:
  IF status == "active" AND quality_score < 0.2:
    IF degraded_since is null: set degraded_since = today
    IF (today - degraded_since) >= 14 days: set status = "degraded"
  ELSE IF status == "active":
    Reset degraded_since = null  (quality recovered before triggering demotion)

  IF status == "degraded" AND quality_score > 0.3:
    IF recovery_streak is null: set recovery_streak_start = today
    IF (today - recovery_streak_start) >= 7 days: set status = "active", reset tracking fields
  ELSE IF status == "degraded" AND quality_score <= 0.3:
    Reset recovery_streak_start = null  (quality dipped again)

Degraded sources: still collected but at lower priority (skip if budget is tight)
```

**New fields on Source.stats:**
- `degraded_since`: ISO8601 or null -- when quality_score first dropped below 0.2
- `recovery_streak_start`: ISO8601 or null -- when quality_score first rose above 0.3 during degraded status

### Pattern 3: Weekly Report as Aggregation Output

**What:** New output type that aggregates 7 days of daily data into a trend report with different quota ratios.

**When to use:** Triggered by weekly cron job (Sunday 20:00 CST).

**Implementation approach:**
```
1. Read last 7 days of data/news/YYYY-MM-DD.jsonl files
2. Read last 7 days of data/metrics/daily-*.json files
3. Read data/events/active.json for event timelines
4. Aggregate:
   - Category distribution trends (which topics grew/shrank)
   - Top events with full timelines
   - Source performance summary
   - Items not in daily digests but worth noting
5. Apply weekly quota: core 40% / adjacent 20% / hotspot 20% / explore 20%
6. Use LLM (strong model) for cross-domain synthesis narrative
7. Ensure >= 5 different categories represented (ANTI-05 requirement)
8. Write to output/latest-weekly.md
9. Write weekly metrics
```

**Weekly report template structure (from design doc):**
- One Week Overview (trend narrative, 2-3 paragraphs)
- Key Events & Timelines (top 5-8 events with full timeline)
- Category Trends (per-category highlights, comparison to previous week)
- Source Health Summary (quality changes, new sources, degraded sources)
- Cross-Domain Connections (LLM-synthesized insights across categories)
- Statistics footer

### Pattern 4: History Query as User Command Router

**What:** Extend SKILL.md "User Commands" section to detect history query intent and route to the appropriate handler.

**When to use:** When user sends a message that is not a cron trigger and not source management or feedback.

**Implementation approach:**
```
When user message detected as query intent:
1. Classify query type using the 6 HIST categories:
   - Time-based: "最近24小时" / "last 24 hours" / "今天" -> HIST-01
   - Topic-based: "AI这周" / "show me X news" -> HIST-02
   - Event-based: "某事件后续" / "what happened with X" -> HIST-03
   - Hotspot: "我错过了什么" / "high importance outside my interests" -> HIST-04
   - Source: "某来源最近怎样" / "how is X source doing" -> HIST-05
   - Preference: "我的偏好" / "what have you learned about me" -> HIST-06

2. Execute data lookup:
   - HIST-01: Read today's JSONL, filter complete items, sort by final_score
   - HIST-02: Read N days JSONL, filter by categories.primary match
   - HIST-03: Read active.json, match event by title/keywords
   - HIST-04: Read recent JSONL, filter importance >= 0.7 AND topic_weight < 0.5
   - HIST-05: Read sources.json, format stats for matched source
   - HIST-06: Read preferences.json, generate text description

3. Format response:
   - For item lists: Compact format (title, summary, source, date)
   - For events: Timeline format (already defined in output-templates.md)
   - For preferences/sources: Dashboard-style text
   - Cap results at 20 items to avoid overwhelming the chat
```

### Pattern 5: Preference Visualization as Text Description

**What:** Convert structured preferences.json into a human-readable narrative that explains what the system has learned.

**When to use:** When user asks about their preferences (HIST-06/PREF-06).

**Example output format:**
```
## Your Preference Profile

**Top interests:** AI Models (weight: 0.8), Developer Tools (weight: 0.75), Open Source (weight: 0.7)
**Lower interest:** Gaming (weight: 0.3), Finance (weight: 0.35)
**Neutral topics:** Business (0.5), International (0.5), ...

**Trusted sources:** 36Kr (trust: +0.9), TechCrunch (+0.7)
**Distrusted sources:** None

**Content style:** You prefer analysis over opinion pieces. You have low rumor tolerance.
**Exploration:** Moderate (appetite: 0.35) -- system will show some diverse content

**Depth preference:** [Phase 3 new] Moderate -- balanced between headlines and deep dives
**Judgment angles:** [Phase 3 new] Not yet learned -- will develop over time

**Feedback history:** {total_feedback_count} feedback signals processed
**Last preference update:** {last_updated}
**Last decay applied:** {last_decay_at}
```

### Anti-Patterns to Avoid

- **Over-engineering history queries:** Do NOT build a query DSL or structured query language. The LLM interprets natural language and maps to the 6 predefined query types. If the query does not fit any type, respond helpfully rather than failing.
- **Accumulating decay:** Do NOT apply multiple decay rounds if more than 30 days have passed. The design doc explicitly says no catch-up -- one decay application regardless of elapsed time.
- **Blocking on degraded sources:** Degraded sources should still be fetched (at lower priority), not completely disabled. The user did not choose to disable them -- the system demoted them automatically and they should have a path back.
- **Weekly report as just "7 daily digests concatenated":** The weekly report must include synthesis, trend analysis, and cross-domain connections. Use the strong model tier for this LLM call.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Natural language query parsing | Regex-based intent classifier | LLM classification of query type | 6 query types with infinite phrasings in zh+en; LLM handles this natively |
| Preference text description | Template string interpolation | LLM formatting of structured data | Natural-sounding narratives require language understanding |
| Weekly trend synthesis | Statistical summary tables | LLM cross-domain synthesis with strong model | Identifying connections across categories requires reasoning |
| Date range JSONL scanning | Custom index file | Direct file read by date-named files | Files are already date-partitioned; 7-day scan reads at most 7 files |

**Key insight:** The OpenClaw Skill framework already provides the LLM as a core tool. All "intelligence" in Phase 3 is LLM-driven interpretation and synthesis. The data structures (JSONL, JSON configs) are simple enough that direct file access with date-based partitioning is sufficient for the expected data volume (~500 items/day, 30-day retention).

## Common Pitfalls

### Pitfall 1: Preference Decay Compounding with Feedback

**What goes wrong:** If decay runs and then feedback is processed in the same run, the feedback may overshoot because it's adjusting from an already-decayed baseline.
**Why it happens:** Decay and feedback both modify the same preference fields in the same pipeline run.
**How to avoid:** Run decay BEFORE feedback processing (as specified in the design doc flow). This way feedback adjustments work against the post-decay baseline, which is correct -- the user's recent feedback should override the decay.
**Warning signs:** Preference weights oscillating between runs instead of converging.

### Pitfall 2: Source Degradation Flapping

**What goes wrong:** A source repeatedly toggles between active and degraded because quality_score fluctuates around the threshold.
**Why it happens:** quality_score is recomputed every run based on 7-day rolling window. A single good/bad day can tip it across 0.2/0.3 boundaries.
**How to avoid:** The 14-day demotion delay and 7-day recovery delay already provide hysteresis. Additionally, `degraded_since` must be reset when quality recovers before the 14-day trigger, preventing premature demotion on brief dips.
**Warning signs:** Source status changing every few days in the metrics logs.

### Pitfall 3: Weekly Report LLM Context Overflow

**What goes wrong:** Feeding 7 days * ~500 items = ~3500 items to the LLM for weekly synthesis exceeds context limits.
**Why it happens:** Naive implementation reads all items and passes them to a single prompt.
**How to avoid:** Pre-filter before LLM call: (a) use only items that were selected for daily digests (already filtered to 15-25/day = ~150/week), (b) group by category and summarize per-category before cross-domain synthesis, (c) pass event summaries rather than full item lists.
**Warning signs:** LLM calls timing out or producing truncated responses during weekly report generation.

### Pitfall 4: History Query Performance on Large Date Ranges

**What goes wrong:** User asks "what happened with AI this month" and the system tries to scan 30 JSONL files.
**Why it happens:** No hard limit on query date range in the user's natural language.
**How to avoid:** Cap query lookback to 7 days by default for topic queries, 30 days for event queries (events have their own index in active.json). If user specifies a longer range, warn about potential slow response. Design doc notes: "if query performance becomes bottleneck, consider SQLite."
**Warning signs:** Query response taking > 30 seconds.

### Pitfall 5: 7-Layer Model Fields Not Wired Into Scoring

**What goes wrong:** `depth_preference` and `judgment_angles` are added to preferences.json but have no effect on content selection.
**Why it happens:** The scoring formula has fixed 7 dimensions and these new layers don't map to existing dimensions.
**How to avoid:** These two new layers influence output FORMATTING rather than scoring: `depth_preference` controls summary depth (headline vs. detailed), `judgment_angles` influences which aspects of a story the summary emphasizes. They affect the summarize/output prompts, not the scoring formula.
**Warning signs:** Users see the new preference fields but notice no behavioral change.

## Code Examples

### Preference Decay Implementation

```
# Pseudocode for decay check (runs at start of Processing Phase)

Read config/preferences.json
IF last_decay_at is null OR (now - last_decay_at) >= 30 days:

  # Decay topic_weights toward 0.5
  FOR each key in topic_weights:
    topic_weights[key] = topic_weights[key] + (0.5 - topic_weights[key]) * 0.05

  # Decay source_trust toward 0 (neutral/absent)
  FOR each key in source_trust:
    source_trust[key] = source_trust[key] + (0.0 - source_trust[key]) * 0.05
    IF abs(source_trust[key]) < 0.01: DELETE key  # clean up near-zero entries

  # Decay form_preference toward 0 (neutral)
  FOR each key in form_preference:
    form_preference[key] = form_preference[key] + (0.0 - form_preference[key]) * 0.05

  Set last_decay_at = now (ISO8601)
  Backup-before-write (existing pattern)
  Atomic write preferences.json

  Log to daily metrics: "preference_decay_applied: true"
```

### Source Auto-Demotion Check

```
# Pseudocode for source status check (runs after source stats computation)

Read config/sources.json
FOR each source:
  IF source.status == "active":
    IF source.stats.quality_score < 0.2:
      IF source.stats.degraded_since is null:
        source.stats.degraded_since = today
      ELIF (today - source.stats.degraded_since) >= 14 days:
        source.status = "degraded"
        Log alert: "Source {name} auto-demoted: quality_score < 0.2 for 14 days"
    ELSE:
      source.stats.degraded_since = null  # quality recovered, reset counter

  ELIF source.status == "degraded":
    IF source.stats.quality_score > 0.3:
      IF source.stats.recovery_streak_start is null:
        source.stats.recovery_streak_start = today
      ELIF (today - source.stats.recovery_streak_start) >= 7 days:
        source.status = "active"
        source.stats.degraded_since = null
        source.stats.recovery_streak_start = null
        Log: "Source {name} auto-recovered: quality_score > 0.3 for 7 days"
    ELSE:
      source.stats.recovery_streak_start = null  # quality dipped, reset

Atomic write sources.json
```

### History Query Intent Classification

```
# LLM prompt structure for history query routing

Given user message: "{user_message}"

Classify into one of these query types:
1. RECENT_ACTIVITY - asking about recent news (last 24h, today, latest)
2. TOPIC_REVIEW - asking about a specific topic over a time period
3. EVENT_TRACKING - asking about a specific event's developments
4. HOTSPOT_SCAN - asking about important news they might have missed
5. SOURCE_ANALYSIS - asking about a specific source's performance
6. PREFERENCE_STATE - asking about their preference profile

Output JSON:
{
  "query_type": "TOPIC_REVIEW",
  "parameters": {
    "topic": "ai-models",
    "days": 7
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 5-layer preference model | 7-layer model (add depth + judgment) | Phase 3 | Richer personalization of output format and perspective |
| No decay | 30-day 5% regression to mean | Phase 3 | Prevents preference fixation |
| Manual source management only | Auto-demotion/recovery + manual | Phase 3 | Self-healing source quality |
| Daily digest only | Daily + Breaking + Weekly | Phase 3 | Full temporal coverage |
| No history access | 6 query types via natural language | Phase 3 | User can explore their data |

## Open Questions

1. **Weekly report cron: lightContext setting**
   - What we know: Daily digest uses `lightContext: false` (required for SKILL.md loading). Quick check also uses `false`. Design doc table says weekly report uses `lightContext: false`.
   - What's unclear: The original design doc table listed weekly report with `lightContext: false` but quick check with `lightContext: true` (which conflicts with the Phase 0 decision that `lightContext` must be false). Current cron-configs.md has quick check as `false`.
   - Recommendation: Use `lightContext: false` for weekly report, consistent with all other jobs. This is the safe default per the Phase 0 decision.

2. **depth_preference and judgment_angles: exact effect on output**
   - What we know: Design doc says these were deferred from 5-layer to Phase 3. `depth_preference` controls detail level, `judgment_angles` controls perspective diversity.
   - What's unclear: No explicit integration point is defined in the scoring formula or output templates. These layers do not add new scoring dimensions.
   - Recommendation: Wire `depth_preference` into the summarize prompt (controls summary length/depth) and `judgment_angles` into the weekly report synthesis (controls which angles to highlight). Do NOT modify the scoring formula -- keep it at 7 dimensions.

3. **History query performance at scale**
   - What we know: ~500 items/day, 30-day retention = ~15,000 items max. JSONL scan of 7 files is fast enough.
   - What's unclear: Whether scanning 30 files for monthly queries will be acceptably fast within a single agent turn.
   - Recommendation: Default to 7-day lookback for most queries. For month-level queries, scan JSONL files and filter client-side. If this proves slow, the design doc explicitly defers SQLite migration to when it's needed.

4. **Source degradation: effect on collection**
   - What we know: Design doc says "降低采集频率" for degraded sources. Current SKILL.md collects all `enabled: true` sources.
   - What's unclear: Exact mechanism for "lower frequency" -- skip every other run? Collect but deprioritize?
   - Recommendation: Simplest approach: degraded sources are still collected each run but their items are deprioritized in scoring (apply a penalty multiplier, e.g., 0.5x to `source_trust` dimension). If budget is tight (>80%), skip degraded sources first. This avoids complex frequency-based scheduling.

## Sources

### Primary (HIGH confidence)

- `gpt-plan-v3.md` -- Full design document reviewed by 6 AI models. Sections 7.5 (source health), 9 (preference system), 10 (anti-echo-chamber), 13 (output types), 14 (feedback + history) provide direct specifications for all Phase 3 requirements.
- Existing codebase files (`SKILL.md`, `references/*.md`, `config/*.json`) -- Verified the current implementation state and available fields/schemas.

### Secondary (MEDIUM confidence)

- Design doc Phase 3 section (line 1316-1334) -- High-level feature list, but lacks detailed implementation specs for some features (especially history query and weekly report internals).

### Tertiary (LOW confidence)

- None. All Phase 3 features are well-specified in the design document or can be trivially derived from existing patterns.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No new dependencies, everything uses existing OpenClaw Skill patterns
- Architecture: HIGH - All patterns extend existing infrastructure with well-defined data models
- Pitfalls: HIGH - Identified from direct analysis of the design doc and existing code interactions

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable -- no external dependencies to go stale)
