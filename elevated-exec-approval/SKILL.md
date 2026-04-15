---
name: elevated-exec-approval
description: Enable elevated (sudo/host-level) exec access for OpenClaw agents across providers (Telegram, Discord, WhatsApp, Slack). Use when an agent cannot run sudo or host-level commands because elevated exec is disabled, or when onboarding a new agent that needs host-level access. Also use to audit or restrict elevated exec permissions across a fleet of agents.
---

# Elevated Exec Approval

Enable agents to run host-level commands (sudo, system scripts, package installs) from chat providers.

## When to Use

- Agent says "elevated exec is disabled" or "I can't run sudo"
- Setting up a new agent that needs host access
- Auditing which agents have elevated access
- Restricting elevated access after a one-time task

## Workflow

### 1. Check Current State

```bash
# Read the agent's config
cat ~/.openclaw/openclaw.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(json.dumps(d.get('tools',{}).get('elevated',{}), indent=2))
"
```

### 2. Enable Elevated Exec

```bash
python3 -c "
import json
p='$HOME/.openclaw/openclaw.json'
d=json.load(open(p))
if 'tools' not in d: d['tools'] = {}
d['tools']['elevated'] = {
    'enabled': True,
    'allowFrom': {
        'telegram': ['*']
    }
}
json.dump(d, open(p,'w'), indent=2)
"
```

### 3. Per-Provider Control

Replace `['*']` with specific user IDs to restrict:

```json
{
  "tools": {
    "elevated": {
      "enabled": true,
      "allowFrom": {
        "telegram": ["855505513"],
        "discord": ["1457708441677332592"]
      }
    }
  }
}
```

Supported providers: `telegram`, `discord`, `whatsapp`, `slack`, `signal`, `matrix`

### 4. Restart Gateway

```bash
openclaw gateway restart
```

Or on macOS:
```bash
export PATH="/opt/homebrew/bin:$PATH" && openclaw gateway restart
```

### 5. Verify

```bash
# Check config applied
openclaw config get tools.elevated
```

Or ask the agent to run a test command like `whoami` with elevated flag.

## Security Notes

- `allowFrom` values **must be arrays** (e.g. `["*"]`), not booleans
- Use `["*"]` to allow all users from that provider, or specific user IDs for restriction
- Elevated exec means the agent can run **any** command on the host — treat with care
- For fleet agents, prefer specific user IDs over `["*"]`
- Disable after one-time tasks if ongoing elevated access isn't needed

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Invalid input: expected array, received boolean` | Used `true` instead of `["*"]` | Change value to array |
| `elevated exec is disabled` | Config not set or gateway not restarted | Set config + restart |
| `config is invalid` | Wrong schema shape | Ensure `allowFrom.<provider>` is array |
