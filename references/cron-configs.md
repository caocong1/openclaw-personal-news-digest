# Cron Job Configurations

Reference document for registering cron jobs on the OpenClaw platform. Each job is defined as a JSON object passed to the `cron` tool.

## Schedule Profiles

`config/schedule-profiles.json` is the source of truth for named deployment schedules. The `active_profile` value selects which repo-backed profile should be applied to the platform cron jobs.
The `schedule_management` intent in `references/feedback-rules.md` is the canonical entry point for profile selection and schedule updates.

| Profile | Purpose |
|--------|---------|
| `daily-default` | Default all-days schedule |
| `weekday-only` | Weekdays only with business-hours quick checks |
| `custom-hours` | Editable example profile for user-defined hours |

Each profile maps onto the same four OpenClaw cron jobs by `job_name`: `news-daily-digest`, `news-quick-check`, `weekly-health-inspection`, and `news-weekly-report`.

**Apply flow**
1. Read `config/schedule-profiles.json` and resolve the `active_profile`.
2. For each job in that profile, run `cron edit <job_name>` and inspect the returned job configuration.
3. If the job is enabled, use `cron create` with the job JSON below or the platform's update path to apply the profile's `expr`.
4. If the job is disabled, run `cron disable <job_name>` instead of deleting the profile entry.

**Management commands**

| Intent | Operator command |
|--------|------------------|
| List profiles | `list schedule profiles` |
| Show active profile | `show active schedule profile` |
| Activate a profile | `activate weekday-only profile` |
| Adjust digest time | `set custom-hours digest to 09:30` |
| Adjust quick-check hours | `set custom-hours quick check to 09,13,17` |

## Daily Digest Job

Runs the full AI-native pipeline once per day at 08:00 CST (Asia/Shanghai). Executes the Collection, Provenance, Processing, Source Discovery, and Output phases, then pushes the generated digest to the chat channel.

```json
{
  "name": "news-daily-digest",
  "schedule": { "kind": "cron", "expr": "0 8 * * *", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Execute the AI-native daily news digest pipeline: run Bootstrap/lock, Collection, Provenance, Processing, Source Discovery, and Output phases; score and rank items, generate the daily digest, update daily metrics, release the lock, and deliver the complete digest.",
    "lightContext": false,
    "timeoutSeconds": 600
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "{target_chat_id}"
  }
}
```

## Quick Check Job (Phase 1+)

Runs every 2 hours to detect breaking news with AI-native alert scoring. It runs Collection + Processing, evaluates processed candidates with `references/prompts/alert-score.md`, applies the existing alert gates, and only delivers a fresh alert when an item is breaking and crosses the alert threshold.

```json
{
  "name": "news-quick-check",
  "schedule": { "kind": "cron", "expr": "0 */2 * * *", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Execute the AI-native quick news check: run Collection + Processing, batch today's complete items through references/prompts/alert-score.md, apply roundup, already-alerted URL, daily cap, and per-run cap gates, then generate and deliver a fresh breaking news alert only when is_breaking is true and alert_score >= 0.85. If no item qualifies, reply with nothing.",
    "lightContext": false,
    "timeoutSeconds": 300
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "{target_chat_id}"
  }
}
```

## Weekly Health Inspection Job (Phase 2+)

Runs full health inspection and data lifecycle management every Monday at 03:00 CST. Reviews recent run metrics, source health, lock/backlog state, alert/digest outputs, and data retention needs. Only delivers a report if alerts or warnings are found.

```json
{
  "name": "weekly-health-inspection",
  "schedule": { "kind": "cron", "expr": "0 3 * * 1", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Run the AI-native weekly health inspection and data lifecycle review: inspect recent daily metrics, source health trends, lock/backlog state, alert and digest outputs, and retention cleanup needs; report findings via the delivery channel only when alerts or warnings are found.",
    "lightContext": false,
    "timeoutSeconds": 300
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "{target_chat_id}",
    "onlyIf": "alerts or warnings found"
  }
}
```

## Weekly Report Job (Phase 3+)

Runs weekly report generation every Sunday at 20:00 CST. Aggregates 7 days of news data, computes category trends, collects event timelines, synthesizes cross-domain connections using strong model tier.

```json
{
  "name": "news-weekly-report",
  "schedule": { "kind": "cron", "expr": "0 20 * * 0", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Generate the weekly news digest report: aggregate last 7 days of news data, compute category trends, collect event timelines, synthesize cross-domain connections, generate weekly report, update weekly metrics.",
    "lightContext": false,
    "timeoutSeconds": 600
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "{target_chat_id}"
  }
}
```

Key config notes:
- Schedule: `0 20 * * 0` = Sunday 20:00 CST (day 0 = Sunday)
- Timeout: 600 seconds (10 min) -- weekly report needs LLM strong model synthesis which takes longer
- lightContext: false (required for SKILL.md loading, per Phase 0 decision)
- sessionTarget: isolated (clean session per cron run)

---

## Configuration Notes

### Critical Settings

- **`lightContext: false`** -- REQUIRED. When set to `true`, workspace skills (SKILL.md) are NOT loaded into the session context. The agent would have no instructions and the pipeline would not execute. This was identified as a critical pitfall during research.
- **`sessionTarget: "isolated"`** -- Each cron run gets a clean, independent session. This prevents state leakage between runs (e.g., stale variables, partial context from previous failures).
- **`timeoutSeconds: 600`** (10 min) for daily digest; `300` (5 min) for quick check. The daily digest processes ~50 items across the full AI-native pipeline and needs more time. Quick check runs Collection + Processing plus AI-native alert scoring over today's completed items.

### Delivery Settings

- **`mode: "announce"`** -- Pushes the generated content (output/latest-digest.md) to the chat channel after the agent turn completes.
- **`channel: "telegram"`** -- Target delivery channel. Change to match your actual channel if not using Telegram.
- **`{target_chat_id}`** -- Placeholder. Replace with your actual Telegram chat ID before registering.

### Placeholder Replacement

Before registering, replace:
- `{target_chat_id}` with your Telegram chat ID (numeric, e.g., `123456789`)

## Managing Cron Jobs

All management is done via the `cron` tool in an OpenClaw chat session:

| Action | Command |
|--------|---------|
| Register a job | `cron create` (paste the JSON config) |
| List all jobs | `cron list` |
| Disable temporarily | `cron disable news-daily-digest` |
| Re-enable | `cron enable news-daily-digest` |
| Delete permanently | `cron delete news-daily-digest` |
| View job details | `cron edit news-daily-digest` (inspect returned config) |

## Recommended Setup Order

1. First complete platform verification (see `references/platform-verification.md`)
2. Register the daily digest job
3. Wait for first execution at 08:00 CST next day, or trigger manually
4. Verify digest appears in chat channel
5. Optionally register the quick check job (Phase 1+)
6. Register the weekly health inspection job (Phase 2+)
7. Register the weekly report job (Phase 3+)
