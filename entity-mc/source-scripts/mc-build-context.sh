#!/bin/bash
# MC Build Context — assembles a context block for task execution
# Usage: mc-build-context.sh <task_json>
# Reads task JSON from stdin or argument, outputs a context preamble for spawn
set -euo pipefail

TASK_JSON="${1:-$(cat)}"

SKILL=$(echo "$TASK_JSON" | jq -r '.skill // ""')
CONTEXT=$(echo "$TASK_JSON" | jq -r '.context // ""')
TASK_NAME=$(echo "$TASK_JSON" | jq -r '.task_name // ""')
TASK_DESC=$(echo "$TASK_JSON" | jq -r '.task_description // ""')
TASK_ID=$(echo "$TASK_JSON" | jq -r '.task_id // ""')
MODEL=$(echo "$TASK_JSON" | jq -r '.model // ""')

OUTPUT=""

# ── 1. Always-load: baseline memory ──
# These give every subagent awareness of tools, agents, and operational rules
BASELINE_FILES=(
  "$HOME/clawd/memory/tools-reference.md"
  "$HOME/clawd/memory/agents-reference.md"
)

BASELINE_BLOCK=""
for f in "${BASELINE_FILES[@]}"; do
  if [ -f "$f" ]; then
    BASELINE_BLOCK+="--- $(basename $f) ---
$(head -80 "$f")
...
"
  fi
done

if [ -n "$BASELINE_BLOCK" ]; then
  OUTPUT+="## Baseline Context (tools & agents)
$BASELINE_BLOCK
"
fi

# ── 1b. Safety rules (NEVER/ALWAYS constraints) ──
RULES_FILE="$HOME/clawd/memory/rules.md"
if [ -f "$RULES_FILE" ]; then
  # Extract Safety and Credentials sections — the guardrails that prevent expensive mistakes
  SAFETY_BLOCK=$(sed -n '/^## Safety/,/^## [^S]/p' "$RULES_FILE" | head -30)
  CREDS_BLOCK=$(sed -n '/^## Credentials/,/^## [^C]/p' "$RULES_FILE" | head -10)
  DELEGATION_BLOCK=$(sed -n '/^## Delegation/,/^## [^D]/p' "$RULES_FILE" | head -10)
  if [ -n "$SAFETY_BLOCK" ]; then
    OUTPUT+="## Operational Rules (MUST follow)
$SAFETY_BLOCK
$CREDS_BLOCK
$DELEGATION_BLOCK
"
  fi
fi

# ── 1c. Learnings from past failures (top 20) ──
LEARNINGS_FILE="$HOME/clawd/memory/learnings.md"
if [ -f "$LEARNINGS_FILE" ]; then
  OUTPUT+="## Known Pitfalls (from past failures)
$(head -60 "$LEARNINGS_FILE")
...
"
fi

# ── 1d. User preferences (how Henry wants work delivered) ──
USER_MODEL="$HOME/clawd/memory/user-model.md"
if [ -f "$USER_MODEL" ]; then
  OUTPUT+="## User Preferences
$(head -30 "$USER_MODEL")
...
"
fi

# ── 2. Skill loading ──
if [ -n "$SKILL" ] && [ "$SKILL" != "null" ] && [ "$SKILL" != "none" ]; then
  # Try common skill locations
  SKILL_PATH=""
  for dir in "$HOME/clawd/skills/$SKILL" "$HOME/.agents/skills/$SKILL" "$HOME/clawdbot/skills/$SKILL" "$HOME/clawdbot/extensions/acpx/skills/$SKILL"; do
    if [ -f "$dir/SKILL.md" ]; then
      SKILL_PATH="$dir/SKILL.md"
      break
    fi
  done
  
  if [ -n "$SKILL_PATH" ]; then
    OUTPUT+="## Skill Instructions
IMPORTANT: Read and follow the skill file at $SKILL_PATH

"
  else
    OUTPUT+="## Skill
Skill '$SKILL' specified but SKILL.md not found. Proceed with best judgment.

"
  fi
fi

