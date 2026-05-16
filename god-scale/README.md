# GOD Scale

Goal-Oriented Delivery Scale: a reusable agent workflow for goals, missions, Codex/Droid execution, verification, and receipts.

## One-line install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/h-mascot/Enterprise-Crew-skills/main/god-scale/install.sh)
```

## Local install from clone

```bash
git clone https://github.com/h-mascot/Enterprise-Crew-skills.git /tmp/enterprise-crew-skills
bash /tmp/Enterprise-Crew-skills/god-scale/install.sh
```

## What gets installed

- `~/.god-scale/` — the skill bundle and helper scripts.
- `~/.local/bin/god-scale` — command wrapper.

No secrets are installed. No shell profile is modified unless `~/.local/bin` is missing from `PATH`; in that case the installer prints the line to add.

## First run

```bash
cd /path/to/git/repo
god-scale init --goal "Ship the smallest useful version of X" --mode codex
god-scale mission add "Implement the core path" --accept "npm test"
god-scale run --mode codex
god-scale status
```

## Runtime options

### Codex

Requires `codex` on PATH.

```bash
god-scale run --mode codex
```

Optional:

```bash
GOD_SCALE_CODEX_ARGS="exec --full-auto" god-scale run --mode codex
```

### Droid

Requires `droid` on PATH.

```bash
god-scale run --mode droid --model "custom:Your-Model-0"
```

Optional:

```bash
GOD_SCALE_DROID_AUTO=low god-scale run --mode droid --model "custom:Your-Model-0"
```

## Design

GOD Scale is deliberately thin:

1. Store the goal.
2. Store missions as JSONL.
3. Build a mission prompt.
4. Run Codex or Droid.
5. Run acceptance checks separately.
6. Save logs and git receipts.

That is enough structure to prevent agent work from turning into interpretive dance.
