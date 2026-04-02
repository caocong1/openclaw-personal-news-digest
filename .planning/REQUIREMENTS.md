# Requirements: OpenClaw News Digest Skill

**Defined:** 2026-04-02
**Core Value:** Replace "pushing messages to user" with "continuously observing the world on behalf of the user" — deep personalization with anti-echo-chamber awareness

## v2.0 Requirements

Requirements for quality & robustness release. Each maps to roadmap phases.

### Documentation

- [ ] **DOC-01**: Project root has README.md with architecture, deployment instructions, configuration guide, and operational scripts documentation

### Localization

- [x] **L10N-01**: Daily digest output uses Chinese labels for all section headers and metadata
- [x] **L10N-02**: Breaking alert output uses Chinese labels (【快讯】format)
- [x] **L10N-03**: Weekly report output uses Chinese labels for all sections
- [x] **L10N-04**: Summarize and weekly-report prompts enforce Chinese-output rule

### Data Quality

- [x] **QUAL-01**: Pre-write quality contract validates UTF-8 sanitization and title validation for all source types
- [x] **QUAL-02**: Quick-Check output strips JSON field names from alert rendering
- [x] **QUAL-03**: Output templates define rendering contract separating user-facing vs internal fields

### Infrastructure

- [x] **INFRA-01**: Cache entries include prompt_version field; version mismatch triggers cache miss
- [x] **INFRA-02**: Data models include bootstrap & migration section with new fields registry
- [x] **INFRA-03**: SKILL.md verifies required directories on first run
- [x] **INFRA-04**: Test fixture directory with deterministic fixture files for all verification scenarios

### Noise Filtering

- [ ] **NOISE-01**: Pre-classify noise filter skips items matching source noise_patterns (zero LLM cost)
- [ ] **NOISE-02**: Post-classify filter marks items with importance < 0.25 as digest_eligible: false
- [ ] **NOISE-03**: Filtered items excluded from scoring pool but retained in JSONL for history queries
- [ ] **NOISE-04**: Source schema supports noise_patterns and title_discard_patterns in fetch_config
- [ ] **NOISE-05**: DailyMetrics tracks noise_filter_suppressed count

### Classification

- [ ] **CLASS-01**: Classify prompt strengthened with 0.0-0.2 tier, borderline examples, disambiguation rules
- [ ] **CLASS-02**: Category config supports negative_examples field included in prompt assembly
- [ ] **CLASS-03**: Cache version bumped from classify-v1 to classify-v2

### Alert System

- [ ] **ALERT-01**: Daily alert state file (alert-state-YYYY-MM-DD.json) with 3-alert daily cap and URL dedup
- [ ] **ALERT-02**: Event objects store per-event alert memory (last_alerted_at, last_alert_news_id, last_alert_brief)
- [ ] **ALERT-03**: Quick-Check uses unified decision tree for alert eligibility
- [ ] **ALERT-04**: Delta alerts fire for event updates (update/correction/reversal/escalation relations)
- [ ] **ALERT-05**: Delta alert prompt and template show what changed vs previous alert
- [ ] **ALERT-06**: Fallback to standard alert when event context unavailable

### Dedup

- [ ] **DEDUP-01**: DigestHistory tracks last 5 runs with event_timeline_snapshot
- [ ] **DEDUP-02**: Cross-digest repetition penalty (0.7x) for events with no new timeline progress
- [ ] **DEDUP-03**: Output footer shows count of suppressed repeat items

### Observability

- [ ] **OBS-01**: source_count reflects enabled sources; footer shows failed source names
- [ ] **OBS-02**: DailyMetrics includes run_log array populated during pipeline execution
- [ ] **OBS-03**: Schema version registry with current versions and change history
- [ ] **OBS-04**: Diagnostics command reads metrics + alert-state + digest-history

### Interaction

- [ ] **INTERACT-01**: Scheduling profiles configurable via SKILL.md commands
- [ ] **INTERACT-02**: Source status command shows per-source health and enable/disable state
- [ ] **INTERACT-03**: Recommendations include structured evidence for why items were selected
- [ ] **INTERACT-04**: NL intent recognition table in feedback-rules.md (no duplication in SKILL.md)
- [ ] **INTERACT-05**: Rolling coverage collapses events with >5 items/day into timeline view

## Future Requirements

Deferred to future release. Tracked but not in current roadmap.

### Hardening

- **HARD-01**: Script over here-doc operability
- **HARD-02**: Alert governance with source confidence tiers and multi-source corroboration
- **HARD-03**: Pre-configured disabled source templates for expansion
- **HARD-04**: Render layer decoupling (content model vs template)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Runtime code changes | Prompt/config/reference-doc project only |
| New source integrations | Beyond pre-configured templates |
| UI/frontend changes | Not applicable to skill architecture |
| Multi-user support | Architecture change deferred to future |
| Embedding-based dedup | Current scale doesn't justify dependency |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOC-01 | Phase 7 | Pending |
| L10N-01 | Phase 8 | Complete |
| L10N-02 | Phase 8 | Complete |
| L10N-03 | Phase 8 | Complete |
| L10N-04 | Phase 8 | Complete |
| QUAL-01 | Phase 8 | Complete |
| QUAL-02 | Phase 8 | Complete |
| QUAL-03 | Phase 8 | Complete |
| INFRA-01 | Phase 8 | Complete |
| INFRA-02 | Phase 8 | Complete |
| INFRA-03 | Phase 8 | Complete |
| INFRA-04 | Phase 8 | Complete |
| NOISE-01 | Phase 9 | Pending |
| NOISE-02 | Phase 9 | Pending |
| NOISE-03 | Phase 9 | Pending |
| NOISE-04 | Phase 9 | Pending |
| NOISE-05 | Phase 9 | Pending |
| CLASS-01 | Phase 9 | Pending |
| CLASS-02 | Phase 9 | Pending |
| CLASS-03 | Phase 9 | Pending |
| ALERT-01 | Phase 10 | Pending |
| ALERT-02 | Phase 10 | Pending |
| ALERT-03 | Phase 10 | Pending |
| ALERT-04 | Phase 10 | Pending |
| ALERT-05 | Phase 10 | Pending |
| ALERT-06 | Phase 10 | Pending |
| DEDUP-01 | Phase 10 | Pending |
| DEDUP-02 | Phase 10 | Pending |
| DEDUP-03 | Phase 10 | Pending |
| OBS-01 | Phase 11 | Pending |
| OBS-02 | Phase 11 | Pending |
| OBS-03 | Phase 11 | Pending |
| OBS-04 | Phase 11 | Pending |
| INTERACT-01 | Phase 12 | Pending |
| INTERACT-02 | Phase 12 | Pending |
| INTERACT-03 | Phase 12 | Pending |
| INTERACT-04 | Phase 12 | Pending |
| INTERACT-05 | Phase 12 | Pending |

**Coverage:**
- v2.0 requirements: 38 total
- Mapped to phases: 38
- Unmapped: 0

---
*Requirements defined: 2026-04-02*
*Last updated: 2026-04-02 after roadmap creation*
