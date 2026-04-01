# Phase 5: Daily Depth Control Wiring - Research

**Researched:** 2026-04-01
**Domain:** Prompt template wiring, SKILL.md documentation alignment, processing-instructions gap closure
**Confidence:** HIGH

## Summary

Phase 5 closes a single well-defined gap identified by the v1.0 milestone audit: the daily summarization batch path never reads or injects `depth_preference` and `judgment_angles` from `config/preferences.json` into the `summarize.md` prompt, even though the prompt template already has placeholders for them. SKILL.md also still describes daily summaries as fixed "2-3 sentence" output, which contradicts the variable-depth design.

The weekly report path (processing-instructions.md Section 7, step 5) already reads these fields from preferences.json and passes them to `weekly-report.md`. The daily path in Section 1 (Summarization Batch) does not. The fix is entirely additive: add a preference-read step to the daily summarization batch instructions and update SKILL.md wording.

**Primary recommendation:** Add a preference-read step to processing-instructions.md Section 1 Summarization Batch, update SKILL.md Processing Phase step 4 wording, and verify BROKEN-01/MISSING-01 are resolved.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PREF-07 | Expand to 7-layer preference model (depth_preference + judgment_angles) | Fields already exist in preferences.json (_schema_v 2) and summarize.md has placeholders. The missing piece is the daily consumer wiring in processing-instructions.md Section 1 and accurate SKILL.md description. |
</phase_requirements>

## Existing State Analysis

### What Already Works (no changes needed)

| Component | Status | Evidence |
|-----------|--------|----------|
| `config/preferences.json` | Has `depth_preference` and `judgment_angles` fields | _schema_v 2, added in Phase 3 (03-01-PLAN) |
| `references/data-models.md` Preferences schema | Documents both fields with types, ranges, defaults | Lines 299-300, backward-compatible defaults for v1 readers |
| `references/prompts/summarize.md` | Has `{depth_preference}` and `{judgment_angles}` placeholders, depth-adjusted rules, angle injection logic | Complete prompt template with all 4 depth levels |
| `references/prompts/weekly-report.md` | Has same placeholders, references depth and angles | Lines 20-21, 31-32 |
| Weekly report data collection (Section 7 step 5) | Reads preferences.json for depth_preference and judgment_angles | processing-instructions.md line 712 |
| Preference visualization | Shows depth_preference and judgment_angles to user | feedback-rules.md lines 181-182 |
| Decay exclusion | depth_preference and judgment_angles do NOT decay | processing-instructions.md line 46 |

### What Is Broken (must fix)

| Component | Current State | Required State |
|-----------|---------------|----------------|
| processing-instructions.md Section 1 "Summarization Batch" | Only fills ID, Title, Source, Content per item. Never reads preferences.json. Never injects depth_preference or judgment_angles into summarize.md. | Must read `config/preferences.json` before filling the summarize prompt. Must inject `depth_preference` and `judgment_angles` into the `{depth_preference}` and `{judgment_angles}` placeholders in summarize.md. |
| SKILL.md Processing Phase step 4 | Says "Generate 2-3 sentence Chinese summary" (fixed depth) | Must say variable-depth summary driven by `depth_preference` setting, referencing summarize.md for depth rules |
| output-templates.md "Output Control Parameters" table | Says "Summary length: 2-3 sentences" as fixed default | Must describe summary length as depth_preference-dependent |

### Audit Gaps This Phase Closes

| Gap ID | Description | Resolution |
|--------|-------------|------------|
| PREF-07 | Expand to 7-layer model (depth_preference + judgment_angles) | Wire the daily summarization consumer so the fields actually take effect |
| MISSING-01 | Daily summarize path ignores preference depth and angles | Add preference read + placeholder injection to Section 1 Summarization Batch |
| BROKEN-01 | Daily depth control E2E flow broken | Once Section 1 reads and injects, the full path preferences -> summarize prompt -> variable-depth output works |

## Architecture Patterns

### Current Daily Summarization Flow (BROKEN)

