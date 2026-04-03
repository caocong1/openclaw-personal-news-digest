# Phase 13: Provenance Core - Research

**Researched:** 2026-04-03
**Domain:** Tier-aware provenance classification, citation extraction, provenance persistence, and expandable direct-source libraries
**Confidence:** HIGH

## Summary

Phase 13 is a pipeline-core and data-contract phase. The repo already has the right primitives for it:

- deterministic `NewsItem.id` values derived from normalized URLs
- daily JSONL storage for collected items
- clear collection and processing references
- schema-versioning rules and atomic-write patterns
- existing prompt/batch patterns for structured LLM work

What the repo does not have yet is a dedicated provenance layer between collection and the existing classification/summarization flow. There are no T1/T2 rule libraries, no provenance prompt contract, no provenance persistence under `data/provenance/`, and no documented rule for resolving URL-rule vs LLM disagreements.

The 2026-04-03 provenance/source-discovery spec provides the target architecture, but the live roadmap narrows Phase 13 to the **core** layer only. That means this phase should stop at:

1. dedicated T1/T2 pattern libraries and URL-rule preclassification
2. heuristic citation extraction from fetched content snippets
3. batched provenance classification for unresolved items
4. deterministic cross-validation and discrepancy logging
5. persistent provenance records keyed by `NewsItem.id`
6. repo-owned schemas, prompts, docs, and fixtures that make Phase 14 source discovery possible without redesign

The spec's internal phase numbering does not match the current roadmap. Use the roadmap's `Phase 13` numbering as canonical for all repo artifacts.

**Primary recommendation:** implement Phase 13 as **3 plans**:
- 13-01: T1/T2 pattern libraries, URL-rule preclassification, and provenance data contracts
- 13-02: Citation extraction, batched provenance classification, and prompt/pipeline wiring
- 13-03: Cross-validation, discrepancy logging, persistence, and verification fixtures

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROV-01 | Every collected news item can be classified into T0/T1/T2/T3/T4 with a confidence score and classification source | The spec defines a five-tier model plus `tier_confidence` and `tier_source`. The repo already has stable item IDs and batch-processing patterns, so provenance records can be keyed by `NewsItem.id` without changing collection identity semantics. |
| PROV-02 | URL-rule preclassification identifies known T1/T2 domains from dedicated pattern libraries without an LLM call | The cleanest implementation is separate `config/t1-sources.json` and `config/t2-sources.json` files. `config/sources.json` is collection config, not a provenance rule library, so overloading it would mix concerns and make later discovery updates brittle. |
| PROV-03 | Citation extraction captures cited URLs or named upstream sources from article content before provenance classification | `content_snippet` already exists for fetched items, and collection docs already preserve plain text or stripped markup. That is enough to support heuristic citation extraction before any LLM provenance call. |
| PROV-04 | Batched provenance classification can infer original source URL/name, cited sources, and propagation hops for items not conclusively resolved by rules | Existing classify/summarize flows already establish the repo's preferred pattern: structured prompt file, 5-10 item batching, retry-once semantics, and JSON output parsing. Provenance classification should reuse that operating model rather than inventing a one-off execution path. |
| PROV-05 | Cross-validation resolves rule-vs-LLM disagreements, logs discrepancies, and preserves why the final tier won | The spec already provides the precedence rule: URL-rule wins for T1, LLM wins for T0 and T2-T4. The repo lacks an auditable discrepancy store today, so this phase should add append-only discrepancy logging under `data/provenance/`. |
| PROV-06 | Provenance results persist to `data/provenance/` stores that can reconstruct the delivered item's provenance chain later | The roadmap success criteria explicitly call for `provenance-db`, `citation-graph`, `tier-stats`, and discrepancy logs. The existing repo is file-backed and schema-driven, so JSON/JSONL stores are the right fit. |
| DISC-05 | T1/T2 source libraries in dedicated config files can grow as new direct sources are discovered | Phase 13 does not need to auto-enable sources yet, but it does need additive, dedicated pattern-library files with category metadata so Phase 14 can extend them without editing `config/sources.json` by hand. |
</phase_requirements>

## Architecture Patterns

### Current State Analysis

**Identity and storage**

- `references/collection-instructions.md` already defines deterministic URL normalization and `SHA256(normalized_url)[:16]` item IDs.
- `references/data-models.md` already treats `NewsItem.id` as the stable identity across dedup and cache flows.
- This makes `NewsItem.id` the natural primary key for provenance persistence. A separate provenance store keyed by item ID is compatible with the current repo and minimizes schema churn.

**Pipeline shape**

