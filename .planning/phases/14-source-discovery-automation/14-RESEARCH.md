# Phase 14: Source Discovery Automation - Research

**Researched:** 2026-04-03
**Domain:** Provenance-backed source discovery, auto-enable and auto-disable policy, generated source configs, and auditable discovery artifacts
**Confidence:** HIGH

## Summary

Phase 14 is a provenance-consumer and source-inventory phase. Phase 13 already created the key upstream contracts this phase needs:

- authoritative provenance records keyed by `NewsItem.id`
- dedicated T1/T2 rule libraries in `config/t1-sources.json` and `config/t2-sources.json`
- citation and tier stats stores under `data/provenance/`
- a current `Source` schema and operator-facing `scripts/source-status.sh` surface

What the repo still does **not** have is any discovery state, no accumulation store for newly observed T1/T2 domains, no enable/disable evaluation contract, no generated-source audit metadata in the `Source` model, and no audit artifact that explains why a discovered domain was enabled, deferred, rejected, or disabled.

The `2026-04-03` design spec supplies the exact discovery thresholds and generated-source shape. The repo already supplies the storage and operator conventions that the phase should reuse. The cleanest way to plan this phase is as **3 plans** matching the roadmap:

- `14-01`: domain normalization, accumulation store, rolling metrics, representative evidence
- `14-02`: auto-enable and auto-disable evaluation plus generated source-config contract
- `14-03`: discovery audit artifacts, T1/T2 pattern-library expansion rules, and verification coverage

**Primary recommendation:** keep three layers distinct:

1. a dedicated discovery state under `data/provenance/`
2. the authoritative collection-source inventory in `config/sources.json`
3. the T1/T2 provenance pattern libraries in `config/t1-sources.json` and `config/t2-sources.json`

If those layers are collapsed together, the repo will lose decision history and Phase 12 operator/status behavior will become harder to reason about.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DISC-01 | Accumulate unique T1/T2 domains with rolling hit counts, last-seen dates, representative titles, and tier ratios | Phase 13 already persists `ProvenanceRecord`, `CitationGraph`, and `TierStats`. Those stores provide tier, URLs, timestamps, and source joins, but the repo still needs a domain-normalized accumulation store and a rolling-window contract. |
| DISC-02 | Auto-enable only after frequency, quality, uniqueness, age, and enabled-state checks pass | The design spec already defines concrete thresholds: `>= 5` items in 7 days, `t1_ratio >= 0.3`, at least one unique event not already covered by enabled sources, domain age `>= 3` days, and not already enabled in `config/sources.json`. The repo already has event and source schemas that can support those checks. |
| DISC-03 | Auto-discovered sources auto-disable when quality or sustained activity drops below documented thresholds | The spec defines discovery-specific disable triggers, while the repo already has generic source `status` demotion and recovery based on `quality_score`. Planning must keep those concepts separate so discovery disable does not trample the existing degraded/active model. |
| DISC-04 | Auto-enabled sources are written into `config/sources.json` with inferred type, defaults, and audit metadata | The existing `Source` model already defines stable defaults for `fetch_config`, `stats`, `enabled`, and `status`. Phase 14 mainly needs to extend that model with discovery-audit fields and specify deterministic ID and type inference rules. |

</phase_requirements>

## Architecture Patterns

### Current State Analysis

**Phase 13 created the right upstream foundation**

- `references/data-models.md` now defines:
  - `ProvenanceRecord`
  - `CitationGraph`
  - `TierStats`
- `references/processing-instructions.md` already defines the provenance stage and the rule-vs-LLM resolution path.
- `config/t1-sources.json` and `config/t2-sources.json` already exist and are intentionally separated from `config/sources.json`.

That means Phase 14 does **not** need to redesign provenance. It needs to consume it.

**The repo already has a usable source inventory model**

- `config/sources.json` is the authoritative source inventory.
- `Source` records already carry:
  - `enabled`
  - `status`
  - `weight`
  - `credibility`
  - `fetch_config`
  - rolling `stats`
- `scripts/source-status.sh` reads those fields directly and surfaces them to the operator.

This is important because Phase 14 should generate new sources in the same model shape rather than inventing a parallel source-config schema.

**There is a semantic gap between discovery state and source inventory**

The spec wants:

- rolling discovery metrics
- representative titles
- decision history
- rejected/deferred records

