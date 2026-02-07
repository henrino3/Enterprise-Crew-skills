# Skill Sharer

Share skills publicly to GitHub with automatic sanitization of personal info, secrets, and IPs.

## What it does

1. Copies a skill into a clean staging folder
2. Strips personal information (IPs, emails, paths, API keys, tokens, SSH strings)
3. Generates a standalone README for the skill
4. Updates the repo's root README index
5. Commits and pushes to GitHub

## Usage

```bash
# Share a skill
./scripts/share-skill.sh /path/to/skill --description "Short description"

# Auto-confirm (skip prompt)
./scripts/share-skill.sh /path/to/skill --description "Short description" --yes

# Custom skill name
./scripts/share-skill.sh /path/to/skill --name "my-skill" --description "Does cool things"
```

## Configuration

### sanitize-rules.conf

Create a `scripts/sanitize-rules.conf` file (never committed) with your personal replacement rules:

```
# Format: type|pattern|replacement
path|/home/youruser|/home/user
email|you@company.com|user@example.com
ssh|youruser|user
host|your-server|<your-host>
ip|1.2.3.4|<REDACTED_IP>
github|yourgithub|<your-github-user>
secret|~/secrets/|<YOUR_SECRET_FILE>
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SKILL_SHARER_REPO` | `Enterprise-Crew-skills` | Target repo name |
| `SKILL_SHARER_OWNER` | (your GitHub user) | Repo owner |

## Built-in sanitization (always active)

Even without a rules file, the sanitizer strips:
- Private/Tailscale IPs (10.x, 172.16-31.x, 192.168.x, 100.x)
- API keys (sk-*, ghp_*, gho_*, xoxb-*, xoxp-*)
- Bearer tokens
- Slack webhook URLs
- Secret files (.key, .pem, .env, .secret, .credentials)

## Scripts

- `share-skill.sh` — Main entry point
- `sanitize.sh` — Strips personal info from files
- `generate-readme.sh` — Creates a README for the skill
- `update-index.sh` — Updates the repo's root README table

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`) — authenticated
- bash, sed, find
- Git

## License

MIT
