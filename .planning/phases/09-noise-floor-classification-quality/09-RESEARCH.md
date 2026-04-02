# Phase 9: Noise Floor & Classification Quality - Research

**Researched:** 2026-04-02
**Domain:** LLM prompt engineering, noise filtering patterns, classification quality for news pipelines
**Confidence:** HIGH

## Summary

Phase 9 addresses two related problems in the news-digest pipeline: (1) low-value items consuming LLM budget unnecessarily, and (2) classification accuracy gaps, particularly at the low end of the importance spectrum (0.0-0.2) and for ambiguous category boundaries.

The noise filtering work splits into two stages: **pre-classify** (regex/pattern matching before any LLM call, saving budget entirely) and **post-classify** (importance threshold filtering after LLM classification, preventing low-value items from entering the scoring pool). Both stages must preserve items in JSONL history for queryability while marking them as ineligible for digest output. The classification work enhances the existing `classify.md` prompt with better calibration at the low end, negative examples per category, and disambiguation rules for frequently confused category pairs.

This is a pure document-editing phase. All changes are to Markdown prompts, JSON configs, and JSON data model definitions. No runtime code is involved -- the OpenClaw agent interprets these documents as instructions. The scope is well-constrained by the existing architecture and data models established in prior phases.

**Primary recommendation:** Implement in 3 plans: (1) source schema + pre-classify noise filter + SKILL.md pipeline integration, (2) post-classify filter + digest_eligible field + metrics tracking, (3) classification prompt hardening + cache version bump + fixture updates.

## Standard Stack

This phase involves no external libraries or packages. All work is editing existing Markdown, JSON, and JSONL files within the OpenClaw Skill framework.

### Core Files to Modify

| File | Purpose | Change Type |
|------|---------|-------------|
| `config/sources.json` | Source definitions | Add `noise_patterns` and `title_discard_patterns` to `fetch_config` |
| `references/data-models.md` | Schema definitions | Add `digest_eligible` field to NewsItem, `noise_filter_suppressed` to DailyMetrics |
| `references/processing-instructions.md` | Pipeline logic | Add pre-classify and post-classify filter sections |
| `SKILL.md` | Pipeline orchestration | Insert noise filter steps into Collection/Processing phases |
| `references/prompts/classify.md` | Classification prompt | Add 0.0-0.2 tier, negative examples, disambiguation rules |
| `config/categories.json` | Category definitions | Add `negative_examples` field per category |
| `data/fixtures/` | Test fixtures | Add noise filter and low-importance fixture scenarios |

## Architecture Patterns

### Recommended Noise Filter Architecture

The noise filter operates as a two-stage funnel injected into the existing pipeline:

```
Collection Phase:
  Step 7 (Write items) -> [NEW] Step 7.5: Pre-Classify Noise Filter
  
Processing Phase:
  Step 3 (Classify batch) -> [NEW] Step 3.5: Post-Classify Importance Filter
```

### Pattern 1: Pre-Classify Noise Filter (NOISE-01, NOISE-04)

**What:** Before items reach the LLM classify call, apply regex-based pattern matching against configurable per-source patterns. Items that match are marked as noise and skipped from LLM processing entirely.

**When to use:** After items are written to JSONL (so they exist in history) but before the classify LLM call.

**Where in pipeline:** Between Collection Phase step 7 (write items) and Processing Phase step 3 (classify batch). More precisely, during the "Collect unprocessed" step (Processing Phase step 2), items matching noise patterns should be filtered out of the LLM batch.

**Source schema extension (NOISE-04):**
```json
{
  "id": "src-36kr",
  "fetch_config": {
    "noise_patterns": [
      "^广告[:：]",
      "^赞助内容",
      "\\[推广\\]",
      "affiliate|sponsored"
    ],
    "title_discard_patterns": [
      "^每日精选$",
      "^本周热门$",
      "^Weekly Roundup$"
    ]
  }
}
```

**Filter logic:**
```
For each item with processing_status "raw":
  1. Read source's fetch_config.noise_patterns and title_discard_patterns
  2. Test item.title against each pattern (case-insensitive regex)
  3. If ANY pattern matches:
     a. Set processing_status: "noise_filtered" (new status value)
     b. Set digest_eligible: false (new field)
     c. Do NOT include in LLM classify batch
     d. Increment noise_filter_suppressed counter
  4. If NO pattern matches: include in classify batch as normal
```

