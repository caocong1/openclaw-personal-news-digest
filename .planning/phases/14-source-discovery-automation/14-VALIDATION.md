---
phase: 14
slug: source-discovery-automation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 14 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual verification via JSON fixtures, grep checks, and script-readable audit artifacts |
| **Config file** | none - prompt/config/reference-doc repo, no formal test runner |
| **Quick run command** | `python3 -c "import json; json.load(open('data/fixtures/discovered-sources-sample.json')); json.load(open('data/fixtures/source-config-auto-discovered-sample.json')); print('PASS')" && rg -n "discovered-sources|auto_discovered|t1_ratio|decision_history|frequency|uniqueness|hit_count" references/data-models.md references/processing-instructions.md SKILL.md` |
| **Full suite command** | Manual: inspect discovery state fixtures, generated source-config fixture, audit artifact, and threshold docs against DISC-01 through DISC-04 |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick command for touched discovery docs or fixtures, then inspect the exact threshold or audit fields changed in that task
- **After every plan wave:** Run the full manual verification walkthrough for all discovery artifacts added in that wave
- **Before `$gsd-verify-work`:** Discovery state, generated-source contract, and audit artifacts must agree on the same enable/disable decisions
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | DISC-01 | schema+fixture | `python3 -c "import json; json.load(open('data/fixtures/discovered-sources-sample.json')); print('PASS')" && rg -n "first_seen|last_seen|hit_count_7d|t1_ratio|representative_titles|decision_history" data/fixtures/discovered-sources-sample.json references/data-models.md` | [ ] W0 | pending |
| 14-01-02 | 01 | 1 | DISC-01 | doc | `rg -n "domain normalization|root domain|representative URL|rolling 7-day|discovered-sources" references/processing-instructions.md SKILL.md` | [ ] W0 | pending |
| 14-02-01 | 02 | 2 | DISC-02, DISC-04 | doc+fixture | `python3 -c "import json; json.load(open('data/fixtures/source-config-auto-discovered-sample.json')); print('PASS')" && rg -n ">= 5|t1_ratio >= 0.3|at least 3 days|src-auto-|auto_discovered|config/sources.json" references/processing-instructions.md references/data-models.md data/fixtures/source-config-auto-discovered-sample.json` | [ ] W0 | pending |
| 14-02-02 | 02 | 2 | DISC-03 | doc+fixture | `python3 -c "import json; json.load(open('data/fixtures/discovered-sources-rejected-sample.json')); print('PASS')" && rg -n "t1_ratio < 0.1|14 consecutive days|hit_count < 2|enabled: false|discovery_decision" references/processing-instructions.md references/data-models.md data/fixtures/discovered-sources-rejected-sample.json` | [ ] W0 | pending |
| 14-03-01 | 03 | 3 | DISC-01, DISC-02, DISC-03, DISC-04 | audit | `rg -n "enabled|disabled|deferred|rejected|t1-sources|t2-sources|pattern-library" data/fixtures/source-discovery-audit-sample.md references/processing-instructions.md references/data-models.md` | [ ] W0 | pending |
| 14-03-02 | 03 | 3 | DISC-02, DISC-03 | manual-only | Read the audit artifact and confirm one domain completes the full lifecycle from observed -> enabled -> disabled with explicit reasons and timestamps | [ ] W0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `data/fixtures/discovered-sources-sample.json` - discovery accumulation fixture with rolling metrics and decision history
- [ ] `data/fixtures/discovered-sources-rejected-sample.json` - rejected or deferred discovery outcomes with explicit reasons
- [ ] `data/fixtures/source-config-auto-discovered-sample.json` - generated `Source` entry fixture with discovery metadata
- [ ] `data/fixtures/source-discovery-audit-sample.md` - human-readable lifecycle audit artifact

*Existing infrastructure covers JSON storage and source-status inspection, but Phase 14 needs dedicated discovery fixtures before verification is concrete.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Uniqueness is based on uncovered event coverage rather than title novelty | DISC-02 | Requires semantic comparison across provenance, item, and event concepts | Read the discovery docs and audit sample, then confirm the unique-event gate names event coverage explicitly instead of URL or title novelty |
| Discovery disable remains distinct from operational degraded status | DISC-03 | Grep can find fields but not prove semantics | Read `references/data-models.md`, `references/processing-instructions.md`, and the audit sample to confirm discovery disable uses `enabled` plus audit metadata without redefining `status` semantics |
| Pattern-library expansion preserves path-sensitive evidence | DISC-01, DISC-04 | Requires human review of representative URL usage | Check that the audit or fixture examples keep representative URLs or path samples rather than collapsing everything to bare root domains |
| Discovery history is actually explainable to an operator | DISC-01, DISC-02, DISC-03 | Audit readability is qualitative | Read the lifecycle sample and confirm a human can tell why a domain was observed, deferred, enabled, or disabled without consulting hidden state |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
