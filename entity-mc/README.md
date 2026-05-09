# entity-mc

Bootstrap Entity Mission Control for AI agents — one-command setup for task management scripts, auto-pull crons, stall-check, structured intake, and verification.

## Structure

```
entity-mc/
├── README.md
├── SKILL.md
├── VERSION
├── install-auto.sh      # One-command auto installer
├── install.sh            # Per-agent manifest installer
├── lib.sh                # Shared installer/runtime library
├── rollback.sh           # Rollback to previous release
├── verify.sh             # Verify install health
├── context/
│   ├── entity-mc-context.md
│   ├── mc-intake-setup.md
│   ├── mc-operating-rules.md
│   ├── mc-task-intake-policy.md
│   └── task-closure-contract.md
├── docs/
│   └── onboarding-flow.md
└── source-scripts/
    ├── mc-assign-model.sh
    ├── mc-auto-pull.sh
    ├── mc-build-context.sh
    ├── mc-health-check.sh
    ├── mc-intake.sh
    ├── mc-stall-check.sh
    └── mc.sh
```

## One-command install

From inside the target OpenClaw-compatible workspace:

```bash
git clone https://github.com/h-mascot/enterprise-crew-skills.git /tmp/enterprise-crew-skills
mkdir -p skills
cp -R /tmp/enterprise-crew-skills/entity-mc skills/entity-mc
bash skills/entity-mc/install-auto.sh
```

That command writes an auto manifest, installs runtime wrappers, installs the default Entity MC cron block, installs portable operating context, and runs verification.

### What gets installed

1. **Scripts** — `mc.sh`, `mc-auto-pull.sh`, `mc-stall-check.sh`, `mc-build-context.sh`, `mc-assign-model.sh`, `mc-health-check.sh`, `mc-intake.sh` into `scripts/`
2. **Context/Rules** — operating rules, task intake policy, closure contract, intake setup, and MC context into `.entity-mc/context/`
3. **Crons** — auto-pull (every 10 min) and stall-check (every 2 hours) via marked cron block
4. **State** — runtime, releases, tracking in `.entity-mc/`

## Requirements

- [OpenClaw](https://github.com/openclaw/openclaw) or compatible AI agent framework
- `curl`, `jq`, `bash`
- An Entity instance to connect to (set `--mc-url` or `ENTITY_MC_MC_URL`)

## License

Apache-2.0