- `SKILL.md` currently runs `Collection -> Processing -> Output`.
- The provenance spec introduces a new `Provenance` stage between collection and the existing classify/summarize processing path.
- Phase 13 therefore needs pipeline wiring in docs and contracts, not just data models.

**Collection inputs already exist**

- Collected items already contain:
  - `normalized_url`
  - `content_snippet`
  - `source_id`
  - timestamps and stable IDs
- That is sufficient for:
  - rule-based T1/T2 matching
  - citation extraction from snippet text
  - batched provenance inference for unresolved items

**Current schema gap**

- `NewsItem` v5 has no provenance fields.
- No provenance-specific config files exist.
- No `data/provenance/` directory or documented store exists.
- No provenance prompt file exists under `references/prompts/`.

**Existing execution conventions should be reused**

- The repo already standardizes:
  - prompt files in `references/prompts/`
  - batch LLM work documented in `references/processing-instructions.md`
  - retry-once behavior
  - atomic writes
  - schema registries and fixture-backed validation
- Provenance should plug into those same conventions.

**Phase boundary matters**

- The milestone spec also describes:
  - discovered-source accumulation and auto-enable/auto-disable
  - provenance-aware scoring and aggregator decay
  - provenance-aware output rendering
- Those are roadmap Phases 14 and 15. If Phase 13 tries to absorb them, planning will sprawl and verification will get muddy.

### Recommended Approach

**1. Make provenance a first-class pipeline phase**

Insert a documented Provenance phase between collection and the current classify/summarize processing steps.

Recommended high-level flow:

1. load today's collected items lacking provenance records
2. apply T1/T2 URL-rule preclassification
3. extract cited URLs and named upstream sources from `content_snippet`
4. batch unresolved or low-confidence items through `references/prompts/provenance-classify.md`
5. cross-validate rule and LLM outputs
6. persist provenance artifacts under `data/provenance/`

**2. Keep authoritative provenance outside `NewsItem` for this phase**

Recommended authoritative store:

- `data/provenance/provenance-db.json` keyed by `NewsItem.id`

Recommended reason:

- avoids immediate schema expansion across all existing readers
- preserves backward compatibility with current JSONL consumers
- gives later phases a stable join key (`item.id`) for ranking and rendering

If Phase 15 later needs lightweight inline fields for ergonomics, it can add them as a derived cache or projection without invalidating Phase 13 data.

**3. Use dedicated T1/T2 libraries, not `config/sources.json`**

Create:

- `config/t1-sources.json`
- `config/t2-sources.json`

Recommended shape:

- category-grouped pattern libraries
- exact/wildcard/subdomain match semantics
- optional priority/category metadata

This satisfies `DISC-05` without prematurely implementing the Phase 14 discovery loop.

**4. Heuristic citation extraction should run before any provenance LLM call**

Recommended extraction sources:

- normalized URLs in snippet text
- HTML anchor tags still present in fetched snippets
- named upstream source phrases in article text
- explicit markers such as "original link", "according to", "press release", or equivalent Chinese phrasing

Recommended rule:

- citation extraction is deterministic and non-LLM
- LLM provenance classification consumes the extracted citations as additional context

**5. Resolve disagreements with a fixed precedence rule**

Use the spec's precedence without reinterpretation:

- T1: URL-rule wins
- T0: LLM wins
- T2/T3/T4: LLM wins

Every disagreement should append a record to `data/provenance/provenance-discrepancies.jsonl` containing at least:

- timestamp
- item ID
- URL
- rule result
- rule category
- LLM result
- final tier
- final winner

**6. Persist only the Phase 13 stores the roadmap requires**

Phase 13 should create and document:

- `data/provenance/provenance-db.json`
- `data/provenance/citation-graph.json`
- `data/provenance/tier-stats.json`
- `data/provenance/provenance-discrepancies.jsonl`

Phase 13 should **not** auto-generate or auto-enable new sources in `config/sources.json`. That is Phase 14 work.

**7. Reuse current budget and batching conventions unless the roadmap changes them explicitly**

The source-of-truth spec says budget is not a constraint for this domain, but the live repo still has:

- `config/budget.json`
- circuit-breaker docs
- standing-order budget escalation

Phase 13 should therefore reuse the repo's existing batch and retry patterns rather than silently removing budget controls as incidental scope.

## Validation Architecture

This repo is still a prompt/config/reference-doc skill project with a few helper scripts, not a conventional application with an automated test suite. Validation for Phase 13 should therefore be schema-driven, fixture-backed, and grep/script based.

### Recommended verification shape

**Pattern libraries**

