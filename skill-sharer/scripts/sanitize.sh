#!/bin/bash
# sanitize.sh — Strip personal/security info from skill files
# Usage: sanitize.sh <input-dir> <output-dir>
#
# Reads replacement rules from sanitize-rules.conf (local, never published).
# Falls back to generic patterns (IPs, API keys, tokens) if no conf found.
set -euo pipefail

INPUT_DIR="$1"
OUTPUT_DIR="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_FILE="$SCRIPT_DIR/sanitize-rules.conf"

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

# Build sed commands from rules file
SED_COMMANDS=""
if [[ -f "$RULES_FILE" ]]; then
  while IFS='|' read -r type pattern replacement; do
    # Skip comments and empty lines
    [[ "$type" =~ ^#.*$ || -z "$type" ]] && continue
    # Escape sed special chars in pattern
    escaped_pattern=$(echo "$pattern" | sed 's/[.[\/*^$]/\\&/g')
    escaped_replacement=$(echo "$replacement" | sed 's/[&/\]/\\&/g')
    
    case "$type" in
      path)   SED_COMMANDS="$SED_COMMANDS -e 's|${pattern}|${replacement}|g'" ;;
      email)  SED_COMMANDS="$SED_COMMANDS -e 's/${escaped_pattern}/${escaped_replacement}/g'" ;;
      ssh)    SED_COMMANDS="$SED_COMMANDS -e 's/ssh ${pattern}@[^ ]*/ssh ${replacement}@<your-host>/g'" ;;
      host)   SED_COMMANDS="$SED_COMMANDS -e 's/${escaped_pattern}/${escaped_replacement}/g'" ;;
      ip)     SED_COMMANDS="$SED_COMMANDS -e 's/${escaped_pattern}/${escaped_replacement}/g'" ;;
      github) SED_COMMANDS="$SED_COMMANDS -e 's/${escaped_pattern}/${escaped_replacement}/g'" ;;
      secret) SED_COMMANDS="$SED_COMMANDS -e 's|${pattern}[^ \"'\'']*|${replacement}|g'" ;;
    esac
  done < "$RULES_FILE"
fi

# Process each text file
find "$OUTPUT_DIR" -type f | while read -r file; do
  # Skip binary files
  if file "$file" | grep -q "binary\|image\|executable\|compressed"; then
    continue
  fi
  
  # Check if it's a text file we should process
  ext="${file##*.}"
  if ! echo "$ext" | grep -qiE "^($TEXT_EXTENSIONS)$"; then
    if [[ "$ext" == "$file" ]] || file "$file" | grep -q "text"; then
      : # process it
    else
      continue
    fi
  fi

  # === GENERIC PATTERNS (always applied) ===
  
  # 1. Private/Tailscale IPs
  sed -i \
    -e 's/100\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/192\.168\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/10\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/172\.1[6-9]\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/172\.2[0-9]\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    -e 's/172\.3[0-1]\.[0-9]\{1,3\}\.[0-9]\{1,3\}/<REDACTED_IP>/g' \
    "$file"

  # 2. API keys and tokens (generic patterns)
  sed -i -E \
    -e 's/(sk-[a-zA-Z0-9]{20,})/<REDACTED_API_KEY>/g' \
    -e 's/(xoxb-[a-zA-Z0-9-]+)/<REDACTED_TOKEN>/g' \
    -e 's/(xoxp-[a-zA-Z0-9-]+)/<REDACTED_TOKEN>/g' \
    -e 's/(ghp_[a-zA-Z0-9]{36,})/<REDACTED_TOKEN>/g' \
    -e 's/(gho_[a-zA-Z0-9]{36,})/<REDACTED_TOKEN>/g' \
    -e 's/(Bearer [a-zA-Z0-9_./-]{20,})/Bearer <REDACTED_TOKEN>/g' \
    "$file"
  
  # 3. Webhook URLs
  sed -i -E \
    -e 's|hooks\.slack\.com/[^ "]*|hooks.slack.com/<REDACTED>|g' \
    -e 's|(HOOK_TOKEN[= ]+)[^ "'\'']+|\1<REDACTED>|g' \
    "$file"

  # 4. Port numbers on redacted IPs
  sed -i -E 's/<REDACTED_IP>:[0-9]+/<REDACTED_IP>:<PORT>/g' "$file"

  # 5. Apply rules from conf file (personal info)
  if [[ -n "$SED_COMMANDS" ]]; then
    eval "sed -i $SED_COMMANDS \"$file\""
  fi

done

# Count what was sanitized
TOTAL_FILES=$(find "$OUTPUT_DIR" -type f | wc -l)
echo "✅ Sanitized $TOTAL_FILES files in $OUTPUT_DIR"
