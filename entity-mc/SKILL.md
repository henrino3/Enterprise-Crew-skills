---
name: entity-mc
description: Bootstrap Entity Mission Control helper runtime for crew agents with a shared canonical bundle, portable MC operating memory, structured intake, per-agent manifest, safe cron install, verification, and rollback.
---

# Entity MC

Use this skill when an agent needs the standard Entity Mission Control helper bundle without manually copying shell scripts around.

This skill packages the current MC helper runtime into one installable bundle:
- `mc.sh`
- `mc-auto-pull.sh`
- `mc-assign-model.sh`
- `mc-build-context.sh`
- `mc-stall-check.sh`
- `mc-intake.sh`
- `.entity-mc/context/*.md` portable MC operating memory

It also handles:
- per-agent manifests
- idempotent install/update
- safe cron registration
- optional structured intake from JSON/JSONL into MC tasks
- portable MC operating context installed into the target `.entity-mc/context/` directory
- post-install verification
- rollback to the previous runtime

## Files

- Installer: `skills/entity-mc/install.sh`
- Verifier: `skills/entity-mc/verify.sh`
- Rollback: `skills/entity-mc/rollback.sh`
- Shared helpers: `skills/entity-mc/lib.sh`
- Manifests: `skills/entity-mc/manifests/*.env`
- Runtime version: `skills/entity-mc/VERSION`

## Manifest contract

Each manifest is a simple env file.

Required:
- `ENTITY_MC_AGENT_NAME`
- `ENTITY_MC_TARGET_HOME`

Optional:
- `ENTITY_MC_TARGET_SCRIPTS_DIR`
- `ENTITY_MC_STATE_DIR`
- `ENTITY_MC_MODE` (`copy` or `symlink`, default `copy`)
- `ENTITY_MC_ENABLE_AUTO_PULL` (`true|false`)
- `ENTITY_MC_ENABLE_STALL_CHECK` (`true|false`)
- `ENTITY_MC_ENABLE_INTAKE` (`true|false`, default `false`)
- `ENTITY_MC_INTAKE_SCHEDULE`
- `ENTITY_MC_CONTEXT_DIR` (derived from `ENTITY_MC_STATE_DIR`, installed automatically)
- `ENTITY_MC_AUTO_PULL_SCHEDULE`
- `ENTITY_MC_STALL_CHECK_SCHEDULE`
- `ENTITY_MC_PROFILE_NAME`
- `ENTITY_MC_EXTRA_NOTES`

## Install

```bash
bash skills/entity-mc/install.sh --manifest skills/entity-mc/manifests/scotty.env
```

Optional flags:

```bash
bash skills/entity-mc/install.sh \
  --manifest skills/entity-mc/manifests/book.env \
  --mode copy \
  --install-cron true
```

## Verify

```bash
bash skills/entity-mc/verify.sh --manifest skills/entity-mc/manifests/scotty.env
```

## Rollback

```bash
bash skills/entity-mc/rollback.sh --manifest skills/entity-mc/manifests/scotty.env
```

## Operational rules

1. Prefer this skill over manual script-copying.
2. Keep shared behavior in the canonical bundle under this skill.
3. Keep agent-specific differences in the manifest, not in forks of the scripts.
4. Re-running install must be safe.
5. Cron entries are managed only inside the Entity MC marker block.
6. Roll out to one agent first, verify, then expand.

## Recommended rollout order

1. Scotty
2. Spock
3. Book

## Definition of done

An install is only done when:
- runtime files are present
- wrappers or symlinks exist in target scripts dir
- version file is written
- cron block is present exactly once when enabled
- portable context files are installed
- `mc.sh review` exists in the installed helper and `mc-intake.sh` can dry-run structured task creation
- `verify.sh` passes

## Auto task creation / intake

Entity MC auto-pull executes tasks that already exist. Automatic task creation is handled by `mc-intake.sh`, bundled with the runtime.

`mc-intake.sh` is deliberately source-agnostic and conservative: it accepts explicit structured JSON/JSONL candidates, dedupes against active tasks and its local seen log, and creates MC tasks. Source-specific watchers should call it rather than embedding task-creation logic.

Examples:

```bash
# Create one task
bash scripts/mc-intake.sh create \
  --title "Investigate failed deploy" \
  --description "Deploy log URL: ..." \
  --assignee Scotty \
  --source discord \
  --source-id "channel/message" \
  --url "https://discord.com/channels/..."

# Ingest structured candidate from another watcher
echo '{"title":"Fix docs link","description":"Broken in thread...","assignee":"Ada","source":"discord","source_id":"123/456"}' \
  | bash scripts/mc-intake.sh ingest --json

# Dry-run inbox JSONL processing
bash scripts/mc-intake.sh scan-file .entity-mc/intake/inbox.jsonl --dry-run
```

Optional cron support is controlled by `ENTITY_MC_ENABLE_INTAKE=true`; by default it is off because each host needs an explicit source watcher/inbox policy.

## Portable operating memory

This bundle installs portable MC context into `.entity-mc/context/` and `mc-build-context.sh` injects it into every pulled task. This is the small memory pack that makes a newly onboarded agent use MC properly without needing Ada's private workspace memory.

Included context:

- `mc-operating-rules.md` — when to use MC, lifecycle, evidence, duplicate avoidance.
- `entity-mc-context.md` — what the runtime installs, manifest contract, structured intake behavior.
- `task-closure-contract.md` — exact review/blocker note requirements.

Keep these files public-safe. Do not add private hostnames, tokens, personal data, or Henry-specific secrets. Put host-specific facts in manifests or local memory, not in the public bundle.