Those fields do **not** belong only in `config/sources.json`, because `config/sources.json` is the live source inventory, not the full discovery audit log.

**The existing source health model is similar, but not identical, to discovery disable logic**

The repo already uses:

- `status: active|paused|degraded`
- `stats.quality_score`
- `stats.degraded_since`
- `stats.recovery_streak_start`

The design spec defines new discovery-specific rules:

- disable if `t1_ratio < 0.1`
- disable after 14 days with no T1/T2 items
- disable if `hit_count < 2` for 7 consecutive days

These should not be forced into the same bucket without an explicit contract. Discovery disable is about whether a discovered direct source still deserves to remain enabled as a source candidate; existing degraded status is about operational health. Planning should keep those roles separate.

### Recommended Approach

**1. Introduce a dedicated discovery state file before touching `config/sources.json`**

Recommended primary store:

- `data/provenance/discovered-sources.json`

Recommended contents:

- normalized discovery key per domain
- canonical/root domain
- representative sample URLs
- inferred tier (`T1` or `T2`)
- `first_seen`
- `last_seen`
- rolling 7-day hit count
- rolling `t1_ratio`
- representative titles
- decision history entries such as `observed`, `deferred`, `enabled`, `disabled`, `rejected`

Optional companion store:

- `data/provenance/discovered-sources-rejected.json`

Use a companion store only if the planner wants a cleaner split between active-watchlist entries and rejected history. The main requirement is auditable decision history, not a specific file count.

**2. Use domain-level identity, but preserve path evidence**

The spec says to group subdomains to root domains, which is right for accumulation. But the T1/T2 pattern libraries are sometimes path-scoped:

- `openai.com/blog`
- `github.com/*/releases`
- `venturebeat.com/ai`

Recommended rule:

- use the registrable/root domain as the discovery identity for counting and enable/disable evaluation
- also persist representative URLs or path samples so pattern-library expansion can remain precise instead of over-broad

Without that second piece, discovery will overfit root domains and pollute the T1/T2 libraries.

**3. Keep discovery evaluation separate from source health status**

Recommended semantics:

- `enabled`: whether the source participates in collection
- `status`: operational health (`active`, `degraded`, `paused`)
- discovery decision history: why a source was enabled, deferred, rejected, or disabled

For discovered-source auto-disable, prefer:

- set `enabled: false`
- keep or derive a discovery audit reason in dedicated metadata
- do **not** invent a new `status` enum unless the whole operator surface is updated to understand it

This preserves compatibility with Phase 12 source-status behavior.

**4. Reuse the current `Source` shape for generated entries**

Auto-generated source entries should reuse the existing `Source` model defaults:

- `weight: 1.0`
- `credibility: 0.9`
- default `stats` block
- `status: "active"`

Then add discovery metadata rather than replacing the model. Recommended new fields or documented extensions:

- `auto_discovered: true`
- `auto_discovered_at`
- `discovery_domain`
- `discovery_tier`
- `discovery_decision`
- `discovery_decided_at`

The planner can refine exact field names, but the model needs enough metadata to explain why the source exists and what last happened to it.

**5. Compute uniqueness from event coverage, not raw title uniqueness**

The spec's uniqueness gate depends on whether a discovered source covers an event not already covered by enabled sources. That means the enable evaluator needs:

- `NewsItem.event_id`
- join from `NewsItem.id` to `ProvenanceRecord`
- the set of currently enabled sources in `config/sources.json`

Recommended check:

- find events where the candidate discovered domain has at least one T1/T2 item
- confirm at least one of those events is not already represented by any enabled source

This is more faithful than checking title novelty or URL novelty alone.

**6. Pattern-library expansion should follow enable decisions, not just observation**

Phase 13 intentionally separated provenance rule libraries from `config/sources.json`. Phase 14 should extend them only when there is strong evidence:

- source is enabled or promoted to a trusted discovered candidate
- tier is stable enough to justify library growth
- representative URLs preserve the path patterns needed for precise matching

This keeps `config/t1-sources.json` and `config/t2-sources.json` additive without turning them into noisy raw-observation dumps.

## Validation Architecture

This repo is still a prompt/config/reference-doc project with helper scripts, not an application with a formal automated test runner. Validation for Phase 14 should therefore stay fixture-backed, grep-verifiable, and script-readable.

### Recommended verification shape

**Discovery state**

