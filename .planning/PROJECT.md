# OpenClaw News Digest Skill

## What This Is

A personalized OpenClaw news research and delivery skill that continuously observes the world on the user's behalf. It combines multi-source collection, LLM-assisted classification and summarization, event tracking, preference learning, alerting, provenance-aware ranking, explainable output rendering, and automated direct-source discovery.

## Core Value

Replace "pushing messages to the user" with "continuously observing the world on the user's behalf" while preserving anti-echo-chamber exposure alongside deep personalization.

## Current State

- Shipped `v3.0 Provenance & Source Discovery` on `2026-04-04`.
- The system now tracks item provenance with T0-T4 source tiers, citation chains, propagation hops, and discrepancy logging through a first-class Provenance Stage.
- Automated T1/T2 source discovery runs with rolling metrics, five-gate auto-enable evaluation, and three-trigger auto-disable — sources accumulate into `data/provenance/discovered-sources.json`.
- Provenance influences ranking through a post-formula modifier (T1/T2 boost, T4 decay when direct coverage exists), event representative selection, tier-aware alert gating (T4 at 0.92, T0-T3 at 0.85), and provenance-aware digest/alert rendering.
- Operator surface hardened with 5 auditable Python modules (`scripts/lib/`), append-only run journal, `pipeline_state` enum, automated smoke tests (`smoke-test.sh`), and cross-channel recovery matrix.
- Backlog failure follow-up wired into SKILL.md — every error journal entry creates a backlog follow-up entry via `backlog_tools.append_failure_followup`.
- Archived milestones: `v1.0 MVP`, `v2.0 Quality & Robustness`, `v3.0 Provenance & Source Discovery`.
- The pipeline now runs from collection through provenance classification, source discovery, provenance-aware ranking, and explainable output delivery with full operator audit trails.

## Next Milestone

Not yet planned — use `/gsd:new-milestone` to start the next cycle.

## Requirements

### Validated

- v1.0 delivered the end-to-end pipeline, multi-source collection, preference learning, anti-echo-chamber quotas, alerts, weekly reports, history queries, and per-source metrics continuity.
- v2.0 delivered repo-root operator documentation and deployment guidance via `README.md`.
- v2.0 localized all user-facing output to Chinese and formalized a rendering contract that separates user-facing vs internal fields.
- v2.0 added prompt-versioned cache invalidation, bootstrap verification, deterministic fixtures, and pre-write quality validation.
- v2.0 hardened noise filtering and classification quality with pre-classify filters, post-classify thresholds, negative examples, and `classify-v2`.
- v2.0 reduced alert fatigue with `AlertState`, per-event alert memory, delta alerts, digest-history repetition control, and suppression transparency.
- v2.0 completed observability with accurate source transparency, `run_log`, a Schema Version Registry, and `scripts/diagnostics.sh`.
- v2.0 expanded operator and user interaction surfaces with repo-backed schedule profiles, canonical intent routing, `scripts/source-status.sh`, deterministic recommendation evidence, and dense-day timeline collapse rules.
- v3.0 Phase 13 delivered dedicated T1/T2 provenance rule libraries, a first-class provenance stage, deterministic citation extraction rules, a structured provenance prompt, fixed disagreement resolution, and persistent provenance fixtures/contracts under `data/provenance/`.
- v3.0 Phase 14 delivered passive T1/T2 source discovery with rolling metrics, auto-enable/disable rules, generated source metadata, and discovery audit artifacts.
- v3.0 Phase 15 delivered provenance-aware ranking, event representative selection, tier-aware alert gating, provenance-aware digest/alert rendering, weekly source-discovery reporting, and an end-to-end verification fixture.
- v3.0 Phase 17 initialized the provenance data store (`data/provenance/`) with all 5 artifact files and a verification script, unblocking PROV-06, PIPE-01, PIPE-04, DISC-01, and PIPE-05 at runtime.

