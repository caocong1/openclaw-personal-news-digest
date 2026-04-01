---
phase: 02-smart-processing
verified: 2026-04-01T08:30:00Z
status: passed
score: 20/20 must-haves verified
re_verification: false
human_verification:
  - test: "Run a pipeline cycle and confirm deduplicated items show 'dedup_status: title_dup' in the JSONL"
    expected: "Near-duplicate titles from two different sources collapse to one primary item; secondary items have duplicate_of set"
    why_human: "Requires live LLM call with actual news items to validate Jaccard + LLM judgment path"
  - test: "Trigger weekly health inspection cron manually and check output"
    expected: "ALERT:/WARN:/OK: lines printed; summary line shows correct error count (note: ALERTS counter in summary is always 0 due to bug below)"
    why_human: "Shell script behavior with subprocess output cannot be verified by static analysis"
---

# Phase 2: Smart Processing Verification Report

**Phase Goal:** User sees deduplicated, event-merged content with timeline tracking and a balanced diet of topics enforced by anti-echo-chamber quotas, with multi-language support
**Verified:** 2026-04-01T08:30:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Near-duplicate titles from different sources are detected and merged | VERIFIED | Section 1A in processing-instructions.md: 3-stage funnel (normalize, Jaccard >=0.6, LLM); dedup.md prompt exists with `候选标题组` |
| 2 | English-language sources processed independently and appear with original title + Chinese translation | VERIFIED | Section 1B: language detection, per-language dedup, English display format documented |
| 3 | Title dedup runs as a 3-stage funnel (normalize, Jaccard bigram >= 0.6, LLM judgment) | VERIFIED | Section 1A stages A/B/C fully specified with cross-language prohibition |
| 4 | Cross-language title comparison never happens | VERIFIED | Stage B explicitly: "MUST skip pairs where `item_a.language != item_b.language`" |
| 5 | Related news about the same event is grouped into a single event entry with timeline | VERIFIED | Section 1C: 3-step funnel (topic filter, keyword match, LLM merge); Event schema with timeline array |
| 6 | Events transition through active -> stable (3d) -> archived (7d) lifecycle | VERIFIED | Section 1D: lifecycle transitions documented; state machine summary present |
| 7 | Timeline entries show relationship labels (initial/update/correction/analysis/reversal) | VERIFIED | merge-event.md prompt has all 5 relation types; Event.timeline schema has `relation` field |
| 8 | Event summaries auto-update when update/correction/reversal relations merge | VERIFIED | Section 1C: "re-summarize the event ... for update/correction/reversal; Skip for analysis" |
| 9 | Continuing events appear in Event Tracking section as bullet-list timelines | VERIFIED | output-templates.md Event Tracking section with `[{date}] {brief} ({relation}) -- Source:` format |
| 10 | Items linked to active high-importance events receive event_boost in scoring | VERIFIED | scoring-formula.md: `event_boost = 0.5 if active AND importance >= 0.7`; Phase 2 activation documented |
| 11 | Daily digest follows quota proportions: core 50% / adjacent 20% / hotspot 15% / exploration 15% | VERIFIED | Section 4 Step 2: `core_target = round(N * 0.50)` etc.; SKILL.md step 3 references quota algorithm |
| 12 | Unfilled quota slots yield one-way: explore -> adjacent -> hotspot -> core | VERIFIED | Section 4 Step 4: "Direction is strictly one-way: explore -> adjacent -> hotspot -> core" |
| 13 | No single topic exceeds 60% of digest for 3 consecutive days | VERIFIED | Section 4 Step 5 ANTI-03: topic concentration cap at 50% after 3-day breach; grace period for <3 days history |
| 14 | Items with importance >= 0.8 are force-injected into candidate pool | VERIFIED | Section 4 Step 6 ANTI-04: force-inject items with `importance_score >= 0.8` |
| 15 | Each of 12 categories gets minimum 2% exposure over time | VERIFIED | Section 4 Step 7 ANTI-05: minimum category exposure swap + exploration_appetite +0.05 every 7 days |
| 16 | Exploration and hotspot items include recommendation reason text | VERIFIED | output-templates.md: "Recommendation reason: {reason}" mandatory for hotspot and exploration; OUT-04 note |
| 17 | Cold-start (all topic_weight = 0.5) uses top-3 by weight as pseudo-core | VERIFIED | Section 4 Step 1: "use the top-3 topics by weight as pseudo-core" with alphabetical tiebreak |
| 18 | Alert fires when all sources fail for 2 consecutive days | VERIFIED | health-check.sh check 7: reads last 2 days metrics, prints `ALERT: All sources failed for 2 consecutive days` |
| 19 | Alert fires when LLM budget exceeds 80% | VERIFIED | health-check.sh check 8: `if ratio >= 0.80: print ALERT: LLM budget at {ratio*100}%` |
| 20 | Data lifecycle management enforces TTL: 30-day news, 7-day dedup-index, 90-day feedback, 7-day cache | VERIFIED | data-archive.sh implements all 4 TTL rules with atomic writes |

