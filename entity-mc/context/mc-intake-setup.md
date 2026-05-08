# MC Intake Setup

This file is installed by the Entity MC bundle so a newly onboarded agent knows how to configure safe task intake from outside sources.

## What intake is

MC intake turns explicit structured candidates into Mission Control tasks.

It is not a chat spy, notification scraper, or vibe detector. Source-specific watchers decide what is eligible. `mc-intake.sh` only validates, dedupes, and creates tasks from structured JSON/JSONL.

## Setup contract

Before enabling the intake cron, create an intake policy in this workspace's memory or `.entity-mc/context/`.

The policy must define:

- Allowed sources: e.g. Discord thread, Slack channel, webhook, inbox file, GitHub issue feed.
- Source owner: who is allowed to create/approve candidate tasks from that source.
- Candidate shape: required JSON fields and optional fields.
- Dedupe key: usually `source + source_id`, or a stable URL/message id.
- Assignee defaults: which MC assignee receives tasks when the candidate omits one.
- Model defaults: which model/profile to use for imported tasks when relevant.
- Priority rules: what becomes P0/P1/P2/backlog.
- Rejection rules: what must never become a task.
- Review boundary: whether candidates are auto-created, staged for review, or require human confirmation.
- Retention/logging: where source watcher receipts and seen ids are stored.

## Candidate JSON shape

Minimum:

```json
{
  "title": "Fix failed deploy",
  "description": "Deploy failed on production. Log URL: ...",
  "source": "discord",
  "source_id": "channel/message-id"
}
```

Recommended:

```json
{
  "title": "Fix failed deploy",
  "description": "Deploy failed on production. Log URL: ...",
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

## How watchers should feed intake

Single candidate:

```bash
echo '{"title":"Fix docs link","description":"Broken in thread...","assignee":"Ada","source":"discord","source_id":"123/456"}' \
  | bash scripts/mc-intake.sh ingest --json
```

Recurring watcher:

```bash
printf '%s\n' '{"title":"Fix docs link","description":"Broken in thread...","assignee":"Ada","source":"discord","source_id":"123/456"}' \
  >> .entity-mc/intake/inbox.jsonl
```

Dry-run before enabling cron:

```bash
bash scripts/mc-intake.sh scan-file .entity-mc/intake/inbox.jsonl --dry-run
```

## Enable intake cron only after policy exists

```bash
bash skills/entity-mc/install-auto.sh --enable-intake true
```

or set this in the manifest before running `install.sh`:

```bash
ENTITY_MC_ENABLE_INTAKE="true"
ENTITY_MC_INTAKE_SCHEDULE="*/15 * * * *"
```

When enabled, the cron scans:

```text
.entity-mc/intake/inbox.jsonl
```

## Safety rules

- Do not enable intake without a written source policy.
- Do not let arbitrary chats, emails, or notifications write directly into intake.
- Do not create tasks from private/sensitive content unless the workspace policy explicitly permits it.
- Prefer staging questionable candidates for human review instead of auto-creating tasks.
- Keep source-specific watcher logic outside `mc-intake.sh`; intake stays generic.
- If duplicates appear, tighten the dedupe key and source policy before increasing cadence.
