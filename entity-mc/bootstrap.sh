#!/usr/bin/env bash
# Entity MC Bootstrap — one-command setup for Mission Control integration
# Usage: bash bootstrap.sh [--entity-url URL] [--agent NAME] [--workspace DIR]
#
# Interactive if no flags provided. Sets up:
# 1. Agent manifest (env file)
# 2. MC helper scripts (mc.sh, mc-auto-pull.sh, etc.)
# 3. Cron jobs for auto-pull and stall-check
# 4. Verification
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults
ENTITY_URL=""
AGENT_NAME=""
WORKSPACE=""
INSTALL_CRONS="true"
AUTO_PULL="true"
STALL_CHECK="true"
PROFILE_NAME=""
RUNTIME="openclaw"
OPENCLAW_BIN=""
SKIP_INTERACTIVE=""

usage() {
  cat <<'EOF'
Entity MC Bootstrap — set up Mission Control for your agent

Usage:
  bash bootstrap.sh [OPTIONS]

Options:
  --entity-url URL     Entity/Mission Control base URL (e.g. http://localhost:3000)
  --agent NAME         Agent display name in MC (e.g. "Ada", "MyBot")
  --workspace DIR      OpenClaw workspace root (default: ~/clawd or auto-detect)
  --no-crons           Skip cron job installation
  --no-auto-pull       Disable auto-pull (agent won't pick up tasks automatically)
  --no-stall-check     Disable stall-check alerts
  --profile NAME       OpenClaw profile name (if using named profiles)
  --runtime TYPE       Runtime: "openclaw" (default) or "hermes"
  --openclaw-bin PATH  Path to openclaw binary (auto-detected if on PATH)
  --yes                Skip interactive prompts, use defaults + flags
  -h, --help           Show this help

Examples:
  # Interactive setup
  bash bootstrap.sh

  # Non-interactive
  bash bootstrap.sh --entity-url http://my-server:3000 --agent "Scout" --workspace ~/clawd --yes

  # Minimal — just scripts, no crons
  bash bootstrap.sh --entity-url http://my-server:3000 --agent "Scout" --no-crons --yes
EOF
  exit 0
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --entity-url) ENTITY_URL="$2"; shift 2 ;;
    --agent) AGENT_NAME="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --no-crons) INSTALL_CRONS="false"; shift ;;
    --no-auto-pull) AUTO_PULL="false"; shift ;;
    --no-stall-check) STALL_CHECK="false"; shift ;;
    --profile) PROFILE_NAME="$2"; shift 2 ;;
    --runtime) RUNTIME="$2"; shift 2 ;;
    --openclaw-bin) OPENCLAW_BIN="$2"; shift 2 ;;
    --yes|-y) SKIP_INTERACTIVE="true"; shift ;;
    --help|-h) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# Auto-detect workspace
detect_workspace() {
  if [[ -n "$WORKSPACE" ]]; then return; fi
  # Check common locations
  for candidate in "$HOME/clawd" "$HOME/.openclaw/workspace" "$HOME/.openclaw" "$PWD"; do
    if [[ -d "$candidate" ]]; then
      WORKSPACE="$candidate"
      return
    fi
  done
  WORKSPACE="$HOME/clawd"
}

# Auto-detect openclaw binary
detect_openclaw_bin() {
  if [[ -n "$OPENCLAW_BIN" ]]; then return; fi
  if command -v openclaw >/dev/null 2>&1; then
    OPENCLAW_BIN="$(command -v openclaw)"
  elif [[ -x "$HOME/.local/share/pnpm/openclaw" ]]; then
    OPENCLAW_BIN="$HOME/.local/share/pnpm/openclaw"
  elif [[ -x "/usr/local/bin/openclaw" ]]; then
    OPENCLAW_BIN="/usr/local/bin/openclaw"
  fi
}

# Interactive prompts
interactive_setup() {
  [[ "$SKIP_INTERACTIVE" == "true" ]] && return

  echo "━━━ Entity MC Bootstrap ━━━"
  echo ""

  if [[ -z "$ENTITY_URL" ]]; then
    read -rp "Entity/Mission Control URL (e.g. http://localhost:3000): " ENTITY_URL
  fi

  if [[ -z "$AGENT_NAME" ]]; then
    read -rp "Agent name (how it appears in MC, e.g. 'Ada'): " AGENT_NAME
  fi

  detect_workspace
  read -rp "Workspace directory [$WORKSPACE]: " input_ws
  [[ -n "$input_ws" ]] && WORKSPACE="$input_ws"

  if [[ "$INSTALL_CRONS" == "true" ]]; then
    read -rp "Install cron jobs for auto-pull & stall-check? [Y/n]: " input_cron
    [[ "$input_cron" =~ ^[Nn] ]] && INSTALL_CRONS="false"
  fi

  echo ""
}