```
config/preferences.json  --(not read)-->  [gap]
                                            |
references/prompts/summarize.md            |
  (has {depth_preference} placeholder)     |
  (has {judgment_angles} placeholder)      |
                                            v
processing-instructions.md Section 1:
  1. Load prompt: summarize.md
  2. Fill batch data: ID, Title, Source, Content  <-- only item data, no preferences
  3. Process with LLM
  4. Parse response
```

### Required Daily Summarization Flow (FIX)

```
config/preferences.json  --(read step 1.5)-->  depth_preference, judgment_angles
                                                      |
references/prompts/summarize.md                       |
  (has {depth_preference} placeholder)                |
  (has {judgment_angles} placeholder)                 |
                                                      v
processing-instructions.md Section 1:
  1. Load prompt: summarize.md
  1.5. Load preferences: read config/preferences.json, extract depth_preference
       and judgment_angles (default "moderate" and [] if missing)
  2. Fill User Preferences Context section: inject depth_preference and
     judgment_angles into prompt placeholders
  3. Fill batch data: ID, Title, Source, Content
  4. Process with LLM
  5. Parse response
```

### Pattern: Consistent with Weekly Path

The weekly report path (Section 7) already follows this exact pattern -- step 5 of data collection reads preferences.json for `depth_preference` and `judgment_angles`. The daily fix mirrors this established pattern.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Default values for missing preference fields | Custom fallback logic scattered across consumers | Schema v2 backward-compatible defaults already defined in data-models.md: `depth_preference` = "moderate", `judgment_angles` = [] | Single source of truth for defaults |

## Common Pitfalls

### Pitfall 1: Forgetting the default fallback for v1 preferences

**What goes wrong:** If preferences.json is still at _schema_v 1 (or depth_preference is somehow missing), the summarize prompt gets empty/undefined placeholders.
**Why it happens:** The daily batch might not account for older schema versions.
**How to avoid:** The processing-instructions fix must specify: "If `depth_preference` is absent or empty, default to `'moderate'`. If `judgment_angles` is absent, default to `[]`." This mirrors the existing schema-v2 backward-compatibility rule in data-models.md.
**Warning signs:** Empty `{depth_preference}` in prompt output.

### Pitfall 2: Changing summary behavior when depth is "moderate"

**What goes wrong:** Wiring the preference changes the LLM output even for existing "moderate" users, breaking backward compatibility.
**Why it happens:** LLM may interpret "moderate" differently than the previous un-parameterized behavior.
**How to avoid:** The summarize.md prompt already defines "moderate" as "2-3 sentences per item" which matches the old fixed behavior. The Phase 4 decision explicitly states: "moderate depth produces identical 2-3 sentence output to preserve backward compatibility." No prompt changes needed -- just wire the value through.
**Warning signs:** Summary length changes for users who have never modified depth_preference.

### Pitfall 3: SKILL.md word budget overflow

**What goes wrong:** Changing step 4 description expands SKILL.md beyond the word budget.
**Why it happens:** SKILL.md has a tight word budget (documented constraint in past decisions).
**How to avoid:** Replace the fixed wording "2-3 sentence Chinese summary" with a compact reference like "Chinese summary at user's depth_preference level (see summarize.md)". Keep the delta minimal.
**Warning signs:** SKILL.md exceeding its word budget.

### Pitfall 4: Not updating the output-templates.md control parameter table

**What goes wrong:** The "Output Control Parameters" table in output-templates.md still says "Summary length: 2-3 sentences" as a fixed value, contradicting the variable-depth behavior.
**Why it happens:** The table is easy to overlook since it is metadata, not executable logic.
**How to avoid:** Update the row to reflect depth_preference-dependent length.
**Warning signs:** Documentation inconsistency found during re-audit.

## Exact Changes Required

### File 1: `references/processing-instructions.md` Section 1 "Summarization Batch"

**Current** (lines 186-197):
```
1. **Load prompt**: Read `references/prompts/summarize.md`
2. **Fill batch data**: For each item, format into the input template: ...
3. **Process**: Use the filled prompt template to generate summaries
4. **Parse response**: ...
5. **Update items**: ...
```