- verify `references/data-models.md` defines the discovery state schema and any new `Source` discovery metadata fields
- verify fixtures show rolling counts, last-seen, representative titles, and decision history
- verify discovery identity and representative URL/path samples coexist

**Enable/disable thresholds**

- verify `references/processing-instructions.md` contains the exact Phase 14 thresholds:
  - frequency `>= 5`
  - `t1_ratio >= 0.3`
  - uniqueness via uncovered event
  - age `>= 3` days
  - disable on `t1_ratio < 0.1`
  - disable on 14 days with 0 T1/T2 items
  - disable on `hit_count < 2` for 7 days

**Generated source contract**

- verify docs or fixtures show a generated `Source` entry with:
  - `id: src-auto-*`
  - inferred `type`
  - discovery metadata
  - default `stats`
  - `enabled: true`
  - `status: active`

**Auditability**

- verify a reader can see why a domain was:
  - observed but not enabled yet
  - enabled
  - rejected
  - later disabled

### Suggested fixture additions

- `data/fixtures/discovered-sources-sample.json`
- `data/fixtures/discovered-sources-rejected-sample.json`
- `data/fixtures/source-config-auto-discovered-sample.json`
- `data/fixtures/source-discovery-audit-sample.md`

Those fixtures should include at least:

- one domain that is accumulating but still below threshold
- one domain that auto-enables because all gates pass
- one domain that is rejected or deferred with an explicit reason
- one auto-enabled domain that later auto-disables because rolling thresholds fail

### Anti-Shallow Validation Rule

Do not accept simple heading presence or file existence as proof. Every Phase 14 task should verify exact thresholds, exact metadata fields, or exact decision-history records that prove the discovery loop is explainable.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Discovery audit trail | Hide all discovery decisions inside `config/sources.json` | A dedicated `data/provenance/discovered-sources.json` state plus source writeback rules | Keeps live inventory separate from decision history |
| Discovery identity | Use full URLs as discovered-source keys | Root-domain identity plus representative URL/path evidence | Prevents fragmentation while preserving path-sensitive rule expansion |
| Generated source shape | A second source schema just for discovered entries | The existing `Source` model with additive discovery metadata | Keeps source-status and inventory tooling compatible |
| Uniqueness gate | Title uniqueness or URL uniqueness | Event coverage via `event_id` joins | Matches the actual requirement and avoids false positives |
| Auto-disable | Reuse `status` for every discovery outcome | Keep `enabled` and discovery decision history separate from operational `status` | Preserves Phase 12 source health semantics |
| Pattern-library growth | Add every seen domain immediately to `t1`/`t2` files | Expand rule libraries only after enable-quality evidence exists | Keeps provenance rules precise and auditable |

## Common Pitfalls

### Pitfall 1: Using `config/sources.json` as both the inventory and the audit log
**What goes wrong:** Deferred, rejected, and later-disabled domains disappear from view once the live source list changes.
**How to avoid:** Keep dedicated discovery state under `data/provenance/` and write summary decisions into source metadata only after evaluation.

### Pitfall 2: Collapsing path-scoped evidence to bare root domains
**What goes wrong:** A source like `openai.com/blog` becomes indistinguishable from any other `openai.com` path, which makes rule-library expansion too broad.
**How to avoid:** Count by normalized/root domain but retain representative URLs or path samples alongside it.

### Pitfall 3: Treating `status` and `enabled` as the same signal
**What goes wrong:** Discovery disable overwrites the existing degraded/active operator model and breaks source-status meaning.
**How to avoid:** Use `enabled` plus discovery metadata for discovery gating; reserve `status` for operational health.

### Pitfall 4: Reusing `quality_score` as a proxy for `t1_ratio`
**What goes wrong:** The repo's current rolling source quality score is not the same metric as provenance-tier quality.
**How to avoid:** Track `t1_ratio` explicitly in discovery state and document how it is computed.

### Pitfall 5: Evaluating uniqueness without event coverage
**What goes wrong:** A source can look "new" by URL while still duplicating events already covered by enabled sources.
**How to avoid:** Base uniqueness on uncovered `event_id` coverage instead of raw title or URL novelty.

### Pitfall 6: Auto-expanding T1/T2 pattern libraries from a single noisy observation
**What goes wrong:** Provenance libraries become polluted and Phase 13 URL-rule precision falls.
**How to avoid:** Tie pattern-library expansion to successful source enable or equivalent high-confidence discovery evidence.

## Interaction with Existing Files

### Files to Modify

