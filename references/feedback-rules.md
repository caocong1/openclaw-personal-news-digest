# Feedback Processing Rules

## Overview

This document specifies how user messages are routed and how feedback is processed into preference updates. It is referenced by SKILL.md as the canonical intent-routing and feedback-handling source.

Feedback flows through a pipeline: user signal -> feedback log -> preference update -> scoring impact. The system supports 8 feedback types, each mapped to specific preference fields with bounded adjustments and safety mechanisms.

---

## Intent Recognition Table

| Intent | Example phrases | Route |
|--------|-----------------|-------|
| `schedule_management` | `set digest to weekdays`, `move daily digest to 9:30`, `change quick check hours`, `activate custom-hours profile` | `references/cron-configs.md` Schedule Profiles section |
| `source_status` | `source status`, `how is 36Kr doing`, `which sources are failing`, `show source health` | Phase 12 source-status command path |
| `source_management` | `add source`, `disable Hacker News`, `increase 36Kr weight` | `references/collection-instructions.md` Source Management Commands |
| `feedback` | `more AI news`, `less gaming`, `trust this source`, `like #3` | Feedback Type Mapping in this file |
| `preference_query` | `what have you learned about me`, `show my preferences`, `my interests` | Preference Visualization in this file |
| `history_query` | `latest news`, `AI news this week`, `what happened with X`, `what did I miss` | `references/prompts/history-query.md` plus `references/processing-instructions.md` Section 8 |
| `diagnostics` | `system status`, `health check`, `diagnostics` | `bash scripts/diagnostics.sh {baseDir}` |
| `seed_discovery` | `从这个视频发现源`, `discover sources from`, `从URL找新闻源`, `分析这个链接`, `seed discovery`, `找新闻来源`, `发现新闻源`, `加载预取的种子`, `load pending seeds`, `导入候选源` | Seed Discovery Command (collection-instructions.md Section 7B) |
| `general` | anything else | General helpful response |

This table is the canonical routing source for SKILL.md. Do not duplicate trigger examples elsewhere.

---

## Feedback Type Mapping

All 8 supported feedback types with their target fields and adjustment values:

| Type | Example Phrases | Target Field | Adjustment | Notes |
|------|----------------|--------------|------------|-------|
| more | "more AI news", "show more about tech" | topic_weights[matched_topic] | +0.1 | Match topic from user text against categories.json IDs |
| less | "less gaming", "fewer finance stories" | topic_weights[matched_topic] | -0.1 | Clamp to [0.0, 1.0] |
| trust_source | "this source is great", "I trust 36Kr" | source_trust[source_id] | +0.15 | Match source by name/ID from sources.json |
| distrust_source | "downgrade this source", "less from X" | source_trust[source_id] | -0.2 | Clamp to [-1.0, 1.0] |
| like | reply "good", "like #3" | feedback_samples.liked_items | append item ref + topic +0.05 | Micro-adjust: related topic_weight +0.05 |
| dislike | reply "bad", "dislike #5" | feedback_samples.disliked_items | append item ref + topic -0.05 | Micro-adjust: related topic_weight -0.05 |
| block_pattern | "no clickbait", "block rumor" | form_preference[matched_form] + blocked_patterns | form -0.2, append pattern | Record pattern string for future filtering |
| adjust_style | "more exploration", "dense format" | style.* | direct set | See style mapping table below |

**Style adjustment mapping:**

| User Phrase Pattern | Target Field | Action |
|---------------------|-------------|--------|
| "more exploration" / "explore more" | style.exploration_appetite | +0.1 (clamp to [0.0, 1.0]) |
| "less exploration" / "stay focused" | style.exploration_appetite | -0.1 (clamp to [0.0, 1.0]) |
| "dense" / "dense format" | style.density | set to "high" |
| "brief" / "short" / "concise" | style.density | set to "low" |
| "medium density" / "normal format" | style.density | set to "medium" |
| "allow repetition" / "repeat ok" | style.repetition_tolerance | set to "high" |
| "no repetition" / "less repeat" | style.repetition_tolerance | set to "low" |
| "allow rumors" / "include unverified" | style.rumor_tolerance | set to "medium" |
| "no rumors" / "verified only" | style.rumor_tolerance | set to "low" |

**Value ranges:**

