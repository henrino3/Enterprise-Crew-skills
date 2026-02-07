# Session Cleaner

Converts OpenClaw/Clawdbot session JSONL files into clean, readable markdown transcripts. Strips tool calls, heartbeats, and noise — keeps the actual conversation.

## What it does

- Parses `.jsonl` session files from `~/.clawdbot/agents/*/sessions/`
- Extracts user/assistant exchanges (no tool call noise)
- Skips noisy cron sessions (fireflies-sync, crewlink, etc.)
- Keeps valuable crons (daily-review, strategic-review, etc.)
- Outputs clean markdown with metadata (date, time, model, tools used)

## Usage

```bash
# Single session
node session-cleaner.mjs <session-file.jsonl>

# All sessions
node session-cleaner.mjs --all

# Yesterday's sessions
node session-cleaner.mjs --yesterday

# Specific date
node session-cleaner.mjs --date 2026-01-30
```

## Output format

```markdown
# Session abc12345

**Date:** 2026-02-07  
**Time:** 08:30 - 09:15 UTC  
**Model:** anthropic/claude-opus-4-5  
**Tools used:** exec, web_search, Read

---

## Summary
First user message preview...

---

## Conversation

### 👤 User (08:30)
Message content...

### 🤖 Assistant (08:31)
Response content...
```

## Multi-agent scripts

- `session-cleaner-spock.sh` — Process Spock's sessions (same gateway, different agent dir)
- `session-cleaner-scotty-remote.sh` — Process Scotty's sessions (run on Pi via SSH)

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SESSIONS_DIR` | `~/.clawdbot/agents/main/sessions` | Input JSONL directory |
| `OUTPUT_DIR` | `../memory/sessions` (relative to script) | Output markdown directory |

## Requirements

- Node.js 18+
- Access to Clawdbot/OpenClaw session JSONL files
