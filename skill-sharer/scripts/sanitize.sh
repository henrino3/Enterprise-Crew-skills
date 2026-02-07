#!/bin/bash
# sanitize.sh — Strip personal/security info from skill files
# Usage: sanitize.sh <input-dir> <output-dir>
set -euo pipefail

INPUT_DIR="$1"
OUTPUT_DIR="$2"

if [[ -z "$INPUT_DIR" || -z "$OUTPUT_DIR" ]]; then
  echo "Usage: sanitize.sh <input-dir> <output-dir>"
  exit 1
fi

# Copy everything first
cp -r "$INPUT_DIR"/. "$OUTPUT_DIR"/

# Remove any secrets files that shouldn't be there
find "$OUTPUT_DIR" -type f \( -name "*.key" -o -name "*.pem" -o -name "*.env" -o -name "*.secret" -o -name "*.credentials" \) -delete
find "$OUTPUT_DIR" -type d -name "secrets" -exec rm -rf {} + 2>/dev/null || true
find "$OUTPUT_DIR" -type f -name ".env*" -delete 2>/dev/null || true

# File extensions to sanitize (text files only)
TEXT_EXTENSIONS="sh|mjs|js|ts|py|md|txt|json|yaml|yml|toml|cfg|conf|ini|html|css|jsx|tsx"

# Process each text file
find "$OUTPUT_DIR" -type f | while read -r file; do
  # Skip binary files
  if file "$file" | grep -q "binary\|image\|executable\|compressed"; then
    continue
  fi
  
  # Check if it's a text file we should process
  ext="${file##*.}"
  if ! echo "$ext" | grep -qiE "^($TEXT_EXTENSIONS)$"; then
    # Also process files with no extension (like Makefile, Dockerfile)
    if [[ "$ext" == "$file" ]] || file "$file" | grep -q "text"; then
      : # process it
    else
      continue
    fi
  fi

  # === SANITIZATION RULES ===
  
  # 1. Tailscale & private IPs
  sed -i \
    -e 's/100\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/192\.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/10\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/172\.1[6-9]\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/172\.2[0-9]\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/172\.3[0-1]\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    "$file"
  
  # 2. Public IPs (GCP, etc.) — 4-octet patterns not already caught
  sed -i -E 's/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:<REDACTED_IP>/g' "$file" 2>/dev/null || true
  # Specific known public IPs
  sed -i \
    -e 's/35\.189\.73\.115/<REDACTED_IP>/g' \
    -e 's/34\.38\.233\.214/<REDACTED_IP>/g' \
    -e 's/34\.70\.68\.105/<REDACTED_IP>/g' \
    "$file"

  # 3. Home directories and user paths
  sed -i \
    -e 's|/home/henrymascot|/home/user|g' \
    -e 's|/home/jamify|/home/user|g' \
    -e 's|/Users/henrymascot|/Users/user|g' \
    -e 's|~/clawd/secrets/[^ "'\'']*|<YOUR_SECRET_FILE>|g' \
    -e 's|~/clawd-spock|~/agent-workspace|g' \
    -e 's|~/clawd-scotty|~/agent-workspace|g' \
    -e 's|~/clawd|~/agent-workspace|g' \
    "$file"

  # 4. Email addresses (known personal ones)
  sed -i \
    -e 's/henry@curacel\.ai/user@example.com/g' \
    -e 's/henryimascot@gmail\.com/user@example.com/g' \
    -e 's/henrino3@gmail\.com/user@example.com/g' \
    -e 's/superada26@gmail\.com/agent@example.com/g' \
    -e 's/ada@agentmail\.to/agent@example.com/g' \
    -e 's/curaceldev@gmail\.com/dev@example.com/g' \
    -e 's/peopleops@curacel\.ai/user@example.com/g' \
    -e 's/admin@curacel\.ai/admin@example.com/g' \
    "$file"

  # 5. SSH connection strings
  sed -i \
    -e 's/ssh henrymascot@[^ ]*/ssh user@<your-host>/g' \
    -e 's/ssh jamify@[^ ]*/ssh user@<your-host>/g' \
    -e 's/ssh agentsadmin@[^ ]*/ssh user@<your-host>/g' \
    -e 's/ssh ubuntu@[^ ]*/ssh user@<your-host>/g' \
    "$file"

  # 6. Machine/host names
  sed -i \
    -e 's/ada-gateway/<your-gateway>/g' \
    -e 's/castlemascot-r1/<your-host>/g' \
    -e 's/MascotM3/<your-mac>/g' \
    -e 's/MascotM3/<your-mac>/g' \
    "$file"

  # 7. API keys and tokens (generic patterns)
  sed -i -E \
    -e 's/(sk-[a-zA-Z0-9]{20,})/<REDACTED_API_KEY>/g' \
    -e 's/(xoxb-[a-zA-Z0-9-]+)/<REDACTED_TOKEN>/g' \
    -e 's/(xoxp-[a-zA-Z0-9-]+)/<REDACTED_TOKEN>/g' \
    -e 's/(ghp_[a-zA-Z0-9]{36,})/<REDACTED_TOKEN>/g' \
    -e 's/(gho_[a-zA-Z0-9]{36,})/<REDACTED_TOKEN>/g' \
    -e 's/(Bearer [a-zA-Z0-9_./-]{20,})/Bearer <REDACTED_TOKEN>/g' \
    "$file"
  
  # 8. Webhook URLs and hook tokens
  sed -i -E \
    -e 's|hooks\.slack\.com/[^ "]*|hooks.slack.com/<REDACTED>|g' \
    -e 's|/hooks/agent|/hooks/agent|g' \
    -e 's|(HOOK_TOKEN[= ]+)[^ "'\'']+|\1<REDACTED>|g' \
    "$file"

  # 9. Company-specific identifiers (optional — keep generic)
  sed -i \
    -e 's/henrino3/<your-github-user>/g' \
    "$file"

  # 10. Port numbers on redacted IPs (clean up artifacts)
  sed -i -E 's/<REDACTED_IP>:[0-9]+/<REDACTED_IP>:<PORT>/g' "$file"

done

# Count what was sanitized
TOTAL_FILES=$(find "$OUTPUT_DIR" -type f | wc -l)
echo "✅ Sanitized $TOTAL_FILES files in $OUTPUT_DIR"