- verify `config/t1-sources.json` and `config/t2-sources.json` are valid JSON
- verify they contain category metadata plus concrete pattern lists
- verify official-domain examples and original-report examples both exist

**Pipeline contracts**

- verify `SKILL.md` and `references/processing-instructions.md` both describe a provenance phase before the existing classification/summarization flow
- verify docs explicitly say citation extraction runs before provenance LLM classification
- verify docs explicitly encode the T1 URL-rule precedence and T2-T4 LLM precedence

**Prompt contract**

- verify `references/prompts/provenance-classify.md` exists
- verify it requests:
  - tier
  - confidence
  - original source name/url
  - cited sources
  - propagation hops
- verify output shape is structured JSON and batch-safe

**Persistence**

- verify `references/data-models.md` documents all `data/provenance/*` stores
- verify schema registries and new-fields notes stay consistent with any model additions
- verify fixture examples prove a provenance chain can be reconstructed for at least one direct-source and one aggregator item

**Discrepancy logging**

- verify docs and fixtures show a disagreement record with both rule and LLM results plus the final winner

### Suggested fixture additions

- `data/fixtures/news-items-provenance-sample.jsonl`
- `data/fixtures/provenance-db-sample.json`
- `data/fixtures/citation-graph-sample.json`
- `data/fixtures/provenance-discrepancies-sample.jsonl`
- `data/fixtures/tier-stats-sample.json`

These fixtures should include at least:

- one T1 official-domain item resolved entirely by URL rules
- one T2 original-report item resolved by rule or LLM
- one T4 aggregator item whose citations point back to a higher-tier origin
- one rule-vs-LLM disagreement case that demonstrates the precedence policy

### Anti-Shallow Validation Rule

Do not treat file existence or heading presence as sufficient verification. Every plan should verify exact fields, precedence rules, or concrete example records that prove the provenance contract is executable and auditable.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Direct-source library | Embed T1/T2 patterns inside `config/sources.json` | Dedicated `config/t1-sources.json` and `config/t2-sources.json` | Keeps collection config separate from provenance rule libraries and supports later discovery growth |
| Provenance identity | A second item identifier or ad hoc provenance key | Existing `NewsItem.id` / normalized URL hash | Avoids cross-file join drift and reuses the repo's stable identity model |
| Citation discovery | LLM-only citation extraction | Deterministic snippet parsing first, LLM only for unresolved provenance classification | Saves calls and preserves auditable extraction behavior |
| Cross-validation | Case-by-case judgment buried in prose | Fixed precedence rule plus discrepancy log | Makes disagreements explainable and testable |
| Discovery loop | Auto-enable or auto-disable source configs in Phase 13 | Defer source enable/disable automation to Phase 14 | Keeps the core phase bounded to provenance capture and persistence |
| Ranking/rendering | Provenance-aware scoring and digest UI updates in this phase | Defer to Phase 15 after provenance data exists | Avoids mixing data-foundation work with downstream consumption |

## Common Pitfalls

### Pitfall 1: Treating `source_id` as a provenance tier signal
**What goes wrong:** The current source config describes how an item was fetched, not what the item's true tier is in the propagation chain.
**How to avoid:** Derive provenance from URL rules, citations, and provenance classification; do not infer tier from `source_id` alone.

### Pitfall 2: Sending every item through the provenance LLM
**What goes wrong:** Official and clearly-known direct domains burn unnecessary LLM calls and still risk being under-classified.
**How to avoid:** Make URL-rule preclassification the first gate and only batch unresolved or low-confidence items.

### Pitfall 3: Expanding `NewsItem` too aggressively in Phase 13
**What goes wrong:** Existing readers, fixtures, and schema registries all need coordinated changes before the provenance foundation even exists.
**How to avoid:** Keep the authoritative provenance chain in `data/provenance/provenance-db.json` keyed by item ID; add inline fields later only if justified.

### Pitfall 4: Mixing source discovery automation into the core provenance phase
**What goes wrong:** Planning scope drifts into auto-enable criteria, source config generation, and aggregator decay before the base provenance data is stable.
**How to avoid:** Limit Phase 13 to classification, persistence, discrepancy logging, and extensible pattern libraries.

### Pitfall 5: Logging only the final tier and losing the disagreement reason
**What goes wrong:** The system cannot explain why a T1 rule beat a T2 LLM result or vice versa.
**How to avoid:** Persist both candidate results and the final winner in discrepancy logs or provenance records.

