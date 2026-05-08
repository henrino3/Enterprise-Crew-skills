# MC Task Intake Policy

This file is installed by the Entity MC bundle so agents remember which work belongs on the Mission Control board.

## Core rule

If work is more than a quick reply, put it on the board or update an existing board task before executing.

Use Mission Control for work that is:

- More than a few minutes.
- Multi-step or likely to survive compaction/restart.
- Assigned to another agent or needs handoff/resume.
- A bug, deploy, runtime, data, config, customer, or docs issue.
- A build, research, QA, release, migration, integration, automation, or follow-up.
- Anything where evidence/status should be visible later.

Do not create a new task for:

- Tiny one-message answers.
- Pure chatter.
- Duplicate work that already has an active task.
- Sensitive/private content that the local policy forbids storing.

## Before creating a task

1. Search current active MC tasks for the same work.
2. If a task exists, add a note/update instead of creating a duplicate.
3. If no task exists, create one with enough context for a cold agent to execute.

## What a good task contains

Required:

- Clear title: verb + object.
- Description with source context and desired outcome.
- Assignee or default pool.
- Source/link/message id when available.

Recommended:

- Priority: P1/P2/P3.
- Model hint for coding/research/review.
- Skill hint if a specific skill should run.
- Acceptance criteria.
- Evidence required before review.

## Default routing

- Build/code/deploy/fix work -> builder agent or coding model.
- Research/market/source-heavy work -> research agent.
- Review/QA/security/privacy checks -> reviewer agent.
- Ops/admin/docs/intake cleanup -> orchestrator/operator agent.
- Unknown ownership -> `Enterprise Crew` backlog, not silent discard.

## Task columns

- Use `backlog` for captured work that is not urgent or not immediately executable.
- Use `todo` for work ready for the assigned agent to pick up.
- Use `doing` only when the agent is actively executing.
- Use `review` only with proof/evidence.
- Use `done` only when accepted/closed by the operator or local policy.

## Automatic intake

Automatic task creation is done by source-specific watchers plus `mc-intake.sh`:

1. Watcher reads an allowed source.
2. Watcher applies the local intake policy.
3. Watcher writes explicit JSON candidates to `.entity-mc/intake/inbox.jsonl`, or pipes one JSON object into `mc-intake.sh ingest --json`.
4. `mc-intake.sh` dedupes and creates/updates MC tasks.
5. `mc-auto-pull.sh` later pulls assigned tasks and executes them.

`mc-auto-pull.sh` does not create tasks from chats by itself. It only pulls tasks that already exist.

## Candidate examples

Bug/deploy:

```json
{"title":"Fix failed production deploy","description":"Deploy failed. Logs: <url>. Expected: production deploy passes and live health verifies.","assignee":"Scotty","priority":"P1","model":"codex","source":"github-actions","source_id":"run-123","url":"https://github.com/.../actions/runs/123"}
```

Research:

```json
{"title":"Research WSO2 agent governance positioning","description":"Compare WSO2 Agent Manager against Entity/ProofDesk and produce a positioning brief.","assignee":"Spock","priority":"P2","model":"sonnet","source":"operator","source_id":"manual-2026-05-08"}
```

Docs/onboarding:

```json
{"title":"Publish Entity MC onboarding docs","description":"Publish onboarding-flow.md and bundle download to public docs site. Verify links return 200.","assignee":"Ada","priority":"P2","source":"discord","source_id":"channel-message-id"}
```

## Agent reminder

When you notice work that should become a task, do not rely on memory. Create/update the MC task immediately with `scripts/mc-intake.sh` or `scripts/mc.sh`, then continue.