**Key design decision:** Items stay in JSONL with their original data. They are NOT deleted. The `processing_status: "noise_filtered"` and `digest_eligible: false` fields mark them as excluded while preserving queryability (NOISE-03).

### Pattern 2: Post-Classify Importance Filter (NOISE-02)

**What:** After LLM classification assigns importance_score, items below 0.25 are marked as digest-ineligible but remain in JSONL.

**When to use:** After classify batch completes (Processing Phase step 3), before scoring.

**Filter logic:**
```
After classification:
  For each newly classified item:
    If importance_score < 0.25:
      Set digest_eligible: false
      (Keep processing_status: "complete" -- the LLM DID process it)
      Increment noise_filter_suppressed counter
```

**Key distinction from pre-classify:** This filter runs AFTER the LLM call (so there IS LLM cost), but prevents low-value items from consuming scoring/quota budget. The LLM cost is already spent, but output quality improves by excluding noise from the digest.

### Pattern 3: Classification Prompt Hardening (CLASS-01, CLASS-02)

**What:** Strengthen the classify prompt with better calibration examples, negative examples per category, and disambiguation rules for frequently confused category pairs.

**Improvements to `classify.md`:**

1. **0.0-0.2 tier examples (CLASS-01):** The current prompt has a reference scale that jumps from 0.3-0.4 to "Low information density" at 0.0-0.2 but gives no concrete examples. Add explicit examples:
```
- **0.0-0.2**: Low information density -- repetitive coverage of already-reported events, 
  clickbait titles without substance, pure marketing/promotional content, routine minor 
  version bumps (e.g., "v1.2.3 patch release"), aggregated round-up posts with no original 
  analysis, social media reaction compilations
```

2. **Negative examples per category (CLASS-02):** Each category in `categories.json` gets a `negative_examples` field listing items that should NOT be classified under that category:
```json
{
  "id": "ai-models",
  "negative_examples": [
    "App that merely uses an AI API (-> tech-products)",
    "AI company funding round (-> business)",
    "Government AI regulation (-> macro-policy)"
  ]
}
```

3. **Disambiguation rules (CLASS-01):** Common confusion pairs with resolution guidance:
```
Disambiguation Rules:
- "AI startup raises funding" -> business (NOT ai-models), unless the funding is specifically for a new model
- "New IDE with AI features" -> dev-tools (NOT ai-models), unless the AI capability is the primary news
- "Open source AI model released" -> ai-models (primary = the model), open-source (secondary)
- "Security vulnerability in AI system" -> security (NOT ai-models), unless the vulnerability is in the model itself
- "Government bans AI technology" -> macro-policy (NOT ai-models)
```

### Pattern 4: Cache Version Bump (CLASS-03)

**What:** Bump classify cache version from `classify-v1` to `classify-v2` to force re-classification with the improved prompt.

**Where:** Update `<!-- prompt_version: classify-v1 -->` to `<!-- prompt_version: classify-v2 -->` in `references/prompts/classify.md`.

**Effect:** All existing classify cache entries with `prompt_version: "classify-v1"` or `"legacy"` will cache-miss on next run, forcing fresh classification with the improved prompt. This is the mechanism established in Phase 8 (INFRA-01).

### Anti-Patterns to Avoid

- **Deleting noise items from JSONL:** Items must remain for history queries (NOISE-03). Mark them, don't delete them.
- **Filtering before writing to JSONL:** The filter must run AFTER items are persisted so they exist in history.
- **Hardcoding noise patterns globally:** Patterns must be per-source in `fetch_config` because different sources have different noise signatures.
- **Adding a new LLM call for noise detection:** The entire point of pre-classify filtering is zero LLM cost. Use only regex patterns.
- **Changing the scoring formula:** The post-classify filter uses `digest_eligible: false` to exclude from the scoring pool -- it does not modify importance_score or the scoring formula itself.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Noise detection | LLM-based noise classifier | Regex patterns per source | Zero LLM cost is the requirement (NOISE-01) |
| Category disambiguation | Complex multi-step classification | Prompt engineering with examples | LLM handles nuance; rules in prompt are sufficient |
| Importance recalibration | Post-hoc score adjustment formula | Better prompt examples | Calibrating the LLM's own scoring is more effective than adjusting outputs |

