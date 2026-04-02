# OpenClaw News Digest Skill

## What This Is

A personalized OpenClaw news research and delivery skill that continuously observes the world on the user's behalf. It combines multi-source collection, LLM-assisted classification and summarization, event tracking, preference learning, alerting, and explainable output rendering to produce Chinese-language digests, alerts, and weekly reports.

## Core Value

Replace "pushing messages to the user" with "continuously observing the world on the user's behalf" while preserving anti-echo-chamber exposure alongside deep personalization.

## Current State

- Shipped `v2.0 Quality & Robustness` on `2026-04-03`.
- Archived milestones: `v1.0 MVP`, `v2.0 Quality & Robustness`.
- Current codebase includes operator documentation, Chinese rendering contracts, prompt-versioned cache invalidation, pre-write data validation, noise filtering, alert fatigue controls, schema/version registries, diagnostics, schedule profiles, source-status inspection, and deterministic recommendation explainability.

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

### Active

- [ ] `HARD-01`: Improve script operability in environments where here-doc patterns are brittle.
- [ ] `HARD-02`: Add alert governance with source confidence tiers and multi-source corroboration.
- [ ] `HARD-03`: Add pre-configured disabled source templates for safer future expansion.
- [ ] `HARD-04`: Decouple render-layer contracts from content-model contracts.
- [ ] `OPER-01`: Run live platform smoke tests for cron delivery, isolated session loading, exec permissions, timeout behavior, and empty-input quality gates.

### Out of Scope

- Runtime code changes inside the OpenClaw platform. This repo remains a prompt, config, and reference-doc skill project.
- New source integrations beyond the current pre-configured template set.
- Standalone frontend or app UI work.
- Multi-user support before the single-user operating model is proven.
- Embedding-based dedup at the current scale.

## Context

Shipped `v2.0` across `6` phases, `16` plans, and `31` tasks between `2026-04-02` and `2026-04-03`.

- Git delta since `v1.0`: `82` commits, `86` files changed, `+11,428/-3,822` lines.
- Tech stack: OpenClaw `SKILL.md`, Markdown reference docs, JSON/JSONL state, bash utilities, deterministic fixture files.
- Quality themes validated in this milestone: localization, deterministic contracts, lower-noise processing, observability, explainability, and operator UX.
- Remaining follow-up: live platform smoke testing is still pending, and Nyquist validation coverage is incomplete for milestone phases.

## Constraints

- Must run as an OpenClaw skill, not as a standalone backend service.
- `SKILL.md` must stay compact enough to fit the platform context budget.
- The system stores structured JSON/JSONL files in the workspace filesystem rather than a database.
- Cost controls still assume a daily LLM budget guardrail and circuit-breaker behavior.
- MVP and current shipped releases are designed for a single operator/user context.
- The system stores rewritten summaries rather than full scraped article bodies.

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

## Next Milestone Goals

- Turn the v2.0 hardening backlog into a scoped `v2.1` or `v3.0` milestone.
- Prioritize runtime hardening and live platform verification before broadening feature scope.
- Keep milestone-planning documents small by continuing to archive shipped roadmap and requirements content under `.planning/milestones/`.

## Evolution

This document should evolve at phase transitions and milestone boundaries.

After each milestone:

1. Move shipped requirements into `Validated`.
2. Refresh `Active` to describe the next real milestone candidate set.
3. Update `Context` with current shipped scope, metrics, and unresolved follow-up work.
4. Add or revise milestone-level decisions that future phases should treat as stable constraints.

---
*Last updated: 2026-04-03 after completing the v2.0 Quality & Robustness milestone*
