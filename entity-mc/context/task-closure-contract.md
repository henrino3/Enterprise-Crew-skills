# Task Closure Contract

Every MC-executed task must close the loop.

## Required final action
Run one of:

```bash
bash scripts/mc.sh review <task_id> "<what changed + evidence>"
bash scripts/mc.sh note <task_id> "BLOCKED: <reason>"
```

## Good review note shape

```text
DONE: <one sentence outcome>
Evidence:
- Changed: <files / repo / commit>
- Verified: <command/test/build/API/browser evidence>
- Live state: <URL/process/deploy if relevant>
Risks/follow-up:
- <only if real>
```

## Blocked note shape

```text
BLOCKED: <exact blocker>
Tried:
- <lookup/command/source checked>
Need:
- <specific missing credential/access/decision>
```

## Never do this
- Do not leave a claimed task in `doing` after you stop working.
- Do not mark review without evidence.
- Do not create duplicate tasks for the same work.
- Do not report completion in chat before MC has the review/blocker note.
