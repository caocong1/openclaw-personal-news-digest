# Phase 7: README Documentation - Research

**Researched:** 2026-04-02
**Domain:** Project documentation (README.md)
**Confidence:** HIGH

## Summary

Phase 7 creates a README.md at the project root that serves as the primary entry point for any operator wanting to understand, deploy, configure, and operate the news-digest skill. This is a documentation-only phase with no code changes, no external dependencies, and no runtime impact.

The project is an OpenClaw platform Skill consisting of SKILL.md (agent instructions), reference documents (processing rules, prompts, templates), configuration files (sources, preferences, budget, categories), operational scripts (health-check, data-archive, dedup-rebuild), and JSONL/JSON data storage. The README must make this architecture legible to a new operator in under 5 minutes.

**Primary recommendation:** Write a single README.md structured with architecture overview, directory map, configuration guide, deployment steps, and operational scripts reference -- all derived from the existing project files documented below.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | Project root has README.md with architecture, deployment instructions, configuration guide, and operational scripts documentation | Full project inventory completed below; all source material identified |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

No CLAUDE.md exists in this project. SKILL.md serves as the primary instruction document for the OpenClaw agent, not for development conventions.

## Architecture Inventory

This section provides the complete inventory the README must document. All findings are HIGH confidence -- derived directly from reading project files.

### Directory Structure

```
openclaw-personal-news-digest/
  SKILL.md                          # Agent instructions (entry point)
  config/
    sources.json                    # News source definitions (6 types)
    preferences.json                # User preference model (7 layers)
    budget.json                     # LLM cost control (daily limits)
    categories.json                 # 12 topic categories + scoring weights
  references/
    collection-instructions.md      # Source fetching rules by type
    processing-instructions.md      # Classification, scoring, dedup, events
    output-templates.md             # Digest/alert/weekly output formats
    scoring-formula.md              # 7-dimension scoring formula
    feedback-rules.md               # 8 feedback types -> preference updates
    data-models.md                  # JSON/JSONL schema definitions
    cron-configs.md                 # Cron job registration configs
    platform-verification.md        # Platform capability verification steps
    prompts/
      classify.md                   # Classification prompt
      summarize.md                  # Summarization prompt
      dedup.md                      # Dedup prompt
      merge-event.md                # Event merge prompt
      filter-search.md              # Search result filter prompt
      extract-content.md            # Content extraction prompt
      history-query.md              # History query prompt
      weekly-report.md              # Weekly report prompt
  scripts/
    health-check.sh                 # Data consistency + alert checks (daily/weekly modes)
    data-archive.sh                 # TTL-based data cleanup
    dedup-index-rebuild.sh          # Dedup index recovery/cleanup
  data/
    news/                           # Daily JSONL files + dedup-index.json
    events/                         # Event lifecycle tracking (active.json)
    feedback/                       # User feedback log (log.jsonl)
    cache/                          # LLM result caches (classify, summary)
    metrics/                        # Daily metrics JSON files
  output/
    latest-digest.md                # Most recent daily digest
    latest-alert.md                 # Most recent breaking alert
    latest-weekly.md                # Most recent weekly report
```

### Module Relationships (Architecture Flow)

The pipeline has three phases that the README must illustrate:

1. **Collection**: SKILL.md Section "Collection Phase" -> reads `config/sources.json` -> fetches by source type per `references/collection-instructions.md` -> writes to `data/news/YYYY-MM-DD.jsonl` + `data/news/dedup-index.json`

2. **Processing**: SKILL.md Section "Processing Phase" -> reads `references/prompts/classify.md` + `summarize.md` -> classifies and summarizes items -> event merge via `references/processing-instructions.md` -> updates `data/events/active.json` -> updates `config/budget.json`

3. **Output**: SKILL.md Section "Output Phase" -> reads `references/scoring-formula.md` -> scores items -> allocates quotas per `references/processing-instructions.md` -> renders via `references/output-templates.md` -> writes to `output/latest-digest.md` -> writes metrics to `data/metrics/`

Additional flows:
- **Quick-Check**: Collection + Processing + breaking news filter (importance >= 0.85) -> `output/latest-alert.md`
- **Weekly Report**: Aggregates 7 days -> `output/latest-weekly.md`
- **Feedback Loop**: User feedback -> `data/feedback/log.jsonl` -> preference updates in `config/preferences.json`

### Configuration Files

| File | Purpose | Key Fields |
|------|---------|------------|
| `config/sources.json` | News source definitions | `id`, `name`, `type` (rss/github/search/official/community/ranking), `enabled`, `weight`, `credibility`, `topics`, `fetch_config`, `stats`, `status` |
| `config/preferences.json` | User preference model | `topic_weights` (12 topics), `source_trust`, `form_preference`, `style` (density/repetition/exploration/rumor), `depth_preference`, `judgment_angles` |
| `config/budget.json` | LLM cost control | `daily_llm_call_limit` (500), `daily_token_limit` (1M), `alert_threshold` (0.8), daily counters |
| `config/categories.json` | Topic taxonomy | 12 categories with scoring weights and sub-topics |

