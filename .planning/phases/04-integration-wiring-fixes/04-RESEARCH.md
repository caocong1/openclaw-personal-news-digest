# Phase 4: Integration Wiring Fixes - Research

**Researched:** 2026-04-01
**Domain:** Cross-phase integration gap closure (JSON config, prompt templates, reference documentation)
**Confidence:** HIGH

## Summary

Phase 4 is a pure wiring-fix phase: no new features, no new libraries, no architectural changes. The v1.0 milestone audit identified 5 integration gaps (MISSING-01 through MISSING-05) and 2 broken E2E flows (BROKEN-01, BROKEN-02) where fields, placeholders, or documentation defined in one phase were never propagated to the files that consume them. All 5 fixes are small, targeted edits to existing files -- adding placeholders to a prompt template, adding a field to a JSON config, adding a documentation paragraph to a reference file, and adding schema fields to a data model.

The root cause across all gaps is the same: a feature was designed and documented in its "home" phase (e.g., `depth_preference` in Phase 3's data-models.md) but the consuming file in a different phase (e.g., `summarize.md` from Phase 0) was not updated to wire the new field through. This is a natural consequence of incremental phase delivery and the audit correctly caught these seams.

**Primary recommendation:** Execute all 5 fixes in a single plan (04-01-PLAN.md) since they are independent edits to different files with no inter-dependency. Each fix is a targeted addition -- no deletions, no restructuring, no logic changes.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PREF-07 | Expand to 7-layer preference model (depth_preference + judgment_angles) | MISSING-01: summarize.md prompt needs {depth_preference} and {judgment_angles} placeholders. weekly-report.md already has them (confirmed). data-models.md and preferences.json schema already define the fields (confirmed). Only the daily summarize prompt is missing the wiring. |
| ANTI-05 | Preference auto-correction (category min 2% exposure, exploration_appetite +0.05 every 7 days, cap 0.4) | MISSING-04: config/preferences.json actual file missing `style.last_exploration_increase` field. data-models.md already documents it. processing-instructions.md Section 4 Step 7 already reads it. The field simply needs to be added to the shipped config file. |
| SRC-09 | Source auto-demotion and recovery (quality < 0.2 for 14 days demote, > 0.3 for 7 days recover) | MISSING-02: scoring-formula.md missing 0.5x degraded source penalty documentation. MISSING-05: config/sources.json entries missing degraded_since/recovery_streak_start stats fields. data-models.md already documents both fields. processing-instructions.md Section 6 already defines the penalty. The scoring reference and shipped config just need the additions. |
| OUT-02 | Breaking news quick alerts (importance >= 0.85, cap 3/day, URL dedup) | MISSING-03: data-models.md DailyMetrics schema missing alerts_sent_today and alerted_urls fields. processing-instructions.md Section 5 and output-templates.md both reference these fields. The canonical schema just needs the additions. |
</phase_requirements>

## Standard Stack

### Core

No new libraries or tools needed. This phase edits only existing project files:

| File | Type | Fix |
|------|------|-----|
| `references/prompts/summarize.md` | Prompt template | Add {depth_preference} and {judgment_angles} placeholders |
| `config/preferences.json` | JSON config | Add `style.last_exploration_increase: null` field |
| `references/scoring-formula.md` | Reference doc | Add degraded source 0.5x penalty documentation |
| `config/sources.json` | JSON config | Add `degraded_since` and `recovery_streak_start` to all 6 source stats |
| `references/data-models.md` | Schema reference | Add `alerts_sent_today` and `alerted_urls` to DailyMetrics schema |

### Supporting

None -- no new dependencies.

### Alternatives Considered

None -- these are prescribed wiring fixes, not design choices.

## Architecture Patterns

### Fix-by-Fix Analysis

#### Fix 1: summarize.md depth/judgment placeholders (MISSING-01, BROKEN-01)

**Current state:** `references/prompts/summarize.md` has a fixed "2-3 sentences" length requirement with no variability. No mention of `{depth_preference}` or `{judgment_angles}`.

**Target state:** The prompt must read the user's `depth_preference` ("brief"/"moderate"/"detailed"/"technical") and `judgment_angles` (array of perspective tags) to produce variable-depth output.

**Reference implementation:** `references/prompts/weekly-report.md` already has the correct wiring:
```
### User Preferences Context
Depth: {depth_preference}
Angles: {judgment_angles or "none specified"}
```

**What to add to summarize.md:**
1. A "User Preferences Context" section with `{depth_preference}` and `{judgment_angles}` placeholders
2. Modify the Length requirement to be depth-dependent:
   - "brief": 1 sentence
   - "moderate": 2-3 sentences (current default, preserves backward compatibility)
   - "detailed": 3-5 sentences with background context
   - "technical": adds implementation details where relevant
3. If `{judgment_angles}` is non-empty, add instruction to emphasize those perspectives

**Key constraint from STATE.md:** "[Phase 03]: depth_preference and judgment_angles wired into summarize prompt, NOT scoring formula" -- the scoring formula must NOT be modified for this.

**Verification:** After fix, the daily summarize prompt must produce different-length summaries when depth_preference varies. The "moderate" setting must produce the same 2-3 sentence output as the current fixed prompt (backward compatible).

#### Fix 2: preferences.json last_exploration_increase field (MISSING-04, BROKEN-02)

**Current state:** `config/preferences.json` actual file has 4 fields in `style`: density, repetition_tolerance, exploration_appetite, rumor_tolerance. The `last_exploration_increase` field is ABSENT.

**Target state:** `style.last_exploration_increase: null` must be present in the shipped config.

**Impact of absence (BROKEN-02 flow):** processing-instructions.md Section 4 Step 7 reads this field. When absent, it evaluates as null, which means "never increased", which triggers +0.05 increment on EVERY pipeline run instead of every 7 days. This causes exploration_appetite to hit the 0.4 cap within ~2 runs from cold start (0.3 -> 0.35 -> 0.40).

**What to change:** Add `"last_exploration_increase": null` to the `style` object in `config/preferences.json`.

**data-models.md status:** Already documents this field correctly (confirmed at line 298). No data-models.md change needed for this fix.

#### Fix 3: scoring-formula.md degraded source penalty (MISSING-02)

**Current state:** `references/scoring-formula.md` has no mention of `status == "degraded"` or the 0.5x source_trust multiplier. The Source Trust dimension (Section 3) simply documents the lookup but not the degraded penalty.

**Target state:** The scoring formula reference must document that when `source.status == "degraded"`, the `source_trust` dimension value is multiplied by 0.5 before the weighted sum.

**Where it IS documented:** `references/processing-instructions.md` Section 6 "Effect on Scoring" (line 688-689) already correctly specifies: "if item.source.status == 'degraded': apply a 0.5x multiplier to the source_trust dimension value before the weighted sum." But scoring-formula.md is the authoritative reference that SKILL.md Output Phase step 1 points to, so the penalty must appear there too.

**What to add:** A note/subsection under "3. Source Trust" documenting:
- If `source.status == "degraded"` in `config/sources.json`, multiply the source_trust value by 0.5 before including it in the weighted sum
- Cross-reference to processing-instructions.md Section 6 for the full demotion/recovery state machine

#### Fix 4: sources.json degraded_since/recovery_streak_start fields (MISSING-05)

**Current state:** All 6 source entries in `config/sources.json` have stats objects with 9 fields (total_fetched through selection_rate). The `degraded_since` and `recovery_streak_start` fields are absent.

**Target state:** Each source's `stats` object must include `"degraded_since": null` and `"recovery_streak_start": null`.

**data-models.md status:** Already documents these fields correctly (confirmed at lines 132-133, 146-149) with null defaults for older schema. The fix is purely in the shipped config file.

**What to change:** Add `"degraded_since": null, "recovery_streak_start": null` to the `stats` object of all 6 source entries in `config/sources.json`.

**Safety note:** The processing-instructions.md Section 6 correctly handles null values (null means "not tracking"). Adding null fields to the config is safe and will not change runtime behavior until a source actually triggers demotion.

#### Fix 5: data-models.md DailyMetrics alert tracking fields (MISSING-03)

**Current state:** The DailyMetrics schema in `references/data-models.md` has no `alerts_sent_today` or `alerted_urls` fields. The schema shows `output`, `quota_distribution`, `category_proportions`, `source_proportions`, and `alerts` (AlertCondition array).

**Target state:** DailyMetrics must include:
- `alerts_sent_today` (integer, default 0) -- count of breaking news alerts sent today
- `alerted_urls` (array of strings, default []) -- URLs already alerted today for dedup

**Where they ARE referenced:**
- `references/processing-instructions.md` Section 5 line 649-650: documents both fields as tracked metrics
- `references/output-templates.md` "Breaking News Alert" section: references `alerts_sent_today` for the 3/day cap and `alerted_urls` for URL dedup
- `SKILL.md` Quick-Check Flow step 2: references both fields

**What to add:** Two fields to the DailyMetrics JSON schema example and a field notes entry explaining their purpose and defaults.

### Anti-Patterns to Avoid

- **Feature creep:** This phase is ONLY wiring fixes. Do not add new features, change scoring weights, modify algorithms, or restructure files. If a fix seems to require a design decision, it is out of scope.
- **Partial fixes:** Each gap must be fully closed. Adding a placeholder without updating the length instruction (Fix 1) would leave the flow still broken.
- **Inconsistent defaults:** When adding fields to config files, use the same defaults documented in data-models.md. Do not introduce new default values.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Prompt variability | Custom prompt switching logic | Placeholder substitution with conditional instructions in the prompt itself | Keeps prompt as single template, consistent with existing weekly-report.md pattern |
| Schema migration | Version bump + migration script | Add fields with null/empty defaults | Schema versioning rules already handle missing fields via defaults |

**Key insight:** All fixes use the project's existing patterns -- placeholder substitution for prompts, null defaults for new JSON fields, and additive documentation for reference files. No new patterns needed.

## Common Pitfalls

### Pitfall 1: Breaking backward compatibility in summarize.md
**What goes wrong:** Changing the fixed "2-3 sentences" instruction to be purely dynamic could break the "moderate" (default) case if the placeholder is not filled.
**Why it happens:** The prompt is used by existing pipeline runs that may not yet inject the new placeholders.
**How to avoid:** Keep "2-3 sentences" as the default/fallback for when depth_preference is "moderate" or missing. Add the variability as ADDITIONAL instructions, not a replacement.
**Warning signs:** Existing summaries changing length unexpectedly after the fix.

### Pitfall 2: Forgetting one of the 6 sources.json entries
**What goes wrong:** Adding degraded_since/recovery_streak_start to some sources but not all 6.
**Why it happens:** Copy-paste across 6 array entries.
**How to avoid:** Edit all 6 entries systematically. Verify count matches (6 sources, each with both fields).
**Warning signs:** Re-audit finding one source still missing the fields.

### Pitfall 3: Placing alert fields in wrong DailyMetrics location
**What goes wrong:** Adding alerts_sent_today inside the existing `output` sub-object rather than as top-level DailyMetrics fields.
**Why it happens:** Natural to group "output-related" fields together.
**How to avoid:** Follow the pattern from processing-instructions.md Section 5, which lists them as top-level metrics alongside `sources`, `items`, `llm`, `output`.
**Warning signs:** Quick-check flow cannot find the fields at the expected path.

### Pitfall 4: Not updating the Phase Activation Status in scoring-formula.md
**What goes wrong:** Adding the degraded penalty note but not updating the Phase Activation Status section at the bottom, leaving it claiming "Phase 2 (current)" with no mention of degraded penalty.
**Why it happens:** The Phase Activation Status section is at the bottom of the file and easy to overlook.
**How to avoid:** Update the Phase Activation Status to reflect Phase 4 additions (degraded penalty documentation).

## Code Examples

### Example 1: summarize.md depth-aware section (modeled after weekly-report.md)

```markdown
## User Preferences Context

Depth: {depth_preference}
Angles: {judgment_angles or "none specified"}

## Depth-Adjusted Requirements

- If depth is "brief": 1 sentence per item, core fact only
- If depth is "moderate": 2-3 sentences (default)
- If depth is "detailed": 3-5 sentences, include background context and significance
- If depth is "technical": same as detailed, plus implementation/technical specifics where relevant
- If judgment_angles is not empty: for each item where an angle applies, briefly note that perspective
```

### Example 2: preferences.json style object after fix

```json
"style": {
  "density": "medium",
  "repetition_tolerance": "low",
  "exploration_appetite": 0.3,
  "rumor_tolerance": "low",
  "last_exploration_increase": null
}
```

### Example 3: sources.json stats object after fix

```json
"stats": {
  "total_fetched": 0,
  "last_fetch": null,
  "last_hit_count": 0,
  "avg_daily_items": 0,
  "consecutive_failures": 0,
  "last_error": null,
  "quality_score": 0.5,
  "dedup_rate": 0.0,
  "selection_rate": 0.0,
  "degraded_since": null,
  "recovery_streak_start": null
}
```

### Example 4: scoring-formula.md degraded penalty addition (under Source Trust section)

```markdown
**Degraded source penalty:** If `source.status == "degraded"` (see `config/sources.json`), multiply the `source_trust` value by **0.5** before including it in the weighted sum. This deprioritizes items from degraded sources without completely excluding them. See `references/processing-instructions.md` Section 6 for the full demotion/recovery state machine.
```

### Example 5: DailyMetrics alert fields addition

```json
{
  "alerts_sent_today": 0,
  "alerted_urls": []
}
```

Field notes addition:
```markdown
- `alerts_sent_today`: Integer count of breaking news alerts sent during quick-check runs today. Default 0. Read by quick-check flow to enforce 3-alert daily cap.
- `alerted_urls`: Array of URL strings already alerted today. Default []. Read by quick-check flow for same-URL dedup.
```

## State of the Art

Not applicable -- this phase involves no external libraries, frameworks, or technology choices. All work is internal project file edits.

## Open Questions

None. All 5 fixes are fully specified by the existing documentation:
- data-models.md defines the target schema for all fields
- processing-instructions.md defines the runtime behavior
- output-templates.md defines the alert format and caps
- weekly-report.md provides the working reference for depth/angles prompt wiring

The audit report precisely identifies what is missing and where. No ambiguity remains.

## Sources

### Primary (HIGH confidence)

All findings verified by direct file inspection of the project's own source files:

- `references/prompts/summarize.md` -- confirmed missing depth_preference/judgment_angles placeholders
- `references/prompts/weekly-report.md` -- confirmed working reference for depth/angles wiring pattern
- `references/scoring-formula.md` -- confirmed missing degraded source penalty documentation
- `references/processing-instructions.md` Section 4 Step 7 -- confirmed last_exploration_increase read logic
- `references/processing-instructions.md` Section 5 -- confirmed alerts_sent_today/alerted_urls as tracked metrics
- `references/processing-instructions.md` Section 6 -- confirmed 0.5x degraded penalty and demotion/recovery state machine
- `references/output-templates.md` "Breaking News Alert" -- confirmed alert cap and URL dedup references
- `references/data-models.md` -- confirmed DailyMetrics schema missing alert fields; confirmed Source schema correctly includes degraded fields; confirmed Preferences schema correctly includes last_exploration_increase
- `config/preferences.json` -- confirmed actual file missing style.last_exploration_increase
- `config/sources.json` -- confirmed all 6 entries missing degraded_since/recovery_streak_start
- `.planning/v1.0-MILESTONE-AUDIT.md` -- authoritative gap list (MISSING-01 through MISSING-05, BROKEN-01, BROKEN-02)
- `SKILL.md` -- confirmed Quick-Check Flow references alerts_sent_today and alerted_urls

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no external dependencies, all internal files verified
- Architecture: HIGH -- all fixes follow existing patterns already used elsewhere in the project
- Pitfalls: HIGH -- gaps are precisely defined with clear before/after states

**Research date:** 2026-04-01
**Valid until:** No expiry -- this is internal project wiring, not subject to external changes