| File | Change | Requirement |
|------|--------|-------------|
| `references/data-models.md` | Add discovery state schema and extend `Source` model notes with discovery metadata | DISC-01, DISC-04 |
| `references/processing-instructions.md` | Define accumulation, normalization, rolling thresholds, enable/disable rules, and pattern-library expansion flow | DISC-01, DISC-02, DISC-03, DISC-04 |
| `SKILL.md` | Add source-discovery responsibilities at the right phase boundary in the pipeline | DISC-01, DISC-02 |
| `config/sources.json` | Potentially document or fixture-align the generated-source defaults the discovery loop writes | DISC-04 |
| `scripts/source-status.sh` | Optionally expose auto-discovered metadata or reasons if Phase 14 wants operator-visible discovery state | DISC-03, DISC-04 |

### New Files

| File | Purpose | Requirement |
|------|---------|-------------|
| `data/fixtures/discovered-sources-sample.json` | Example discovery accumulation store with rolling metrics and decision history | DISC-01 |
| `data/fixtures/discovered-sources-rejected-sample.json` | Example rejected/deferred records with explicit reasons | DISC-03 |
| `data/fixtures/source-config-auto-discovered-sample.json` | Generated `Source` entry example with discovery metadata | DISC-04 |
| `data/fixtures/source-discovery-audit-sample.md` | Human-readable audit artifact showing enable and disable reasoning | DISC-02, DISC-03 |

### Files Likely Not Modified

- `references/scoring-formula.md` - provenance-aware ranking is Phase 15 work
- `references/output-templates.md` - digest and report rendering remain Phase 15 work
- `references/prompts/provenance-classify.md` - Phase 13 already defined provenance classification; Phase 14 consumes its output
- `scripts/diagnostics.sh` - only touch if the planner decides discovery audit needs to appear in an existing diagnostics surface

## Plan Decomposition Recommendation

### Plan 14-01: Domain Normalization, Discovery Accumulation, and Rolling Metrics
**Requirements:** DISC-01

- define the discovery identity and representative-URL contract
- add the discovery state schema and fixture examples
- document rolling hit counts, `first_seen`, `last_seen`, representative titles, and `t1_ratio`
- keep discovery state separate from the live source inventory

### Plan 14-02: Auto-Enable, Auto-Disable, and Generated Source Configs
**Requirements:** DISC-02, DISC-03, DISC-04

- encode the exact enable and disable thresholds
- define how uniqueness joins provenance to event coverage
- define deterministic generated-source IDs, type inference, defaults, and discovery metadata
- specify how `config/sources.json` is updated without breaking existing source-status semantics

### Plan 14-03: Discovery Audit Artifacts, Pattern-Library Expansion, and Verification Coverage
**Requirements:** DISC-01, DISC-02, DISC-03, DISC-04

- add audit artifacts and fixtures that prove enable, defer, reject, and disable outcomes
- define when discovery results can extend `config/t1-sources.json` and `config/t2-sources.json`
- add concrete verification commands and fixture-backed checks for the whole discovery loop

## Open Questions

None that block planning.

The only design choice that remains open is whether rejected/deferred discovery records should live inside `discovered-sources.json` or in a companion `discovered-sources-rejected.json`. Either is acceptable if the final plan preserves explicit reasons and does not lose history.

## Sources

### Primary (HIGH confidence)
- `C:\Users\sorawatcher\.claude\plugins\cache\claude-plugins-official\superpowers\5.0.6\skills\brainstorming\docs\superpowers\specs\2026-04-03-news-digest-provenance-source-discovery-design.md`
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/PROJECT.md`
- `.planning/phases/13-provenance-core/13-RESEARCH.md`
- `.planning/phases/13-provenance-core/13-VERIFICATION.md`
- `.planning/phases/14-source-discovery-automation/14-CONTEXT.md`
- `references/data-models.md`
- `references/processing-instructions.md`
- `SKILL.md`
- `config/sources.json`
- `config/t1-sources.json`
- `config/t2-sources.json`
- `scripts/source-status.sh`

## Metadata

**Confidence breakdown:**
- discovery-state separation from source inventory: HIGH
- enable/disable threshold translation: HIGH
- keep `enabled` distinct from `status`: HIGH
- event-based uniqueness check: HIGH
- pattern-library expansion after enable evidence: HIGH

**Research date:** 2026-04-03
**Valid until:** 2026-05-03