| Field | Range | Default |
|-------|-------|---------|
| topic_weights.* | [0.0, 1.0] | 0.5 |
| source_trust.* | [-1.0, 1.0] | (absent = use source credibility) |
| form_preference.* | [-1.0, 1.0] | 0.0 |
| style.exploration_appetite | [0.0, 1.0] | 0.3 |
| style.density | "low" / "medium" / "high" | "medium" |
| style.repetition_tolerance | "low" / "medium" / "high" | "low" |
| style.rumor_tolerance | "low" / "medium" / "high" | "low" |

---

## Feedback Reference Disambiguation

When user gives feedback, resolve which item/source/topic they mean using this cascade (try each step in order, stop at first match):

1. **Message reply context**: If the user replies to a digest message, the replied message provides context. Extract the news item, source, or topic from the replied-to content.

2. **Sequence number**: If user says "#3" or "item 3", map to the 3rd item in the most recent digest. Look up the item in the latest output JSONL to get its metadata (category, source, URL).

3. **Keyword search**: Search recent items (last 24h JSONL files in `data/news/`) by title keyword match. Use case-insensitive substring matching on `title` field.

4. **Source name match**: Match against `config/sources.json` entries by `name` field (case-insensitive substring). Example: "36Kr" matches source with name containing "36Kr".

5. **Topic match**: Match against `config/categories.json` category IDs and display names. Example: "AI" matches category ID "ai-models".

6. **Ambiguous**: If no match found, or multiple matches at the same cascade level, list top 3 candidates and ask user to clarify. Format: "Did you mean: 1) [candidate 1], 2) [candidate 2], 3) [candidate 3]?"

**Disambiguation output:** The resolved reference must include:
- `target`: The resolved ID (topic_id, source_id, item_url, or pattern_string)
- `context`: The full item/source metadata that was matched (for audit trail)

---

## Incremental Preference Update Procedure

Step-by-step processing flow for applying feedback to preferences:

1. **Read preferences**: Load `config/preferences.json` into memory.

2. **Check kill switch**: If `feedback_processing_enabled` is `false`, skip all processing (steps 3-10). Log "Kill switch active: feedback processing disabled." and exit.

3. **Read feedback log**: Load `data/feedback/log.jsonl` (one JSON object per line).

4. **Filter unprocessed entries**: Select entries where `timestamp > preferences.last_updated`. If `last_updated` is `null`, process all entries.

5. **Sort by timestamp**: Sort filtered entries by `timestamp` ascending (oldest first). This ensures changes are applied in chronological order.

6. **Initialize per-session cumulative tracker**: Create a map `cumulative_changes = {}` to track net change per field per run. This prevents feedback loop runaway (Research Pitfall 3).

7. **For each entry, apply adjustment:**
   a. Look up adjustment in Feedback Type Mapping table above.
   b. **Per-session cumulative cap check**: Calculate what the cumulative change to the target field would be after this adjustment. If any single field's cumulative change would exceed +/- 0.3, DO NOT apply this adjustment. Log warning: "Cumulative cap reached for [field]: [cumulative_amount]. Skipping entry [timestamp]." Mark entry as `status: "skipped"`.
   c. **Large single adjustment check (Escalation)**: If this single adjustment would change any preference value by > 0.3, DO NOT apply. Mark entry as `status: "pending_confirmation"` in log. Escalate to user: "Feedback would change [field] by [amount]. Confirm? (yes/no)". Skip to next entry.
   d. Apply the adjustment to the in-memory preferences. Clamp values to valid ranges:
      - topic_weights: [0.0, 1.0]
      - source_trust: [-1.0, 1.0]
      - form_preference: [-1.0, 1.0]
      - style.exploration_appetite: [0.0, 1.0]
   e. Update `cumulative_changes` map with the applied delta.
   f. Increment `total_feedback_count`.
   g. Mark entry as `status: "applied"` and set `run_id`.

8. **Create backup**: Before writing updated preferences, copy current `config/preferences.json` to `data/feedback/backup/preferences-{ISO8601_timestamp}.json`. List all backup files sorted by name. If count exceeds 10, delete the oldest files until only 10 remain.

9. **Update metadata**: Set `last_updated` to current ISO8601 timestamp. Increment `version`.

10. **Atomic write**: Write updated preferences to `config/preferences.json.tmp.{run_id}`, then rename to `config/preferences.json`. This prevents partial writes from corrupting the file.

---

## Kill Switch

