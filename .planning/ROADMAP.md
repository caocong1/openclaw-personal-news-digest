# Roadmap: OpenClaw News Digest Skill

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-04-02) — [archive](milestones/v1.0-ROADMAP.md)
- 🚧 **v2.0 Quality & Robustness** — Phases 7-12 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 0-6) — SHIPPED 2026-04-02</summary>

- [x] Phase 0: MVP Pipeline (3/3 plans) — completed 2026-04-01
- [x] Phase 1: Multi-Source + Preferences (4/4 plans) — completed 2026-04-01
- [x] Phase 2: Smart Processing (4/4 plans) — completed 2026-04-01
- [x] Phase 3: Closed Loop (4/4 plans) — completed 2026-04-01
- [x] Phase 4: Integration Wiring Fixes (1/1 plan) — completed 2026-04-01
- [x] Phase 5: Daily Depth Control Wiring (1/1 plan) — completed 2026-04-01
- [x] Phase 6: Per-Source Metrics Continuity (1/1 plan) — completed 2026-04-01

</details>

### v2.0 Quality & Robustness (In Progress)

- [ ] **Phase 7: README Documentation** — Project root README with architecture, deployment, config, and ops docs [S]
- [ ] **Phase 8: Output Quality Foundation & Infrastructure** — Chinese localization, data quality contracts, cache versioning, test fixtures [M]
- [ ] **Phase 9: Noise Floor & Classification Quality** — Pre/post-classify noise filtering, classification prompt hardening [M]
- [x] **Phase 10: Dedup Hardening & Alert Fatigue** — Alert daily cap, delta alerts, cross-digest repetition penalty, event memory [L] (completed 2026-04-02)
- [x] **Phase 11: Observability & Data Integrity** — Correct source_count, run_log, schema registry, diagnostics command [M] (completed 2026-04-02)
- [ ] **Phase 12: Interaction Surface & Deployment UX** — Scheduling profiles, source status, recommendation explainability, rolling coverage [L]

## Phase Details

### Phase 7: README Documentation
**Goal**: Project has clear, navigable documentation so any operator can understand architecture, deploy, configure, and run operational tasks
**Depends on**: Nothing (independent)
**Requirements**: DOC-01
**Complexity**: S
**Success Criteria** (what must be TRUE):
  1. README.md exists at project root with architecture overview showing module relationships
  2. README.md includes deployment instructions covering OpenClaw platform setup
  3. README.md documents all configuration files and their purposes
  4. README.md lists operational scripts with usage examples
**Plans:** 1 plan

Plans:
- [ ] 07-01-PLAN.md — Create README.md with architecture, deployment, config, ops docs and verify accuracy

### Phase 8: Output Quality Foundation & Infrastructure
**Goal**: All user-facing output is fully localized to Chinese, data quality is validated before writes, cache versioning prevents stale results, and deterministic test fixtures exist for verification
**Depends on**: Phase 7
**Requirements**: L10N-01, L10N-02, L10N-03, L10N-04, QUAL-01, QUAL-02, QUAL-03, INFRA-01, INFRA-02, INFRA-03, INFRA-04
**Complexity**: M
**Success Criteria** (what must be TRUE):
  1. Daily digest, breaking alert, and weekly report outputs display all labels and headers in Chinese (no English field names leak to user)
  2. Cache entries include prompt_version and a version mismatch forces re-computation
  3. Test fixture directory contains deterministic fixture files covering all verification scenarios
  4. SKILL.md bootstrap verifies required directories exist on first run
  5. Pre-write quality contract validates UTF-8 and title correctness before any JSONL write
**Plans:** 3 plans

Plans:
- [x] 08-01-PLAN.md — Localize all output templates to Chinese and add rendering contract
- [x] 08-02-PLAN.md — Cache versioning, data model registry, bootstrap verification, test fixtures
- [x] 08-03-PLAN.md — Pre-write quality contract for JSONL data validation

### Phase 9: Noise Floor & Classification Quality
**Goal**: Low-value items are filtered before they consume LLM budget, and classification accuracy is improved through better prompts and negative examples
**Depends on**: Phase 8
**Requirements**: NOISE-01, NOISE-02, NOISE-03, NOISE-04, NOISE-05, CLASS-01, CLASS-02, CLASS-03
**Complexity**: M
**Success Criteria** (what must be TRUE):
  1. Items matching source noise_patterns are skipped before classify LLM call (zero LLM cost for noise)
  2. Items with importance < 0.25 are marked digest_eligible: false and excluded from scoring
  3. Filtered items remain queryable in JSONL history
  4. Classification prompt includes 0.0-0.2 tier examples, negative examples per category, and disambiguation rules
  5. DailyMetrics tracks noise_filter_suppressed count
**Plans:** 2/3 plans executed

