# Cron Job Configurations

Reference document for registering cron jobs on the OpenClaw platform. Each job is defined as a JSON object passed to the `cron` tool.

## Daily Digest Job

Runs the full pipeline once per day at 08:00 CST (Asia/Shanghai). Collects RSS, deduplicates, classifies/summarizes, scores, generates digest, pushes to chat channel.

```json
{
  "name": "news-daily-digest",
  "schedule": { "kind": "cron", "expr": "0 8 * * *", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Execute the daily news digest pipeline: collect RSS sources, deduplicate, classify/summarize new items, score and rank, generate daily digest, update metrics.",
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

Runs every 2 hours to detect breaking news. If any item scores importance >= 0.85, generates and delivers a breaking news alert. Otherwise does nothing.

```json
{
  "name": "news-quick-check",
  "schedule": { "kind": "cron", "expr": "0 */2 * * *", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Quick news check: collect RSS sources, deduplicate, classify new items only. If any item has importance_score >= 0.85, generate and deliver a breaking news alert. Otherwise, do nothing.",
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

## Configuration Notes

### Critical Settings

- **`lightContext: false`** -- REQUIRED. When set to `true`, workspace skills (SKILL.md) are NOT loaded into the session context. The agent would have no instructions and the pipeline would not execute. This was identified as a critical pitfall during research.
- **`sessionTarget: "isolated"`** -- Each cron run gets a clean, independent session. This prevents state leakage between runs (e.g., stale variables, partial context from previous failures).
- **`timeoutSeconds: 600`** (10 min) for daily digest; `300` (5 min) for quick check. The daily digest processes ~50 items with LLM calls and needs more time. Quick check only classifies new items.

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
| View job details | `cron get news-daily-digest` |

## Recommended Setup Order

1. First complete platform verification (see `references/platform-verification.md`)
2. Register the daily digest job
3. Wait for first execution at 08:00 CST next day, or trigger manually
4. Verify digest appears in chat channel
5. Optionally register the quick check job (Phase 1+)