- **Field:** `preferences.feedback_processing_enabled` (boolean)
- **When `false`:** Skip steps 3-10 of the Incremental Preference Update Procedure entirely. Log "Kill switch active: feedback processing disabled."
- **Feedback logging continues:** The kill switch does NOT prevent feedback LOGGING. User feedback is still appended to `data/feedback/log.jsonl`. It only prevents preference UPDATES from being applied.
- **Re-enable:** User sets `feedback_processing_enabled: true` in preferences (or instructs the agent to re-enable feedback processing).
- **Use cases:** Emergency stop if feedback loop is degrading digest quality, or during manual preference tuning.

---

## Escalation Thresholds

Safety mechanisms to prevent runaway preference changes:

### Single Adjustment Escalation
- **Trigger:** Any single feedback entry would change a preference value by more than 0.3.
- **Action:** Do NOT apply the change. Mark the entry as `status: "pending_confirmation"` in `data/feedback/log.jsonl`. Escalate to the user with a confirmation prompt.
- **Message format:** "Feedback would change [field] by [amount]. This exceeds the safety threshold of 0.3. Confirm? (yes/no)"
- **On confirmation:** Re-process the entry with escalation bypass. Mark as `status: "applied"`.
- **On rejection:** Mark as `status: "skipped"`.

### Per-Session Cumulative Cap
- **Trigger:** The net change to any single `topic_weight` field exceeds +/- 0.3 during a single pipeline run (across all entries processed in that run).
- **Action:** Stop applying further changes to that specific field for the remainder of the run. Other fields continue processing normally.
- **Logging:** "Cumulative cap reached for [field]: net change [amount] would exceed +/- 0.3 limit."
- **Rationale:** Prevents a burst of feedback (e.g., rapid "more/more/more") from causing extreme preference shifts in a single run. Changes spread across multiple runs instead.

These thresholds align with SKILL.md Standing Orders "Large preference weight change" escalation condition.

---

## Preference Backup Management

- **Backup location:** `data/feedback/backup/`
- **Naming convention:** `preferences-{YYYY-MM-DDTHH:mm:ss}Z.json` (ISO8601 timestamp of backup creation)
- **Retention policy:** Keep the 10 most recent backups. When count exceeds 10, delete the oldest files.
- **Timing:** Backup is created BEFORE each preference update, not after. This ensures the pre-update state is always recoverable.
- **Restore procedure:** To restore, copy the desired backup file to `config/preferences.json`. The next pipeline run will process any unprocessed feedback entries from the log.

---

## Preference Visualization (PREF-06 / HIST-06)

Generate a human-readable preference state description when the user queries their preference profile.

### Trigger

User asks about preferences: "what have you learned about me", "show my preferences", "我的偏好", "偏好状态", "what are my interests", or similar intent.

### Procedure

1. Read `config/preferences.json`
2. Generate text description using the following structure:

```
## Your Preference Profile

**Top interests:** {topics with weight >= 0.7, sorted descending, format: "TopicName (weight: X.X)"}
**Lower interest:** {topics with weight <= 0.3, sorted ascending}
**Neutral topics:** {topics with weight 0.4-0.6, list names only}

**Trusted sources:** {source_trust entries > 0, format: "SourceName (trust: +X.X)"}
**Distrusted sources:** {source_trust entries < 0, format: "SourceName (trust: X.X)"}
{If source_trust is empty: "No source preferences yet -- will develop from feedback"}

**Content style:** {Interpret form_preference values -- positive means preference, negative means avoidance. Example: "You prefer analysis over opinion pieces. You have low rumor tolerance."}
**Exploration:** {Interpret exploration_appetite -- 0.0-0.2: "Low", 0.2-0.35: "Moderate", 0.35+: "High"} (appetite: {value}) -- {explain effect}

**Depth preference:** {depth_preference value} -- {explain: brief=headlines only, moderate=balanced summaries, detailed=in-depth with context, technical=includes implementation details}
**Judgment angles:** {If empty: "Not yet learned -- will develop over time". If set: list angles with explanations}

**Feedback history:** {total_feedback_count} feedback signals processed
**Last preference update:** {last_updated or "Never"}
**Last decay applied:** {last_decay_at or "Never"}
```

3. Use LLM to polish the structured data into natural-sounding narrative text (not just template fill). The LLM should make it conversational while preserving all data points.
4. Cap response to reasonable length -- all key preference dimensions but no verbose explanations.
