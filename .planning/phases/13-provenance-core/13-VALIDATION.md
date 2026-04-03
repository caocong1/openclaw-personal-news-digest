---
phase: 13
slug: provenance-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 13 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual verification via JSON/JSONL fixtures, schema reads, and grep checks |
| **Config file** | none - prompt/config/reference-doc repo, no formal test runner |
| **Quick run command** | `python3 -c "import json; json.load(open('config/t1-sources.json')); json.load(open('config/t2-sources.json'))" && rg -n "provenance|citation|cross-validation|tier-stats|provenance-discrepancies" SKILL.md references/processing-instructions.md references/data-models.md references/prompts/provenance-classify.md` |
| **Full suite command** | Manual: inspect provenance rule libraries, prompt contract, pipeline docs, provenance fixtures, and persistence schemas against the Phase 13 requirements |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick command for touched provenance docs/configs, then inspect the specific fixture or schema changed in that task
- **After every plan wave:** Run the full manual verification walkthrough for all new provenance artifacts in that wave
- **Before `$gsd-verify-work`:** All provenance fixtures, schemas, and precedence rules must agree on the same tier-resolution contract
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | PROV-02, DISC-05 | schema+doc | `python3 -c "import json; json.load(open('config/t1-sources.json')); json.load(open('config/t2-sources.json'))" && rg -n "t1-sources|t2-sources|pattern|priority|applies_to_subdomains" config/t1-sources.json config/t2-sources.json references/data-models.md` | [ ] W0 | pending |
| 13-01-02 | 01 | 1 | PROV-01, PROV-06 | schema+doc | `rg -n "data/provenance|provenance-db|citation-graph|tier-stats|provenance-discrepancies|Phase.*Provenance" SKILL.md references/processing-instructions.md references/data-models.md` | [ ] W0 | pending |
| 13-02-01 | 02 | 2 | PROV-03 | fixture+doc | `rg -n "citation|cited_sources|original link|according to|content_snippet" references/processing-instructions.md data/fixtures/news-items-provenance-sample.jsonl data/fixtures/citation-graph-sample.json` | [ ] W0 | pending |
| 13-02-02 | 02 | 2 | PROV-04 | prompt+doc | `rg -n "\"tier\"|\"original_source_name\"|\"original_source_url\"|\"cited_sources\"|propagation_hops|confidence" references/prompts/provenance-classify.md references/processing-instructions.md` | [ ] W0 | pending |
| 13-03-01 | 03 | 3 | PROV-05 | doc+fixture | `rg -n "URL-rule wins|LLM wins|discrepanc|final_winner|rule_result|llm_result" references/processing-instructions.md references/data-models.md data/fixtures/provenance-discrepancies-sample.jsonl` | [ ] W0 | pending |
| 13-03-02 | 03 | 3 | PROV-06 | fixture | `python3 -c "import json; json.load(open('data/fixtures/provenance-db-sample.json')); json.load(open('data/fixtures/citation-graph-sample.json')); json.load(open('data/fixtures/tier-stats-sample.json'))" && rg -n "provenance_chain|classified_at|tier_confidence|tier_source" data/fixtures/provenance-db-sample.json references/data-models.md` | [ ] W0 | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `config/t1-sources.json` - T1 rule-library scaffold with parseable JSON and category metadata
- [ ] `config/t2-sources.json` - T2 rule-library scaffold with parseable JSON and category metadata
- [ ] `references/prompts/provenance-classify.md` - provenance prompt contract used by Plan 13-02
- [ ] `data/fixtures/news-items-provenance-sample.jsonl` - mixed direct-source and aggregator sample items
- [ ] `data/fixtures/provenance-db-sample.json` - authoritative provenance store sample
- [ ] `data/fixtures/citation-graph-sample.json` - provenance citation graph sample
- [ ] `data/fixtures/provenance-discrepancies-sample.jsonl` - rule-vs-LLM disagreement sample
- [ ] `data/fixtures/tier-stats-sample.json` - tier distribution sample

*Existing infrastructure covers JSON storage and grep/manual review, but Phase 13 needs dedicated provenance fixtures to make verification concrete.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| URL-rule preclassification really avoids the LLM for known official domains | PROV-02 | Requires reading both rule-library examples and pipeline wording together | Confirm `SKILL.md` and `references/processing-instructions.md` state that known T1/T2 matches resolve before provenance LLM batching, and confirm fixtures include an official-domain example |
| Citation extraction captures upstream references without pretending to be a crawler | PROV-03 | Regex examples and sample snippets need semantic review | Read the sample item fixture and ensure extraction rules only use available snippet/markup context, not hidden page fetches |
| Cross-validation preserves why the final tier won | PROV-05 | A grep can find fields but not prove the reasoning is reconstructable | Read the discrepancy fixture and confirm it records both candidate results plus the final winner or resolution reason |
| Provenance chain reconstruction is actually possible for an indirect item | PROV-06 | Requires tracing multiple stores together | Use the aggregator example in fixtures to trace `NewsItem.id` to `provenance-db`, then confirm its cited sources appear in `citation-graph` and the chain is intelligible |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
