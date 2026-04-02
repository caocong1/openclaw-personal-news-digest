---
phase: 09-noise-floor-classification-quality
verified: 2026-04-02T09:00:00Z
status: passed
score: 5/5 must-haves verified
re_verification: false
---

# Phase 9: Noise Floor & Classification Quality Verification Report

**Phase Goal:** Low-value items are filtered before they consume LLM budget, and classification accuracy is improved through better prompts and negative examples
**Verified:** 2026-04-02T09:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

From ROADMAP.md success criteria:

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Items matching source noise_patterns are skipped before classify LLM call (zero LLM cost for noise) | VERIFIED | Section 0E in processing-instructions.md (line 214) specifies full filter-before-classify logic; SKILL.md step 2.5 (line 31) wires it into pipeline |
| 2 | Items with importance < 0.25 are marked digest_eligible: false and excluded from scoring | VERIFIED | Post-Classify Importance Filter in processing-instructions.md (line 285) specifies 0.25 threshold; SKILL.md step 3.5 (line 33) wires it; SKILL.md Output Phase step 1 (line 47) excludes `digest_eligible: false` from scoring pool |
| 3 | Filtered items remain queryable in JSONL history | VERIFIED | Section 0E line 247: "Noise-filtered items remain in JSONL — they are NOT deleted"; noise_filtered status keeps items in JSONL |
| 4 | Classification prompt includes 0.0-0.2 tier examples, negative examples per category, and disambiguation rules | VERIFIED | classify.md bumped to classify-v2 with 7 low-end tier examples, 6 Borderline Examples, 9 Disambiguation Rules; 12 categories each have 3 negative_examples in categories.json |
| 5 | DailyMetrics tracks noise_filter_suppressed count | VERIFIED | references/data-models.md line 348 adds `noise_filter_suppressed: 0` to DailyMetrics.items; New Fields Registry entry at line 484; metrics-sample.json fixture updated with value 3 |

**Score:** 5/5 truths verified

---

## Required Artifacts

### Plan 09-01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `references/data-models.md` | NewsItem v4 with digest_eligible, DailyMetrics noise_filter_suppressed, Source noise_patterns | VERIFIED | `digest_eligible` (3 occurrences), `_schema_v: 4`, `noise_filter_suppressed` (2 occurrences in schema + registry), `noise_patterns` documented in Common fetch_config fields section (lines 164-166), all 4 Phase 9 fields in New Fields Registry |
| `config/sources.json` | All 6 sources have noise_patterns and title_discard_patterns | VERIFIED | Grep confirms 6 occurrences each of `"noise_patterns"` and `"title_discard_patterns"`, matching 6 total source entries |
| `references/processing-instructions.md` | Section 0E pre-classify noise filter | VERIFIED | Section 0E at line 214 between Section 0D (line 157) and Section 1 (line 254); contains full filter procedure, backward compatibility notes, and pipeline interaction rules |
| `SKILL.md` | Noise filter step 2.5 in Processing Phase | VERIFIED | Step 2.5 at line 31 with Section 0E cross-reference; Output Phase step 1 excludes `digest_eligible: false` from scoring pool |

### Plan 09-02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `references/prompts/classify.md` | Hardened classify-v2 prompt with low-end calibration and disambiguation | VERIFIED | Line 1: `<!-- prompt_version: classify-v2 -->`, `## Borderline Examples` with 6 anchor rows, `## Disambiguation Rules` with 9 rules + general principle, 0.0-0.2 tier expanded to 7 concrete example types |
| `config/categories.json` | 12 categories each with negative_examples field (3 entries) | VERIFIED | Grep confirms 12 `"negative_examples"` and 12 `"id":` entries — 1:1 match; each array has 3 entries with `->` format for alternative category |
| `references/processing-instructions.md` | Section 1 Step 2 formats negative_examples into {categories_list} | VERIFIED | Line 267-270 updated Fill categories step explicitly formats negative_examples with `NOT this category:` format |

### Plan 09-03 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `references/processing-instructions.md` | Post-Classify Importance Filter subsection in Section 1 | VERIFIED | `### Post-Classify Importance Filter (NOISE-02)` at line 285; contains 0.25 threshold, digest_eligible marking, summarization skip, processing_status behavior, and noise_filter_suppressed sum documentation |
| `data/fixtures/news-items-noise-filtered.jsonl` | 4 JSONL items covering all noise filter scenarios | VERIFIED | 4 lines confirmed; item 1: noise_filtered + digest_eligible:false + categories.primary:null; item 2: noise_filtered + digest_eligible:false; item 3: complete + digest_eligible:false + importance_score:0.15; item 4: complete + digest_eligible:true + importance_score:0.85; all use _schema_v:4 |
| `data/fixtures/metrics-sample.json` | noise_filter_suppressed field added | VERIFIED | `"noise_filter_suppressed": 3` present in items object |

---

## Key Link Verification

### Plan 09-01 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `SKILL.md` | `references/processing-instructions.md` | Section 0E cross-reference in Processing Phase step 2.5 | WIRED | Line 31 in SKILL.md: "See `{baseDir}/references/processing-instructions.md` Section 0E" |
| `references/processing-instructions.md` | `config/sources.json` | noise_patterns lookup in Section 0E | WIRED | Section 0E line 224: "Read `config/sources.json` to load `fetch_config.noise_patterns` and `fetch_config.title_discard_patterns`" |
| `references/data-models.md` | `references/processing-instructions.md` | digest_eligible field used by filter logic | WIRED | Section 0E and Post-Classify filter both set `digest_eligible: false`; field defined in data-models.md with default `true` |