# ── 3. Explicit context files ──
if [ -n "$CONTEXT" ] && [ "$CONTEXT" != "null" ]; then
  IFS=',' read -ra CTX_FILES <<< "$CONTEXT"
  CTX_BLOCK=""
  for cf in "${CTX_FILES[@]}"; do
    cf=$(echo "$cf" | xargs) # trim whitespace
    # Resolve relative paths against ~/clawd/
    if [[ "$cf" != /* ]]; then
      cf="$HOME/clawd/$cf"
    fi
    if [ -f "$cf" ]; then
      CTX_BLOCK+="--- $(basename $cf) ---
$(head -100 "$cf")
...
"
    fi
  done
  if [ -n "$CTX_BLOCK" ]; then
    OUTPUT+="## Project Context
$CTX_BLOCK
"
  fi
fi

# ── 4. Auto-infer project context via qmd search ──
# Uses qmd semantic/BM25 search instead of hardcoded keyword→file mappings.
# Falls back to legacy keyword matching if qmd is unavailable.
COMBINED="$TASK_NAME $TASK_DESC"
INFERRED_CTX=""
QMD_BIN="${QMD_BIN:-$(command -v qmd 2>/dev/null || echo "")}"

if [ -n "$QMD_BIN" ] && [ -x "$QMD_BIN" ]; then
  # Clean query: strip punctuation/noise, keep meaningful words, cap length for BM25
  CLEAN_QUERY=$(echo "$TASK_NAME $TASK_DESC" | sed 's/[^a-zA-Z0-9 ]/ /g' | tr -s ' ')
  CLEAN_QUERY=$(echo "$CLEAN_QUERY" | tr ' ' '\n' | grep -viE '^(a|an|the|and|or|for|to|in|on|of|is|it|with|from|by|as|at|be|has|was|are|will|this|that)$' | head -8 | tr '\n' ' ')
  NAME_QUERY=$(echo "$TASK_NAME" | sed 's/[^a-zA-Z0-9 ]/ /g' | tr -s ' ')

  # ── Query expansion via cheap LLM call ──
  # Generate 2-3 alternate phrasings so BM25 can find files with different vocabulary
  EXPANDED_QUERIES=""
  # Query expansion via Gemini Flash (cheapest, fastest)
  GEMINI_KEY="${GEMINI_API_KEY:-}"
  if [ -z "$GEMINI_KEY" ]; then
    for kf in "$HOME/clawd/secrets/gemini-api-key" "$HOME/clawd/secrets/gemini" "$HOME/.hermes/secrets/gemini"; do
      [ -f "$kf" ] && GEMINI_KEY=$(cat "$kf") && break
    done
  fi
  if [ -n "$GEMINI_KEY" ]; then
    EXPAND_BODY=$(jq -n --arg t "$TASK_NAME" '{
      contents: [{parts: [{text: ("Given this task: \"" + $t + "\"\nGenerate exactly 3 short search queries (max 5 words each) that would find relevant files in a codebase. Use different vocabulary/synonyms for each. Output one per line, nothing else.")}]}],
      generationConfig: {maxOutputTokens: 60, temperature: 0.3}
    }')
    EXPANDED_QUERIES=$(timeout 8 curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_KEY" \
      -H "Content-Type: application/json" -d "$EXPAND_BODY" 2>/dev/null | \
      jq -r '.candidates[0].content.parts[0].text // ""' 2>/dev/null | \
      grep -v '^$' | head -3 || true)
  fi

  # Search: original queries + expanded variants
  QMD_RESULTS=""
  ALL_QUERIES=("$CLEAN_QUERY" "$NAME_QUERY")
  if [ -n "$EXPANDED_QUERIES" ]; then
    while IFS= read -r eq; do
      eq=$(echo "$eq" | sed 's/^[0-9]*[.):-]* *//' | sed 's/[^a-zA-Z0-9 ]/ /g' | tr -s ' ' | xargs)
      [ -n "$eq" ] && ALL_QUERIES+=("$eq")
    done <<< "$EXPANDED_QUERIES"
  fi

  for QUERY in "${ALL_QUERIES[@]}"; do
    [ -z "$QUERY" ] && continue
    for coll in output docs skills; do
      COLL_HITS=$(timeout 5 "$QMD_BIN" search "$QUERY" -n 2 --files -c "$coll" 2>/dev/null || true)
      [ -n "$COLL_HITS" ] && QMD_RESULTS+="$COLL_HITS"$'\n'
    done
    # Memory collection but exclude sessions/
    MEM_HITS=$(timeout 5 "$QMD_BIN" search "$QUERY" -n 3 --files -c memory 2>/dev/null | grep -v '/sessions/' || true)
    [ -n "$MEM_HITS" ] && QMD_RESULTS+="$MEM_HITS"$'\n'
  done
  # Deduplicate by path and take top 5
  QMD_RESULTS=$(echo "$QMD_RESULTS" | grep -v '^$' | sort -t, -k3 -u | sort -t, -k2 -rn | head -5)
  # Future: when embeddings are fully built, add qmd query fallback here
  # Currently disabled because qmd query hangs if embeddings are incomplete
  
  if [ -n "$QMD_RESULTS" ]; then
    while IFS=',' read -r _docid _score filepath _ctx; do
      # Skip if empty or already in explicit context
      [ -z "$filepath" ] && continue
      # Resolve qmd:// paths to real filesystem paths
      # Collection mapping: qmd://memory/ -> ~/clawd/memory/, qmd://output/ -> ~/clawd/output/, etc.
      REAL_PATH=$(echo "$filepath" | sed \
        -e "s|^qmd://memory/|$HOME/clawd/memory/|" \
        -e "s|^qmd://output/|$HOME/clawd/output/|" \
        -e "s|^qmd://docs/|$HOME/clawd/docs/|" \
        -e "s|^qmd://skills/|$HOME/clawd/skills/|")
      # If still qmd:// or not absolute, skip
      if [[ "$REAL_PATH" == qmd://* ]] || [[ ! "$REAL_PATH" == /* ]]; then
        continue
      fi
      [ -f "$REAL_PATH" ] || continue
      BASENAME=$(basename "$REAL_PATH")
      # Skip if already loaded via explicit context
      echo "$CONTEXT" | grep -q "$BASENAME" && continue
      # Skip baseline files (already loaded in section 1)
      case "$BASENAME" in
        tools-reference.md|agents-reference.md|rules.md|learnings.md|user-model.md) continue ;;
      esac
      INFERRED_CTX+="--- $BASENAME (qmd-discovered) ---
$(head -100 "$REAL_PATH")
...
"
    done <<< "$QMD_RESULTS"
  fi
else
  # Fallback: keyword-to-context-file matching when qmd is not available
  # Users can customize by creating a context map file at:
  #   $HOME/.entity-mc/context-map.conf
  # Format: one entry per line: KEYWORD_REGEX|PATH_TO_CONTEXT_FILE
  # Example:
  #   deploy|ci/cd|pipeline|$HOME/clawd/memory/deploy-context.md
  #   blog|article|publish|$HOME/clawd/memory/blog-context.md
  CONTEXT_MAP="${MC_CONTEXT_MAP:-$HOME/.entity-mc/context-map.conf}"
  if [[ -f "$CONTEXT_MAP" ]]; then
    while IFS='|' read -r keywords ctx_file; do
      # Skip comments and empty lines
      [[ "$keywords" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$keywords" ]] && continue
      # Last pipe-delimited field is the file path
      ctx_file=$(echo "$keywords" | rev | cut -d'|' -f1 | rev)
      keywords=$(echo "$keywords" | rev | cut -d'|' -f2- | rev)
      ctx_file=$(eval echo "$ctx_file")  # Expand $HOME etc.
      if echo "$COMBINED" | grep -qiE "$keywords"; then
        local base
        base=$(basename "$ctx_file")
        if [[ -f "$ctx_file" ]] && ! echo "$CONTEXT" | grep -q "$base"; then
          INFERRED_CTX+="--- $base (keyword-inferred) ---
$(head -80 "$ctx_file")
...
"
        fi
      fi
    done < "$CONTEXT_MAP"
  fi
  # Default: check for tools-setup.md on openclaw-related tasks
  if echo "$COMBINED" | grep -qiE 'openclaw|gateway|cron|plugin|heartbeat'; then
    CTX_FILE="$HOME/clawd/memory/tools-setup.md"
    if [ -f "$CTX_FILE" ] && ! echo "$CONTEXT" | grep -q "tools-setup"; then
      INFERRED_CTX+="--- tools-setup.md (keyword-inferred) ---
$(head -80 "$CTX_FILE")
...
"
    fi
  fi
fi

if [ -n "$INFERRED_CTX" ]; then
  OUTPUT+="## Auto-Discovered Context
$INFERRED_CTX
"
fi

# ── 5. Task itself ──
OUTPUT+="## Task #$TASK_ID: $TASK_NAME
$TASK_DESC

## When done
Run: bash ~/clawd/scripts/mc.sh review $TASK_ID \"Brief summary of what was done\"
If blocked: bash ~/clawd/scripts/mc.sh update $TASK_ID --column todo --note \"Blocker: <reason>\"
"

echo "$OUTPUT"
