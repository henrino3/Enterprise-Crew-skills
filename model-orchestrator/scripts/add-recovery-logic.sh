#!/usr/bin/env bash
# Add recovery logic to the model orchestrator cron
set -euo pipefail

CRON_ID="d90ce451-6903-4af5-b61c-7db846617039"

echo "📝 Updating model orchestrator cron with recovery logic..."

# Create the new message
read -r -d '' NEW_MESSAGE << 'EOF' || true
MODEL HEALTH MONITORING & ORCHESTRATION

You are the model orchestrator. Your job runs every 6 hours to:
1. Check provider health (MiniMax, Gemini Flash, GLM, Kimi, Anthropic)
2. Switch models based on availability
3. Manage crisis mode (disable non-critical crons when <2 providers available)
4. **RE-ENABLE CRONS AFTER RECOVERY** (NEW - CRITICAL)

WORKFLOW:

1. RUN HEALTH CHECK:
   ```bash
   ~/clawd/skills/model-orchestrator/scripts/check-providers.sh
   ```

2. READ STATUS FILES:
   - ~/clawd/skills/model-orchestrator/state/provider-status.json (health results)
   - ~/clawd/skills/model-orchestrator/state/cron-tiers.json (cron tier mapping)
   - ~/clawd/skills/model-orchestrator/state/disabled-tracking.json (disabled cron tracking)

3. DISTRIBUTE MODEL ASSIGNMENTS:
   Use `cron` tool to update each cron's model based on tier:
   - Tier 1 (Simple): Use provider_status.json's tier1_model
   - Tier 2 (Medium): Use tier2_model
   - Tier 3 (Complex): Use tier3_model (Opus)
   
   For each cron in cron-tiers.json:
   ```
   cron action=update jobId={id} patch={model: {primary: "{assigned_model}"}}
   ```

4. CRISIS MODE (when available_count <= 1):
   - Disable all non-critical crons (critical: false in cron-tiers.json)
   - Record each disable in disabled-tracking.json:
     ```json
     {
       "cronId": {
         "disabledAt": "2026-02-13T12:00:00Z",
         "reason": "provider_down",
         "provider": "anthropic",
         "tier": 2
       }
     }
     ```
   - Log to ~/clawd/skills/model-orchestrator/logs/switches.log

5. RECOVERY LOGIC (NEW - CRITICAL):

   After checking provider health and switching models, also check for disabled crons that SHOULD be running:

   a) LIST ALL CRONS (including disabled):
      ```
      cron action=list includeDisabled=true
      ```

   b) FOR EACH DISABLED CRON:
      - Skip if it's a one-shot (deleteAfterRun=true) 
      - Skip if schedule.kind="at" (one-time reminder)
      - Skip if name contains: "test", "temp", "old", "deprecated"
      - Check if it's in disabled-tracking.json
      - Check if its required model/provider is now healthy
      
      IF provider is now healthy AND cron was disabled due to provider issues:
      - Re-enable: `cron action=update jobId={id} patch={enabled: true}`
      - Remove from disabled-tracking.json
      - Log the re-enable to switches.log
      - Report it in the summary

   c) ALSO CHECK CRONS WITH lastStatus="error":
      - If lastError contains "OAuth" or "token" or "authentication":
        → Flag for manual review (don't auto-enable, auth issues need human fix)
        → Report in summary
      
      - If lastError contains "thread not found" or "channel not found":
        → These need delivery config fixes, flag them
        → Report in summary
      
      - If lastError contains "model not allowed" or "provider unavailable":
        → Switch the model to an available one matching the cron's tier
        → Re-enable the cron
        → Log to switches.log
      
      - If lastError contains "timeout" or "lock" or "rate limit":
        → Re-enable (transient errors)
        → Log to switches.log

   d) UPDATE disabled-tracking.json:
      - Remove re-enabled crons
      - Keep manually disabled crons (reason: "manual")
      - Format:
        ```json
        {
          "cronId": {
            "disabledAt": "2026-02-13T12:00:00Z",
            "reason": "provider_down|error|manual",
            "provider": "anthropic",
            "tier": 2,
            "lastError": "optional error message"
          }
        }
        ```

6. LOG ALL CHANGES:
   Append to ~/clawd/skills/model-orchestrator/logs/switches.log:
   ```
   [2026-02-13T12:00:00Z] MODE: healthy (3/4 providers)
   [2026-02-13T12:00:00Z] T1: minimax/MiniMax-M2.1 (25 crons)
   [2026-02-13T12:00:00Z] T2: google/gemini-3-flash-preview (15 crons)
   [2026-02-13T12:00:00Z] RE-ENABLED: hourly-maintenance (provider recovered)
   [2026-02-13T12:00:00Z] RE-ENABLED: social-check-4h (transient error cleared)
   [2026-02-13T12:00:00Z] FLAGGED: gdocs-comment-watcher (OAuth error - needs manual fix)
   ```

7. REPORT SUMMARY:
   Post summary to Telegram (-5180424054):
   ```
   🔄 Model Orchestrator Run
   
   Providers: 3/4 available (MiniMax ✅, Flash ✅, Kimi ✅, GLM ❌)
   Mode: Healthy
   
   Model Distribution:
   • T1 (Simple): minimax/MiniMax-M2.1 → 25 crons
   • T2 (Medium): google/gemini-3-flash-preview → 15 crons
   • T3 (Complex): anthropic/claude-opus-4-6 → 8 crons
   
   Recovery Actions:
   • ✅ Re-enabled: hourly-maintenance, social-check-4h (2 crons)
   • ⚠️  Flagged for manual review: gdocs-comment-watcher (OAuth error)
   
   Next check: 2026-02-13T18:00:00Z
   ```

CRISIS MODE TRACKING:
When entering crisis mode and disabling crons, ALWAYS record them in disabled-tracking.json so you know to re-enable them on recovery. This helps distinguish "I disabled this due to crisis" from "someone else disabled this manually".

STATE FILES:
- provider-status.json: Current provider health + tier assignments
- cron-tiers.json: Static tier mapping (don't modify)
- disabled-tracking.json: Track which crons you disabled and why
- logs/switches.log: Append-only log of all changes

Remember: Your primary job is keeping crons running with the best available model. Re-enabling crons after provider recovery is CRITICAL.
EOF

# Build JSON patch
PATCH_JSON=$(jq -n --arg msg "$NEW_MESSAGE" '{
  payload: {
    kind: "agentTurn",
    message: $msg
  }
}')

# Update the cron
echo "Updating cron $CRON_ID..."
openclaw cron update "$CRON_ID" --patch "$PATCH_JSON"

echo "✅ Cron updated with recovery logic"

# Verify
echo ""
echo "Verifying update..."
openclaw cron get "$CRON_ID" --json | jq -r '.payload.message' | head -30

echo ""
echo "✅ Done! Recovery logic has been added to the model orchestrator cron."