### Plan 09-02 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `references/prompts/classify.md` | `config/categories.json` | negative_examples injected from categories into prompt | WIRED | classify.md line 13 notes negative_examples per category; line 53 instructs LLM to use them; processing-instructions.md line 267 specifies format injection |
| `references/prompts/classify.md` | `data/cache/classify-cache.json` | classify-v2 forces cache miss on v1 entries | WIRED | classify.md line 1 declares `classify-v2`; cache invalidation mechanism documented in plan |
| `references/processing-instructions.md` | `config/categories.json` | Section 1 Step 2 formats negative_examples into {categories_list} | WIRED | Lines 267-270 explicitly instruct: "format the 12 categories into {categories_list}... include negative_examples... NOT this category: format" |

### Plan 09-03 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `references/processing-instructions.md` | `SKILL.md` | SKILL.md step 3.5 references post-classify filter | WIRED | SKILL.md line 33: "See `{baseDir}/references/processing-instructions.md` Section 1 'Post-Classify Importance Filter'" |
| `data/fixtures/news-items-noise-filtered.jsonl` | `references/data-models.md` | Fixture items use NewsItem v4 schema with digest_eligible | WIRED | All 4 fixture items have `"_schema_v":4` and `"digest_eligible"` field, matching v4 schema defined in data-models.md |

---

## Data-Flow Trace (Level 4)

Not applicable — this phase produces documentation artifacts (markdown specifications, JSON configuration, JSONL fixtures) rather than runnable code components with live data rendering. The artifacts are pipeline instructions consumed by LLM agents, not UI components or API routes.

---

## Behavioral Spot-Checks

**Step 7b: SKIPPED** — No runnable entry points. All phase outputs are documentation, configuration, and fixture files. The pipeline described is executed by LLM agents at runtime, not by compiled/runnable code.

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| NOISE-01 | 09-01 | Pre-classify noise filter skips items matching source noise_patterns (zero LLM cost) | SATISFIED | Section 0E in processing-instructions.md; SKILL.md step 2.5; sources.json has noise_patterns on all 6 sources |
| NOISE-02 | 09-03 | Post-classify filter marks items with importance < 0.25 as digest_eligible: false | SATISFIED | Post-Classify Importance Filter in processing-instructions.md (line 285) with explicit 0.25 threshold; SKILL.md step 3.5 |
| NOISE-03 | 09-01 | Filtered items excluded from scoring pool but retained in JSONL for history queries | SATISFIED | Section 0E: "remain in JSONL — they are NOT deleted"; SKILL.md Output Phase step 1 excludes `digest_eligible: false` from scoring pool |
| NOISE-04 | 09-01 | Source schema supports noise_patterns and title_discard_patterns in fetch_config | SATISFIED | data-models.md Common fetch_config fields documentation (lines 164-166); New Fields Registry; all 6 sources in config/sources.json have both fields |
| NOISE-05 | 09-01, 09-03 | DailyMetrics tracks noise_filter_suppressed count | SATISFIED | data-models.md DailyMetrics schema has `noise_filter_suppressed: 0`; New Fields Registry entry; metrics-sample.json fixture updated; processing-instructions.md documents it as sum of pre- and post-classify counts |
| CLASS-01 | 09-02 | Classify prompt strengthened with 0.0-0.2 tier, borderline examples, disambiguation rules | SATISFIED | classify.md has 7-item 0.0-0.2 tier (lines 69-75), Borderline Examples table with 6 rows, Disambiguation Rules with 9 rules + general principle |
| CLASS-02 | 09-02 | Category config supports negative_examples field included in prompt assembly | SATISFIED | config/categories.json: 12 categories with 3 negative_examples each (36 total); processing-instructions.md Section 1 Step 2 wires them into {categories_list}; classify.md instructs LLM to use them |
| CLASS-03 | 09-02 | Cache version bumped from classify-v1 to classify-v2 | SATISFIED | classify.md line 1: `<!-- prompt_version: classify-v2 -->` |

**Orphaned requirements check:** Requirements.md shows NOISE-01 through NOISE-05 and CLASS-01 through CLASS-03 all mapped to Phase 9. All 8 IDs are claimed across the 3 plans. No orphaned requirements.

---

## Anti-Patterns Found

Scan performed on: `references/data-models.md`, `config/sources.json`, `references/processing-instructions.md`, `SKILL.md`, `references/prompts/classify.md`, `config/categories.json`, `data/fixtures/news-items-noise-filtered.jsonl`, `data/fixtures/metrics-sample.json`

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | — |

All grep matches were intentional template placeholder documentation (`{baseDir}`, `run-YYYYMMDD-HHmmss-XXXX`) used as formatting examples in specification documents, not code stubs. No TODO/FIXME/placeholder markers, no empty implementations, no hollow components.

Note: noise_patterns arrays are intentionally empty `[]` on all 6 sources. This is a documented conservative default, not a stub — the field infrastructure is fully wired; patterns will be populated based on observed production noise. The 09-01-SUMMARY.md explicitly acknowledges this as a known intentional state.

---

## Human Verification Required

No human verification required. All success criteria for this phase are specification/documentation artifacts verifiable through static analysis:
- Configuration fields exist and have correct structure (grep verified)
- Section ordering in processing-instructions.md correct (line numbers confirmed)
- Prompt content has required sections (grep confirmed presence and content)
- Fixture files have correct schema and field values (raw content read and verified)

---

## Gaps Summary

No gaps. All 5 observable truths verified, all 9 artifacts pass all applicable levels (exists, substantive, wired), all 8 key links wired, all 8 requirement IDs satisfied, no anti-patterns found.

---

_Verified: 2026-04-02T09:00:00Z_
_Verifier: Claude (gsd-verifier)_
