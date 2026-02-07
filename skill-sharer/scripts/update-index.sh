#!/bin/bash
# update-index.sh — Update the root README.md skill index
# Usage: update-index.sh <repo-dir> <skill-name> <description>
set -euo pipefail

REPO_DIR="$1"
SKILL_NAME="$2"
DESCRIPTION="$3"
README="$REPO_DIR/README.md"

if [[ ! -f "$README" ]]; then
  echo "❌ No README.md found in $REPO_DIR"
  exit 1
fi

# Check if skill already in the table
if grep -q "| \[${SKILL_NAME}\]" "$README"; then
  # Update existing entry
  sed -i "s|^\(| \[${SKILL_NAME}\].*\)|$|" "$README"
  sed -i "s|^| \[${SKILL_NAME}\].*|$|" "$README" 2>/dev/null || true
  # Replace the line
  sed -i "/| \[${SKILL_NAME}\]/c\\| [${SKILL_NAME}](./${SKILL_NAME}/) | ${DESCRIPTION} |" "$README"
  echo "✅ Updated existing entry for $SKILL_NAME in README"
else
  # Add new entry before the last empty line after the table
  # Find the table and append
  LAST_TABLE_LINE=$(grep -n "^|" "$README" | tail -1 | cut -d: -f1)
  
  if [[ -n "$LAST_TABLE_LINE" ]]; then
    sed -i "${LAST_TABLE_LINE}a\\| [${SKILL_NAME}](./${SKILL_NAME}/) | ${DESCRIPTION} |" "$README"
    echo "✅ Added $SKILL_NAME to README index"
  else
    echo "⚠️  Could not find table in README — appending manually"
    echo "| [${SKILL_NAME}](./${SKILL_NAME}/) | ${DESCRIPTION} |" >> "$README"
  fi
fi
