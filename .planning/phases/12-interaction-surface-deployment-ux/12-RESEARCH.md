# Phase 12: Interaction Surface & Deployment UX - Research

**Researched:** 2026-04-03
**Domain:** Scheduling profiles, source health visibility, deterministic recommendation explainability, rolling coverage rendering
**Confidence:** HIGH

## Summary

Phase 12 is a command-and-rendering UX phase, not a frontend phase. The repo already has most of the raw ingredients: cron job examples in `references/cron-configs.md`, source health metrics in `config/sources.json`, per-run `per_source` counters in DailyMetrics, a diagnostics script, quota/scoring rules, recommendation-reason slots for hotspot/exploration items, and event timelines with digest-history snapshots.

The gaps are at the interaction layer:

1. Scheduling is documented as copy-paste cron JSON, but there is no reusable "profile" model or SKILL command surface for configuring schedules.
2. Source health data exists, but the user-facing command surface is split between `HIST-05` in `references/processing-instructions.md` and `scripts/diagnostics.sh`; there is no dedicated source-status UX that clearly exposes enabled/disabled/degraded state.
3. Recommendation reasons are currently partial and unstructured. The system knows why items were selected, but it does not expose that evidence deterministically across all selected items.
4. Natural-language intent routing is duplicated in `SKILL.md` and spread across references; Phase 12 should centralize intent recognition in `references/feedback-rules.md` and let `SKILL.md` stay thin.
5. Event tracking already renders timelines, but it does not collapse high-volume same-day bursts into a compact rolling-coverage view when a single day has more than 5 entries.

**Primary recommendation:** implement Phase 12 as **3 plans**:
- 12-01: Scheduling profiles + centralized intent routing
- 12-02: Source status command + deterministic recommendation evidence
- 12-03: Rolling coverage timeline collapse

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INTERACT-01 | Scheduling profiles configurable via SKILL.md commands | `references/cron-configs.md` already defines canonical daily, quick-check, weekly health, and weekly report jobs plus `cron create/list/disable/enable/delete/get`. Missing pieces are a persistent profile model and a command-routing spec for profile selection/update. |
| INTERACT-02 | Source status command shows per-source health and enable/disable state | Source metrics already exist in `config/sources.json` (`quality_score`, `dedup_rate`, `selection_rate`, `consecutive_failures`, `status`) and in DailyMetrics `per_source`. `references/processing-instructions.md` already defines `HIST-05: Source Analysis Query`, and `scripts/diagnostics.sh` already prints enabled/disabled/degraded counts and failed sources. |
| INTERACT-03 | Recommendations include structured evidence for why items were selected | `references/output-templates.md` only supports freeform `推荐理由` for hotspot/exploration items. The actual evidence already exists implicitly in scoring/quota rules: `final_score`, `importance_score`, `quota_group`, hotspot injection, event boost, repetition penalty, topic match, and source health. |
| INTERACT-04 | NL intent recognition table in feedback-rules.md without duplication in SKILL.md | `SKILL.md` currently hardcodes user-intent branches. `references/feedback-rules.md` already handles feedback and preference-query triggers, but there is no single routing table covering scheduling, source status, diagnostics, history, and feedback. |
| INTERACT-05 | Rolling coverage collapses events with >5 items/day into timeline view | `references/output-templates.md` already has an Event Tracking section and caps visible entries to 5 with an omission note. `references/processing-instructions.md` already stores `event.timeline` and `digest-history` snapshots. Missing is a same-day collapse rule based on daily density rather than total event length. |
</phase_requirements>

## Architecture Patterns

### Current State Analysis

**Scheduling / deployment UX**

- `references/cron-configs.md` contains four concrete job definitions:
  - `news-daily-digest`
  - `news-quick-check`
  - `weekly-health-inspection`
  - `news-weekly-report`
- The file also documents platform-critical settings such as `lightContext: false`, `sessionTarget: "isolated"`, and the exact `cron` management commands.
- There is no persistent schedule profile file in `config/`, no named profile abstraction (for example `weekday-only` or `custom-hours`), and no user command flow telling the agent how to translate a natural-language scheduling request into a profile update or `cron` action.