Plans:
- [x] 09-01-PLAN.md — Source schema + data models + pre-classify noise filter + SKILL.md pipeline wiring
- [x] 09-02-PLAN.md — Classification prompt hardening with low-end calibration, disambiguation, and negative examples
- [x] 09-03-PLAN.md — Post-classify importance filter + noise filtering test fixtures

### Phase 10: Dedup Hardening & Alert Fatigue
**Goal**: Users receive at most 3 alerts per day, see delta information for event updates, and never see stale repeat content across consecutive digests
**Depends on**: Phase 9
**Requirements**: ALERT-01, ALERT-02, ALERT-03, ALERT-04, ALERT-05, ALERT-06, DEDUP-01, DEDUP-02, DEDUP-03
**Complexity**: L
**Success Criteria** (what must be TRUE):
  1. Daily alert cap of 3 is enforced via alert-state file with URL dedup
  2. Delta alerts fire for event updates showing what changed vs previous alert
  3. Cross-digest repetition penalty (0.7x) is applied to events with no new timeline progress
  4. Event objects persist per-event alert memory (last_alerted_at, last_alert_news_id)
  5. Digest footer shows count of suppressed repeat items
**Plans:** 3/3 plans complete

Plans:
- [x] 10-01-PLAN.md — AlertState data model, unified alert decision tree, standard alert fallback
- [x] 10-02-PLAN.md — Event v3 schema with alert memory, delta alert prompt and template
- [x] 10-03-PLAN.md — DigestHistory model, cross-digest repetition penalty, suppression footer

### Phase 11: Observability & Data Integrity
**Goal**: Operator can verify system health through accurate metrics, structured run logs, and a single diagnostics command
**Depends on**: Phase 10
**Requirements**: OBS-01, OBS-02, OBS-03, OBS-04
**Complexity**: M
**Success Criteria** (what must be TRUE):
  1. source_count in output reflects only enabled sources; footer names any failed sources
  2. DailyMetrics run_log array is populated with timestamped entries during pipeline execution
  3. Schema version registry exists with current versions and change history for all data models
  4. Diagnostics command reads metrics + alert-state + digest-history and produces a consolidated report
**Plans:** 3/3 plans complete

Plans:
- [x] 11-01-PLAN.md — Source count accuracy and failed source footer in transparency output
- [x] 11-02-PLAN.md — Run log schema, pipeline instrumentation, and fixture update
- [x] 11-03-PLAN.md — Schema version registry and diagnostics command

### Phase 12: Interaction Surface & Deployment UX
**Goal**: Users can configure scheduling, inspect source health, understand why items were recommended, and see collapsed timeline views for high-volume events
**Depends on**: Phase 11
**Requirements**: INTERACT-01, INTERACT-02, INTERACT-03, INTERACT-04, INTERACT-05
**Complexity**: L
**Success Criteria** (what must be TRUE):
  1. Scheduling profiles (e.g., weekday-only, custom hours) are configurable via SKILL.md commands
  2. Source status command shows per-source health metrics and enable/disable state
  3. Recommendations include structured evidence explaining why each item was selected
  4. Events with >5 items in a single day are collapsed into a timeline view in rolling coverage
  5. NL intent recognition lives in feedback-rules.md without duplication in SKILL.md
**Plans**: 1/3 plans executed

Plans:
- [x] 12-01: TBD
- [ ] 12-02: TBD
- [ ] 12-03: TBD

## Progress

**Execution Order:** Phase 7 (independent), then 8 -> 9 -> 10 -> 11 -> 12 (sequential)

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 0. MVP Pipeline | v1.0 | 3/3 | Complete | 2026-04-01 |
| 1. Multi-Source + Preferences | v1.0 | 4/4 | Complete | 2026-04-01 |
| 2. Smart Processing | v1.0 | 4/4 | Complete | 2026-04-01 |
| 3. Closed Loop | v1.0 | 4/4 | Complete | 2026-04-01 |
| 4. Integration Wiring Fixes | v1.0 | 1/1 | Complete | 2026-04-01 |
| 5. Daily Depth Control Wiring | v1.0 | 1/1 | Complete | 2026-04-01 |
| 6. Per-Source Metrics Continuity | v1.0 | 1/1 | Complete | 2026-04-01 |
| 7. README Documentation | v2.0 | 0/1 | Not started | - |
| 8. Output Quality Foundation & Infrastructure | v2.0 | 0/3 | Not started | - |
| 9. Noise Floor & Classification Quality | v2.0 | 2/3 | In Progress|  |
| 10. Dedup Hardening & Alert Fatigue | v2.0 | 3/3 | Complete    | 2026-04-02 |
| 11. Observability & Data Integrity | v2.0 | 3/3 | Complete    | 2026-04-02 |
| 12. Interaction Surface & Deployment UX | v2.0 | 1/3 | In Progress|  |
