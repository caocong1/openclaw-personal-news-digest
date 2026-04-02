---
phase: 12
slug: interaction-surface-deployment-ux
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 12 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual verification via fixture files, grep checks, and script output review |
| **Config file** | none - prompt/config project, no formal test runner |
| **Quick run command** | `bash scripts/diagnostics.sh .` |
| **Full suite command** | Manual: inspect schedule profile config, source-status output, digest explainability template, and dense-day event fixture against Phase 12 rules |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/diagnostics.sh .` if source-status behavior changed, then grep/read touched docs and fixtures
- **After every plan wave:** Run the full manual verification walkthrough for all changed artifacts in that wave
- **Before `$gsd-verify-work`:** All Phase 12 fixtures and command/render contracts must be consistent
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | INTERACT-01 | fixture+doc | `rg -n "schedule-profiles|weekday|custom hours|cron" config references SKILL.md` | 鉂?W0 | 猬?pending |
| 12-01-02 | 01 | 1 | INTERACT-04 | doc | `rg -n "Intent Recognition|schedule|source status|feedback|preference query|history|diagnostics" references/feedback-rules.md SKILL.md` | 鉂?W0 | 猬?pending |
| 12-02-01 | 02 | 2 | INTERACT-02 | script+fixture | `bash scripts/diagnostics.sh .` | 鉂?W0 | 猬?pending |
| 12-02-02 | 02 | 2 | INTERACT-03 | doc+fixture | `rg -n "primary_driver|quota_group|signals|推荐" references/output-templates.md references/processing-instructions.md references/data-models.md` | 鉂?W0 | 猬?pending |
| 12-03-01 | 03 | 3 | INTERACT-05 | fixture | `rg -n ">5 items/day|collapsed|timeline" references/output-templates.md references/processing-instructions.md` | 鉂?W0 | 猬?pending |
| 12-03-02 | 03 | 3 | INTERACT-05 | manual-only | Read dense-day fixture and verify rendered contract preserves day, count, and newest update | 鉂?W0 | 猬?pending |

*Status: 猬?pending 路 鉁?green 路 鉂?red 路 鈿狅笍 flaky*

---

## Wave 0 Requirements

- [ ] `config/schedule-profiles.json` - stub or complete profile file for INTERACT-01
- [ ] `data/fixtures/source-status-metrics.json` - source health fixture for INTERACT-02
- [ ] `data/fixtures/digest-explainability-sample.json` - selection-evidence fixture for INTERACT-03
- [ ] `data/fixtures/events-active-dense-day.json` - dense same-day timeline fixture for INTERACT-05

*Existing infrastructure covers diagnostics and source health primitives, but the new Phase 12 UX contracts still need dedicated fixtures.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Schedule profile UX is actually operator-friendly | INTERACT-01 | Repo stores docs/config, not executable scheduler state | Read profile docs and confirm a human can map each profile to concrete `cron` commands without guessing |
| Intent routing is centralized and not duplicated | INTERACT-04 | Requires comparing multiple docs together | Confirm `references/feedback-rules.md` is the canonical intent table and `SKILL.md` only references it |
| Recommendation evidence matches real scoring/quota logic | INTERACT-03 | Requires semantic review, not just string presence | Compare evidence fields against `references/scoring-formula.md` and quota rules; ensure no LLM-invented rationale path exists |
| Dense-day timeline collapse preserves story continuity | INTERACT-05 | Rendering contract needs qualitative review | Read the dense-day fixture plus output template example; confirm same-day bursts collapse while newest/high-signal updates remain visible |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