### Pitfall 6: Silently dropping the repo's budget/circuit-breaker behavior because the spec mentions unlimited budget
**What goes wrong:** Phase 13 changes global runtime behavior without an explicit roadmap requirement or verification plan.
**How to avoid:** Reuse the repo's current batching and retry conventions unless a later roadmap phase explicitly removes budget controls.

## Interaction with Existing Files

### Files to Modify

| File | Change | Requirement |
|------|--------|-------------|
| `SKILL.md` | Add the provenance phase to the documented pipeline and bootstrap any required provenance directories | PROV-01, PROV-04, PROV-06 |
| `references/processing-instructions.md` | Define provenance-stage order, citation extraction rules, batch classification contract, and cross-validation precedence | PROV-01, PROV-03, PROV-04, PROV-05 |
| `references/data-models.md` | Document provenance stores and any schema additions or registry updates | PROV-01, PROV-05, PROV-06 |
| `references/collection-instructions.md` | Clarify any provenance-relevant collection guarantees around `content_snippet` and normalized URLs if needed | PROV-02, PROV-03 |

### New Files

| File | Purpose | Requirement |
|------|---------|-------------|
| `config/t1-sources.json` | T1 official/direct-source pattern library | PROV-02, DISC-05 |
| `config/t2-sources.json` | T2 original-report pattern library | PROV-02, DISC-05 |
| `references/prompts/provenance-classify.md` | Structured provenance-classification prompt | PROV-04 |
| `data/fixtures/news-items-provenance-sample.jsonl` | Sample items for provenance verification | PROV-01, PROV-03, PROV-04 |
| `data/fixtures/provenance-db-sample.json` | Example authoritative provenance store | PROV-01, PROV-06 |
| `data/fixtures/citation-graph-sample.json` | Example citation graph with node/edge semantics | PROV-03, PROV-06 |
| `data/fixtures/provenance-discrepancies-sample.jsonl` | Example discrepancy log records | PROV-05 |
| `data/fixtures/tier-stats-sample.json` | Example tier distribution store | PROV-06 |

### Files Likely Not Modified

- `references/scoring-formula.md` - provenance-aware ranking is Phase 15 work
- `references/output-templates.md` - provenance rendering is Phase 15 work
- `references/prompts/summarize.md` - provenance classification needs its own prompt, not summarize prompt changes
- `config/sources.json` - this phase should not yet auto-enable new sources or redefine the collection-source schema

## Plan Decomposition Recommendation

### Plan 13-01: Pattern Libraries, URL Rules, and Provenance Data Contracts
**Requirements:** PROV-01, PROV-02, DISC-05

- Add dedicated `config/t1-sources.json` and `config/t2-sources.json`
- Document matching semantics and priority handling
- Add `data/provenance/` stores and schema/docs for authoritative provenance persistence keyed by item ID
- Wire the pipeline docs so provenance becomes a first-class stage

### Plan 13-02: Citation Extraction, Batched Provenance Classification, and Prompt Contracts
**Requirements:** PROV-03, PROV-04

- Define deterministic citation extraction from `content_snippet`
- Add `references/prompts/provenance-classify.md` with structured JSON output
- Document batch routing and unresolved-item handling in the provenance stage
- Add fixtures that prove citation-derived context feeds into provenance classification

### Plan 13-03: Cross-Validation, Discrepancy Logging, Persistence, and Verification Fixtures
**Requirements:** PROV-05, PROV-06

- Encode the rule-vs-LLM precedence policy
- Persist discrepancies and winning decisions
- Define `citation-graph`, `tier-stats`, and `provenance-db` contracts
- Add verification fixtures and explicit acceptance checks for auditability and chain reconstruction

## Open Questions

None that block planning.

The only optional follow-on decision is whether a later phase should add lightweight provenance projection fields directly onto `NewsItem`. The strongest default for Phase 13 is to keep the authoritative chain in `data/provenance/provenance-db.json` and join by item ID.

## Sources

### Primary (HIGH confidence)
- `SKILL.md`
- `references/collection-instructions.md`
- `references/processing-instructions.md`
- `references/data-models.md`
- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/PROJECT.md`
- `C:\Users\sorawatcher\.claude\plugins\cache\claude-plugins-official\superpowers\5.0.6\skills\brainstorming\docs\superpowers\specs\2026-04-03-news-digest-provenance-source-discovery-design.md`

## Metadata

**Confidence breakdown:**
- T1/T2 library approach: HIGH
- Provenance-stage pipeline insertion: HIGH
- Separate provenance store keyed by item ID: HIGH
- Phase boundary vs source discovery and scoring/output: HIGH

**Research date:** 2026-04-03
**Valid until:** 2026-05-03