**Source status / observability UX**

- `config/sources.json` already stores the operator-facing health fields the requirement needs:
  - `enabled`
  - `status`
  - `stats.quality_score`
  - `stats.dedup_rate`
  - `stats.selection_rate`
  - `stats.consecutive_failures`
  - `stats.last_fetch`
  - `stats.last_error`
- `references/data-models.md` and `references/processing-instructions.md` already define DailyMetrics `per_source`.
- `references/processing-instructions.md` already has `HIST-05: Source Analysis Query` with a response format that is close to the Phase 12 requirement.
- `scripts/diagnostics.sh` already prints aggregate source health and recent failed sources.
- The gap is UX consolidation: today the "source status" behavior is split between query docs and diagnostics script output rather than a single explicit command contract.

**Recommendation explainability**

- `references/output-templates.md` currently renders `推荐理由` only for hotspot and exploration items.
- `references/processing-instructions.md` quota allocation already produces selection signals:
  - `quota_group`
  - hotspot injection for `importance_score >= 0.8`
  - reverse diversity constraints
  - cross-digest repetition penalty
  - exploration appetite correction
- `references/scoring-formula.md` defines the exact scoring inputs.
- `references/prompts/summarize.md` already asks for "why it matters / impact", but that is content summary, not "why selected for this user".
- The safest path is deterministic evidence derived from actual scoring/quota state, not LLM-generated justification.

**Intent recognition**

- `SKILL.md` currently enumerates intent routes inline:
  - source management
  - feedback
  - preference query
  - history query
  - diagnostics
- `references/feedback-rules.md` already contains trigger examples for feedback and preference visualization, making it the natural place to become the source of truth for broader intent routing.
- The gap is duplication. If Phase 12 adds scheduling and source-status intents, continuing to hardcode intent categories in `SKILL.md` will increase drift risk.

**Rolling coverage / dense event timelines**

- `references/output-templates.md` already has an Event Tracking section with timeline entries and a rule to show only the most recent 5 entries overall.
- `references/processing-instructions.md` already stores a complete `event.timeline` array and preserves event snapshots in `data/digest-history.json`.
- This is close, but not sufficient for INTERACT-05: the requirement is specifically about **more than 5 items in a single day**. The render layer needs a day-bucket collapse rule so high-volume bursts do not overwhelm rolling coverage.

### Recommended Approach

**INTERACT-01 / INTERACT-04**

1. Add a repo-owned schedule profile source of truth, for example:
   - `config/schedule-profiles.json`
2. Document schedule-management commands in a dedicated scheduling reference or an expanded `references/cron-configs.md`:
   - list profiles
   - activate profile
   - set daily digest time
   - set quick-check hours
   - weekday-only / weekends-off / custom-hours
3. Move the NL intent recognition table into `references/feedback-rules.md` and let `SKILL.md` reference that table rather than repeating trigger lists.

**INTERACT-02 / INTERACT-03**

1. Add an explicit "source status" command path that can:
   - show all sources summary
   - show a specific source detail view
2. Reuse existing health fields from `config/sources.json` and DailyMetrics `per_source` instead of inventing new metrics.
3. Define a deterministic recommendation evidence structure, for example:

```json
{
  "quota_group": "core|adjacent|hotspot|explore",
  "primary_driver": "topic_match|high_importance|event_followup|diversity_injection|hotspot_injection",
  "signals": [
    "importance>=0.80",
    "topic_weight=0.82",
    "source_quality=0.74",
    "event_boost=0.5",
    "repeat_penalty_applied=false"
  ]
}
```

4. Render compact evidence in digest output using fixed labels, not prose invented by the model.

**INTERACT-05**

1. Add a same-day grouping step before Event Tracking rendering:
   - bucket `event.timeline` entries by calendar day
   - if a day has `> 5` entries, collapse that day into a summarized block
