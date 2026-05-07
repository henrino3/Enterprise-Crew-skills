# Entity MC Context

Entity MC is the Mission Control helper runtime for agents working through Entity.

## What it installs
- `mc.sh`: Mission Control CLI/API helper.
- `mc-auto-pull.sh`: claims assigned tasks and launches an agent/runtime to execute them.
- `mc-assign-model.sh`: model assignment helper.
- `mc-build-context.sh`: builds task context before execution.
- `mc-stall-check.sh`: detects stalled tasks.
- `mc-intake.sh`: creates tasks from explicit structured JSON/JSONL candidates.
- `.entity-mc/context/*.md`: portable operating memory injected into task prompts.
- marked cron block for auto-pull/stall-check/optional intake.

## Config contract
Each host uses a manifest env file. Required:
- `ENTITY_MC_AGENT_NAME`
- `ENTITY_MC_TARGET_HOME`

Important optional values:
- `ENTITY_MC_MC_URL`: Entity Mission Control base URL.
- `ENTITY_MC_TARGET_SCRIPTS_DIR`: where wrappers are installed.
- `ENTITY_MC_STATE_DIR`: where runtime/context/logs live.
- `ENTITY_MC_ENABLE_AUTO_PULL`: enable task claiming cron.
- `ENTITY_MC_ENABLE_STALL_CHECK`: enable stalled-task cron.
- `ENTITY_MC_ENABLE_INTAKE`: enable inbox JSONL intake cron. Default off.
- `ENTITY_MC_INTAKE_SCHEDULE`: intake cron cadence.
- `ENTITY_MC_RUNTIME`, `ENTITY_MC_OPENCLAW_BIN`, `ENTITY_MC_HERMES_BIN`: runtime overrides.

## Structured intake
Auto-pull executes existing tasks. It does not spy on chats or infer tasks from vibes.
Task creation from external sources should feed explicit candidates into `mc-intake.sh`:

```bash
echo '{"title":"Fix broken deploy","description":"...","assignee":"Scotty","source":"discord","source_id":"channel/message"}' \
  | bash scripts/mc-intake.sh ingest --json
```

For recurring source watchers, write JSONL to `.entity-mc/intake/inbox.jsonl` and enable intake cron only after defining the source policy.

## Agent behavior
- Pull only tasks assigned to your agent unless explicitly told otherwise.
- Load task-specific skill/context when metadata specifies it.
- Execute, verify, and move to review.
- If blocked, note the blocker and do not silently fail.
