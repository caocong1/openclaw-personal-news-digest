# Milestones

## v4.0 Quick-Check Audit Fixes (Shipped: 2026-04-06)

**Phases completed:** 3 phases, 5 plans, 9 tasks

**Key accomplishments:**

- Process-level flock prevents concurrent cron runs from corrupting state (INFRA-01)
- Atomic tmp+fsync+os.replace writes ensure crash mid-write leaves valid state intact (INFRA-02)
- State-before-alert write ordering eliminates duplicate alerts after crash (INFRA-03)
- Single correct sort preserving importance_score tiebreaker + daily alert cap of 3 enforced (LOGIC-01/02)
- Enumerate-based union-find eliminates wrong-cluster bug + dollar-anchor guard prevents spurious merges (LOGIC-03/04)
- Removed 44 lines of dead code: 2 unused constants and normalize_event_key() function (CLEAN-01/02/03)

**Stats:** 14 commits, 17 files changed, +1,902/-42 lines over 1 day (2026-04-06)
**Source:** Multi-CLI audit report (7 CLI runs, 2 rounds, 12 confirmed bugs → 10 fixed, 2 out-of-scope)

---

## v3.0 Provenance & Source Discovery (Shipped: 2026-04-04)

**Phases completed:** 7 phases, 16 plans

**Key accomplishments:**

- Added T1/T2 provenance rule libraries, a first-class Provenance Stage, citation extraction, and persistent provenance stores under `data/provenance/` with cross-validation and discrepancy logging
- Built automated T1/T2 source discovery with rolling metrics, five-gate auto-enable evaluation, three-trigger auto-disable, and generated source config metadata
- Integrated provenance into ranking as a post-formula modifier, added event representative selection, tier-aware alert gating, and provenance-aware digest/alert rendering with Chinese-tier labels
- Hardened the operator surface with 5 auditable Python modules (`scripts/lib/`), append-only run journal, `pipeline_state` enum, automated smoke tests, and cross-channel recovery matrix
- Wired `backlog_tools.append_failure_followup` into SKILL.md so every error journal entry creates a backlog follow-up entry (closing OPER-03)
- Created E2E fixture and smoke test coverage for provenance-aware pipeline assertions (PIPE-01 through PIPE-03)

**Stats:** 52 commits, 22 files changed, +1107/-45 lines over ~1.5 days (2026-04-03 → 2026-04-04)

---

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
