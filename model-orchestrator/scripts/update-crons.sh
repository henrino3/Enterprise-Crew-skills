#!/bin/bash
# Update cron jobs with proper tier-based model assignments and enable critical crons

JOBS_FILE="$HOME/.openclaw/cron/jobs.json"
LOG_FILE="$HOME/clawd/skills/model-orchestrator/state/switches.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Tier assignments
T1_MODEL="minimax/MiniMax-M2.5"
T2_MODEL="zai/glm-4.7"
T3_MODEL="anthropic/claude-opus-4-6"

echo "[$TIMESTAMP] RECOVERY RUN: Updating cron models and re-enabling critical crons" >> "$LOG_FILE"

# Backup current jobs.json
cp "$JOBS_FILE" "$JOBS_FILE.backup-$TIMESTAMP"

# Create temp file for updates
TMP_FILE=$(mktemp)

# Read and update jobs.json
cat "$JOBS_FILE" | jq --arg t1 "$T1_MODEL" --arg t2 "$T2_MODEL" --arg t3 "$T3_MODEL" '
  .jobs |= map(
    if .name == "daily-brief" then
      .enabled = true | .model = $t3
    elif .name == "agent-health-check" then
      .enabled = true | .model = $t1
    elif .name == "cron-health-report" then
      .enabled = true | .model = $t2
    elif .name == "crew-sync" then
      .enabled = true | .model = $t1
    elif .name == "system-health-check" then
      .model = $t1
    elif .name == "gdocs-comment-watcher" then
      .model = $t2
    elif .name == "hourly-maintenance" then
      .model = $t1
    elif .name == "crash-recovery-diagnosis" then
      .model = $t2
    elif .name == "model-health-monitor" or .name == "model-orchestrator" then
      .model = $t1
    elif .name == "gmail-push-check" or .name == "Check Gmail notifications" then
      .model = $t2
    elif .name == "mc-scrub" then
      .model = $t1
    elif .name == "social-check-4h" then
      .model = $t2
    elif .name == "screenshot-roast" then
      .model = $t2
    elif .name == "collect-activitywatch" then
      .model = $t1
    elif .name == "collect-screentime" then
      .model = $t1
    elif .name == "collect-git-stats" then
      .model = $t1
    elif .name == "fireflies-sync" then
      .model = $t1
    elif .name == "spock-research-digest" then
      .model = $t3
    elif .name == "discord-export" then
      .model = $t1
    elif .name == "tinkerer-club-export" then
      .model = $t1
    elif .name == "discord-insights" then
      .model = $t2
    elif .name == "sync-sessions-to-qmd" then
      .model = $t1
    elif .name == "morning-batch" then
      .model = $t1
    elif .name == "skill-of-the-day" then
      .model = $t2
    elif .name == "clawdbot-updates-check" then
      .model = $t1
    elif .name == "learnings-reminder" then
      .model = $t2
    elif .name == "secrets-backup-drive" then
      .model = $t1
    elif .name == "opus-budget-fri-check" then
      .model = $t2
    elif .name == "weekly-disk-cleanup" then
      .model = $t1
    elif .name == "opus-budget-mon-restore" then
      .model = $t1
    elif .name == "gmail-watch-renew" then
      .model = $t1
    elif .name == "session-pruner-daily" then
      .model = $t1
    elif .name == "mc-session-sync" then
      .model = $t1
    elif .name == "evening-batch" then
      .model = $t1
    elif .name == "proactive-skill-run" or .name == "Proactive Skill Run" then
      .model = $t3
    elif .name == "happy-hour-summary" then
      .model = $t3
    elif .name == "daily-elon-audit" then
      .model = $t3
    elif .name == "daily-1000x-optimization" then
      .model = $t3
    elif .name == "overnight-proactive-work" then
      .model = $t3
    elif .name == "self-improvement-weekly" then
      .model = $t3
    else
      .
    end
  )
' > "$TMP_FILE"

# Replace the original file
mv "$TMP_FILE" "$JOBS_FILE"

# Log changes
echo "[$TIMESTAMP] RE-ENABLED: daily-brief (tier 3, critical)" >> "$LOG_FILE"
echo "[$TIMESTAMP] RE-ENABLED: agent-health-check (tier 1, critical)" >> "$LOG_FILE"
echo "[$TIMESTAMP] RE-ENABLED: cron-health-report (tier 2, critical)" >> "$LOG_FILE"
echo "[$TIMESTAMP] RE-ENABLED: crew-sync (tier 1)" >> "$LOG_FILE"
echo "[$TIMESTAMP] MODEL UPDATES: All crons assigned to optimal tier models" >> "$LOG_FILE"
echo "[$TIMESTAMP] T1 → $T1_MODEL | T2 → $T2_MODEL | T3 → $T3_MODEL" >> "$LOG_FILE"
echo "[$TIMESTAMP] ACTION REQUIRED: Gateway restart needed for changes to take effect" >> "$LOG_FILE"

echo "✓ Cron config updated. Changes logged to $LOG_FILE"
echo "⚠️  Gateway restart required for changes to take effect"

# Summary
echo ""
echo "SUMMARY:"
echo "- daily-brief: re-enabled → $T3_MODEL (tier 3, critical)"
echo "- agent-health-check: re-enabled → $T1_MODEL (tier 1, critical)"
echo "- cron-health-report: re-enabled → $T2_MODEL (tier 2, critical)"
echo "- crew-sync: re-enabled → $T1_MODEL (tier 1)"
echo "- All other crons: models assigned to optimal tiers"
