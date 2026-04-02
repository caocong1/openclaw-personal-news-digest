# Milestones

## v1.0 MVP (Shipped: 2026-04-02)

**Phases completed:** 7 phases, 18 plans, 35 tasks

**Key accomplishments:**

- End-to-end daily news digest pipeline with RSS collection, LLM classification/summarization, and link-level dedup
- Multi-source collection (6 types) with natural language source management and disambiguation
- Event merging with timeline tracking, anti-echo-chamber quota system, and 7-dimension personalized scoring
- Closed-loop feedback learning, preference decay, weekly trend reports, and NL history queries
- Daily depth-control wiring connecting user preferences to variable-depth summaries
- Per-source metrics continuity enabling source health, monitoring, and auto-demotion/recovery

**Stats:** 82 commits, 100 files, ~20,764 lines added over 2 days (2026-03-31 -> 2026-04-02)

---

## v2.0 Quality & Robustness (Shipped: 2026-04-03)

**Phases completed:** 6 phases, 16 plans, 31 tasks

**Key accomplishments:**

- Added a repo-root `README.md` covering architecture, deployment, configuration, and operational workflows
- Localized all user-facing output to Chinese and formalized rendering contracts, prompt-version cache invalidation, bootstrap verification, and deterministic fixtures
- Hardened the processing pipeline with pre-classify noise filtering, post-classify digest eligibility thresholds, and stronger classification prompts with negative examples
- Reduced alert fatigue with `AlertState`, per-event alert memory, delta alerts, digest history, and cross-digest repetition suppression
- Completed observability with accurate source transparency, structured `run_log`, schema-version tracking, and `scripts/diagnostics.sh`
- Added operator-facing interaction improvements including schedule profiles, canonical intent routing, `scripts/source-status.sh`, deterministic recommendation evidence, and dense-day timeline collapse rules

**Stats:** 82 commits since `v1.0`, 86 files changed, +11,428/-3,822 lines over 2 days (2026-04-02 -> 2026-04-03)

---
