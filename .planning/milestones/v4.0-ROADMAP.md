# Roadmap: OpenClaw News Digest Skill

## Milestones

- ✅ **v1.0 MVP** — Phases 0-6 (shipped 2026-04-02) — [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v2.0 Quality & Robustness** — Phases 7-12 (shipped 2026-04-03) — [archive](milestones/v2.0-ROADMAP.md)
- ✅ **v3.0 Provenance & Source Discovery** — Phases 13-19 (shipped 2026-04-04) — [archive](milestones/v3.0-ROADMAP.md)
- **v4.0 Quick-Check Audit Fixes** — Phases 20-22 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 0-6) — SHIPPED 2026-04-02</summary>

- [x] Phase 0: MVP Pipeline (3/3 plans) — completed 2026-04-01
- [x] Phase 1: Multi-Source Collection & Preferences (4/4 plans) — completed 2026-04-01
- [x] Phase 2: Smart Processing (4/4 plans) — completed 2026-04-01
- [x] Phase 3: Closed-Loop Learning (4/4 plans) — completed 2026-04-01
- [x] Phase 4: Integration Wiring Fixes (1/1 plans) — completed 2026-04-02
- [x] Phase 5: Daily Depth Control Wiring (1/1 plans) — completed 2026-04-02
- [x] Phase 6: Per-Source Metrics Continuity (1/1 plans) — completed 2026-04-02

</details>

<details>
<summary>v2.0 Quality & Robustness (Phases 7-12) — SHIPPED 2026-04-03</summary>

- [x] Phase 7: README Documentation (1/1 plans) — completed 2026-04-02
- [x] Phase 8: Output Quality Foundation & Infrastructure (3/3 plans) — completed 2026-04-02
- [x] Phase 9: Noise Floor & Classification Quality (2/2 plans) — completed 2026-04-03
- [x] Phase 10: Dedup Hardening & Alert Fatigue (3/3 plans) — completed 2026-04-03
- [x] Phase 11: Observability & Data Integrity (3/3 plans) — completed 2026-04-03
- [x] Phase 12: Interaction Surface & Deployment UX (3/3 plans) — completed 2026-04-03

</details>

<details>
<summary>v3.0 Provenance & Source Discovery (Phases 13-19) — SHIPPED 2026-04-04</summary>

- [x] Phase 13: Provenance Core (3/3 plans) — completed 2026-04-03
- [x] Phase 14: Source Discovery Automation (3/3 plans) — completed 2026-04-03
- [x] Phase 15: Provenance-Aware Ranking & Delivery (3/3 plans) — completed 2026-04-03
- [x] Phase 16: Operational Hardening & Verification (4/4 plans) — completed 2026-04-03
- [x] Phase 17: Initialize Provenance Data Store (1/1 plans) — completed 2026-04-03
- [x] Phase 18: Wire Backlog Failure Follow-up (1/1 plans) — completed 2026-04-04
- [x] Phase 19: Add Missing E2E Fixture (1/1 plans) — completed 2026-04-04

</details>

### v4.0 Quick-Check Audit Fixes (In Progress)

**Milestone Goal:** Fix all P0/P1 bugs and clean dead code in `scripts/debug_quick_check.py`, identified by multi-CLI audit with ground-truth verification.

- [x] **Phase 20: P0 Infrastructure Fixes** - Concurrency guard, atomic writes, write ordering (completed 2026-04-06)
- [x] **Phase 21: P1 Logic Bug Fixes** - Sort fix, alert cap, index fix, anchor guard (completed 2026-04-06)
- [x] **Phase 22: Dead Code Cleanup** - Remove unused constants and functions (completed 2026-04-06)

## Phase Details

### Phase 20: P0 Infrastructure Fixes
**Goal**: Pipeline runs never corrupt state or produce duplicate alerts, even under concurrent cron or mid-write crash
**Depends on**: Nothing (first phase of v4.0)
**Requirements**: INFRA-01, INFRA-02, INFRA-03
**Success Criteria** (what must be TRUE):
  1. A second cron invocation while the first is running exits cleanly without corrupting state or producing partial output
  2. Killing the process mid-write to any state/metrics file leaves the previous valid version intact (no partial JSON on disk)
  3. A crash between state write and alert publish never causes the same alert to fire again on the next run
