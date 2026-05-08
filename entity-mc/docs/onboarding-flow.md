# Entity MC Onboarding Flow

This document describes exactly how Entity Mission Control onboarding works for a new user, workspace, or agent crew.

## Goal

A new operator should be able to install the Entity MC bundle and get:

- Mission Control helper scripts installed into the workspace.
- Default operational crons installed automatically.
- Portable MC operating memory installed locally.
- Intake setup guidance installed locally, so future task intake can be configured safely.
- A verification pass proving the install worked.

## One-command install

Run this from the target workspace:

```bash
git clone https://github.com/henrino3/enterprise-crew-skills.git /tmp/enterprise-crew-skills
mkdir -p skills
cp -R /tmp/enterprise-crew-skills/entity-mc skills/entity-mc
bash skills/entity-mc/install-auto.sh
```

Optional explicit form:

```bash
bash skills/entity-mc/install-auto.sh \
  --workspace /path/to/workspace \
  --agent AgentName
```

## What `install-auto.sh` does

The auto installer:

1. Detects or accepts the target workspace.
2. Creates the local skill directory if needed:
   - `skills/entity-mc/`
3. Creates a local manifest:
   - `skills/entity-mc/manifests/auto.env`
4. Installs runtime wrappers into:
   - `scripts/mc.sh`
   - `scripts/mc-auto-pull.sh`
   - `scripts/mc-assign-model.sh`
   - `scripts/mc-build-context.sh`
   - `scripts/mc-stall-check.sh`
   - `scripts/mc-intake.sh`
5. Installs runtime state into:
   - `.entity-mc/`
6. Installs portable context into:
   - `.entity-mc/context/mc-operating-rules.md`
   - `.entity-mc/context/entity-mc-context.md`
   - `.entity-mc/context/mc-intake-setup.md`
   - `.entity-mc/context/task-closure-contract.md`
7. Creates the intake inbox directory:
   - `.entity-mc/intake/`
8. Writes the default cron block.
9. Runs verification.

## Default crons

By default, the installer writes one marked cron block for the agent.

The block includes:

```text
*/10 * * * *   mc-auto-pull.sh
0 */2 * * *    mc-stall-check.sh
```

Meaning:

- Every 10 minutes, the agent checks Mission Control for assigned tasks.
- Every 2 hours, the agent checks for stalled tasks.

Cron entries are wrapped in a marker block:

```text
# BEGIN ENTITY_MC:<AgentName>
...
# END ENTITY_MC:<AgentName>
```

Re-running the installer replaces only that marked block, so duplicate Entity MC cron blocks should not accumulate.

## What happens after install

After install, the workspace can participate in Mission Control:

1. A task exists in Mission Control.
2. The task is assigned to this agent.
3. `mc-auto-pull.sh` sees the task on its next run.
4. The runtime builds task context using `.entity-mc/context/`.
5. The local agent executes the task.
6. The agent must close with either:

```bash
bash scripts/mc.sh review <task_id> "DONE: ... Evidence: ..."
```

or:

```bash
bash scripts/mc.sh note <task_id> "BLOCKED: ..."
```

## MC intake: what it is

MC intake is how external sources become Mission Control tasks.

Examples of external sources:

- Discord thread
- Slack channel
- GitHub issue feed
- webhook
- local inbox file
- customer support queue

The intake layer is deliberately split into two parts:

1. **Source-specific watcher**
   - Reads a specific source.
   - Applies source policy.
   - Writes explicit candidate tasks.

2. **Generic `mc-intake.sh`**
   - Reads structured JSON/JSONL candidates.
   - Dedupes them.
   - Creates Mission Control tasks.

`mc-intake.sh` is not the policy brain. It should not decide what random chats, emails, or notifications mean. The watcher and local intake policy decide what is eligible.

## Intake setup memory

The installer adds this file to the target workspace:

```text
.entity-mc/context/mc-intake-setup.md
```

That document tells the newly installed agent/operator how to define intake safely.

Before enabling intake, the workspace should define:

- Allowed sources.
- Source owner.
- Required candidate JSON fields.
- Optional candidate JSON fields.
- Dedupe key.
- Default assignee.
- Default model.
- Priority mapping.
- Rejection rules.
- Review boundary.
- Receipts/logging location.

## Candidate JSON shape

Minimum candidate:

```json
{
  "title": "Fix failed deploy",
  "description": "Deploy failed. Log URL: ...",
  "source": "discord",
  "source_id": "channel/message-id"
}
```

Recommended candidate:

```json
{
  "title": "Fix failed deploy",
  "description": "Deploy failed. Log URL: ...",
  "assignee": "Scotty",
  "model": "codex",
  "priority": "P1",
  "source": "discord",
  "source_id": "channel/message-id",
  "url": "https://discord.com/channels/...",
  "metadata": {
    "intake": true,
    "source_policy": "discord-support-v1"
  }
}
```

## How a watcher feeds intake

A source watcher appends one JSON object per line to:

```text
.entity-mc/intake/inbox.jsonl
```

Example:

```bash
printf '%s\n' '{"title":"Fix docs link","description":"Broken link reported in Discord","assignee":"Ada","source":"discord","source_id":"123/456"}' \
  >> .entity-mc/intake/inbox.jsonl
```

Manual one-off ingest:

```bash
echo '{"title":"Fix docs link","description":"Broken link reported in Discord","assignee":"Ada","source":"discord","source_id":"123/456"}' \
  | bash scripts/mc-intake.sh ingest --json
```

Dry-run before enabling cron:

```bash
bash scripts/mc-intake.sh scan-file .entity-mc/intake/inbox.jsonl --dry-run
```

## Enabling intake cron

Intake cron is off by default.

Enable it only after the workspace has a written intake policy.

```bash
bash skills/entity-mc/install-auto.sh --enable-intake true
```

When enabled, the cron periodically runs:

```bash
bash scripts/mc-intake.sh scan-file .entity-mc/intake/inbox.jsonl
```

## Full onboarding sequence

The full intended product flow is:

```text
install bundle
  -> install runtime wrappers
  -> install default ops crons
  -> install portable MC context
  -> install intake setup memory
  -> verify install
  -> define source-specific intake policy
  -> connect watcher/source
  -> dry-run candidate ingestion
  -> enable intake cron
  -> MC tasks appear
  -> auto-pull executes assigned tasks
  -> agent closes tasks with review/blocker evidence
```

## Safety boundaries

- Do not enable intake without a written source policy.
- Do not let arbitrary chats, emails, notifications, or webpages write directly into intake.
- Do not create tasks from private or sensitive content unless the workspace policy explicitly permits it.
- Stage questionable candidates for human review instead of auto-creating tasks.
- Keep watcher logic outside `mc-intake.sh`; keep `mc-intake.sh` generic.
- If duplicates appear, fix the dedupe key or source policy before increasing cadence.

## Verification checklist

After onboarding, verify:

```bash
test -f skills/entity-mc/SKILL.md
test -f skills/entity-mc/manifests/auto.env
test -f .entity-mc/context/mc-intake-setup.md
ls scripts/mc*.sh
crontab -l | grep ENTITY_MC
bash skills/entity-mc/verify.sh --manifest skills/entity-mc/manifests/auto.env
```

Expected result:

- Runtime scripts exist.
- Portable context exists.
- The cron block exists exactly once.
- Verification prints `VERIFY_OK`.
