# entity-mc

Bootstrap Entity Mission Control for AI agents — one-command setup for task management scripts, auto-pull crons, stall-check, and verification.

## Structure

```
entity-mc/
├── README.md
├── SKILL.md
├── VERSION
├── install-auto.sh
├── install.sh
├── lib.sh
├── rollback.sh
├── context/mc-intake-setup.md
├── source-scripts/mc-assign-model.sh
├── source-scripts/mc-auto-pull.sh
├── source-scripts/mc-build-context.sh
├── source-scripts/mc-stall-check.sh
├── source-scripts/mc.sh
├── verify.sh
```

## One-command install

From inside the target OpenClaw-compatible workspace:

```bash
bash skills/entity-mc/install-auto.sh
```

That command writes an auto manifest, installs the runtime wrappers, installs the default Entity MC cron block, installs portable MC/intake setup context, and runs verification.

If the bundle is outside the target workspace, pass the workspace explicitly:

```bash
bash /tmp/enterprise-crew-skills/entity-mc/install-auto.sh --workspace /path/to/openclaw-workspace --agent Ada
```

## Agent Instructions

This skill includes a `SKILL.md` file with instructions for AI agents on how to use it. If you're running [OpenClaw](https://github.com/openclaw/openclaw), copy this folder into your skills directory, then run `bash skills/entity-mc/install-auto.sh` from the workspace to complete setup and install crons.

## Requirements

- [OpenClaw](https://github.com/openclaw/openclaw) or compatible AI agent framework
- Node.js 18+ (for JavaScript-based scripts)

## License

MIT
