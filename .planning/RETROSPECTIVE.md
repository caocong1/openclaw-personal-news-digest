# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-04-02
**Phases:** 7 | **Plans:** 18

### What Was Built
- Complete personalized news digest Skill with 6 source types, LLM-driven classification/summarization, 3-layer dedup, and event merging
- 7-layer preference model with feedback learning, decay, and anti-echo-chamber quota system
- Daily digest, breaking news alerts, and weekly trend reports with NL history queries
- Monitoring, cost controls, and per-source metrics for source health automation

### What Worked
- Modular SKILL.md design (< 3000 tokens) with references/ kept complexity manageable
- Milestone audit → targeted gap-closure phases (5 + 6) caught integration wiring issues before shipping
- High velocity: 18 plans across 7 phases completed in ~1.5 hours of execution time
- 6-model design review (gpt-plan-v3.md) front-loaded quality decisions that held through implementation

### What Was Inefficient
- ROADMAP progress table became stale — phases 1-4 and 6 showed "Not started" despite being complete
- Milestone audit was done before all follow-up phases existed, requiring re-interpretation of gap status
- Some phase summaries lacked one_liner fields, breaking automated extraction

### Patterns Established
- Atomic writes (tmp+mv) for all JSON modifications
- Schema versioning with backward-compatible defaults
- Backup-before-write with 10-backup retention
- Per-session cumulative caps to prevent feedback runaway
- Additive-only integration fixes to preserve backward compatibility

### Key Lessons
1. Milestone audits should run after all gap-closure phases complete, not before — avoids confusion about which gaps are still open
2. SKILL.md word budget is a real constraint; every new feature requires compacting existing content
3. per_source metrics contracts should be defined alongside aggregate metrics from the start, not wired retroactively

### Cost Observations
- Model mix: primarily opus for planning/execution, sonnet for subagents
- Notable: average plan execution ~5 min; Phase 1 was the outlier at 11.5 min/plan due to largest scope

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 7 | 18 | Initial delivery with audit-driven gap closure |

### Top Lessons (Verified Across Milestones)

1. Front-loading design review with multiple AI models produces decisions that survive implementation
2. Targeted gap-closure phases are more effective than reopening completed phases
