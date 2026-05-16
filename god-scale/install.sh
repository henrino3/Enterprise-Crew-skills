#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${GOD_SCALE_HOME:-$HOME/.god-scale}"
BIN_DIR="${GOD_SCALE_BIN_DIR:-$HOME/.local/bin}"

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
  echo "Note: $BIN_DIR is not on PATH for this shell. Add: export PATH="$BIN_DIR:\$PATH""
fi
echo "Verify: $BIN_DIR/god-scale --version && $BIN_DIR/god-scale doctor"