### Active

- [ ] `HARD-*`: Replace brittle inline exec paths with auditable scripts and add collection atomization.
- [ ] `OPER-*`: Add run journaling, clearer failure states, baseline source profiles, CLI/docs parity checks, version safeguards, and live platform smoke coverage.

### Out of Scope

- Runtime code changes inside the OpenClaw platform. This repo remains a prompt, config, reference-doc, and helper-script skill project.
- Manual source approval or review workflows. v3.0 is intentionally fully automated once discovery rules are trusted.
- Cross-platform source discovery beyond the OpenClaw VM/workspace environment used by this skill.
- Historical backfill of provenance metadata for pre-v3 news items. The milestone only guarantees provenance for items processed after rollout.
- Standalone frontend or app UI work.
- Multi-user support before the single-user operating model is proven.

## Context

- `v2.0` proved the skill can localize, rank, alert, explain, and diagnose results, but it still leans on T4 aggregation-heavy feeds for part of its coverage.
- The `2026-04-03` provenance/source-discovery spec expands the roadmap from passive source monitoring to active provenance tracking and automated direct-source acquisition.
- Existing source-status inspection, schedule profiles, deterministic recommendation evidence, and schema registries provide the operational base for this milestone.
- The same spec also folds in the outstanding P0/P1 backlog around inline exec safety, failure journaling, collection atomization, docs parity, and version consistency.

## Constraints

- Must run as an OpenClaw skill, not as a standalone backend service.
- `SKILL.md` must stay compact enough to fit the platform context budget.
- The system stores structured JSON/JSONL files in the workspace filesystem rather than a database.
- The provenance and source-discovery rollout is fully automated; user approval is not part of the steady-state source enable/disable loop.
- Runtime code changes inside the hosted OpenClaw platform are out of scope for this repo.
- The project still targets a single operator/user context while the automated discovery loop is being proven.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep `SKILL.md` thin and push detail into `references/` | Preserves context budget while keeping the operating model inspectable | Good |
| Use prompt-versioned cache keys | Prompt changes must invalidate stale cached outputs deterministically | Good |
| Separate user-facing rendering contracts from internal fields | Prevents raw JSON leakage in digest and alert output | Good |
| Use regex-based pre-classify noise filters plus post-classify eligibility gates | Saves LLM budget and lowers low-value digest noise | Good |
| Store alert tracking in `AlertState` instead of `DailyMetrics` | Keeps alert governance authoritative and reduces race-prone derived state | Good |
| Compare repetition penalty only against the most recent digest | Avoids compounding penalties while still suppressing stale repeats | Good |
| Maintain both Schema Version Registry and New Fields Registry | Keeps schema evolution explicit for future milestone work | Good |
| Derive recommendation evidence deterministically, not from LLM-authored rationale | Explainability should be reproducible from scoring and quota state | Good |
| Store schedule profiles in repo state with stable IDs | Makes deployment UX auditable and editable without hidden platform state | Good |
| Add explicit T0-T4 provenance tiers plus persistent stores under `data/provenance/` | The ranking and discovery loop needs a first-class record of where stories came from | Good |
| Auto-enable newly discovered T1/T2 sources when quality gates pass | The core milestone value is replacing T4-heavy coverage without manual curation bottlenecks | Good |
| Keep provenance as a post-formula modifier plus representative-selection layer | Lets ranking change without retuning the seven existing weighted dimensions | Good |
| Keep provenance diagnostics internal while rendering user-facing tier/original-source/chain context | Adds trust context without leaking raw classifier internals into digest and alert output | Good |
| Resolve T1 disagreements in favor of URL rules and T2/T3/T4 disagreements in favor of LLM classification | Official domains are precision-friendly, while deeper propagation tiers need content understanding | Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check -> still the right priority?
3. Audit Out of Scope -> reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-04 after completing v3.0 Provenance & Source Discovery*