2. Preserve exact counts and newest timestamps in the collapsed block.
3. Keep raw event data untouched; collapse is presentation-only.

## Validation Architecture

This repo still behaves like a prompt/config/reference-doc system rather than a conventional application with a test runner. Validation for Phase 12 should therefore be fixture-driven and grep/script based.

### Recommended verification shape

**Scheduling profiles**
- Verify a profile file exists and contains named profiles with concrete cron expressions and time zones.
- Verify command docs cover activation/update/list flows and reference actual `cron` commands.

**Source status**
- Verify the source-status command contract exposes:
  - source `enabled`
  - source `status`
  - `quality_score`
  - `dedup_rate`
  - `selection_rate`
  - `consecutive_failures`
- Prefer scriptable checks against fixture JSON or `scripts/diagnostics.sh` output.

**Recommendation evidence**
- Verify digest templates contain a structured evidence line for all selected-item groups the plan intends to support.
- Verify processing docs define deterministic evidence derivation from quota/scoring state.
- Verify no instruction says to ask the LLM to invent selection rationale.

**Rolling coverage collapse**
- Verify render rules explicitly say "collapse when a single day has >5 timeline entries".
- Verify collapsed output preserves:
  - day
  - collapsed count
  - at least one newest/high-signal pointer
  - source/event continuity

### Suggested fixture additions

- `data/fixtures/source-status-metrics.json`
- `data/fixtures/events-active-dense-day.json`
- `data/fixtures/digest-explainability-sample.json`

These do not need to be executable tests; they are enough to support manual or grep-based validation in a Nyquist-style validation contract.

### Anti-Shallow Validation Rule

Do not accept verification that only checks for heading presence. Each plan should verify concrete strings, schema fields, or command examples that prove the UX contract is actionable.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Schedule state | Only prose examples in `cron-configs.md` | A profile config file plus command docs | Keeps desired state explicit and editable |
| Source health data | New parallel health schema | Existing `config/sources.json` stats + DailyMetrics `per_source` | Data already exists and is authoritative |
| Recommendation reasons | Freeform LLM explanations | Deterministic evidence derived from scoring/quota signals | Prevents hallucinated or inconsistent reasons |
| Dense timeline collapse | Mutating `event.timeline` storage | Presentation-only day-bucket collapse | Preserves history and digest-history compatibility |

## Common Pitfalls

### Pitfall 1: Treating schedule profiles as pure documentation
**What goes wrong:** The repo gains more sample cron JSON, but the agent still has no consistent command surface for changing schedules.
**How to avoid:** Make one file the schedule-profile source of truth and route schedule intents through it.

### Pitfall 2: Duplicating intent routing in multiple files
**What goes wrong:** `SKILL.md`, `feedback-rules.md`, and new scheduling docs drift apart.
**How to avoid:** Centralize intent recognition in `references/feedback-rules.md` and let `SKILL.md` point to it.

### Pitfall 3: Using LLM-authored recommendation justifications
**What goes wrong:** The digest claims reasons that do not match the actual scoring or quota path.
**How to avoid:** Build recommendation evidence from concrete fields like `quota_group`, `importance_score`, topic weight, hotspot injection, and repeat-penalty state.

### Pitfall 4: Collapsing by total event size instead of same-day density
**What goes wrong:** Long-lived events get collapsed even when each day only has one or two updates, while bursty days still flood the digest.
**How to avoid:** Apply the threshold to entries sharing the same calendar day, exactly as the requirement states.

### Pitfall 5: Creating a source-status command that ignores disabled sources
**What goes wrong:** The output only covers sources present in recent metrics, hiding disabled or paused sources entirely.
**How to avoid:** Build the view from `config/sources.json` first, then enrich with recent metrics where available.

## Interaction with Existing Files

### Files to Modify

