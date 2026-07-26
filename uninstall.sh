#!/usr/bin/env bash
#
# Removes the logsentry CLI installed by install.sh.
# Use the same PREFIX you installed with, e.g. PREFIX="$HOME/.local" ./uninstall.sh

set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
DEST="$PREFIX/bin/logsentry"

if [ ! -e "$DEST" ]; then
  printf 'LogSentry is not installed at %s\n' "$DEST"
  exit 0
fi

printf 'Removing %s\n' "$DEST"

if [ -w "$(dirname "$DEST")" ]; then
  rm -f "$DEST"
else
  sudo rm -f "$DEST"
fi

printf 'LogSentry removed. Reports and backups on disk were left untouched.\n'
