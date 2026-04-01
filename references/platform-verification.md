# Platform Capability Verification (PLAT-04)

Step-by-step verification checklist for confirming that the OpenClaw platform can execute the news digest pipeline in cron-triggered isolated sessions. Run this procedure once during initial setup.

**Requirements covered:** PLAT-01, PLAT-02, PLAT-03, PLAT-04

## Capability 1: Isolated Session File Access (PLAT-03)

**Purpose:** Confirm that a cron-triggered isolated session can read workspace files (SKILL.md, config/, references/) and write output files.

**Test procedure:**

1. Register a one-shot test cron job:
```json
{
  "name": "test-file-access",
  "schedule": { "kind": "once", "delay": "10s" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Read the file SKILL.md in the workspace and write its first line to output/test-access.txt",
    "lightContext": false
  }
}
```

2. Wait ~30 seconds for execution.

3. Verify:
   - `output/test-access.txt` exists
   - Content contains the SKILL.md frontmatter line (e.g., `---`)

**Pass criteria:** File created with correct content from SKILL.md.

**Fail action:** Check that `lightContext` is `false`. If still failing, the platform may not support workspace file access in isolated sessions -- contact platform support.

**Cleanup:** Delete `output/test-access.txt` and the cron job: `cron delete test-file-access`

---

## Capability 2: Exec Tool Permissions

**Purpose:** Confirm that `exec()` runs shell commands without interactive approval prompts in isolated sessions.

**Test procedure:**

1. In an isolated session (or via test cron job), run:
```
exec("echo hello from exec")
```

2. Expected result: Returns `hello from exec` without any approval dialog.

3. Test Python availability (needed for feedparser fallback):
```
exec("python3 -c \"import json; print(json.dumps({'test': True}))\"")
```

4. Expected result: Returns `{"test": true}`

**Pass criteria:** Both commands return expected output without approval prompts.

**Fail action:**
- If approval is required: Check if the platform has an `exec.ask` setting. Set to `"off"` for cron sessions.
- If Python is not available: The pipeline can still work (web_fetch + LLM parsing), but the feedparser fallback in references/data-models.md will not function. Document this limitation.

---

## Capability 3: Browser Availability

**Purpose:** Verify browser tool access for future phases (Phase 1+ full-text extraction). Not required for Phase 0 MVP.

**Test procedure:**

1. In an isolated session, run:
```
browser("https://example.com")
```

2. Expected result: Returns page content (HTML or rendered text).

**Pass criteria:** Page content returned successfully.

**Fail action:** Browser is NOT required for Phase 0 (RSS uses `web_fetch`). If unavailable, document the limitation for Phase 1 planning. The pipeline will still function for Phase 0 without browser access.

**Note:** This is a forward-looking check. Phase 0 does not depend on browser availability.

---

## Capability 4: Delivery Routing (PLAT-02)

**Purpose:** Confirm that cron job delivery config correctly pushes output to the target chat channel.

**Test procedure:**

1. Register a test job with delivery:
```json
{
  "name": "test-delivery",
  "schedule": { "kind": "once", "delay": "10s" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Reply with exactly: Delivery test successful",
    "lightContext": false
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "{target_chat_id}"
  }
}
```

2. Replace `{target_chat_id}` with your actual Telegram chat ID.

3. Wait ~30 seconds.

4. Check your Telegram chat for the message "Delivery test successful".

**Pass criteria:** Message arrives in the target chat channel.

**Fail action:**
- Verify `{target_chat_id}` is correct (numeric ID, not username)
- Check delivery channel spelling matches platform expectations
- Try `"mode": "webhook"` as an alternative if `"announce"` is not supported
- If delivery is completely unavailable: the pipeline still generates `output/latest-digest.md` which can be read manually. Delivery is convenience, not a hard requirement.

**Cleanup:** `cron delete test-delivery`

---

## Capability 5: Timeout Limits

**Purpose:** Confirm that the platform supports execution times of at least 10 minutes (needed for daily digest with LLM processing).

**Test procedure:**

1. Register a long-running test job:
```json
{
  "name": "test-timeout",
  "schedule": { "kind": "once", "delay": "10s" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Wait for 5 minutes by counting to 300 (one count per second), then write 'Timeout test passed' to output/test-timeout.txt",
    "lightContext": false,
    "timeoutSeconds": 600
  }
}
```

2. Wait ~6 minutes for completion.

3. Verify `output/test-timeout.txt` exists with content "Timeout test passed".

**Pass criteria:** Job completes after 5+ minutes without being killed.

**Fail action:**
- If 5 minutes fails: try 3 minutes. If 3 minutes works, the quick check job (5 min timeout) is safe but the daily digest may need optimization (fewer LLM calls, smaller batches).
- If even 3 minutes fails: the pipeline needs significant restructuring into multiple shorter runs. This would be a blocker for the current architecture.

**Cleanup:** Delete `output/test-timeout.txt` and `cron delete test-timeout`

---

## Verification Summary

| # | Capability | Required for Phase 0? | Fallback if Missing |
|---|-----------|----------------------|---------------------|
| 1 | File Access | YES | None -- blocker |
| 2 | Exec Permissions | YES (for scripts) | Inline logic in SKILL.md (degraded) |
| 3 | Browser | NO (Phase 1+) | web_fetch sufficient for RSS |
| 4 | Delivery Routing | NO (convenience) | Manual read of output/latest-digest.md |
| 5 | Timeout (>= 5 min) | YES | Reduce batch sizes, split into multiple runs |

**Minimum viable:** Capabilities 1, 2, and 5 must pass. Capabilities 3 and 4 are nice-to-have for Phase 0.

**After verification:** Record results in `data/metrics/platform-verification.json` for reference:
```json
{
  "verified_at": "YYYY-MM-DDTHH:MM:SSZ",
  "capabilities": {
    "file_access": true,
    "exec_permissions": true,
    "browser": false,
    "delivery_routing": true,
    "timeout_5min": true
  },
  "notes": "Any observations"
}
```