**Required** -- insert step 1.5 and modify step 2:
```
1. **Load prompt**: Read `references/prompts/summarize.md`
1.5 **Load depth preferences**: Read `config/preferences.json`. Extract `depth_preference` (default `"moderate"` if absent) and `judgment_angles` (default `[]` if absent). Fill the prompt's User Preferences Context section: `{depth_preference}` and `{judgment_angles}`.
2. **Fill batch data**: For each item, format into the input template: ...
3. **Process**: Use the filled prompt template to generate summaries
4. **Parse response**: ...
5. **Update items**: ...
```

### File 2: `SKILL.md` Processing Phase step 4

**Current:**
```
4. **Summarize batch**: Group 5-10 items per LLM call. Generate 2-3 sentence Chinese summary.
```

**Required:**
```
4. **Summarize batch**: Group 5-10 items per LLM call. Read `depth_preference` and `judgment_angles` from `config/preferences.json`, inject into `references/prompts/summarize.md`. Generate Chinese summary at configured depth.
```

### File 3: `references/output-templates.md` Output Control Parameters table

**Current row:**
```
| Summary length | 2-3 sentences | Per-item summary length |
```

**Required row:**
```
| Summary length | depth_preference-dependent | brief=1 sentence, moderate=2-3, detailed=3-5, technical=3-5+specs |
```

### File 4: `references/feedback-rules.md` Style adjustment mapping table (OPTIONAL but recommended)

The style adjustment mapping table has no entries for `depth_preference` or `judgment_angles`. While users can set these through general feedback interpretation, adding explicit mappings would close the user-facing loop:

```
| "more detail" / "detailed summaries" | depth_preference | set to "detailed" |
| "brief summaries" / "shorter" | depth_preference | set to "brief" |
| "technical depth" / "include technical details" | depth_preference | set to "technical" |
| "care about {angle}" / "show {angle}" | judgment_angles | append angle if valid |
| "don't care about {angle}" | judgment_angles | remove angle if present |
```

This is optional for PREF-07 closure (the requirement is about wiring preference fields through the summarization path, not about feedback-to-preference input), but it completes the end-to-end user experience.

## Verification Checklist (for re-audit)

After implementation, these statements must be TRUE:

1. `references/processing-instructions.md` Section 1 Summarization Batch includes a step that reads `config/preferences.json` and injects `depth_preference` and `judgment_angles` into the summarize prompt
2. `SKILL.md` Processing Phase step 4 does NOT say "2-3 sentence" as a fixed description
3. `references/output-templates.md` Output Control Parameters table reflects variable depth
4. Re-running the audit check for MISSING-01 finds the daily consumer now reads and injects preference depth and angles
5. Re-running the audit check for BROKEN-01 finds the daily depth control E2E flow complete: preferences -> summarize prompt -> variable-depth output

## Sources

### Primary (HIGH confidence)
- `references/processing-instructions.md` -- direct inspection of Section 1 Summarization Batch (lines 186-197) and Section 7 Weekly Report (line 712)
- `references/prompts/summarize.md` -- direct inspection of placeholders (lines 9-10) and depth rules (lines 21-30)
- `SKILL.md` -- direct inspection of Processing Phase step 4
- `references/data-models.md` -- direct inspection of Preferences schema (lines 276-308)
- `config/preferences.json` -- direct inspection of current field values
- `.planning/v1.0-MILESTONE-AUDIT.md` -- audit findings for MISSING-01, BROKEN-01, PREF-07
- `references/feedback-rules.md` -- style adjustment mapping (lines 26-38) and preference visualization (lines 181-182)
- `references/output-templates.md` -- Output Control Parameters table (lines 82-88)

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` decisions log -- Phase 3 and Phase 4 decisions about depth_preference wiring

## Metadata

**Confidence breakdown:**
- Architecture: HIGH - all affected files inspected directly, gap is precisely identified
- Changes required: HIGH - exact line-level changes documented from source inspection
- Pitfalls: HIGH - backward compatibility concern explicitly addressed by prior Phase 4 decision

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable -- no external dependencies, all changes are internal documentation)
