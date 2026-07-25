#!/usr/bin/env bash
#
# Installs the logsentry CLI.
#
#   ./install.sh                     -> /usr/local/bin/logsentry (uses sudo if needed)
#   PREFIX="$HOME/.local" ./install.sh  -> ~/.local/bin/logsentry (no sudo)

set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="$PREFIX/bin"
SRC="$(cd "$(dirname "$0")" && pwd)/logsentry"
DEST="$BIN_DIR/logsentry"

[ -f "$SRC" ] || {
  printf 'install: cannot find logsentry next to this script (%s)\n' "$SRC" >&2
  exit 1
}

printf 'Installing LogSentry CLI to %s\n' "$DEST"

# Only reach for sudo when the target really is not writable.
if mkdir -p "$BIN_DIR" 2>/dev/null && [ -w "$BIN_DIR" ]; then
  install -m 755 "$SRC" "$DEST"
else
  printf 'Elevated permissions required for %s\n' "$BIN_DIR"
  sudo mkdir -p "$BIN_DIR"
  sudo install -m 755 "$SRC" "$DEST"
fi

printf 'Installed: %s\n' "$("$DEST" --version)"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Note: %s is not on your PATH; add it in your shell profile to run logsentry from anywhere.\n' "$BIN_DIR" ;;
esac
