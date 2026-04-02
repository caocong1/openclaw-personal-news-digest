---
phase: 9
slug: noise-floor-classification-quality
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-02
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual fixture verification (document-only project, no automated test framework) |
| **Config file** | N/A |
| **Quick run command** | Manual: verify fixture files contain expected fields |
| **Full suite command** | Manual: review all modified files against requirements checklist |
| **Estimated runtime** | ~2 minutes (manual review) |

---

## Sampling Rate

- **After every task commit:** Manual spot-check of modified files
- **After every plan wave:** Full manual review of all wave deliverables
- **Before `/gsd:verify-work`:** All requirements checklist must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | NOISE-04 | fixture | Verify sources.json has noise_patterns and title_discard_patterns | W0 | pending |
| 09-01-02 | 01 | 1 | NOISE-01 | fixture | Verify processing-instructions.md has Section 0E | W0 | pending |
| 09-02-01 | 02 | 1 | NOISE-02 | fixture | Verify processing-instructions.md has post-classify filter | W0 | pending |
| 09-02-02 | 02 | 1 | NOISE-03 | fixture | Verify noise items present in fixture JSONL with digest_eligible: false | W0 | pending |
| 09-02-03 | 02 | 1 | NOISE-05 | fixture | Verify metrics fixture has noise_filter_suppressed | W0 | pending |
| 09-03-01 | 03 | 2 | CLASS-01 | manual | Read classify.md for 0.0-0.2 tier and disambiguation rules | N/A | pending |
| 09-03-02 | 03 | 2 | CLASS-02 | manual | Read categories.json for negative_examples field | N/A | pending |
| 09-03-03 | 03 | 2 | CLASS-03 | manual | Check `<!-- prompt_version: classify-v2 -->` in classify.md | N/A | pending |

*Status: pending | green | red | flaky*

---

## Wave 0 Requirements

- [ ] `data/fixtures/news-items-noise-filtered.jsonl` — new fixture with noise-filtered and low-importance items
- [ ] Update `data/fixtures/metrics-sample.json` — add noise_filter_suppressed field
- [ ] Verify existing fixtures are updated for schema v4 (digest_eligible field)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Classify prompt has 0.0-0.2 tier examples | CLASS-01 | Prompt quality is subjective; verify examples are concrete and cover the right scenarios | Read classify.md, confirm 0.0-0.2 section has at least 4 concrete examples |
| Disambiguation rules cover common confusion pairs | CLASS-01 | Rule quality requires domain judgment | Read classify.md, confirm rules for ai-models vs business, dev-tools, macro-policy |
| Negative examples are relevant per category | CLASS-02 | Content quality requires domain knowledge | Read categories.json, verify each category has 2-3 relevant negative examples |
| Cache version forces re-classification | CLASS-03 | Effect only observable at runtime | Verify prompt_version comment reads classify-v2 |

---

## Validation Sign-Off

- [ ] All tasks have fixture verify or manual verification
- [ ] Sampling continuity: no 3 consecutive tasks without verification
- [ ] Wave 0 covers all fixture dependencies
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
