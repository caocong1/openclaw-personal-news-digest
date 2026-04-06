# Requirements: OpenClaw News Digest Skill

**Defined:** 2026-04-06
**Core Value:** Replace "pushing messages to the user" with "continuously observing the world on the user's behalf" while preserving anti-echo-chamber exposure
**Source:** Multi-CLI audit report (7 CLI runs, 2 rounds, ground-truth verified)

## v4.0 Requirements

Requirements for quick-check audit fixes. Each maps to roadmap phases.

### P0 Infrastructure (data loss / silent crash prevention)

- [x] **INFRA-01**: Concurrent cron runs are prevented via non-blocking file lock (`fcntl.flock`), second instance exits cleanly (B4)
- [x] **INFRA-02**: State and metrics files are written atomically via tmp+fsync+os.replace — mid-write crash never corrupts state (B1)
- [x] **INFRA-03**: State file is persisted BEFORE alert file is published — crash between writes never causes duplicate alerts on next run (B2)

### P1 Logic Bugs (incorrect behavior)

- [x] **LOGIC-01**: Alert sort preserves `importance_score` as tiebreaker — the buggy second sort that erases LLM-derived importance is removed (B8)
- [x] **LOGIC-02**: Daily alert cap is enforced at 3 per SKILL.md spec — `MAX_ALERTS_PER_RUN` set to 3, remaining computed from state (B5)
- [x] **LOGIC-03**: Union-find cluster ID lookup uses `enumerate` instead of `alerts.index()` — eliminates O(n^2) and wrong-cluster bug with dict-equal records (B11)
- [x] **LOGIC-04**: Dollar-amount-only anchor no longer merges unrelated events — requires a second non-generic anchor for merge (B9)

### Dead Code Cleanup

- [x] **CLEAN-01**: Dead constant `MAX_ALERTS_PER_DAY = None` is removed (B15)
- [x] **CLEAN-02**: Dead constant `ALERT_THRESHOLD = 0.85` is removed — never referenced in code (B14)
- [x] **CLEAN-03**: Dead function `normalize_event_key()` (42 lines) is removed — deferred B7 activation to future milestone (B13)

## v5.0 Requirements (Deferred)

### AI-First Scoring Migration

- **TIER-01**: classify.md prompt outputs a `tier` field for LLM-native importance classification
- **TIER-02**: `ai_score_item()` (184 lines keyword matching) replaced by tier-based scoring from classify.md
- **TIER-03**: Shadow-mode A/B comparison runs 7 days before cutover
- **TIER-04**: `--legacy-scoring` CLI switch enables instant rollback without code deploy

### Cross-Run Event Suppression

- **EVENT-01**: `normalize_event_key()` activated and wired into state for cross-run event dedup (B7)
- **EVENT-02**: Alert gate aligned with SKILL.md spec (`importance_score >= 0.85 + form_type filter`) (B6)

### Ops Hardening

- **OPS-01**: Additional metrics (ai_score_distribution, tier_distribution, event_merge_collision_rate, etc.)
- **OPS-02**: Negative test cases (0-candidate day, 50+ burst day, mid-write kill, concurrent cron)

## Out of Scope

| Feature | Reason |
|---------|--------|
| B3 http_get timeout fix | Debunked in Part II — code already has timeout=20 and per-source try/except |
| B10 transitive union-find guard | Complex architectural change, better addressed with B9 fix + future tier migration |
| B12 empty-anchor fallback | Low frequency, better solved by LLM tier classification in v5.0 |
| `score_item()` deletion | Daily pipeline reads `importance_score` from JSONL — must verify no consumers before removing |
| Full `ai_score_item()` deletion | Requires tier migration (TIER-01/02) — unsafe without shadow-mode validation |
| Phase 5 ops metrics | Independent work, not blocking P0/P1 fixes |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 20 | Complete |
| INFRA-02 | Phase 20 | Complete |
| INFRA-03 | Phase 20 | Complete |
| LOGIC-01 | Phase 21 | Complete |
| LOGIC-02 | Phase 21 | Complete |
| LOGIC-03 | Phase 21 | Complete |
| LOGIC-04 | Phase 21 | Complete |
| CLEAN-01 | Phase 22 | Pending |
| CLEAN-02 | Phase 22 | Pending |
| CLEAN-03 | Phase 22 | Pending |

**Coverage:**
- v4.0 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-04-06*
*Last updated: 2026-04-06 after roadmap creation*