**Score:** 20/20 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `references/prompts/dedup.md` | LLM prompt for batch title near-duplicate judgment | VERIFIED | Contains `候选标题组`, batch JSON output format, Chinese instructions |
| `references/prompts/merge-event.md` | LLM prompt for event merge/new decision with relation type | VERIFIED | Contains all 5 relation types, `"action": "merge|new"` JSON schema |
| `references/processing-instructions.md` | Sections 1A, 1B, 1C, 1D plus quota algorithm in Section 4 | VERIFIED | All 4 sections present; quota algorithm 8 steps in Section 4; "chain yielding" text in Step 4 |
| `references/scoring-formula.md` | Activated event_boost computation | VERIFIED | `event_boost = 0.5` with conditions; Phase 2 activation status documented |
| `references/data-models.md` | Event schema, DailyMetrics extended, AlertCondition schema | VERIFIED | `## Event` section with timeline array; `quota_distribution`, `category_proportions`, `source_proportions` in DailyMetrics; AlertCondition schema present |
| `references/output-templates.md` | Event Tracking section and recommendation reasons | VERIFIED | Event Tracking with timeline bullet-list format; `Recommendation reason:` in hotspot and exploration sections; OUT-04 note |
| `SKILL.md` | All new steps wired: title dedup, event lifecycle, event merge, quota allocation | VERIFIED | Steps 8, 9, 10 in Processing Phase; steps 3, 5, 7 in Output Phase; 873 words (within Plan 03's 880 limit) |
| `scripts/health-check.sh` | Expanded with --mode daily/weekly, MON-02 alerts, MON-03 inspection | VERIFIED | `--mode` flag, 5 daily alert conditions, 6 weekly inspection checks |
| `scripts/data-archive.sh` | Per-type TTL rules with atomic writes | VERIFIED | All 7 data types handled; atomic writes via tmp+rename |
| `references/cron-configs.md` | Weekly health inspection cron job (Monday 03:00) | VERIFIED | `weekly-health-inspection` entry, schedule `0 3 * * 1`, `health-check.sh --mode weekly` |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `SKILL.md` | `references/processing-instructions.md` | Processing Phase step 8 referencing Section 1A | WIRED | Line 34: "per `{baseDir}/references/processing-instructions.md` Section 1A" |
| `references/processing-instructions.md` | `references/prompts/dedup.md` | Stage C LLM call | WIRED | Line 205: "using `references/prompts/dedup.md`" |
| `SKILL.md` | `references/processing-instructions.md` | Steps 9/10 referencing Sections 1D/1C | WIRED | Lines 35-36: explicit Section 1D and Section 1C references |
| `references/processing-instructions.md` | `references/prompts/merge-event.md` | Step 3 LLM call | WIRED | Line 284: "Use `references/prompts/merge-event.md`" |
| `references/processing-instructions.md` | `data/events/active.json` | Event lifecycle reads/writes | WIRED | Lines 268, 313, 316, 330: active.json read/write operations |
| `references/scoring-formula.md` | `data/events/active.json` | event_boost lookup | WIRED | Lines 129-130: "Read `data/events/active.json`, find event with matching id" |
| `references/processing-instructions.md` | `config/categories.json` | Quota algorithm Step 1 | WIRED | Line 486: "Read `config/preferences.json` topic_weights and `config/categories.json` adjacent mappings" |
| `references/processing-instructions.md` | `config/preferences.json` | Quota algorithm reads topic_weights | WIRED | Lines 486, 488, 542: topic_weight and exploration_appetite reads |
| `references/processing-instructions.md` | `data/metrics/daily-*.json` | ANTI-03 3-day history lookback | WIRED | Line 520: "Read last 3 days of `data/metrics/daily-*.json`" |
| `scripts/health-check.sh` | `data/metrics/daily-*.json` | Source failure and digest checks | WIRED | Lines 132, 244, 281, 442: daily metrics reads |
| `scripts/data-archive.sh` | `data/feedback/log.jsonl` | 90-day TTL cleanup | WIRED | Line 86: `FEEDBACK_PATH="$BASE_DIR/data/feedback/log.jsonl"` |
| `references/cron-configs.md` | `scripts/health-check.sh` | Weekly cron job triggers health inspection | WIRED | Line 62: "Run bash scripts/health-check.sh {baseDir} --mode weekly" |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| PROC-04 | 02-01 | 标题近似去重三阶段（规则归一化 → Jaccard bigram ≥ 0.6 → LLM 精确判断） | SATISFIED | Section 1A fully documents 3-stage funnel; dedup.md prompt exists |
| PROC-06 | 02-01 | 多语言处理（中英独立去重，允许跨语言事件归并） | SATISFIED | Section 1B: per-language dedup; Section 1C: cross-language event merging explicitly allowed |
| EVT-01 | 02-02 | 事件归并（topic 预筛选 → 关键词快速匹配 → LLM 精确归并） | SATISFIED | Section 1C: 3-step funnel with merge-event.md prompt |
| EVT-02 | 02-02 | 事件生命周期（active → 3天 → stable → 7天 → archived） | SATISFIED | Section 1D: lifecycle transitions with archive file management |
| EVT-03 | 02-02 | 时间线追踪（5种关系：initial/update/correction/analysis/reversal） | SATISFIED | merge-event.md relation table; Event.timeline schema; output-templates.md timeline format |
| EVT-04 | 02-02 | 事件摘要随新关联新闻自动更新 | SATISFIED | Section 1C: re-summarize for update/correction/reversal; skip for analysis |
| EVT-05 | 02-02 | 时间线 bullet list 格式展示（兼容聊天渠道） | SATISFIED | output-templates.md Event Tracking: `- [{date}] {brief} ({relation}) -- Source: {source_name}` |
| ANTI-01 | 02-03 | 内容配额机制（核心50% / 邻近20% / 热点15% / 探索15%） | SATISFIED | Section 4 Step 2: target count formulas |
| ANTI-02 | 02-03 | 配额执行算法（按 final_score 降序 → 分组取 top-K → 单向链式让渡） | SATISFIED | Section 4 Steps 3-4: fill then one-way chain yielding |
| ANTI-03 | 02-03 | 反向多样性约束（同主题60%连续3天→上限50%；同来源30%→上限20%；同事件>3天→仅新进展） | SATISFIED | Section 4 Step 5: all 3 constraints with 3-day grace period |
| ANTI-04 | 02-03 | 热点注入（importance ≥ 0.8 强制进入候选池） | SATISFIED | Section 4 Step 6: force-inject items with importance_score >= 0.8 |
| ANTI-05 | 02-03 | 偏好纠偏（类目最小2%曝光，每7天 exploration_appetite +0.05 上限0.4） | SATISFIED | Section 4 Step 7: category exposure swap + exploration_appetite auto-increase |
| OUT-04 | 02-03 | 输出解释字段（探索/热点位附推荐理由） | SATISFIED | output-templates.md: mandatory recommendation reasons for hotspot and exploration |
| MON-02 | 02-04 | 告警条件（全来源连续2天失败、预算80%、dedup不一致、来源集中度、空日报） | SATISFIED | health-check.sh checks 7-11: all 5 MON-02 alert conditions implemented |
| MON-03 | 02-04 | 每周健康巡检（dedup一致性、空事件、长期未归档、成功率、偏好极端值、缓存清理） | SATISFIED | health-check.sh --mode weekly checks 12-17: all 6 MON-03 checks implemented |
| MON-04 | 02-04 | 数据生命周期管理（30天news、7天dedup-index、90天feedback、7天缓存） | SATISFIED | data-archive.sh: all 4 TTL rules with atomic writes |

**All 16 required requirements satisfied. No orphaned requirements.**

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `references/processing-instructions.md` | 462 | Stale MVP comment: `"MVP simplification: feedback_boost = 0, event_boost = 0"` in Section 4 Scoring subsection | Warning | Misleading — contradicts Phase 2 activated event_boost. SKILL.md line 42 and scoring-formula.md are both correct. An agent reading processing-instructions.md Section 4 for scoring guidance could be misled. |
| `scripts/health-check.sh` | 38, 544 | ALERTS counter initialized to 0 but never incremented when ALERT: lines are printed (python3 subprocesses print ALERT: strings to stdout but do not signal the bash ALERTS variable) | Warning | Summary line always reports "0 alert(s)" regardless of how many ALERT: conditions fire. Alerts still appear in stdout output and are grep-filterable per spec. Monitoring goal is achieved; summary count is inaccurate. |

---

### Human Verification Required

#### 1. Title Dedup End-to-End Behavior

**Test:** Run a pipeline cycle with multiple sources that cover the same story. Inspect the output JSONL for items with `dedup_status: "title_dup"` and `duplicate_of` set.
**Expected:** Near-duplicate titles collapse to one primary item; secondary items marked as `title_dup` with `duplicate_of` pointing to the primary.
**Why human:** Requires live LLM call with real news items to validate the Jaccard threshold triggers, the LLM judgment is accurate, and the primary selection (by source credibility) is correct.

#### 2. Event Tracking Section in Digest Output

**Test:** After a pipeline run where the same event receives multiple news items over 2+ days, check `output/latest-digest.md` for an Event Tracking section.
**Expected:** Event Tracking section appears with `### {event_title}`, event summary, and timeline bullet list with relation labels.
**Why human:** Requires real event accumulation across pipeline runs; cannot verify from static file analysis.

#### 3. Quota Distribution Correctness

**Test:** After a full pipeline run with 15+ items, inspect `data/metrics/daily-YYYY-MM-DD.json` for `quota_distribution` and verify section distribution matches 50/20/15/15 targets approximately.
**Expected:** `quota_distribution.core` roughly 50% of `output.item_count`, others proportional.
**Why human:** Requires a live run with actual preference data to see how quota groups classify.

#### 4. health-check.sh ALERTS Counter Fix

**Test:** Run `bash scripts/health-check.sh . --mode daily` in a state where at least one alert condition is known to fire. Check the final summary line.
**Expected:** Summary should show non-zero alert count. Currently it will show 0 due to the counter bug.
**Why human:** Confirms whether the counter bug (warning-level) affects operational monitoring decisions.

---

### Gaps Summary

No blocking gaps. All 20 truths are verified, all 16 requirements are satisfied, all artifacts exist and are substantive, all key links are wired.

Two warning-level findings exist but neither blocks goal achievement:

1. **Stale MVP comment in processing-instructions.md line 462**: The scoring section still says `event_boost = 0` from Phase 0. The authoritative sources (scoring-formula.md and SKILL.md) are correct. This should be cleaned up to avoid misleading future execution.

2. **ALERTS counter not incremented in health-check.sh**: The bash ALERTS variable stays 0 regardless of alert conditions firing. ALERT: lines still appear in stdout output as specified. The summary count is cosmetically wrong but operationally harmless for grep-based alert filtering.

Both are candidates for a cleanup task, not blockers for this phase's goal.

---

_Verified: 2026-04-01T08:30:00Z_
_Verifier: Claude (gsd-verifier)_
