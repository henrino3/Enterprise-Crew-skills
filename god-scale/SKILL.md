---
name: god-scale
description: Goal-Oriented Delivery Scale (GOD Scale): an installable agent workflow for turning a goal into bounded missions, running them with Codex or Droid, verifying outcomes, and leaving receipts. Use when you want a reusable build loop with goals, missions, modes, verification, and resumable state.
version: 1.0.0
author: SuperAda
license: MIT
metadata:
  tags: [agent-workflow, codex, droid, missions, goals, verification]
---

# GOD Scale — Goal-Oriented Delivery Scale

GOD Scale is a small operating layer for coding agents. It turns a broad goal into one or more bounded missions, runs each mission through a chosen agent runtime, and records proof before moving on.

The name is loud. The machinery is intentionally boring.

## What it does

- Defines a **goal**: the outcome the operator wants.
- Breaks work into **missions**: bounded units with acceptance checks.
- Runs missions through **Codex** or **Droid**.
- Keeps state in `.god-scale/state/` so runs can be resumed or audited.
- Separates implementation from verification.
- Captures receipts: command logs, git diff summaries, and verification results.

## Install

From the source repo:

```bash
git clone https://github.com/henrino3/enterprise-crew-skills.git /tmp/enterprise-crew-skills
bash /tmp/enterprise-crew-skills/god-scale/install.sh
```

Or one line:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/henrino3/enterprise-crew-skills/main/god-scale/install.sh)
```

The installer copies the bundle into `~/.god-scale`, creates `~/.local/bin/god-scale`, and prints a verification command.

## Quick start

```bash
cd /path/to/repo
god-scale init --goal "Ship dark mode settings" --mode codex
god-scale mission add "Add settings toggle" --accept "npm test"
god-scale run --mode codex
god-scale status
```

Droid version:

```bash
cd /path/to/repo
god-scale init --goal "Fix checkout form validation" --mode droid
god-scale mission add "Repair validation and errors" --accept "npm test"
god-scale run --mode droid --model "custom:Kimi-K2.5-[VibeProxy]-0"
```

## Modes

### Codex mode

Uses `codex exec` from the current git repository.

Good for:
- feature builds
- refactors
- tests and type fixes
- PR review follow-up

Default command shape:

```bash
codex exec --full-auto "<mission prompt>"
```

Override with:

```bash
GOD_SCALE_CODEX_ARGS="exec --full-auto" god-scale run --mode codex
```

### Droid mode

Uses `droid exec` with optional `--model` and `--auto` settings.

Good for:
- BYOK model routing
- custom OpenAI-compatible endpoints
- Droid mission-style coding passes
- UI/code tasks where Droid is already configured

Default command shape:

```bash
droid exec --auto medium --cwd "$PWD" -m "$MODEL" "<mission prompt>"
```

Override with:

```bash
GOD_SCALE_DROID_AUTO=low god-scale run --mode droid --model "custom:Your-Model-0"
```

## Mission contract

Each mission should include:

- **Title** — what to change.
- **Acceptance command** — what proves it worked.
- **Scope note** — what not to touch, if relevant.

Example:

```bash
god-scale mission add   "Add CSV export to reports page"   --accept "npm run test:unit -- reports"   --scope "Only reports UI and export helper files. Do not modify auth."
```

## State layout

Inside the target repo:

```text
.god-scale/
  goal.md
  missions.jsonl
  state/
    run-YYYYmmdd-HHMMSS/
      mission-001.prompt.md
      mission-001.log
      mission-001.verify.log
      git-before.txt
      git-after.txt
      summary.md
```

## Operator rules

1. Do not run open-ended prompts when a mission can be bounded.
2. Do not count agent completion as success; run the acceptance command.
3. Do not hide failures. Preserve the log and make the next mission smaller.
4. Do not put secrets in missions, prompts, or logs.
5. Commit only after verification passes.

## When to use it

Use GOD Scale when the work is larger than a single prompt but smaller than a full project-management system:

- Build a feature across a few files.
- Convert a PRD into a sequence of agent missions.
- Run the same mission through Codex or Droid and compare results.
- Keep receipts for agent work without building a whole control plane.

## Verification

```bash
god-scale doctor
```

Checks:
- bundle installed
- target directory is a git repo
- requested runtime exists (`codex` or `droid`)
- mission file is parseable
- acceptance command is available for each mission