## Common Pitfalls

### Pitfall 1: Breaking History Queries with New Status Values

**What goes wrong:** Adding `processing_status: "noise_filtered"` breaks existing history query code that only checks for `"complete"` status.
**Why it happens:** History queries (Section 8) filter on `processing_status: "complete"`. Noise-filtered items have a different status and would be excluded from history -- which is actually correct behavior for most queries.
**How to avoid:** The `digest_eligible` field is the primary exclusion mechanism for scoring/output. The `processing_status: "noise_filtered"` serves as an audit trail. History queries that specifically look for "all items from a source" should use `processing_status != "raw"` rather than `== "complete"`.
**Warning signs:** Users ask "why are some items missing from history?" after noise filtering is enabled.

### Pitfall 2: Overly Aggressive Noise Patterns

**What goes wrong:** Noise patterns are too broad and filter legitimate items.
**Why it happens:** Regex patterns like "update" or "release" would catch legitimate important news.
**How to avoid:** Start with narrow, high-confidence patterns (pure promotional prefixes, aggregation post titles). Document that patterns should be conservative. The default `noise_patterns` in existing sources should start as empty arrays.
**Warning signs:** Sudden drop in items processed, noise_filter_suppressed count is very high (>30% of fetched items).

### Pitfall 3: Forgetting to Track Noise in Metrics

**What goes wrong:** The `noise_filter_suppressed` count is defined but never incremented.
**Why it happens:** Multiple pipeline steps need to increment the counter (pre-classify and post-classify), and one gets missed.
**How to avoid:** Both filter steps must increment the same counter. Document clearly that `noise_filter_suppressed = pre_classify_filtered + post_classify_filtered`. Consider tracking them separately for diagnostics.

### Pitfall 4: Negative Examples Bloating the Prompt

**What goes wrong:** Adding too many negative examples makes the classify prompt too long, increasing token cost and potentially confusing the LLM.
**Why it happens:** Enthusiasm for exhaustive coverage.
**How to avoid:** Cap negative examples at 2-3 per category. Focus on the most commonly confused cases. The disambiguation rules section handles cross-category confusion; negative examples handle within-category false positives.

### Pitfall 5: Schema Version Collision

**What goes wrong:** Adding `digest_eligible` to NewsItem requires bumping `_schema_v` from 3 to 4, but missing the backward-compatible default.
**Why it happens:** Forgetting to define the default for older records that lack the new field.
**How to avoid:** Follow the Schema Change Procedure in data-models.md: (1) add field, (2) increment version, (3) define default (`digest_eligible` defaults to `true` for old records -- they should be eligible since they passed the old pipeline), (4) update New Fields Registry table, (5) update fixture files.

## Code Examples

### Pre-Classify Noise Filter Logic (for processing-instructions.md)

```markdown
## Section 0E: Pre-Classify Noise Filter (NOISE-01, NOISE-04)

Before LLM classification, apply pattern-based filtering to skip obvious noise items.

### When to Run

During Processing Phase, after collecting unprocessed items (step 2) and before 
classification batch (step 3).

### Filter Procedure

1. Read `config/sources.json` to get `fetch_config.noise_patterns` and 
   `fetch_config.title_discard_patterns` for each source
2. For each item with `processing_status: "raw"`:
   a. Look up the item's `source_id` in sources.json
   b. Get `noise_patterns` array (default `[]` if absent)
   c. Get `title_discard_patterns` array (default `[]` if absent)
   d. Test `item.title` against each noise_pattern (case-insensitive regex match)
   e. Test `item.title` against each title_discard_patterns (case-insensitive regex match)
   f. If ANY pattern matches:
      - Set `processing_status: "noise_filtered"`
      - Set `digest_eligible: false`
      - Remove item from the LLM classification batch
      - Increment `noise_filter_suppressed` counter in run metrics
      - Log: "Noise filtered: {item.title} (matched pattern: {pattern})"
   g. If NO pattern matches: keep item in classification batch

### Backward Compatibility

- Sources without `noise_patterns` or `title_discard_patterns` in fetch_config 
  default to empty arrays (no filtering)
- Existing items without `digest_eligible` field default to `true`
```

