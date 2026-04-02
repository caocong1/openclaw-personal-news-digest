# OpenClaw News Digest Skill

**OpenClaw 个性化新闻研究与推送 Skill**

A personalized news research and delivery system running on the [OpenClaw](https://openclaw.ai/) AI agent platform. It performs multi-source collection (RSS, GitHub releases, web search, official blogs, community forums, ranking lists), LLM-driven classification and summarization, URL and title deduplication, event tracking with timeline merging, a multi-layer user preference model (topic weights, source trust, form preference, style, depth, judgment angles, feedback samples), anti-echo-chamber quota allocation (core 50% / adjacent 20% / hotspot 15% / explore 15%), a feedback learning loop, and LLM cost control with circuit-breaker budgeting. All output is in Chinese.

能从"给用户推消息"升级为"替用户持续观察世界中他关心的部分"——在深度个性化的同时，通过防茧房机制保留对外部世界重要入口的感知。

## Architecture

```
                    +------------------+
                    |   config/        |
                    | sources.json     |
                    | preferences.json |
                    | budget.json      |
                    | categories.json  |
                    +--------+---------+
                             |
              +--------------v--------------+
              |        SKILL.md             |
              |   (Agent Instructions)      |
              +----+--------+--------+------+
                   |        |        |
          +--------v--+ +---v----+ +-v---------+
          | Collection| |Process | |  Output   |
          | Phase     | | Phase  | |  Phase    |
          +-----+-----+ +---+---+ +-----+-----+
                |            |           |
          +-----v-----+ +---v----+ +----v------+
          | data/news/ | | data/  | | output/   |
          | *.jsonl    | | events | | digest.md |
          +------------+ +--------+ +-----------+
```

**Pipeline flows:**

- **Daily Digest:** Collection -> Processing -> Scoring -> Output -> `output/latest-digest.md`
- **Quick-Check:** Collection -> Processing -> breaking filter (importance >= 0.85) -> `output/latest-alert.md`
- **Weekly Report:** 7-day aggregation -> `output/latest-weekly.md`
- **Feedback Loop:** user feedback -> `data/feedback/log.jsonl` -> preference updates in `config/preferences.json`
- **Health Check:** `scripts/health-check.sh` -> data consistency validation
- **Data Lifecycle:** `scripts/data-archive.sh` -> TTL-based cleanup

## Directory Structure

```
openclaw-personal-news-digest/
  SKILL.md                              # Agent instructions (entry point)
  README.md                             # This file
  config/
    sources.json                        # News source definitions (6 types)
    preferences.json                    # User preference model (multi-layer)
    budget.json                         # LLM cost control (daily limits)
    categories.json                     # 12 topic categories with adjacency
  references/
    collection-instructions.md          # Source fetching rules by type
    processing-instructions.md          # Classification, dedup, events, quotas
    output-templates.md                 # Digest/alert/weekly output formats
    scoring-formula.md                  # 7-dimension scoring formula
    feedback-rules.md                   # 8 feedback types -> preference updates
    data-models.md                      # JSON/JSONL schema definitions
    cron-configs.md                     # Cron job registration configs
    platform-verification.md            # Platform capability verification steps
    prompts/
      classify.md                       # Classification prompt
      summarize.md                      # Summarization prompt
      dedup.md                          # Title dedup prompt
      merge-event.md                    # Event merge prompt
      filter-search.md                  # Search result filter prompt
      extract-content.md                # Content extraction prompt
      history-query.md                  # History query classification prompt
      weekly-report.md                  # Weekly report synthesis prompt
  scripts/
    health-check.sh                     # Data consistency + alert checks (daily/weekly modes)
    data-archive.sh                     # TTL-based data cleanup
    dedup-index-rebuild.sh              # Dedup index recovery/cleanup
  data/
    news/                               # Daily JSONL files + dedup-index.json
      dedup-index.json                  # URL hash index for dedup
    events/                             # Event lifecycle tracking
      active.json                       # Currently tracked events
    feedback/                           # User feedback log
      log.jsonl                         # Timestamped feedback entries
    cache/                              # LLM result caches
      classify-cache.json               # Classification cache
      summary-cache.json                # Summarization cache
    metrics/                            # Daily run metrics
  output/
    latest-digest.md                    # Most recent daily digest
    latest-alert.md                     # Most recent breaking news alert
    latest-weekly.md                    # Most recent weekly report
```

## Configuration

| File | Purpose | Key Fields |
|------|---------|------------|
| [`config/sources.json`](config/sources.json) | News source definitions (6 types: rss, github, search, official, community, ranking) | `id`, `name`, `type`, `enabled`, `weight`, `credibility`, `topics`, `fetch_config` |
| [`config/preferences.json`](config/preferences.json) | User preference model | `topic_weights`, `source_trust`, `form_preference`, `style`, `depth_preference`, `judgment_angles` |
| [`config/budget.json`](config/budget.json) | LLM cost control | `daily_llm_call_limit` (500), `daily_token_limit` (1M), `alert_threshold` (0.8) |
| [`config/categories.json`](config/categories.json) | Topic taxonomy (12 categories) | Category `id`, `name_zh`, `name_en`, `description`, `adjacent` |

See individual files for full schema. Data model schemas in [`references/data-models.md`](references/data-models.md).

## Deployment

### Prerequisites

- OpenClaw platform account with workspace
- Telegram chat ID for delivery

### Setup Steps

1. Clone this repository into your OpenClaw workspace.

2. Install the skill by loading [`SKILL.md`](SKILL.md) into your workspace.

3. > **CRITICAL:** Set `lightContext: false` in all cron job payloads. The skill requires full context to load reference documents. Without this, cron jobs will fire but produce no output.

4. Set `sessionTarget: "isolated"` for all cron jobs to ensure clean sessions per run, preventing state leakage between executions.

5. Run platform verification per [`references/platform-verification.md`](references/platform-verification.md) to confirm file access, exec permissions, browser availability, delivery routing, and timeout support.

6. Register cron jobs per [`references/cron-configs.md`](references/cron-configs.md). See the [Cron Jobs](#cron-jobs) section below for the schedule overview.

### Platform Verification

Before registering cron jobs, complete the 5-capability verification checklist in [`references/platform-verification.md`](references/platform-verification.md). This confirms that isolated sessions can access workspace files, run scripts via `exec`, deliver to Telegram, and support the required execution timeouts. Capabilities 1 (file access), 2 (exec), and 5 (timeout >= 5 min) are required; capabilities 3 (browser) and 4 (delivery) have fallbacks.

## Cron Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| `news-daily-digest` | `0 8 * * *` (08:00 CST daily) | Full pipeline: collect, process, score, generate digest |
| `news-quick-check` | `0 */2 * * *` (every 2 hours) | Breaking news detection (importance >= 0.85) |
| `weekly-health-inspection` | `0 3 * * 1` (Monday 03:00 CST) | Health check + data archive |
| `news-weekly-report` | `0 20 * * 0` (Sunday 20:00 CST) | Weekly aggregation report |

See [`references/cron-configs.md`](references/cron-configs.md) for full registration JSON including delivery configuration and timeout settings.

## Operational Scripts

### health-check.sh

Validates data consistency and checks alert conditions. Supports two modes: `daily` (quick checks + budget/source alerts) and `weekly` (full inspection including dedup drift, event lifecycle, source success rates, preference extremes, and cache sizes).

```bash
# Daily health check
bash scripts/health-check.sh /path/to/skill

# Weekly full inspection
bash scripts/health-check.sh /path/to/skill --mode weekly
```

Output lines are prefixed with `OK:`, `INFO:`, `WARN:`, or `ALERT:` for easy filtering.

### data-archive.sh

TTL-based cleanup for all data types. Removes expired entries using atomic writes (tmp + rename) to prevent data corruption.

```bash
# Data cleanup (TTL: news 30d, cache 7d, metrics 30d, feedback 90d)
bash scripts/data-archive.sh /path/to/skill
```

### dedup-index-rebuild.sh

Rebuilds `data/news/dedup-index.json` from the last 7 days of JSONL files. Use after index corruption or for periodic maintenance.

```bash
# Rebuild dedup index after corruption
bash scripts/dedup-index-rebuild.sh /path/to/skill
```

## User Commands

The skill responds to natural language commands via the OpenClaw chat interface. See [`SKILL.md`](SKILL.md) for the full command reference.

- **Source management:** add, remove, enable, disable, or adjust news sources
- **Feedback:** like, dislike, more, less, trust, distrust, block, or style preferences
- **History queries:** search recent news, review topics, track events, scan hotspots, analyze sources
- **Preference adjustment:** view current preferences, reset weights, adjust exploration appetite

## Data Lifecycle

| Data | Location | Retention |
|------|----------|-----------|
| News items | `data/news/*.jsonl` | 30 days |
| LLM cache | `data/cache/` | 7 days |
| Metrics | `data/metrics/` | 30 days |
| Feedback | `data/feedback/` | 90 days |
| Events | `data/events/` | Until archived |

The `scripts/data-archive.sh` script enforces these TTL rules. The weekly health inspection cron job runs this automatically every Monday.

## References

- [`references/collection-instructions.md`](references/collection-instructions.md) -- Source fetching rules for each of the 6 source types
- [`references/processing-instructions.md`](references/processing-instructions.md) -- Classification, title dedup, event lifecycle, quota allocation, weekly report, history queries
- [`references/output-templates.md`](references/output-templates.md) -- Markdown templates for daily digest, breaking alert, and weekly report
- [`references/scoring-formula.md`](references/scoring-formula.md) -- 7-dimension weighted scoring formula
- [`references/feedback-rules.md`](references/feedback-rules.md) -- 8 feedback types and how they update preferences
- [`references/data-models.md`](references/data-models.md) -- JSON/JSONL schema definitions for all data files
- [`references/cron-configs.md`](references/cron-configs.md) -- Cron job registration JSON configs and setup order
- [`references/platform-verification.md`](references/platform-verification.md) -- 5-capability platform verification checklist
- [`references/prompts/`](references/prompts/) -- LLM prompt templates (classify, summarize, dedup, merge-event, filter-search, extract-content, history-query, weekly-report)