# Validate
validate() {
  if [[ -z "$ENTITY_URL" ]]; then
    echo "ERROR: --entity-url is required" >&2
    exit 1
  fi
  if [[ -z "$AGENT_NAME" ]]; then
    echo "ERROR: --agent is required" >&2
    exit 1
  fi

  detect_workspace
  detect_openclaw_bin

  # Strip trailing slash from URL
  ENTITY_URL="${ENTITY_URL%/}"

  # Test Entity connectivity
  echo "Testing connection to $ENTITY_URL ..."
  if ! curl -sf --max-time 10 "$ENTITY_URL/api/tasks?column=todo&limit=1" >/dev/null 2>&1; then
    echo "WARNING: Could not reach $ENTITY_URL/api/tasks — continuing anyway (check URL later)" >&2
  else
    echo "  ✓ Entity reachable"
  fi

  echo "  Agent:     $AGENT_NAME"
  echo "  Workspace: $WORKSPACE"
  echo "  Crons:     $INSTALL_CRONS"
  echo "  Runtime:   $RUNTIME"
  [[ -n "$OPENCLAW_BIN" ]] && echo "  Binary:    $OPENCLAW_BIN"
  echo ""
}

# No source-script patching needed — MC_URL is set via env in manifests/wrappers.
# The source scripts default to localhost:3000, but the manifest's MC_URL takes precedence
# because the wrapper stubs export it before exec'ing the real script.
patch_entity_url() {
  : # noop — handled by manifest + lib.sh MC_URL export
}

# Generate manifest
generate_manifest() {
  local manifest_path="$SCRIPT_DIR/manifests/${AGENT_NAME,,}.env"
  local scripts_dir="${WORKSPACE}/scripts"
  local state_dir="${WORKSPACE}/.entity-mc"

  cat > "$manifest_path" <<EOF
# Auto-generated by bootstrap.sh — $(date -Iseconds)
ENTITY_MC_AGENT_NAME="${AGENT_NAME}"
ENTITY_MC_TARGET_HOME="${WORKSPACE}"
ENTITY_MC_TARGET_SCRIPTS_DIR="${scripts_dir}"
ENTITY_MC_STATE_DIR="${state_dir}"
ENTITY_MC_MODE="copy"
ENTITY_MC_INSTALL_CRON="${INSTALL_CRONS}"
ENTITY_MC_ENABLE_AUTO_PULL="${AUTO_PULL}"
ENTITY_MC_ENABLE_STALL_CHECK="${STALL_CHECK}"
ENTITY_MC_AUTO_PULL_SCHEDULE="*/30 * * * *"
ENTITY_MC_STALL_CHECK_SCHEDULE="0 */2 * * *"
ENTITY_MC_MC_URL="${ENTITY_URL}"
ENTITY_MC_RUNTIME="${RUNTIME}"
$([ -n "$PROFILE_NAME" ] && echo "ENTITY_MC_PROFILE_NAME=\"${PROFILE_NAME}\"")
$([ -n "$OPENCLAW_BIN" ] && echo "ENTITY_MC_OPENCLAW_BIN=\"${OPENCLAW_BIN}\"")
ENTITY_MC_EXTRA_NOTES="Generated by bootstrap.sh"
EOF

  echo "$manifest_path"
}

# Main
interactive_setup
validate

echo "━━━ Installing ━━━"

# 1. Patch Entity URL in source scripts
echo "1. Patching Entity URL in scripts..."
patch_entity_url
echo "  ✓ Scripts patched to use $ENTITY_URL"

# 2. Generate manifest
echo "2. Generating manifest..."
MANIFEST_PATH="$(generate_manifest)"
echo "  ✓ Manifest: $MANIFEST_PATH"

# 3. Run installer
echo "3. Installing MC runtime..."
bash "$SCRIPT_DIR/install.sh" --manifest "$MANIFEST_PATH"
echo "  ✓ Runtime installed"

# 4. Verify
echo "4. Verifying..."
if bash "$SCRIPT_DIR/verify.sh" --manifest "$MANIFEST_PATH" | grep -q "VERIFY_OK"; then
  echo "  ✓ Verification passed"
else
  echo "  ✗ Verification failed — check output above" >&2
  exit 1
fi

# 5. Summary
echo ""
echo "━━━ Setup Complete ━━━"
echo ""
echo "MC scripts installed to: ${WORKSPACE}/scripts/"
echo "State directory: ${WORKSPACE}/.entity-mc/"
echo "Manifest: $MANIFEST_PATH"
echo ""
echo "Available commands:"
echo "  ${WORKSPACE}/scripts/mc.sh list                 # List tasks"
echo "  ${WORKSPACE}/scripts/mc.sh create \"Title\" \"Desc\" # Create task"
echo "  ${WORKSPACE}/scripts/mc.sh note <id> \"Update\"    # Add note"
echo "  ${WORKSPACE}/scripts/mc.sh review <id> \"output\"  # Move to review"
echo "  ${WORKSPACE}/scripts/mc.sh done <id>             # Complete task"
echo ""

if [[ "$INSTALL_CRONS" == "true" ]]; then
  echo "Cron jobs installed:"
  [[ "$AUTO_PULL" == "true" ]] && echo "  Auto-pull: every 30 min (agent picks up todo tasks)"
  [[ "$STALL_CHECK" == "true" ]] && echo "  Stall-check: every 2 hours (alerts on stuck tasks)"
  echo ""
  echo "View crons: crontab -l | grep ENTITY_MC"
fi

echo ""
echo "Add this to your agent's AGENTS.md or system prompt:"
echo "  ## Mission Control"
echo "  MC URL: $ENTITY_URL"
echo "  MC scripts: ${WORKSPACE}/scripts/mc.sh"
echo "  Use mc.sh for task management. Auto-pull runs every 30 min."
echo ""
echo "Done! 🚀"