### Post-Classify Importance Filter Logic

```markdown
## Post-Classify Importance Filter (NOISE-02)

After classification, filter items below the noise floor threshold.

### When to Run

After Processing Phase step 3 (classify batch), for each item that was just classified.

### Filter Procedure

1. For each item that received fresh classification results:
   a. If `importance_score < 0.25`:
      - Set `digest_eligible: false`
      - Keep `processing_status: "complete"` (classification DID succeed)
      - Increment `noise_filter_suppressed` counter
      - Log: "Low-importance filtered: {item.title} (score: {importance_score})"
   b. If `importance_score >= 0.25`:
      - Set `digest_eligible: true`
      - Proceed to summarization batch
```

### Source Schema Extension

```json
{
  "id": "src-36kr",
  "fetch_config": {
    "noise_patterns": [],
    "title_discard_patterns": []
  }
}
```

### NewsItem Schema v4 Addition

```json
{
  "digest_eligible": true,
  "_schema_v": 4
}
```

Default for old records (v3 and earlier): `digest_eligible: true`

### DailyMetrics Addition

```json
{
  "items": {
    "noise_filter_suppressed": 0
  }
}
```

### Category negative_examples Field

```json
{
  "id": "ai-models",
  "negative_examples": [
    "App using AI API without model innovation (-> tech-products)",
    "AI company funding/acquisition (-> business)",
    "Government AI regulation/policy (-> macro-policy)"
  ]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| No noise filtering | All items go to LLM | Phase 0 (v1.0) | Wasted LLM budget on promotional/aggregation content |
| Importance scale 0.3-1.0 only | Full 0.0-1.0 with examples | Phase 9 (this phase) | Better calibration at low end prevents noise from entering digest |
| No negative examples | Category-specific negative examples | Phase 9 (this phase) | Reduces category confusion for ambiguous items |
| classify-v1 prompt | classify-v2 with hardened prompt | Phase 9 (this phase) | Forces re-classification of cached items with improved prompt |

## Open Questions

1. **Optimal importance threshold for post-classify filter**
   - What we know: The requirement specifies 0.25 as the threshold (NOISE-02)
   - What's unclear: Whether 0.25 is the right number in practice -- may need tuning after observation
   - Recommendation: Implement 0.25 as specified. The threshold is a constant in processing-instructions.md and easy to adjust later if metrics show it's too aggressive or too lenient.

2. **Whether to skip summarization for post-classify filtered items**
   - What we know: NOISE-02 says items with importance < 0.25 are marked `digest_eligible: false`
   - What's unclear: Should we skip the summarize LLM call for these items to save additional budget?
   - Recommendation: YES, skip summarization for items with `digest_eligible: false` after post-classify filter. These items won't appear in digests, so summaries are wasted LLM cost. This saves additional budget beyond just the scoring exclusion.

3. **Separate tracking of pre-classify vs post-classify suppression**
   - What we know: NOISE-05 requires `noise_filter_suppressed` count in DailyMetrics
   - What's unclear: Whether to track as single aggregate or split into `pre_classify_suppressed` and `post_classify_suppressed`
   - Recommendation: Use a single `noise_filter_suppressed` field per requirement, but add a note in the metrics section that this is the sum of both stages. This keeps the schema simple while satisfying the requirement.

4. **Default noise_patterns for existing sources**
   - What we know: The sole enabled source (src-36kr, RSS) needs appropriate patterns
   - What's unclear: What noise patterns are appropriate for 36kr's RSS feed specifically
   - Recommendation: Start with empty arrays for all sources. Users add patterns through source management commands or manual config edits based on observed noise. The system should start conservative and let patterns accumulate organically.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOISE-01 | Pre-classify noise filter skips items matching source noise_patterns (zero LLM cost) | Pattern 1: Pre-Classify Noise Filter -- regex matching against per-source fetch_config patterns, items marked with processing_status "noise_filtered" and digest_eligible false |
| NOISE-02 | Post-classify filter marks items with importance < 0.25 as digest_eligible: false | Pattern 2: Post-Classify Importance Filter -- runs after classify batch, sets digest_eligible false, keeps processing_status "complete" |
| NOISE-03 | Filtered items excluded from scoring pool but retained in JSONL for history queries | Both filter patterns write to JSONL before filtering; digest_eligible field controls scoring exclusion while items remain queryable |
| NOISE-04 | Source schema supports noise_patterns and title_discard_patterns in fetch_config | Pattern 1 source schema extension -- new fields in fetch_config with empty array defaults for backward compatibility |
| NOISE-05 | DailyMetrics tracks noise_filter_suppressed count | DailyMetrics addition -- single counter incremented by both pre-classify and post-classify filters |
| CLASS-01 | Classify prompt strengthened with 0.0-0.2 tier, borderline examples, disambiguation rules | Pattern 3: Classification Prompt Hardening -- concrete examples at each tier, disambiguation rules for commonly confused category pairs |
| CLASS-02 | Category config supports negative_examples field included in prompt assembly | Pattern 3 -- negative_examples array added to each category in categories.json, injected into classify prompt template |
| CLASS-03 | Cache version bumped from classify-v1 to classify-v2 | Pattern 4: Cache Version Bump -- prompt_version comment updated, forces re-classification of all cached items |
</phase_requirements>

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual fixture verification (no automated test framework -- this is a document-only project) |
| Config file | N/A |
| Quick run command | Manual: verify fixture files contain expected fields |
| Full suite command | Manual: review all modified files against requirements checklist |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOISE-01 | Items matching noise_patterns have processing_status: "noise_filtered" and digest_eligible: false | fixture | Verify fixture file has noise-filtered item with correct fields | Wave 0 |
| NOISE-02 | Items with importance < 0.25 have digest_eligible: false | fixture | Verify fixture file has low-importance item with digest_eligible: false | Wave 0 |
| NOISE-03 | Filtered items exist in JSONL (not deleted) | fixture | Verify noise items present in fixture JSONL | Wave 0 |
| NOISE-04 | Source schema has noise_patterns and title_discard_patterns | fixture | Verify sources.json fixture has the new fields | Wave 0 |
| NOISE-05 | DailyMetrics has noise_filter_suppressed field | fixture | Verify metrics fixture has the field | Wave 0 |
| CLASS-01 | Classify prompt has 0.0-0.2 tier examples and disambiguation rules | manual | Read classify.md and verify sections exist | N/A |
| CLASS-02 | categories.json has negative_examples per category | manual | Read categories.json and verify field exists | N/A |
| CLASS-03 | Prompt version is classify-v2 | manual | Check `<!-- prompt_version: classify-v2 -->` in classify.md | N/A |

### Wave 0 Gaps

- [ ] `data/fixtures/news-items-noise-filtered.jsonl` -- new fixture with noise-filtered and low-importance items
- [ ] Update `data/fixtures/metrics-sample.json` -- add noise_filter_suppressed field

## Sources

### Primary (HIGH confidence)

- Existing codebase files (SKILL.md, data-models.md, processing-instructions.md, classify.md, categories.json, sources.json) -- full review of current pipeline architecture, data models, and classification prompt
- Phase 8 completed work (INFRA-01 cache versioning) -- established the prompt_version mechanism used for CLASS-03

### Secondary (MEDIUM confidence)

- Requirements definition (REQUIREMENTS.md NOISE-01 through CLASS-03) -- clear specifications for all 8 requirements
- Roadmap success criteria (ROADMAP.md Phase 9) -- 5 verifiable success criteria

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - No external dependencies; all changes are to existing project files with well-understood schemas
- Architecture: HIGH - Two-stage noise filter pattern is straightforward and slots cleanly into the existing pipeline. All integration points are clearly identified in SKILL.md and processing-instructions.md
- Pitfalls: HIGH - All pitfalls derive from actual schema, pipeline, and prompt constraints observed in the codebase

**Research date:** 2026-04-02
**Valid until:** 2026-05-02 (stable project, no external dependency changes)
