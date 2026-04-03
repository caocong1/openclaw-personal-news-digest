# Phase 14: Source Discovery Automation - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning
**Source:** Repo state plus `C:\Users\sorawatcher\.claude\plugins\cache\claude-plugins-official\superpowers\5.0.6\skills\brainstorming\docs\superpowers\specs\2026-04-03-news-digest-provenance-source-discovery-design.md`

<domain>
## Phase Boundary

Phase 14 turns the provenance artifacts introduced in Phase 13 into a persistent, auditable source-discovery loop. The phase must:

- accumulate normalized T1/T2 domains from provenance output into a durable discovery store
- maintain rolling discovery metrics, representative evidence, and decision history per discovered domain
- evaluate auto-enable and auto-disable criteria without a manual approval step
- generate or update direct-source entries in `config/sources.json` when a discovered source qualifies
- define how newly qualified sources expand `config/t1-sources.json` and `config/t2-sources.json`
- add verification and audit artifacts that prove discovery decisions are explainable and reproducible

This phase is downstream of the Phase 13 provenance contracts and upstream of provenance-aware scoring, alerting, and output rendering. Do not pull ranking, alert-threshold, aggregator-decay scoring, or digest rendering changes into Phase 14 unless they are strictly needed to support discovery-state auditability.

</domain>

<decisions>
## Implementation Decisions

### Discovery inputs
- Discovery operates on Phase 13 provenance output, especially `data/provenance/provenance-db.json`, `data/provenance/citation-graph.json`, and `data/provenance/tier-stats.json`.
- Only T1/T2 domains discovered through provenance should enter the source-discovery accumulation flow.
- Domain normalization and deduplication must consolidate equivalent variants before counting hits or evaluating enable/disable status.

### Auto-enable policy
- Auto-enable is fully automated; there is no manual review workflow in steady state.
- A discovered source is enabled only when all checks pass:
  - frequency: at least 5 T1/T2 items in the rolling 7-day window
  - quality: `t1_ratio >= 0.3`
  - uniqueness: at least 1 item covers an event not covered by any currently enabled source
  - enabled-state: the domain is not already enabled in `config/sources.json`
  - age: the domain has been seen for at least 3 days

### Auto-disable policy
- Auto-discovered sources auto-disable when any documented rolling threshold is breached:
  - 7-day rolling `t1_ratio < 0.1`
  - 14 consecutive days with 0 T1/T2 items
  - `hit_count < 2` for 7 consecutive days

### Generated source-config contract
- Auto-enabled sources are written into `config/sources.json` with inferred type, defaults, and audit metadata.
- Generated source entries include:
  - `id: src-auto-{hash(domain)}`
  - inferred `name`, `type`, `url`, `topics`
  - `weight: 1.0`
  - `credibility: 0.9`
  - `enabled: true`
  - `auto_discovered: true`
  - `auto_discovered_at: ISO8601`
  - default `fetch_config`
  - default `stats`
  - `status: active`
- Type inference rules:
  - GitHub release URLs -> `github`
  - RSS-like endpoints -> `rss`
  - policy or official-domain matches -> `official`
  - otherwise default to `official` with browser-friendly fetch defaults

### Pattern-library growth
- Phase 13 already created dedicated `config/t1-sources.json` and `config/t2-sources.json`; Phase 14 may extend those libraries as new direct sources are discovered.
- Pattern-library expansion stays automated and auditable; it must not depend on a separate human source-review workflow.

### Phase boundary protections
- Provenance-aware ranking, aggregator decay scoring, alert threshold changes, and weekly source-discovery report rendering remain downstream work.
- Historical provenance backfill, governance UI, and cross-platform discovery remain out of scope.

### the agent's Discretion
- Exact schema details for discovery decision history, rejection records, and representative-title retention limits
- Whether enable/disable evaluations live in one script or multiple focused scripts
- How to encode audit fixtures and verification commands as long as thresholds and outputs remain concrete and grep-verifiable

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap and requirement source of truth
- `.planning/ROADMAP.md` - canonical Phase 14 goal, plan decomposition, and success criteria
- `.planning/REQUIREMENTS.md` - `DISC-01` through `DISC-04` acceptance targets and traceability
- `.planning/STATE.md` - current milestone state and active phase target
- `.planning/PROJECT.md` - current repo scope, constraints, and v3.0 decisions

### Provenance foundation from Phase 13
- `.planning/phases/13-provenance-core/13-RESEARCH.md` - what Phase 13 intentionally deferred into discovery automation
- `.planning/phases/13-provenance-core/13-VERIFICATION.md` - verified provenance contracts and storage guarantees now available to build on
- `references/data-models.md` - authoritative schemas for `Source`, `ProvenanceRecord`, `CitationGraph`, and `TierStats`
- `references/processing-instructions.md` - current provenance-stage behavior and source-status/demotion conventions that discovery logic must align with
- `SKILL.md` - current pipeline ordering and operator command surface

### Discovery-specific design source
- `C:\Users\sorawatcher\.claude\plugins\cache\claude-plugins-official\superpowers\5.0.6\skills\brainstorming\docs\superpowers\specs\2026-04-03-news-digest-provenance-source-discovery-design.md` - Section 4 source-discovery engine, Section 7 file inventory, and the explicit enable/disable thresholds

### Existing source inventory and extension points
- `config/sources.json` - current source schema and enable/disable state that auto-generated entries must respect
- `config/t1-sources.json` - dedicated T1 direct-source pattern library that Phase 14 may expand
- `config/t2-sources.json` - dedicated T2 original-report pattern library that Phase 14 may expand
- `scripts/source-status.sh` - existing operator-facing source-state surface that discovery artifacts should complement rather than bypass

</canonical_refs>

<specifics>
## Specific Ideas

- `data/provenance/discovered-sources.json` should become the durable accumulation store with normalized domain, tier, first_seen, last_seen, rolling hit counts, tier ratios, representative titles, and decision history.
- Discovery decisions should remain auditable through explicit status fields and reason strings rather than implicit changes to `config/sources.json`.
- Plan decomposition from the roadmap is already clear and should stay at three plans:
  - normalization plus accumulation
  - auto-enable/auto-disable plus source-config generation
  - audit artifacts, rule-library expansion, and verification coverage

</specifics>

<deferred>
## Deferred Ideas

- Aggregator decay scoring and provenance-aware ranking changes
- Digest or alert rendering updates based on provenance/discovery state
- Weekly source-discovery report delivery output
- Manual approval workflows or governance UI
- Historical provenance backfill and cross-platform discovery

</deferred>

---

*Phase: 14-source-discovery-automation*
*Context gathered: 2026-04-03 via repo state and milestone design spec*
