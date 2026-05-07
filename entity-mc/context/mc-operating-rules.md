# Entity MC Operating Rules

This file is installed by the Entity MC bundle so an agent can use Mission Control without relying on Ada/Henry-specific workspace memory.

## When to use Mission Control
- Use Mission Control for work that takes more than a few minutes, spans multiple steps, touches runtime/deploy state, or needs another agent to resume.
- Before starting new work, check whether a matching task already exists.
- Prefer updating an existing task over creating duplicates.

## Task lifecycle
- `todo` / `backlog`: work not started.
- `doing`: work has been claimed and is actively being executed.
- `review`: work is complete enough for human/operator review and includes evidence.
- `done`: human/operator accepted or explicitly closed.

## Completion contract
Do not end a task by only saying what you would do.
Before finishing an MC task, do exactly one of these:

```bash
bash scripts/mc.sh review <task_id> "<summary with evidence, files, URLs, logs, tests>"
bash scripts/mc.sh note <task_id> "BLOCKED: <specific blocker and what is needed>"
```

If blocked, do not leave the task silently rotting in `doing`. Add the blocker note and move it back to an appropriate queue if your local workflow supports that.

## Evidence requirements
A review note should include the useful proof, not vibes:
- files changed
- commands run
- test/build/lint output
- live URL/API/browser check where relevant
- commit SHA and pushed/deployed status for repo work
- remaining risks or follow-ups

## Runtime safety
- Do not claim DONE until change -> apply/restart if needed -> verify with evidence.
- For UI work, live/browser verification beats code inspection.
- For runtime/deploy work, verify the actual live process/URL/DB, not a convenient local copy.
- Prefer source-of-truth repo changes; direct runtime patching is recovery-only and should be backported.

## Duplicate avoidance
- Search active MC tasks first.
- If a task already exists, note/update it instead of creating another copy.
- `mc-intake.sh` also maintains a local seen log for structured intake dedupe.
