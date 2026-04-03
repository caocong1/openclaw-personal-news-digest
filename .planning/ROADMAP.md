# Roadmap: OpenClaw News Digest Skill

## Milestones

- [x] **v1.0 MVP** - Phases 0-6 (shipped 2026-04-02) - [archive](milestones/v1.0-ROADMAP.md)
- [x] **v2.0 Quality & Robustness** - Phases 7-12 (shipped 2026-04-03) - [archive](milestones/v2.0-ROADMAP.md)
- [ ] **v3.0 Provenance & Source Discovery** - Phases 13-16 (planned 2026-04-03)

## Overview

`v3.0` reduces dependence on T4 aggregation by tracing provenance for every item, discovering direct T1/T2 sources automatically, and closing the remaining operational hardening backlog. The milestone keeps the existing OpenClaw delivery model but changes how the pipeline understands source trust, selects representative items, and grows its source library over time.

## Phases

### Phase 13: Provenance Core

**Goal:** Add tier-aware provenance classification, citation extraction, and persistent provenance records for every collected item.
**Depends on:** Phase 12
**Requirements:** `PROV-01`..`PROV-06`, `DISC-05`
**Plans:** 3/3 plans complete

Plans:
- [x] `13-01-PLAN.md` - Add T1/T2 pattern libraries, URL-rule preclassification, and provenance data models
- [x] `13-02-PLAN.md` - Add citation extraction, batched provenance classification, and provenance prompt contracts
- [x] `13-03-PLAN.md` - Add cross-validation, discrepancy logging, persistence, and verification fixtures

**Success Criteria:**
1. Every newly collected item receives tier, confidence, original-source, and propagation metadata that can be reconstructed after the run
2. Known official/direct domains resolve via URL rules without an LLM call, while unresolved items fall back to batched provenance classification
3. Citation extraction and discrepancy logging make upstream references and rule-vs-LLM disagreements auditable
4. Dedicated `data/provenance/` stores exist for provenance DB, citation graph, tier stats, and discrepancy logs

### Phase 14: Source Discovery Automation

**Goal:** Turn provenance output into an auditable source-discovery loop that can accumulate, enable, and disable direct sources automatically.
**Depends on:** Phase 13
**Requirements:** `DISC-01`..`DISC-04`
**Plans:** 3 plans

Plans:
- [ ] `14-01-PLAN.md` - Add domain normalization, discovered-source accumulation, and rolling discovery metrics
- [ ] `14-02-PLAN.md` - Add auto-enable and auto-disable evaluation with generated source configs
- [ ] `14-03-PLAN.md` - Add discovery audit artifacts, pattern-library expansion rules, and discovery verification coverage

**Success Criteria:**
1. T1/T2 domains accumulate into `discovered-sources.json` with hit counts, tier ratios, representative titles, and decision history
2. Auto-enable only occurs when frequency, quality, uniqueness, age, and enabled-state checks all pass
3. Degraded or inactive auto-discovered sources auto-disable using documented rolling thresholds
4. New direct sources can expand the dedicated T1/T2 pattern libraries without manual source-review workflows

### Phase 15: Provenance-Aware Ranking & Delivery

**Goal:** Use provenance to influence ranking, alerting, event representative selection, and user-facing output.
**Depends on:** Phase 14
**Requirements:** `PIPE-01`..`PIPE-05`
**Plans:** 3 plans

Plans:
- [ ] `15-01-PLAN.md` - Add provenance scoring, aggregator decay, and event representative selection
- [ ] `15-02-PLAN.md` - Add tier-aware alert gating plus provenance and English-title rendering rules
- [ ] `15-03-PLAN.md` - Add weekly source-discovery reporting and end-to-end verification for provenance-aware output

**Success Criteria:**
1. T1/T2 items receive provenance-based ranking lifts and T4 aggregation decays when direct coverage exists
2. Event-level representative selection keeps one item per event, and alert gating applies tier-aware thresholds before alert delivery
3. Digest and alert output display provenance chain, source tier, original-source attribution, and English-title formatting consistently
4. Weekly source-discovery reporting surfaces newly enabled sources, tier distribution changes, and sources to watch

### Phase 16: Operational Hardening & Verification

**Goal:** Close the remaining P0/P1 backlog so the skill is auditable, script-driven, and operator-safe in live runs.
**Depends on:** Phase 15
**Requirements:** `HARD-01`..`HARD-03`, `OPER-01`..`OPER-06`
**Plans:** 4 plans

Plans:
- [ ] `16-01-PLAN.md` - Extract brittle exec paths into scripts and add explicit success/failure state differentiation
- [ ] `16-02-PLAN.md` - Add collection atomization and enforce single representative selection for merged events
- [ ] `16-03-PLAN.md` - Add run journaling, external backlog sync, and a production multi-source profile
- [ ] `16-04-PLAN.md` - Add channel recovery docs, CLI/docs parity checks, version checks, and live platform smoke verification

**Success Criteria:**
1. Critical execution paths use auditable scripts instead of inline here-docs, and blocked runs surface structured failure state
2. Collection roundups split into child items, one event representative survives scoring, and degraded states remain transparent
3. Run journal, backlog sync, baseline source profile, and recovery docs give operators an explicit audit and recovery trail
4. Health checks and smoke tests detect CLI/docs drift, version mismatches, and live-run regressions before they silently rot operations

## Milestone Summary

**Key Decisions:**

- Make provenance a first-class input to ranking rather than a passive diagnostic field.
- Auto-enable and auto-disable T1/T2 sources with auditable thresholds instead of manual approval loops.
- Keep phase numbering continuous across milestones; v3.0 starts at Phase 13.
- Use the user-supplied `2026-04-03` design spec as the milestone source of truth and skip extra ecosystem research for this cycle.

**Issues Addressed:**

- T4-heavy latency and credibility loss from aggregation chains
- Missing provenance traceability and direct-source discovery
- Remaining exec-safety, atomization, run-journal, docs-parity, and version-consistency backlog items
- Alert and ranking behavior that should now distinguish direct vs aggregated coverage

**Issues Deferred:**

- Manual governance UI for discovered sources
- Historical provenance backfill for pre-v3 items
- Cross-platform discovery outside the current OpenClaw deployment environment

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 13. Provenance Core | 3/3 | Complete    | 2026-04-03 |
| 14. Source Discovery Automation | 0/3 | Not started | - |
| 15. Provenance-Aware Ranking & Delivery | 0/3 | Not started | - |
| 16. Operational Hardening & Verification | 0/4 | Not started | - |
