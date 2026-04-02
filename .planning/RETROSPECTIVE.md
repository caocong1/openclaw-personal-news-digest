# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 - MVP

**Shipped:** 2026-04-02
**Phases:** 7 | **Plans:** 18

### What Was Built
- Complete personalized news digest skill with 6 source types, LLM-driven classification/summarization, 3-layer dedup, and event merging
- 7-layer preference model with feedback learning, decay, and anti-echo-chamber quota system
- Daily digest, breaking news alerts, and weekly trend reports with NL history queries
- Monitoring, cost controls, and per-source metrics for source health automation

### What Worked
- Modular `SKILL.md` design plus `references/` kept complexity manageable
- Milestone audit plus targeted gap-closure phases caught integration wiring issues before shipping
- High execution velocity across a large set of planning documents and prompt contracts
- Upfront multi-model design review produced decisions that survived implementation

### What Was Inefficient
- `ROADMAP.md` progress tracking went stale during execution
- The first milestone audit happened before all gap-closure phases existed
- Some summary metadata was inconsistent enough to break automated extraction

### Patterns Established
- Atomic writes (`tmp + mv`) for JSON modifications
- Schema versioning with backward-compatible defaults
- Backup-before-write with retention for preference safety
- Per-session cumulative caps to prevent feedback runaway

### Key Lessons
1. Run milestone audits after the follow-up phases they imply actually finish.
2. Treat `SKILL.md` word budget as a hard constraint from the start.
3. Define cross-phase data contracts early, especially for metrics and observability fields.

### Cost Observations
- Model mix favored high-quality planning and execution over minimal token use
- Phase 1 was the main scope outlier; later phases were much tighter

---

## Milestone: v2.0 - Quality & Robustness

**Shipped:** 2026-04-03
**Phases:** 6 | **Plans:** 16

### What Was Built
- Operator-ready documentation, including a full root `README.md`
- Chinese-localized rendering contracts, prompt-version cache invalidation, bootstrap verification, and deterministic fixtures
- Noise-floor controls, stronger classification prompts, delta-alert behavior, digest-history repetition suppression, and better transparency output
- Structured observability (`run_log`, schema registry, diagnostics) plus schedule profiles, source-status inspection, recommendation evidence, and dense-day timeline collapse

### What Worked
- Fixture-backed documentation changes kept prompt/config work verifiable even without a conventional test runner
- Summary frontmatter and verification reports gave enough evidence to reconcile stale roadmap/requirements state safely
- Quality hardening work layered cleanly on top of the MVP because earlier phases preserved additive, contract-first patterns

### What Was Inefficient
- `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md` drifted out of sync with completed work during the milestone
- Nyquist validation coverage remained partial or missing across several phases
- Some phase planning artifacts stayed uncommitted in the working tree, making milestone closure riskier than necessary

### Patterns Established
- Deterministic explainability should come from scoring and quota state, not generated prose
- Repo-backed operator state (`schedule-profiles.json`, fixtures, diagnostics scripts) is easier to audit than hidden runtime settings
- Documentation-only milestones still need explicit completion bookkeeping, not just per-phase verification

### Key Lessons
1. Milestone completion should reconcile `ROADMAP.md`, `REQUIREMENTS.md`, and `STATE.md` immediately after the last phase, not at archive time.
2. Validation artifacts need the same discipline as research, plan, summary, and verification documents if they are going to matter later.
3. For prompt/config-heavy projects, deterministic fixtures are the closest thing to durable regression tests and should be treated that way.

### Cost Observations
- `v2.0` delivered a large quality jump with comparatively contained execution time because the MVP contracts already existed
- The biggest hidden cost was document reconciliation, not feature implementation

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 7 | 18 | Initial delivery with audit-driven gap closure |
| v2.0 | 6 | 16 | Contract hardening, observability, and operator UX improvements |

### Top Lessons (Verified Across Milestones)

1. Front-loading architecture and contract decisions pays off across later milestones.
2. Audits are only useful when the source-of-truth planning docs stay aligned with completed execution.
3. Deterministic fixtures and explicit schema/version registries are essential for prompt/config-heavy systems.
