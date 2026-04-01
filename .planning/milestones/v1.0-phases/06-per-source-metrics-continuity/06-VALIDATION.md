---
phase: 6
slug: per-source-metrics-continuity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash scripts + grep verification |
| **Config file** | none — documentation/wiring phase |
| **Quick run command** | `bash scripts/health-check.sh` |
| **Full suite command** | `bash scripts/health-check.sh` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/health-check.sh`
- **After every plan wave:** Run `bash scripts/health-check.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | SRC-08 | grep | `grep -q 'per_source' references/data-models.md` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | SRC-09 | grep | `grep -q 'per_source' references/processing-instructions.md` | ❌ W0 | ⬜ pending |
| 06-01-03 | 01 | 1 | MON-02 | grep | `grep -q 'per_source' references/collection-instructions.md` | ❌ W0 | ⬜ pending |
| 06-01-04 | 01 | 1 | MON-03 | script | `bash scripts/health-check.sh` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Degrade/recover continuity | SRC-09 | Requires multi-day metrics history | Verify source quality_history array supports recomputation |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