| File | Change | Requirement |
|------|--------|-------------|
| `SKILL.md` | Replace duplicated user-intent routing with references to a centralized intent table; add schedule/source-status command hooks | INTERACT-01, INTERACT-02, INTERACT-04 |
| `references/feedback-rules.md` | Add a canonical NL intent recognition table including scheduling, source status, feedback, preference query, history, diagnostics | INTERACT-04 |
| `references/cron-configs.md` | Expand from static job examples into profile-aware scheduling guidance and management flows | INTERACT-01 |
| `references/processing-instructions.md` | Define source-status behavior, recommendation-evidence derivation, and rolling-coverage collapse rules | INTERACT-02, INTERACT-03, INTERACT-05 |
| `references/output-templates.md` | Render structured selection evidence and collapsed same-day event blocks | INTERACT-03, INTERACT-05 |
| `references/data-models.md` | Add any new profile or evidence schema the docs depend on | INTERACT-01, INTERACT-03 |
| `references/scoring-formula.md` | Document which scoring/quota signals are legal inputs to recommendation evidence | INTERACT-03 |
| `scripts/diagnostics.sh` | Optionally extend or align output for source-status UX reuse | INTERACT-02 |

### New Files

| File | Purpose | Requirement |
|------|---------|-------------|
| `config/schedule-profiles.json` | Named scheduling profiles and concrete cron settings | INTERACT-01 |
| `data/fixtures/source-status-metrics.json` | Source-status verification fixture | INTERACT-02 |
| `data/fixtures/events-active-dense-day.json` | Dense same-day timeline fixture | INTERACT-05 |
| `data/fixtures/digest-explainability-sample.json` | Example structured evidence fixture | INTERACT-03 |

### Files Likely Not Modified

- `references/prompts/summarize.md` -- it already covers "why it matters"; this is not the same as recommendation evidence.
- `scripts/health-check.sh` -- diagnostics and source-status UX should stay distinct from automated alerting.
- `config/sources.json` structure likely stays mostly intact unless a minor profile pointer or display field is needed.

## Plan Decomposition Recommendation

### Plan 12-01: Scheduling Profiles + Centralized Intent Routing
**Requirements:** INTERACT-01, INTERACT-04

- Add a schedule profile schema and defaults in `config/`
- Expand scheduling reference docs from static examples to profile-oriented commands
- Centralize NL intent recognition in `references/feedback-rules.md`
- Slim down `SKILL.md` so it references the canonical routing table instead of duplicating trigger logic

### Plan 12-02: Source Status Command + Deterministic Recommendation Evidence
**Requirements:** INTERACT-02, INTERACT-03

- Formalize a source-status command for all-sources and per-source views
- Reuse `config/sources.json`, DailyMetrics `per_source`, and diagnostics output patterns
- Define a structured recommendation-evidence contract derived from scoring/quota state
- Update digest templates so recommendation evidence appears in a consistent, structured way

### Plan 12-03: Rolling Coverage Timeline Collapse
**Requirements:** INTERACT-05

- Add a same-day collapse algorithm for `event.timeline`
- Update Event Tracking rendering so days with more than 5 entries collapse into a compact rolling-coverage block
- Preserve raw history and digest-history compatibility
- Add dense-day fixtures and render examples

## Open Questions

None that block planning.

The only design choice to lock during planning is **where schedule profiles live**. The strongest default is repo-owned `config/schedule-profiles.json` as desired state, with `references/cron-configs.md` documenting how the agent translates that into platform `cron` commands.

## Sources

### Primary (HIGH confidence)
- `SKILL.md`
- `references/cron-configs.md`
- `references/feedback-rules.md`
- `references/processing-instructions.md`
- `references/output-templates.md`
- `references/scoring-formula.md`
- `references/data-models.md`
- `references/collection-instructions.md`
- `scripts/diagnostics.sh`
- `config/sources.json`

## Metadata

**Confidence breakdown:**
- Scheduling profile architecture: HIGH
- Source-status reuse of existing observability data: HIGH
- Deterministic explainability path: HIGH
- Rolling coverage collapse approach: HIGH

**Research date:** 2026-04-03
**Valid until:** 2026-05-03
