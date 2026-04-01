# Roadmap: OpenClaw News Digest Skill

## Overview

This roadmap delivers a personalized news digest Skill on the OpenClaw platform across 4 phases. Phase 0 establishes the end-to-end pipeline with a single RSS source. Phase 1 expands to multi-source collection with basic preferences and feedback. Phase 2 adds intelligent processing (event merging, timeline tracking, anti-echo-chamber). Phase 3 closes the loop with full feedback learning, advanced preferences, history query, and weekly reports.

## Phases

**Phase Numbering:**
- Integer phases (0, 1, 2, 3): Planned milestone work
- Decimal phases (1.1, 2.1): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 0: MVP Pipeline** - End-to-end single RSS: collect, dedup, classify/summarize, daily digest
- [ ] **Phase 1: Multi-Source + Preferences** - Multiple source types, basic preferences, feedback, breaking news, LLM cache
- [ ] **Phase 2: Smart Processing** - Title dedup, event merging, timeline, anti-echo-chamber, multi-language
- [ ] **Phase 3: Closed Loop** - Full feedback loop, 7-layer preferences, weekly report, history query

## Phase Details

### Phase 0: MVP Pipeline
**Goal**: User receives a working daily news digest from a single RSS source, with classified and summarized content, proving the entire platform pipeline works end-to-end
**Depends on**: Nothing (first phase)
**Requirements**: FRMW-01, FRMW-02, FRMW-03, FRMW-04, FRMW-05, FRMW-06, SRC-01, PROC-01, PROC-02, PROC-03, PROC-05, PROC-07, PROC-08, PREF-02, OUT-01, OUT-05, COST-01, MON-01, PLAT-01, PLAT-02, PLAT-03, PLAT-04
**Success Criteria** (what must be TRUE):
  1. Manual trigger collects RSS items, writes to JSONL, and a repeated trigger produces no duplicate records
  2. Daily digest output contains classified tags, Chinese summaries, source attribution, and score-based ordering
  3. Empty input does not produce an empty digest -- the system stays silent or outputs a shortened version
  4. LLM call counts are tracked in budget.json and daily health metrics file is generated
  5. Platform capabilities are verified (isolated session file access, cron delivery, exec permissions, timeout limits)
**Plans**: 3 plans

Plans:
- [x] 00-01-PLAN.md — Scaffold directory structure, config files, data model references, and SKILL.md orchestration framework
- [x] 00-02-PLAN.md — LLM prompt templates, RSS collection instructions, processing/error-handling/output instructions
- [x] 00-03-PLAN.md — Cron job configs, delivery setup, platform verification checklist, maintenance scripts

### Phase 1: Multi-Source + Preferences
**Goal**: User can add multiple source types, receives personalized content influenced by their stated preferences and feedback, and gets breaking news alerts for high-importance events
**Depends on**: Phase 0
**Requirements**: SRC-02, SRC-03, SRC-04, SRC-05, SRC-06, SRC-07, SRC-08, SRC-10, PREF-01, PREF-03, PREF-05, OUT-02, OUT-06, FB-01, FB-02, FB-03, FB-04, FB-05, COST-02, COST-03, COST-04
**Success Criteria** (what must be TRUE):
  1. User can add and manage sources of 3+ types (RSS, GitHub, search, web pages) via natural language commands, with disambiguation for ambiguous inputs
  2. User feedback (like/dislike/more/less/trust/distrust) visibly changes subsequent digest content ordering
  3. Breaking news alerts fire when high-importance events occur (importance >= 0.85), and no alert fires when nothing qualifies
  4. LLM cache is operational with observable cache hit rate, and cost budget triggers warning at 80% and circuit-breaker at 100%
  5. Digest footer shows transparency stats (source count, items processed, LLM calls, cache hits)
**Plans**: 4 plans

Plans:
- [ ] 01-01-PLAN.md — Multi-source collection: 5 new source types (GitHub, search, official, community, ranking), NL source management, disambiguation, health metrics
- [ ] 01-02-PLAN.md — Feedback system + preference scoring: 8 feedback types, incremental update, disambiguation, backup, kill switch, feedback_boost activation
- [ ] 01-03-PLAN.md — LLM cache + cost controls: classify/summary cache with 7-day TTL, circuit-breaker (80% warn / 100% stop), tiered model strategy
- [ ] 01-04-PLAN.md — Breaking news alerts + output transparency: importance >= 0.85 trigger with safeguards, digest footer stats wiring

### Phase 2: Smart Processing
**Goal**: User sees deduplicated, event-merged content with timeline tracking and a balanced diet of topics enforced by anti-echo-chamber quotas, with multi-language support
**Depends on**: Phase 1
**Requirements**: PROC-04, PROC-06, EVT-01, EVT-02, EVT-03, EVT-04, EVT-05, ANTI-01, ANTI-02, ANTI-03, ANTI-04, ANTI-05, OUT-04, MON-02, MON-03, MON-04
**Success Criteria** (what must be TRUE):
  1. Near-duplicate titles from different sources are merged -- user sees one entry per story, not three reworded copies
  2. Related news about the same event is grouped, and continuing events show a timeline view (bullet list with relationship labels)
  3. Daily digest visibly follows quota proportions (core/adjacent/hot/exploration) and no single topic exceeds 60% for 3+ consecutive days
  4. English-language sources are correctly processed and appear in the digest with Chinese summaries alongside preserved original titles
  5. Weekly health check runs automatically, cleaning stale data and flagging anomalies (source failures, budget spikes, dedup inconsistencies)
**Plans**: TBD

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD
- [ ] 02-03: TBD

### Phase 3: Closed Loop
**Goal**: User has a fully adaptive system with preference decay preventing fixation, weekly trend reports, natural language history queries, and self-healing source management
**Depends on**: Phase 2
**Requirements**: SRC-09, PREF-04, PREF-06, PREF-07, OUT-03, HIST-01, HIST-02, HIST-03, HIST-04, HIST-05, HIST-06
**Success Criteria** (what must be TRUE):
  1. Preferences do not fixate over time -- after 30 days without reinforcement, weights visibly drift back toward neutral (decay mechanism works)
  2. Weekly report covers 5+ topic categories with trend analysis, event timelines, and cross-domain summary
  3. User can query history in natural language ("what happened with X this week", "show me AI news from last 3 days") and get relevant results
  4. User can view their current preference state as a text description and understand what the system has learned about them
  5. Low-quality sources are automatically demoted after 14 days of poor scores and recover after 7 days of improvement, without manual intervention
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 0 -> 0.1 -> 1 -> 1.1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. MVP Pipeline | 3/3 | Complete | 2026-04-01 |
| 1. Multi-Source + Preferences | 0/4 | Not started | - |
| 2. Smart Processing | 0/3 | Not started | - |
| 3. Closed Loop | 0/2 | Not started | - |
