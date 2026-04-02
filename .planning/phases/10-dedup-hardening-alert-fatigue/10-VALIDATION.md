---
phase: 10
slug: dedup-hardening-alert-fatigue
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual verification via fixture files |
| **Config file** | N/A (prompt/config project, no test runner) |
| **Quick run command** | Manual: compare fixture data against expected behavior |
| **Full suite command** | Manual: run pipeline with fixture data, verify outputs |
| **Estimated runtime** | ~60 seconds (manual inspection) |

---

## Sampling Rate

- **After every task commit:** Verify fixture files match schema, trace decision tree manually
- **After every plan wave:** Full manual walkthrough of Quick-Check and Output Phase flows
- **Before `/gsd:verify-work`:** All fixtures valid, all templates updated, all data models documented
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | ALERT-01 | fixture | Verify alert-state fixture has cap=3, URL dedup | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 1 | ALERT-03 | manual-only | Read Quick-Check flow, trace decision tree | N/A | ⬜ pending |
| 10-01-03 | 01 | 1 | ALERT-06 | manual-only | Trace fallback path for items without event_id | N/A | ⬜ pending |
| 10-02-01 | 02 | 2 | ALERT-02 | fixture | Verify events-active fixture has v3 alert memory fields | ❌ W0 | ⬜ pending |
| 10-02-02 | 02 | 2 | ALERT-04 | fixture | Verify delta alert fixture output shows changes | ❌ W0 | ⬜ pending |
| 10-02-03 | 02 | 2 | ALERT-05 | manual-only | Inspect delta-alert prompt and template | N/A | ⬜ pending |
| 10-03-01 | 03 | 3 | DEDUP-01 | fixture | Verify digest-history fixture has 5-run snapshots | ❌ W0 | ⬜ pending |
| 10-03-02 | 03 | 3 | DEDUP-02 | fixture | Score item with/without penalty, compare values | ❌ W0 | ⬜ pending |
| 10-03-03 | 03 | 3 | DEDUP-03 | manual-only | Inspect output template for suppression footer line | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `data/fixtures/alert-state-sample.json` — stub for ALERT-01 (alert state with cap reached)
- [ ] `data/fixtures/events-active-v3.json` — stub for ALERT-02 (events with alert memory fields)
- [ ] `data/fixtures/digest-history-sample.json` — stub for DEDUP-01, DEDUP-02 (5-run history with snapshots)

*Existing fixture infrastructure in data/fixtures/ covers pattern conventions.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Unified decision tree documented | ALERT-03 | Prompt/config project — logic in reference docs | Read Quick-Check flow, verify single decision tree path |
| Delta alert template shows changes | ALERT-05 | Template content verification | Inspect delta-alert prompt for change comparison |
| Standard fallback for no event context | ALERT-06 | Decision tree branch trace | Follow decision tree for item without event_id |
| Suppression footer line | DEDUP-03 | Template content verification | Check output-templates.md for suppression count line |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