**Plans**: TBD

### Phase 21: P1 Logic Bug Fixes
**Goal**: Alert sorting, daily caps, cluster indexing, and event merging behave correctly per SKILL.md spec
**Depends on**: Phase 20 (uses atomic_write_text helper introduced in INFRA-02)
**Requirements**: LOGIC-01, LOGIC-02, LOGIC-03, LOGIC-04
**Success Criteria** (what must be TRUE):
  1. Alerts are sorted by importance_score descending, with the LLM-derived score preserved as tiebreaker (no second sort erasing it)
  2. No more than 3 alerts fire per day, regardless of how many candidates exceed the threshold
  3. Union-find cluster ID lookup produces the correct cluster for every alert, even when two alert dicts are value-equal
  4. Two events sharing only a dollar-amount anchor (e.g. "$1B") are NOT merged unless they share a second non-generic anchor
**Plans**: 2 plans
- [ ] 21-01-PLAN.md — Fix alert sort order and enforce daily alert cap (LOGIC-01, LOGIC-02)
- [ ] 21-02-PLAN.md — Fix union-find cluster lookup and dollar-anchor merge guard (LOGIC-03, LOGIC-04)

### Phase 22: Dead Code Cleanup
**Goal**: Unused constants and functions are removed, reducing noise for future audits
**Depends on**: Nothing (independent of Phase 20 and 21)
**Requirements**: CLEAN-01, CLEAN-02, CLEAN-03
**Success Criteria** (what must be TRUE):
  1. `MAX_ALERTS_PER_DAY = None` constant no longer exists in the codebase
  2. `ALERT_THRESHOLD = 0.85` constant no longer exists in the codebase
  3. `normalize_event_key()` function (42 lines) no longer exists in the codebase — deferred activation tracked in v5.0 requirements (EVENT-01)
**Plans**: 1 plan
- [ ] 22-01-PLAN.md — Remove dead constants and unused function (CLEAN-01, CLEAN-02, CLEAN-03)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 0. MVP Pipeline | 3/3 | Complete | 2026-04-01 |
| 1. Multi-Source Collection & Preferences | 4/4 | Complete | 2026-04-01 |
| 2. Smart Processing | 4/4 | Complete | 2026-04-01 |
| 3. Closed-Loop Learning | 4/4 | Complete | 2026-04-01 |
| 4. Integration Wiring Fixes | 1/1 | Complete | 2026-04-02 |
| 5. Daily Depth Control Wiring | 1/1 | Complete | 2026-04-02 |
| 6. Per-Source Metrics Continuity | 1/1 | Complete | 2026-04-02 |
| 7. README Documentation | 1/1 | Complete | 2026-04-02 |
| 8. Output Quality Foundation & Infrastructure | 3/3 | Complete | 2026-04-02 |
| 9. Noise Floor & Classification Quality | 2/2 | Complete | 2026-04-03 |
| 10. Dedup Hardening & Alert Fatigue | 3/3 | Complete | 2026-04-03 |
| 11. Observability & Data Integrity | 3/3 | Complete | 2026-04-03 |
| 12. Interaction Surface & Deployment UX | 3/3 | Complete | 2026-04-03 |
| 13. Provenance Core | 3/3 | Complete | 2026-04-03 |
| 14. Source Discovery Automation | 3/3 | Complete | 2026-04-03 |
| 15. Provenance-Aware Ranking & Delivery | 3/3 | Complete | 2026-04-03 |
| 16. Operational Hardening & Verification | 4/4 | Complete | 2026-04-03 |
| 17. Initialize Provenance Data Store | 1/1 | Complete | 2026-04-03 |
| 18. Wire Backlog Failure Follow-up | 1/1 | Complete | 2026-04-04 |
| 19. Add Missing E2E Fixture | 1/1 | Complete | 2026-04-04 |
| 20. P0 Infrastructure Fixes | 2/2 | Complete    | 2026-04-06 |
| 21. P1 Logic Bug Fixes | 2/2 | Complete    | 2026-04-06 |
| 22. Dead Code Cleanup | 1/1 | Complete    | 2026-04-06 |