### Operational Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/health-check.sh` | Validate data consistency and alert conditions | `bash scripts/health-check.sh [base_dir] [--mode daily\|weekly]` |
| `scripts/data-archive.sh` | TTL-based cleanup (news 30d, cache 7d, metrics 30d, feedback 90d) | `bash scripts/data-archive.sh [base_dir]` |
| `scripts/dedup-index-rebuild.sh` | Rebuild dedup index from last 7 days of JSONL | `bash scripts/dedup-index-rebuild.sh [base_dir]` |

### Cron Jobs

| Job | Schedule | Purpose |
|-----|----------|---------|
| `news-daily-digest` | 08:00 CST daily | Full pipeline: collect, process, score, generate digest |
| `news-quick-check` | Every 2 hours | Breaking news detection (importance >= 0.85) |
| `weekly-health-inspection` | Monday 03:00 CST | Health check + data archive |
| `news-weekly-report` | Sunday 20:00 CST | Weekly aggregation report |

### Deployment Prerequisites

From `references/cron-configs.md` and `references/platform-verification.md`:
- OpenClaw platform account with workspace
- Skill installed in workspace (SKILL.md loaded)
- `lightContext: false` (CRITICAL -- skill won't load otherwise)
- `sessionTarget: "isolated"` for cron jobs
- Telegram chat ID configured for delivery
- Platform verification completed before cron registration

## Architecture Patterns

### README Structure Pattern

For a project that is a "prompt/config/reference-doc" system (no runtime code), the README should follow this structure:

1. **What This Is** -- one paragraph, bilingual (Chinese project, English README)
2. **Architecture Overview** -- ASCII diagram showing Collection -> Processing -> Output pipeline with data stores
3. **Directory Structure** -- annotated tree
4. **Configuration Guide** -- table of config files with key fields and how to customize
5. **Deployment** -- step-by-step OpenClaw setup instructions
6. **Cron Jobs** -- table + registration instructions
7. **Operational Scripts** -- usage examples for each script
8. **User Commands** -- brief reference to feedback, source management, history queries
9. **Data Lifecycle** -- TTL rules, storage locations

### Anti-Patterns to Avoid

- **Duplicating SKILL.md content**: README should reference SKILL.md for agent behavior, not restate it
- **Documenting internal schemas**: README links to `references/data-models.md` rather than inlining schema details
- **Stale examples**: All usage examples must match current script signatures and config shapes

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Architecture diagram | Custom image file | ASCII art in markdown | No external dependencies, version-controlled, renders everywhere |
| Config documentation | Separate wiki | Inline tables in README | Single source of truth, always up to date with repo |

## Common Pitfalls

### Pitfall 1: README Drift from Source Files
**What goes wrong:** README describes config fields or script flags that have changed
**Why it happens:** Documentation written once, never updated alongside config changes
**How to avoid:** README should reference file paths and link to detailed docs rather than duplicating content
**Warning signs:** README mentions fields not present in current config files

### Pitfall 2: Missing Critical Platform Settings
**What goes wrong:** Operator follows README but skill never loads in cron
**Why it happens:** `lightContext: false` requirement not prominently documented
**How to avoid:** Put platform-critical settings in a "CRITICAL" callout box at top of deployment section
**Warning signs:** Cron jobs fire but produce no output

### Pitfall 3: Language Mismatch
**What goes wrong:** README is all English but PROJECT.md and SKILL.md use Chinese extensively
**Why it happens:** Inconsistent language choice
**How to avoid:** README in English (for broader accessibility) with Chinese project name preserved. The project's user-facing output is Chinese but documentation can be English.

## Code Examples

### README Architecture Diagram Pattern

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

### Script Usage Examples (for README)

```bash
# Daily health check
bash scripts/health-check.sh /path/to/skill

# Weekly full inspection
bash scripts/health-check.sh /path/to/skill --mode weekly

# Data cleanup
bash scripts/data-archive.sh /path/to/skill

# Rebuild dedup index after corruption
bash scripts/dedup-index-rebuild.sh /path/to/skill
```

## Open Questions

None. This is a straightforward documentation phase. All source material has been inventoried from the existing project files.

## Sources

### Primary (HIGH confidence)
- SKILL.md -- full agent instructions, pipeline phases, user commands
- config/*.json -- all 4 configuration files read directly
- scripts/*.sh -- all 3 scripts read (headers + usage)
- references/cron-configs.md -- cron job definitions and critical settings
- .planning/PROJECT.md -- project overview, constraints, key decisions

## Metadata

**Confidence breakdown:**
- Architecture inventory: HIGH - derived directly from reading all project files
- README structure: HIGH - standard documentation practice
- Pitfalls: HIGH - based on observed project characteristics (bilingual, platform-specific settings)

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable -- documentation of existing architecture)
