---
name: entity-mc
description: Bootstrap Entity Mission Control helper runtime for AI agents. One-command setup for task management scripts, auto-pull crons, stall-check alerts, and verification.
---

# Entity MC

Mission Control task management integration for AI agents running on [OpenClaw](https://github.com/openclaw/openclaw) (or any agent framework with shell access).

Gives your agent the ability to:
- **Create, update, and complete tasks** via `mc.sh`
- **Auto-pull tasks** from the todo queue on a schedule
- **Detect stalled tasks** stuck in "doing" too long
- **Assign models** to tasks based on complexity
- **Health-check** agent connectivity and board state
- **Build context** for tasks before execution

## Quick Start

### One-Command Bootstrap

```bash
# Clone the repo
git clone https://github.com/henrino3/Enterprise-Crew-skills.git
cd Enterprise-Crew-skills/entity-mc

# Interactive setup — asks for your Entity URL, agent name, workspace
bash bootstrap.sh

# Or non-interactive
bash bootstrap.sh \
  --entity-url http://your-entity-server:3000 \
  --agent "MyAgent" \
  --workspace ~/clawd \
  --yes
```

This will:
1. Generate a manifest for your agent
2. Install all MC scripts to your workspace
3. Set up cron jobs for auto-pull and stall-check
4. Verify everything works

### Manual Install

```bash
# 1. Copy the template manifest
cp manifests/template.env manifests/my-agent.env

# 2. Edit with your values
vim manifests/my-agent.env

# 3. Install
bash install.sh --manifest manifests/my-agent.env

# 4. Verify
bash verify.sh --manifest manifests/my-agent.env
```

## What Gets Installed

### Scripts

| Script | Purpose |
|--------|---------|
| `mc.sh` | CLI for task CRUD (create, list, note, review, done) |
| `mc-auto-pull.sh` | Cron job: pulls oldest todo task and starts it |
| `mc-assign-model.sh` | Assigns AI model tier to tasks based on complexity |
| `mc-build-context.sh` | Builds execution context for a task before working on it |
| `mc-stall-check.sh` | Cron job: flags tasks stuck in "doing" >24h |
| `mc-health-check.sh` | Monitors agent connectivity and board health |

### Usage

```bash
# List tasks
mc.sh list

# Create a task
mc.sh create "Build login page" "React component with OAuth flow"

# Add a progress note
mc.sh note 42 "Auth flow working, testing edge cases"

# Move to review with output
mc.sh review 42 "PR #123 ready, deployed to staging"

# Mark done
mc.sh done 42
```

### Cron Jobs (optional)

When enabled, bootstrap installs:
- **Auto-pull** (every 30 min): agent picks up the oldest todo task
- **Stall-check** (every 2h): alerts when tasks are stuck in "doing" >24h

Customize schedules in your manifest or via bootstrap flags.

## Manifest Reference

Each agent gets a manifest file (`.env` format) that configures its MC integration.

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ENTITY_MC_AGENT_NAME` | ✅ | — | Agent's display name in MC |
| `ENTITY_MC_TARGET_HOME` | ✅ | — | Workspace root directory |
| `ENTITY_MC_TARGET_SCRIPTS_DIR` | | `$TARGET_HOME/scripts` | Where scripts get installed |
| `ENTITY_MC_STATE_DIR` | | `$TARGET_HOME/.entity-mc` | State/releases/logs directory |
| `ENTITY_MC_MODE` | | `copy` | `copy` (wrapper stubs) or `symlink` |
| `ENTITY_MC_INSTALL_CRON` | | `true` | Install cron jobs |
| `ENTITY_MC_ENABLE_AUTO_PULL` | | `true` | Enable auto-pull cron |
| `ENTITY_MC_ENABLE_STALL_CHECK` | | `true` | Enable stall-check cron |
| `ENTITY_MC_AUTO_PULL_SCHEDULE` | | `*/30 * * * *` | Auto-pull cron schedule |
| `ENTITY_MC_STALL_CHECK_SCHEDULE` | | `0 */2 * * *` | Stall-check cron schedule |
| `ENTITY_MC_MC_URL` | | `http://localhost:3000` | Entity/MC server URL |
| `ENTITY_MC_RUNTIME` | | `openclaw` | Runtime: `openclaw` or `hermes` |
| `ENTITY_MC_PROFILE_NAME` | | — | OpenClaw profile name |
| `ENTITY_MC_OPENCLAW_BIN` | | auto-detect | Path to openclaw binary |

## Prerequisites

- [Entity](https://github.com/openclaw/entity) running somewhere accessible to your agent
- `bash`, `curl`, `jq` installed
- `crontab` access (if using auto-pull/stall-check)
- [OpenClaw](https://github.com/openclaw/openclaw) (recommended but not strictly required — scripts work standalone)

## Rollback

If something breaks:

```bash
bash rollback.sh --manifest manifests/my-agent.env
```

This restores the previous release from the backup.

## Files

```
entity-mc/
├── bootstrap.sh          # One-command setup (interactive or flags)
├── install.sh            # Core installer
├── verify.sh             # Post-install verification
├── rollback.sh           # Restore previous version
├── lib.sh                # Shared helpers
├── VERSION               # Current version tag
├── manifests/
│   └── template.env      # Manifest template — copy and fill in
└── source-scripts/
    ├── mc.sh              # Task CLI
    ├── mc-auto-pull.sh    # Auto-pull cron script
    ├── mc-assign-model.sh # Model assignment
    ├── mc-build-context.sh# Context builder
    ├── mc-stall-check.sh  # Stall detection
    └── mc-health-check.sh # Agent health monitor
```

## Adding to Your Agent's Prompt

After bootstrap, add something like this to your agent's system prompt or AGENTS.md:

```markdown
## Mission Control
- URL: http://your-server:3000
- Scripts: ~/clawd/scripts/mc.sh
- Auto-pull runs every 30 min — agent picks up todo tasks automatically
- Use mc.sh for all task management (create, note, review, done)
- Always move tasks to "review" with output before claiming done
```
