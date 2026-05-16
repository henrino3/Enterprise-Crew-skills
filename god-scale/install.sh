#!/usr/bin/env bash
set -euo pipefail

REPO_TARBALL_URL="${GOD_SCALE_TARBALL_URL:-https://codeload.github.com/h-mascot/Enterprise-Crew-skills/tar.gz/refs/tags/v1.0.0}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${GOD_SCALE_HOME:-$HOME/.god-scale}"
BIN_DIR="${GOD_SCALE_BIN_DIR:-$HOME/.local/bin}"
TEMP_DIR=""

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

# When run as `bash <(curl ...)`, BASH_SOURCE points at /dev/fd instead of a
# checked-out bundle. Fetch the public repository tarball and install from it.
if [ ! -f "$SOURCE_DIR/SKILL.md" ] || [ ! -d "$SOURCE_DIR/scripts" ]; then
  command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required for remote install" >&2; exit 1; }
  command -v tar >/dev/null 2>&1 || { echo "ERROR: tar is required for remote install" >&2; exit 1; }
  TEMP_DIR="$(mktemp -d)"
  curl -fsSL "$REPO_TARBALL_URL" | tar -xz -C "$TEMP_DIR"
  SOURCE_DIR="$(find "$TEMP_DIR" -type d -path '*/god-scale' | head -1)"
  [ -n "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/SKILL.md" ] || { echo "ERROR: could not locate god-scale bundle in repository archive" >&2; exit 1; }
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Copy bundle without VCS noise.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete --exclude '.git' "$SOURCE_DIR/" "$INSTALL_DIR/"
else
  rm -rf "$INSTALL_DIR.tmp"
  mkdir -p "$INSTALL_DIR.tmp"
  cp -R "$SOURCE_DIR/." "$INSTALL_DIR.tmp/"
  rm -rf "$INSTALL_DIR"
  mv "$INSTALL_DIR.tmp" "$INSTALL_DIR"
fi

cat > "$BIN_DIR/god-scale" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail
GOD_SCALE_HOME="${GOD_SCALE_HOME:-$HOME/.god-scale}"
exec "$GOD_SCALE_HOME/scripts/god-scale" "$@"
WRAPPER
chmod +x "$BIN_DIR/god-scale" "$INSTALL_DIR/scripts/god-scale"

echo "GOD Scale installed to $INSTALL_DIR"
echo "Command: $BIN_DIR/god-scale"
if ! command -v god-scale >/dev/null 2>&1; then
  echo "Note: $BIN_DIR is not on PATH for this shell. Add: export PATH=\"$BIN_DIR:\$PATH\""
fi
echo "Verify: $BIN_DIR/god-scale --version && $BIN_DIR/god-scale doctor"
